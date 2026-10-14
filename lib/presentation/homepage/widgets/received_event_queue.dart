import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/constants.dart';
import '../../../utils/db.dart';
import '../../../utils/helping_function.dart';

/// Model for a received call or SMS event
class ReceivedEvent {
  final String eventId;
  final String mobile;
  final String message;
  final DateTime receivedAt;
  bool isSent;

  ReceivedEvent({
    required this.eventId,
    required this.mobile,
    required this.message,
    required this.receivedAt,
    this.isSent = false,
  });

  factory ReceivedEvent.fromJson(Map<String, dynamic> json) {
    return ReceivedEvent(
      eventId: json['eventId'] ?? '',
      mobile: json['mobile'] ?? '',
      message: json['message'] ?? '',
      receivedAt: DateTime.tryParse(json['receivedAt'] ?? '') ?? DateTime.now(),
      isSent: json['isSent'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'mobile': mobile,
      'message': message,
      'receivedAt': receivedAt.toIso8601String(),
      'isSent': isSent,
    };
  }
}

class ReceivedEventQueue {
  static const String _queueKey = 'received_event_queue';
  static const String _processedIdsKey = 'received_event_processed_ids';
  static const int _maxRetries = 3;
  static const int _maxProcessedIdsStored = 500;

  /// In-memory queue for events received while offline
  static final List<ReceivedEvent> _memoryQueue = [];

  /// Prevent concurrent flushes
  static bool _isFlushing = false;

  /// ── Add event — called from call/SMS listener ─────────────────────────────
  /// Fire and forget — never blocks the caller
  static void enqueue(String mobile, String message, {String? eventId}) {
    final key =
        eventId ??
        'fallback_${mobile}_${message}_${DateTime.now().millisecondsSinceEpoch ~/ 10000}';
    _enqueueInternal(key, mobile, message);
  }

  static Future<void> _enqueueInternal(
    String key,
    String mobile,
    String message,
  ) async {
    try {
      final alreadyProcessed = await _isDuplicate(key);
      if (alreadyProcessed) {
        developer.log("ReceivedEventQueue: Duplicate skipped — key=$key");
        return;
      }

      await _markProcessed(key);

      final event = ReceivedEvent(
        eventId: key,
        mobile: mobile,
        message: message,
        receivedAt: DateTime.now(),
      );

      developer.log(
        "ReceivedEventQueue: Enqueued — key=$key mobile=$mobile message=$message",
      );

      _memoryQueue.add(event);
      await _persistMemoryQueue();
      unawaited(_tryFlush());
    } catch (e) {
      developer.log("ReceivedEventQueue: _enqueueInternal error: $e");
    }
  }

  static Future<bool> _isDuplicate(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final processed = prefs.getStringList(_processedIdsKey) ?? [];
      return processed.contains(key);
    } catch (e) {
      developer.log("ReceivedEventQueue: _isDuplicate error: $e");
      return false; // fail open — better to risk a rare dupe than lose a message
    }
  }

  static Future<void> _markProcessed(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final processed = prefs.getStringList(_processedIdsKey) ?? [];
      processed.add(key);
      // Cap the list so SharedPreferences doesn't grow unbounded over time
      final trimmed = processed.length > _maxProcessedIdsStored
          ? processed.sublist(processed.length - _maxProcessedIdsStored)
          : processed;
      await prefs.setStringList(_processedIdsKey, trimmed);
    } catch (e) {
      developer.log("ReceivedEventQueue: _markProcessed error: $e");
    }
  }

  /// ── Try to send all pending events ────────────────────────────────────────
  /// Called on enqueue and when internet restores
  static Future<void> _tryFlush() async {
    if (_isFlushing) return;
    _isFlushing = true;

    try {
      await _mergeFromDisk();

      final pending = _memoryQueue.where((e) => !e.isSent).toList();

      if (pending.isEmpty) {
        developer.log("ReceivedEventQueue: Nothing to flush.");
        return;
      }

      developer.log(
        "ReceivedEventQueue: Flushing ${pending.length} event(s) in one batch...",
      );

      final success = await _sendEventsBatch(pending);

      if (success) {
        for (final event in pending) {
          event.isSent = true;
        }
        developer.log(
          "ReceivedEventQueue: Batch sent — ${pending.length} event(s).",
        );
      } else {
        developer.log(
          "ReceivedEventQueue: Batch failed to send. Will retry on next internet restore.",
        );
      }

      _memoryQueue.removeWhere((e) => e.isSent);
      await _persistMemoryQueue();

      developer.log(
        "ReceivedEventQueue: Flush complete. "
        "${_memoryQueue.length} unsent remaining.",
      );
    } catch (e) {
      developer.log("ReceivedEventQueue: Flush error: $e");
    } finally {
      _isFlushing = false;
    }
  }

  /// ── Called by HomepageCon when internet comes back ────────────────────────
  static Future<void> flushOnInternetRestore() async {
    developer.log("ReceivedEventQueue: Internet restored — flushing queue...");
    await _tryFlush();
  }

  /// ── Send batch of events to API in a single call ──────────────────────────
  static Future<bool> _sendEventsBatch(List<ReceivedEvent> events) async {
    if (events.isEmpty) return true;

    if (Constants.email.isEmpty || Constants.password.isEmpty) {
      try {
        final db = await SQLite.instance.database;
        final queryData = await db.rawQuery(
          "SELECT Email, Password, Mobile FROM User WHERE UserID = 0",
        );
        if (queryData.isNotEmpty) {
          final row = queryData[0];
          Constants.email = row["Email"]?.toString() ?? "";
          Constants.password = row["Password"]?.toString() ?? "";
          Constants.mobile = row["Mobile"]?.toString() ?? "";
          Constants.isLogin = true;
        }
      } catch (e) {
        developer.log("ReceivedEventQueue: credential rehydration error: $e");
      }
    }

    int attempt = 0;
    Duration delay = const Duration(seconds: 2);

    while (attempt < _maxRetries) {
      attempt++;
      try {
        final jsonMap = {
          'DocType': 'ReceivedSMS',
          'DocDate': DateTime.now().toString(),
          'AppType': defaultTargetPlatform == TargetPlatform.iOS
              ? 'iOS'
              : 'Android',
          'UserName': Constants.email,
          'Password': Constants.password,
          'Mobile': events.map((e) => e.mobile).toList(),
          'Message': events.map((e) => e.message).toList(),
          'SMSDate': events.map((e) => e.receivedAt.toIso8601String()).toList(),
          'AppVersion': "1.0",
          'Token': Constants.appToken,
          'ClientMobID': Constants.clientMobID,
          'ClientID': Constants.clientID,
          'DeviceName': "${Constants.mobileName}-${Constants.mobile}",
        };
        developer.log("SMS REC BATCH JSON (${events.length} events): $jsonMap");
        final response = await Functions.sendJson(
          jsonMap,
          'sms_received',
        ).timeout(const Duration(seconds: 15));

        if (response == null || response == '') {
          developer.log("ReceivedEventQueue: Empty response attempt $attempt");
        } else if (response["DocType"] == "ReceivedSMS" &&
            response["Message"] == "Done") {
          return true;
        } else if (response["DocType"] == "Error") {
          developer.log(
            "ReceivedEventQueue: API error: ${response["Message"]}",
          );
          return false;
        }
      } catch (e) {
        developer.log("ReceivedEventQueue: Batch attempt $attempt failed: $e");
      }

      if (attempt < _maxRetries) {
        await Future.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * 1.5).round());
      }
    }

    return false;
  }

  /// ── Persist unsent memory queue to disk ───────────────────────────────────
  static Future<void> _persistMemoryQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unsent = _memoryQueue.where((e) => !e.isSent).toList();
      final encoded = unsent.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_queueKey, encoded);
    } catch (e) {
      developer.log("ReceivedEventQueue: Persist error: $e");
    }
  }

  /// ── Load disk events not already in memory ────────────────────────────────
  static Future<void> _mergeFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getStringList(_queueKey);
      if (encoded == null || encoded.isEmpty) return;

      final diskEvents = encoded
          .map((s) => ReceivedEvent.fromJson(jsonDecode(s)))
          .where((e) => !e.isSent)
          .toList();

      /// Add disk events not already tracked in memory
      /// (avoids duplicates on app restart)
      final memoryKeys = _memoryQueue
          .map((e) => '${e.mobile}_${e.receivedAt.toIso8601String()}')
          .toSet();

      for (final diskEvent in diskEvents) {
        final key =
            '${diskEvent.mobile}_${diskEvent.receivedAt.toIso8601String()}';
        if (!memoryKeys.contains(key)) {
          _memoryQueue.add(diskEvent);
        }
      }

      developer.log(
        "ReceivedEventQueue: Merged ${diskEvents.length} events from disk.",
      );
    } catch (e) {
      developer.log("ReceivedEventQueue: Merge from disk error: $e");
    }
  }

  /// ── How many unsent events are pending ────────────────────────────────────
  static int get pendingCount => _memoryQueue.where((e) => !e.isSent).length;
}
