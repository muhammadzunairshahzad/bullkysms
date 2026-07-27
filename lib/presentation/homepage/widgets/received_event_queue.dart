import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/constants.dart';
import '../../../utils/helping_function.dart';

// Model for a received call or SMS event
class ReceivedEvent {
  final String mobile;
  final String message; // "Missed Call" for calls, SMS text for messages
  final DateTime receivedAt;
  bool isSent;

  ReceivedEvent({
    required this.mobile,
    required this.message,
    required this.receivedAt,
    this.isSent = false,
  });

  factory ReceivedEvent.fromJson(Map<String, dynamic> json) {
    return ReceivedEvent(
      mobile: json['mobile'] ?? '',
      message: json['message'] ?? '',
      receivedAt: DateTime.tryParse(json['receivedAt'] ?? '') ?? DateTime.now(),
      isSent: json['isSent'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mobile': mobile,
      'message': message,
      'receivedAt': receivedAt.toIso8601String(),
      'isSent': isSent,
    };
  }
}

class ReceivedEventQueue {
  static const String _queueKey = 'received_event_queue';
  static const int _maxRetries = 3;

  // In-memory queue for events received while offline
  static final List<ReceivedEvent> _memoryQueue = [];

  // Prevent concurrent flushes
  static bool _isFlushing = false;

  // ── Add event — called from call/SMS listener ─────────────────────────────
  // Fire and forget — never blocks the caller
  static void enqueue(String mobile, String message) {
    final event = ReceivedEvent(
      mobile: mobile,
      message: message,
      receivedAt: DateTime.now(),
    );

    developer.log(
      "ReceivedEventQueue: Enqueued — "
      "mobile=$mobile message=$message",
    );

    // Add to memory queue immediately (no await — non-blocking)
    _memoryQueue.add(event);

    // Persist to disk and try to flush — both fire-and-forget
    _persistMemoryQueue();
    _tryFlush();
  }

  // ── Try to send all pending events ────────────────────────────────────────
  // Called on enqueue and when internet restores
  static Future<void> _tryFlush() async {
    if (_isFlushing) return;
    _isFlushing = true;

    try {
      // Load anything saved on disk that isn't in memory yet
      await _mergeFromDisk();

      final pending = _memoryQueue.where((e) => !e.isSent).toList();

      if (pending.isEmpty) {
        developer.log("ReceivedEventQueue: Nothing to flush.");
        return;
      }

      developer.log("ReceivedEventQueue: Flushing ${pending.length} events...");

      for (final event in pending) {
        final success = await _sendEvent(event);
        if (success) {
          event.isSent = true;
          developer.log(
            "ReceivedEventQueue: Sent — ${event.mobile} / ${event.message}",
          );
        } else {
          developer.log(
            "ReceivedEventQueue: Failed to send — "
            "${event.mobile}. Will retry on next internet restore.",
          );
          // Don't break — try remaining events too
        }
      }

      // Remove successfully sent events from memory
      _memoryQueue.removeWhere((e) => e.isSent);

      // Update disk with only unsent events
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

  // ── Called by HomepageCon when internet comes back ────────────────────────
  static Future<void> flushOnInternetRestore() async {
    developer.log("ReceivedEventQueue: Internet restored — flushing queue...");
    await _tryFlush();
  }

  // ── Send single event to API ───────────────────────────────────────────────
  static Future<bool> _sendEvent(ReceivedEvent event) async {
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
          'Mobile': event.mobile,
          'Message': event.message,
          'AppVersion': "1.0",
          'Token': Constants.appToken,
          'ClientMobID': Constants.clientMobID,
        };
        developer.log("SMS REC JSON: $jsonMap");
        final response = await Functions.sendJson(
          jsonMap,
          'sms_received',
        ).timeout(const Duration(seconds: 10));

        if (response == null || response == '') {
          developer.log("ReceivedEventQueue: Empty response attempt $attempt");
        } else if (response["DocType"] == "ReceivedSMS" &&
            response["Message"] == "Done") {
          return true;
        } else if (response["DocType"] == "Error") {
          developer.log(
            "ReceivedEventQueue: API error: ${response["Message"]}",
          );
          return false; // Don't retry on API errors
        }
      } catch (e) {
        developer.log("ReceivedEventQueue: Attempt $attempt failed: $e");
      }

      if (attempt < _maxRetries) {
        await Future.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * 1.5).round());
      }
    }

    return false;
  }

  // ── Persist unsent memory queue to disk ───────────────────────────────────
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

  // ── Load disk events not already in memory ────────────────────────────────
  static Future<void> _mergeFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getStringList(_queueKey);
      if (encoded == null || encoded.isEmpty) return;

      final diskEvents = encoded
          .map((s) => ReceivedEvent.fromJson(jsonDecode(s)))
          .where((e) => !e.isSent)
          .toList();

      // Add disk events not already tracked in memory
      // (avoids duplicates on app restart)
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

  // ── How many unsent events are pending ────────────────────────────────────
  static int get pendingCount => _memoryQueue.where((e) => !e.isSent).length;
}
