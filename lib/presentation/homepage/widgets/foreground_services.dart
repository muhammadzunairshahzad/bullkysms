// import 'dart:async';
// import 'dart:developer';
// import 'package:bullkysms/presentation/homepage/widgets/received_event_queue.dart';
// import 'package:flutter_foreground_task/flutter_foreground_task.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import '../homepage_bin.dart';
//
// // ── Task handler — runs in a separate isolate ─────────────────────────────
// // This is the code that executes even when app is killed/backgrounded
// @pragma('vm:entry-point')
// class BullkySmsTaskHandler extends TaskHandler {
//   Timer? _periodicTimer;
//   bool _wasConnected = false;
//   bool _isChecking = false;
//
//   @override
//   Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
//     log("ForegroundService: Task started");
//     // Run immediately on start
//     await _checkAndSync();
//     // Then check every 60 seconds
//     _periodicTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
//       await _checkAndSync();
//     });
//   }
//
//   @override
//   Future<void> onRepeatEvent(DateTime timestamp) async {
//     // Not used — we manage our own timer in onStart
//   }
//
//   @override
//   Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
//     log("ForegroundService: Task destroyed");
//     _periodicTimer?.cancel();
//     _periodicTimer = null;
//   }
//
//   @override
//   void onReceiveData(Object data) {
//     log("ForegroundService: Received data: $data");
//     if (data == 'check_now') {
//       _checkAndSync();
//     }
//   }
//
//   @override
//   void onNotificationButtonPressed(String id) {}
//
//   @override
//   void onNotificationDismissed() {}
//
//   Future<void> _checkAndSync() async {
//     if (_isChecking) return;
//     _isChecking = true;
//
//     try {
//       final hasInternet = await _verifyInternet();
//       log(
//         "ForegroundService: Internet check — $hasInternet (was: $_wasConnected)",
//       );
//
//       if (hasInternet && !_wasConnected) {
//         // Transitioned offline → online
//         log("ForegroundService: Internet restored — triggering pipeline.");
//
//         // Update notification to show activity
//         FlutterForegroundTask.updateService(
//           notificationTitle: 'BullkySMS',
//           notificationText: 'Processing pending messages...',
//         );
//
//         await HomepageCon.resolveAndStartPipeline();
//         await ReceivedEventQueue.flushOnInternetRestore();
//
//         FlutterForegroundTask.updateService(
//           notificationTitle: 'BullkySMS',
//           notificationText: 'Running in background',
//         );
//       } else if (!hasInternet && _wasConnected) {
//         log("ForegroundService: Internet lost.");
//         FlutterForegroundTask.updateService(
//           notificationTitle: 'BullkySMS',
//           notificationText: 'Waiting for internet...',
//         );
//       }
//       // If state didn't change, do nothing — no unnecessary API calls
//
//       _wasConnected = hasInternet;
//     } catch (e) {
//       log("ForegroundService: _checkAndSync error: $e");
//     } finally {
//       _isChecking = false;
//     }
//   }
//
//   Future<bool> _verifyInternet() async {
//     try {
//       final response = await http
//           .get(
//             Uri.parse('https://www.gstatic.com/generate_204'),
//             headers: {'Cache-Control': 'no-cache'},
//           )
//           .timeout(const Duration(seconds: 5));
//       return response.statusCode == 204 || response.statusCode == 200;
//     } catch (_) {
//       return false;
//     }
//   }
// }
//
// // ── Service manager — controls start/stop ─────────────────────────────────
// class BullkySmsService {
//   static Future<void> init() async {
//     FlutterForegroundTask.init(
//       androidNotificationOptions: AndroidNotificationOptions(
//         channelId: 'bullky_sms_service',
//         channelName: 'BullkySMS Service',
//         channelDescription: 'Keeps BullkySMS running in background',
//         channelImportance: NotificationChannelImportance.LOW,
//         priority: NotificationPriority.LOW,
//       ),
//       iosNotificationOptions: const IOSNotificationOptions(
//         showNotification: true,
//         playSound: false,
//       ),
//       foregroundTaskOptions: ForegroundTaskOptions(
//         // We manage our own timer, so set this very long
//         eventAction: ForegroundTaskEventAction.repeat(60000),
//         autoRunOnBoot: true,
//         autoRunOnMyPackageReplaced: true,
//         allowWakeLock: true,
//         allowWifiLock: true,
//       ),
//     );
//   }
//
//   static Future<void> start() async {
//     final isRunning = await FlutterForegroundTask.isRunningService;
//     if (isRunning) {
//       log("BullkySmsService: Already running.");
//       return;
//     }
//
//     await FlutterForegroundTask.startService(
//       serviceId: 1001,
//       notificationTitle: 'BullkySMS',
//       notificationText: 'Running in background',
//       callback: startCallback,
//     );
//
//     log("BullkySmsService: Started.");
//   }
//
//   static Future<void> stop() async {
//     await FlutterForegroundTask.stopService();
//     log("BullkySmsService: Stopped.");
//   }
//
//   static Future<void> triggerImmediateCheck() async {
//     FlutterForegroundTask.sendDataToTask('check_now');
//   }
// }
//
// @pragma('vm:entry-point')
// void startCallback() {
//   FlutterForegroundTask.setTaskHandler(BullkySmsTaskHandler());
// }
