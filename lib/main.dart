import 'dart:async';
import 'dart:developer';

import 'package:bullkysms/presentation/homepage/homepage_bin.dart';
import 'package:bullkysms/utils/app_routes.dart';
import 'package:bullkysms/utils/constants.dart';
import 'package:bullkysms/utils/initial_bindings.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final List<DarwinNotificationCategory> darwinNotificationCategories =
    <DarwinNotificationCategory>[
      DarwinNotificationCategory(
        "BullkySMS",
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.text(
            'text_1',
            'Action 1',
            buttonTitle: 'Send',
            placeholder: 'Placeholder',
          ),
        ],
      ),
      DarwinNotificationCategory(
        "BullkySMS",
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.plain('id_1', 'Action 1'),
          DarwinNotificationAction.plain(
            'id_2',
            'Action 2 (destructive)',
            options: <DarwinNotificationActionOption>{
              DarwinNotificationActionOption.destructive,
            },
          ),
          DarwinNotificationAction.plain(
            "id_3",
            'Action 3 (foreground)',
            options: <DarwinNotificationActionOption>{
              DarwinNotificationActionOption.foreground,
            },
          ),
          DarwinNotificationAction.plain(
            'id_4',
            'Action 4 (auth required)',
            options: <DarwinNotificationActionOption>{
              DarwinNotificationActionOption.authenticationRequired,
            },
          ),
        ],
        options: <DarwinNotificationCategoryOption>{
          DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
        },
      ),
    ];

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  log("Handling a background message: ${message.messageId}");
  await HomepageCon.resolveAndStartPipeline();
}

RemoteMessage? globalInitialMessage;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // await BullkySmsService.init();
  requestPermission();
  WakelockPlus.enable();
  await initInfo();
  runApp(const MyApp());
}

void requestPermission() async {
  if (await Permission.notification.isDenied) {
    PermissionStatus status = await Permission.notification.request();
    if (status.isGranted) {
      log("Notification permission granted");
    } else {
      log("Notification permission denied");
    }
  }

  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (kDebugMode) {
    log('User granted permission: ${settings.authorizationStatus}');
  }
}

Future<bool> ensureSmsPermissions() async {
  final statuses = await [Permission.sms, Permission.phone].request();
  bool allGranted = statuses.values.every((s) => s.isGranted);
  if (!allGranted) {
    Get.snackbar(
      'Permissions Required',
      'SMS and Phone State permissions are needed to send messages.',
    );
    return false;
  }
  return true;
}

final StreamController<ReceivedNotification> didReceiveLocalNotificationStream =
    StreamController<ReceivedNotification>.broadcast();
Map<String, dynamic>? lastNotificationData;

Future<void> initInfo() async {
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  var androidInitialize = const AndroidInitializationSettings(
    '@mipmap/ic_launcher',
  );
  var iOSInitialize = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,

    notificationCategories: darwinNotificationCategories,
  );
  var initializationsSettings = InitializationSettings(
    android: androidInitialize,
    iOS: iOSInitialize,
  );
  flutterLocalNotificationsPlugin.initialize(
    settings: initializationsSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      final payloadData = response.payload;
      log("Notification clicked with payload: $payloadData");
    },
  );
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'BullkySMS',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    lastNotificationData = message.data;
    log("lastNotificationData $lastNotificationData");
    if (kDebugMode) {
      log("....................onMessage....................");
    }
    if (kDebugMode) {
      log(
        "onMessage: ${message.notification?.title}/${message.notification?.body}/${message.data}",
      );
    }
    if (message.notification != null) {
      if (kDebugMode) {
        log('Message also contained a notification: ${message.notification}');
      }
    }
    if (Constants.isLogin == true) {
      HomepageCon.resolveAndStartPipeline();
    }
    int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      100000,
    );
    BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      message.notification!.body.toString(),
      htmlFormatBigText: true,
      contentTitle: message.notification!.title.toString(),
      htmlFormatContentTitle: true,
    );
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'BullkySMS',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          channel.id,
          channel.name,
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: bigTextStyleInformation,
          playSound: true,
          enableVibration: true,
        );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: const DarwinNotificationDetails(),
    );
    await flutterLocalNotificationsPlugin.show(
      title: message.notification?.title,
      body: message.notification?.body,
      notificationDetails: platformChannelSpecifics,
      payload: message.data['body'],
      id: notificationId,
    );
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    log("Url: ${message.data['title']}");
    lastNotificationData = message.data;
    log("lastNotificationData $lastNotificationData");
  });
}

class ReceivedNotification {
  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'BullkySMS',
      debugShowCheckedModeBanner: false,
      initialBinding: InitialBindings(),
      getPages: AppRoutes.pages,
      initialRoute: AppRoutes.initialRoute,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: Overlay(
            initialEntries: [OverlayEntry(builder: (_) => child!)],
          ),
        );
      },
    );
  }
}
