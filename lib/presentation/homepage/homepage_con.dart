part of 'homepage_bin.dart';

class HomepageCon extends GetxController {
  RxBool isSending = false.obs;
  final SmsSender smsSender = SmsSender();
  final RxList<IndividualSms> smsList = <IndividualSms>[].obs;
  final SimData _simDataPlugin = SimData();
  RxList<AndroidSMSMessage> inboxMessages = <AndroidSMSMessage>[].obs;
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
    var status = await Permission.sms.status;
    if (!status.isGranted) {

      status = await Permission.sms.request();
    }
    // 1. Request Permissions via the plugin's own method
    final granted = await AndroidSMSReader.requestPermissions();

    if (granted) {

      final initialMessages = await AndroidSMSReader.fetchMessages(
        type: AndroidSMSType.inbox,
        start: 0,
        count: 20,
      );
      inboxMessages.assignAll(initialMessages);

      if (!isListening) {
        AndroidSMSReader.observeIncomingMessages().listen((message) {
          inboxMessages.insert(0, message);

          developer.log("New SMS from: ${message.address}");
        });
        isListening = true;
      }
    } else {
      Get.snackbar("Permission Denied", "Cannot read inbox without SMS permission.");
    }
  }
  Future<int?> getSubscriptionIdForSlot(int targetSlotIndex) async {
    try {
      bool hasPerm = await smsSender.checkPhoneStatePermission();
      if (!hasPerm) await smsSender.requestPhoneStatePermission();


      final simDataPlugin = SimData();
      final List<SimDataModel> cards = await simDataPlugin.getSimData();

      for (var card in cards) {
        if (card.simSlotIndex == targetSlotIndex) {
          developer.log("Found SubscriptionId: ${card.subscriptionId} for Slot: $targetSlotIndex");
          return card.subscriptionId;
        }
      }
    } catch (e) {
      developer.log("Error fetching Subscription ID: $e");
    }
    return null;
  }
  void addIndividualSms({
    required String number,
    required String message,
    required int simSlot,
  }) {
    smsList.add(
      IndividualSms(number: number, message: message, simSlot: simSlot),
    );

    if (kDebugMode) {
      developer.log('Added SMS to list: $number | SIM ${simSlot + 1}');
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
          targetSim = cards.firstWhere((card) => card.simSlotIndex == sms.simSlot);
        } catch (_) {
          targetSim = cards.isNotEmpty ? cards.first : null;
        }

        if (targetSim == null) continue;

        try {
          // --- THE KEY FIX IS HERE ---
          // We wrap the call in a timeout. If the plugin hangs for more than 3 seconds,
          // we "force" it to move to the next SMS.
          await _simDataPlugin.sendSMS(
            phoneNumber: sms.number,
            message: sms.message,
            subId: targetSim.subscriptionId,
          ).timeout(const Duration(seconds: 3), onTimeout: () {
            developer.log("Timeout reached for ${sms.number}, moving to next.");
            return; // This completes the await and lets the loop continue
          });

          successCount++;
          smsList[i] = sms.copyWith(status: SmsStatus.sent);
          developer.log('✅ Progress: ${i+1}/${smsList.length}');

          // Carrier delay - very important for dual SIM phones
          if (i < smsList.length - 1) {
            await Future.delayed(const Duration(seconds: 5));
          }
        } catch (e) {
          failCount++;
          smsList[i] = sms.copyWith(status: SmsStatus.failed, error: e.toString());
          developer.log('❌ Failed ${sms.number}: $e');
        }
      }
    } catch (globalError) {
      developer.log("Global SMS Error: $globalError");
    } finally {
      // Ensuring this always runs so the UI isn't stuck on "Sending..."
      isSending.value = false;
      _showResultDialog(successCount, failCount);
    }
  }
  void _showResultDialog(int success, int fail) {
    Get.defaultDialog(
      title: 'Campaign Complete',
      content: Column(
        children: [
          Text('✅ Success: $success'),
          Text('❌ Failed: $fail'),
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
  void startListening() {
    batterySubscription?.cancel();
    batterySubscription = battery.onBatteryStateChanged.listen((BatteryState state) {
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
      case BatteryState.unknown:
        return 'Unknown';
      case BatteryState.connectedNotCharging:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }
  Color getBatteryColor(int level) {
    if (level > 50) return Colors.green;
    if (level > 20) return Colors.orange;
    return Colors.red;
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
