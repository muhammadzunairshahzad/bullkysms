// import 'dart:async';
// import 'dart:developer' as developer;
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:another_telephony/telephony.dart';
// import 'package:workmanager/workmanager.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
// import 'package:http/http.dart' as http; // For API sync
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return GetMaterialApp(
//       title: 'Bullky SMS',
//       theme: ThemeData(primarySwatch: Colors.blue),
//       home: const SmsScreen(),
//     );
//   }
// }
//
// class SmsController extends GetxController {
//   final Telephony telephony = Telephony.instance;
//   RxList<SmsModel> smsList = <SmsModel>[].obs; // List to send
//   RxList<String> receivedSms = <String>[].obs; // Incoming SMS log
//   Database? db;
//   final Telephony telephony = Telephony.instance;
//
//   Future<List<int>> getSimSubscriptionIds() async {
//     // Returns a list of subscription IDs for all active SIMs
//     List<SubscriptionInfo> sims = await telephony.networkOperator;
//     return sims.map((sim) => sim.subscriptionId!).toList();
//   }
//
//   @override
//   void onInit() {
//     super.onInit();
//     initDb();
//     requestPermissions();
//     initSmsListener();
//   }
//
//   Future<void> initDb() async {
//     final databasesPath = await getDatabasesPath();
//     String path = join(databasesPath, 'sms.db');
//     db = await openDatabase(
//       path,
//       version: 1,
//       onCreate: (db, version) {
//         return db.execute(
//           'CREATE TABLE sms(id INTEGER PRIMARY KEY, number TEXT, message TEXT, sim INTEGER, status TEXT)',
//         );
//       },
//     );
//   }
//
//   Future<void> requestPermissions() async {
//     var status = await Permission.sms.request();
//     if (status.isDenied) {
//       Get.snackbar('Error', 'SMS permissions required');
//     }
//     // Also request notification if needed
//   }
//
//   // final Telephony telephony = Telephony.instance;
//
//   Future<List<int>> getSimSubscriptionIds() async {
//     // Returns a list of subscription IDs for all active SIMs
//     List<SubscriptionInfo> sims = await telephony.requestSmsPermissions;
//     return sims.map((sim) => sim.subscriptionId!).toList();
//   }
//
//   // Add SMS to list and DB for sending
//   void addSmsToList(List<Map<String, dynamic>> batch) {
//     for (var item in batch) {
//       smsList.add(
//         SmsModel(
//           number: item['number'],
//           message: item['message'],
//           sim: item['sim'] ?? 0, // Default SIM 0
//         ),
//       );
//       // Save to DB as pending
//       db?.insert('sms', {
//         'number': item['number'],
//         'message': item['message'],
//         'sim': item['sim'] ?? 0,
//         'status': 'pending',
//       });
//     }
//   }
//
//   // Send all in list
//   Future<void> sendSmsBatch() async {
//     final simInfoList = telephony;
//     for (var sms in smsList) {
//       if (simInfoList.length > sms.sim) {
//         final subId = simInfoList[sms.sim].subscriptionId;
//         final status = await telephony.sendSms(
//           to: sms.number,
//           message: sms.message,
//           subscriptionId: subId,
//         );
//         developer.log('SMS sent to ${sms.number} via SIM ${sms.sim}: $status');
//         // Update DB status
//         db?.update(
//           'sms',
//           {'status': 'sent'},
//           where: 'number = ?',
//           whereArgs: [sms.number],
//         );
//         // Sync to API (example)
//         await syncToApi(sms.number, sms.message, 'sent');
//       } else {
//         Get.snackbar('Error', 'Invalid SIM index: ${sms.sim}');
//       }
//     }
//     smsList.clear(); // Clear after sending
//   }
//
//   // Listen for incoming SMS
//   void initSmsListener() {
//     telephony.listenIncomingSms(
//       onNewMessage: (SmsMessage message) {
//         final incoming = 'Received from ${message.address}: ${message.body}';
//         receivedSms.add(incoming);
//         developer.log(incoming);
//         // Save to DB
//         db?.insert('sms', {
//           'number': message.address,
//           'message': message.body,
//           'sim': 0,
//           'status': 'received',
//         });
//         // Sync to API
//         syncToApi(message.address ?? '', message.body ?? '', 'received');
//       },
//       onBackgroundMessage: backgroundSmsHandler,
//       listenInBackground: true,
//     );
//   }
//
//   Future<void> syncToApi(String number, String msg, String status) async {
//     // Example POST to your API
//     try {
//       final response = await http.post(
//         Uri.parse('your_api_endpoint'),
//         body: {'number': number, 'msg': msg, 'status': status},
//       );
//       developer.log('API response: ${response.body}');
//     } catch (e) {
//       developer.log('API error: $e');
//     }
//   }
// }
//
// // Background SMS handler
// @pragma('vm:entry-point')
// Future<bool> backgroundSmsHandler(SmsMessage message) async {
//   // Handle in background (e.g., save to DB, sync API)
//   developer.log('Background SMS: ${message.body}');
//   // Use WorkManager to schedule API sync if needed
//   return true;
// }
//
// // Model for SMS
// class SmsModel {
//   final String number;
//   final String message;
//   final int sim; // 0 = SIM1, 1 = SIM2
//
//   SmsModel({required this.number, required this.message, required this.sim});
// }
//
// // UI Screen
// class SmsScreen extends StatelessWidget {
//   const SmsScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final con = Get.put(SmsController());
//
//     return Scaffold(
//       appBar: AppBar(title: const Text('Bullky SMS')),
//       body: Column(
//         children: [
//           ElevatedButton(
//             onPressed: () {
//               // Example batch list – pass your actual list here
//               con.addSmsToList([
//                 {'number': '+1234567890', 'message': 'Test SMS 1', 'sim': 0},
//                 {'number': '+0987654321', 'message': 'Test SMS 2', 'sim': 1},
//               ]);
//               con.sendSmsBatch();
//             },
//             child: const Text('Send SMS Batch'),
//           ),
//           Obx(
//             () => ListView.builder(
//               shrinkWrap: true,
//               itemCount: con.receivedSms.length,
//               itemBuilder: (context, index) =>
//                   ListTile(title: Text(con.receivedSms[index])),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // Helper to send pending from DB in background
// Future<void> sendPendingSmsFromDb(Telephony telephony) async {
//   final databasesPath = await getDatabasesPath();
//   String path = join(databasesPath, 'sms.db');
//   final db = await openDatabase(path);
//   final pending = await db.query(
//     'sms',
//     where: 'status = ?',
//     whereArgs: ['pending'],
//   );
//   for (var row in pending) {
//     // Send and update status
//     // ... similar to sendSms
//   }
// }
