part of 'homepage_bin.dart';

@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  developer.log("📱 Background SMS received from: ${message.address}");
  developer.log("📱 Background SMS body: ${message.body}");
}

class HomepageCon extends GetxController {
  final Telephony telephony = Telephony.instance;
  RxBool isSending = false.obs;
  final RxList<IndividualSms> smsList = <IndividualSms>[].obs;
  final SimData _simDataPlugin = SimData();
  RxList<SmsMessage> inboxMessages = <SmsMessage>[].obs;
  RxList<SmsMessage> sim1Messages = <SmsMessage>[].obs;
  RxList<SmsMessage> sim2Messages = <SmsMessage>[].obs;
  bool isListening = false;
  final Battery battery = Battery();
  RxInt batteryLevel = 0.obs;
  BatteryState batteryState = BatteryState.unknown;
  StreamSubscription? batterySubscription;

  Future<int> getBatteryPercentage() async {
    try {
      final level = await battery.batteryLevel;
      return level;
    } catch (e) {
      developer.log('Error getting battery level: $e');
      return -1;
    }
  }

  Future<BatteryState> getBatteryState() async {
    return await battery.batteryState;
  }

  Future<void> initSmsReader() async {
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;

    if (permissionsGranted ?? false) {
      List<SmsMessage> messages = await telephony.getInboxSms(
        columns: [
          SmsColumn.ID,
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
          SmsColumn.SUBSCRIPTION_ID,
        ],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      inboxMessages.assignAll(messages);
      await _sortMessagesBySim(messages);

      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          inboxMessages.insert(0, message);
          await _addMessageToCorrectSim(message);
          update();
          developer.log("New SMS received and added to UI");
        },
        listenInBackground: true,
        onBackgroundMessage: backgroundMessageHandler,
      );
    }
  }

  Future<void> _sortMessagesBySim(List<SmsMessage> messages) async {
    sim1Messages.clear();
    sim2Messages.clear();

    final List<SimDataModel> cards = await _simDataPlugin.getSimData();

    Map<int, int> subToSlot = {
      for (var e in cards) e.subscriptionId: e.simSlotIndex,
    };

    for (var msg in messages) {
      int? slot = subToSlot[msg.subscriptionId];
      if (slot == 0) {
        sim1Messages.add(msg);
      } else if (slot == 1) {
        sim2Messages.add(msg);
      }
    }
  }

  Future<void> _addMessageToCorrectSim(SmsMessage msg) async {
    final List<SimDataModel> cards = await _simDataPlugin.getSimData();
    int? slotIndex;
    try {
      slotIndex = cards
          .firstWhere((e) => e.subscriptionId == msg.subscriptionId)
          .simSlotIndex;
    } catch (e) {
      developer.log(
        "Could not determine slot for subId: ${msg.subscriptionId}",
      );
    }
    if (slotIndex == 0) {
      sim1Messages.insert(0, msg);
    } else if (slotIndex == 1) {
      sim2Messages.insert(0, msg);
    }
  }

  void addMultipleSms(List<IndividualSms> messages) {
    smsList.addAll(messages);

    if (kDebugMode) {
      developer.log('Added ${messages.length} SMS to list');
    }
  }

  Future<void> sendAllSms() async {
    if (smsList.isEmpty || isSending.value) return;

    isSending.value = true;
    int successCount = 0;
    int failCount = 0;

    try {
      final List<SimDataModel> cards = await _simDataPlugin.getSimData();

      for (int i = 0; i < smsList.length; i++) {
        final sms = smsList[i];
        SimDataModel? targetSim;

        try {
          targetSim = cards.firstWhere(
            (card) => card.simSlotIndex == sms.simSlot,
          );
        } catch (_) {
          targetSim = cards.isNotEmpty ? cards.first : null;
        }

        if (targetSim == null) continue;

        try {
          await _simDataPlugin
              .sendSMS(
                phoneNumber: sms.number,
                message: sms.message,
                subId: targetSim.subscriptionId,
              )
              .timeout(
                const Duration(seconds: 3),
                onTimeout: () {
                  developer.log(
                    "Timeout reached for ${sms.number}, moving to next.",
                  );
                  return;
                },
              );

          successCount++;
          smsList[i] = sms.copyWith(status: SmsStatus.sent);
          developer.log('✅ Progress: ${i + 1}/${smsList.length}');

          if (i < smsList.length - 1) {
            await Future.delayed(const Duration(seconds: 5));
          }
        } catch (e) {
          failCount++;
          smsList[i] = sms.copyWith(
            status: SmsStatus.failed,
            error: e.toString(),
          );
          developer.log('❌ Failed ${sms.number}: $e');
        }
      }
    } catch (globalError) {
      developer.log("Global SMS Error: $globalError");
    } finally {
      isSending.value = false;
      _showResultDialog(successCount, failCount);
    }
  }

  void _showResultDialog(int success, int fail) {
    Get.defaultDialog(
      title: 'Campaign Complete',
      content: Column(
        children: [
          Text('Success: $success'),
          Text('Failed: $fail'),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: () => Get.back(), child: const Text('OK')),
        ],
      ),
    );
  }

  void clearAllSms() {
    smsList.clear();
    if (kDebugMode) {
      developer.log("All SMS Removed");
    }
  }

  void loadSampleData() {
    smsList.clear();

    addMultipleSms([
      IndividualSms(
        number: '+923206621808',
        message: 'Hello! Your appointment is confirmed for tomorrow at 10 AM.',
        simSlot: 0,
      ),

      IndividualSms(
        number: '+923196621808',
        message: 'Test message for system verification.',
        simSlot: 0,
      ),
      IndividualSms(
        number: '+923336910787',
        message:
            'Welcome to Prime Medic! Book your first appointment and get special discount.',
        simSlot: 0,
      ),
    ]);
  }

  @override
  void onInit() async {
    super.onInit();
    askPermission().then((_) {
      loadSampleData();
      initSmsReader();
      initBatteryInfo();
      startListening();
      smsGet();
    });
  }

  Future<void> askPermission() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.sms,
        Permission.phone,
        Permission.notification,
      ].request();

      statuses.forEach((permission, status) {
        developer.log("Permission $permission status: $status");
      });

      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      developer.log("Permission sequence error: $e");
    }
  }

  Future<void> initBatteryInfo() async {
    final level = await battery.batteryLevel;
    final state = await battery.batteryState;
    batteryLevel.value = level;
    batteryState = state;
  }

  @override
  void onClose() {
    batterySubscription?.cancel();
    developer.log("HomepageCon disposed: Battery listener stopped.");
    super.onClose();
  }

  void startListening() {
    batterySubscription?.cancel();
    batterySubscription = battery.onBatteryStateChanged.listen((
      BatteryState state,
    ) {
      batteryState = state;
      updateBatteryLevel();
      update();
      developer.log("Battery State Changed: $state");
    });
  }

  Future<void> updateBatteryLevel() async {
    final level = await battery.batteryLevel;
    batteryLevel.value = level;
  }

  String getBatteryStateText(BatteryState state) {
    switch (state) {
      case BatteryState.charging:
        return 'Charging ⚡';
      case BatteryState.discharging:
        return 'Discharging';
      case BatteryState.full:
        return 'Full 🔋';
      case BatteryState.connectedNotCharging:
        return 'Connected (Not Charging) 🔌';
      case BatteryState.unknown:
        return 'Unknown';
    }
  }

  Color getBatteryColor(int level) {
    if (level > 50) return Colors.green;
    if (level > 20) return Colors.orange;
    return Colors.red;
  }

  Future<void> smsGet() async {
    var msgResult = "";
    dynamic response;
    try {
      var jsonMap = {
        'DocType': 'GetSMS',
        'DocDate': DateTime.now().toString(),
        'AppType': Platform.isIOS ? 'iOS' : 'Android',
        'UserName': Constants.email,
        'Password': Constants.password,
        'Mobile': Constants.mobile,
        'AppVersion': "1.0",
        'Token': Constants.appToken,
        'ClientMobID': Constants.clientMobID,
      };
      if (kDebugMode) {
        print(jsonMap);
      }
      response = await Functions.sendJson(jsonMap, 'sms_get');
      if (kDebugMode) {
        print(response);
      }
      if (response == '') {
        msgResult = "Can't Connect - Try again.";
        return;
      }
      if (response["DocType"] == "Error") {
        msgResult = response["Message"];
        return;
      }
      if (response["DocType"] == "Delete Requested") {
        msgResult = "DeleteReq";
        return;
      }
      msgResult = "Success";
    } catch (e) {
      msgResult = "Check Internet Connection & Try again.";
    } finally {
      if (msgResult == 'Success') {
        developer.log(response.toString());
      } else {
        DialogUtils.errorDialog(msgResult);
      }
    }
  }
}

class IndividualSms {
  final String number;
  final String message;
  final int simSlot;
  final SmsStatus status;
  final String? error;

  IndividualSms({
    required this.number,
    required this.message,
    required this.simSlot,
    this.status = SmsStatus.pending,
    this.error,
  });

  IndividualSms copyWith({
    String? number,
    String? message,
    int? simSlot,
    SmsStatus? status,
    String? error,
  }) {
    return IndividualSms(
      number: number ?? this.number,
      message: message ?? this.message,
      simSlot: simSlot ?? this.simSlot,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}

enum SmsStatus { pending, sending, sent, failed }
