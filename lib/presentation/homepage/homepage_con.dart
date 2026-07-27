part of 'homepage_bin.dart';

@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  developer.log("Background SMS received from: ${message.address}");
  developer.log("Background SMS body: ${message.body}");
  final number = message.address ?? '';
  final text = message.body ?? '';
  if (number.isNotEmpty) {
    ReceivedEventQueue.enqueue(number, text);
  }
}

enum SmsStatus { pending, sending, sent, failed }

/// ── Controller ─────────────────────────────────────────────────────────────

class HomepageCon extends GetxController {
  /// ── Constants ─────────────────────────────────────────────────────────────
  static const String _pendingUpdateKey = 'pending_sms_update';

  /// ── Fields ────────────────────────────────────────────────────────────────
  bool _wasConnected = false;
  bool _isCheckingInternet = false;

  final Telephony telephony = Telephony.instance;
  final SimData _simDataPlugin = SimData();
  final Battery battery = Battery();
  final Connectivity _connectivity = Connectivity();

  StreamSubscription? batterySubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  BatteryState batteryState = BatteryState.unknown;
  List<SimDataModel> simCards = [];
  bool isListening = false;

  /// ── Reactive ──────────────────────────────────────────────────────────────
  RxBool isSending = false.obs;
  RxBool isSimDataReady = false.obs;
  RxBool isConnected = false.obs;
  RxBool isServerSmsSending = false.obs;
  RxBool hasPendingUpdates = false.obs;

  RxInt batteryLevel = 0.obs;
  RxInt serverTotalSms = 0.obs;
  RxInt serverSentCount = 0.obs;

  RxString connectionStatus = "Checking...".obs;
  RxString currentCampaignName = "".obs;
  RxString campaignName = "SMS API.".obs;
  RxString totalSMS = "50".obs;
  RxString sentSMS = "5".obs;

  RxList<IndividualSms> smsList = <IndividualSms>[].obs;
  RxList<SmsMessage> inboxMessages = <SmsMessage>[].obs;
  RxList<SmsMessage> sim1Messages = <SmsMessage>[].obs;
  RxList<SmsMessage> sim2Messages = <SmsMessage>[].obs;
  RxList<ServerSms> serverSmsList = <ServerSms>[].obs;
  StreamSubscription? _callSubscription;
  String? _lastCallNumber;

  /// ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void onInit() async {
    super.onInit();
    // Ask permissions first, then init everything that needs them
    await askPermission();
    loadSampleData();
    initSmsReader();
    initBatteryInfo();
    startListening();
    _initCallListener();
    // Connectivity init handles first internet check + pipeline trigger
    await initConnectivity();
    // BullkySmsService.start();
  }

  Timer? _periodicInternetTimer;

  @override
  void onClose() {
    batterySubscription?.cancel();
    _connectivitySubscription?.cancel();
    _callSubscription?.cancel();
    _periodicInternetTimer?.cancel();
    developer.log("HomepageCon disposed.");
    super.onClose();
  }

  /// ── Call Listener ───────────────────────────────────────────────────────────

  /// Add this method
  void _initCallListener() {
    _callSubscription?.cancel();

    // This stores the INCOMING caller's number, not the device number
    String? incomingCallerNumber;

    _callSubscription = PhoneState.stream.listen((PhoneState state) {
      developer.log("Call state: ${state.status} — number: ${state.number}");

      switch (state.status) {
        case PhoneStateStatus.CALL_INCOMING:
          // state.number here is reliably the CALLER'S number on incoming
          incomingCallerNumber = state.number;
          _lastCallNumber = state.number;
          developer.log("Incoming call FROM: ${state.number}");
          break;

        case PhoneStateStatus.CALL_STARTED:
          // Call answered — keep using the stored incoming number
          developer.log("Call answered, caller was: $incomingCallerNumber");
          break;

        case PhoneStateStatus.CALL_ENDED:
          // Always use _incomingCallerNumber — NOT state.number here
          // because state.number at CALL_ENDED can return device's own number
          final number = incomingCallerNumber ?? '';
          if (number.isNotEmpty) {
            developer.log(
              "Call ended FROM: $number — reporting as Missed Call",
            );
            ReceivedEventQueue.enqueue(number, 'Missed Call');
          }
          // Reset for next call
          incomingCallerNumber = null;
          _lastCallNumber = null;
          break;

        case PhoneStateStatus.CALL_OUTGOING:
          // Outgoing — reset stored number, don't report
          incomingCallerNumber = null;
          _lastCallNumber = null;
          developer.log("Outgoing call to: ${state.number}");
          break;

        case PhoneStateStatus.NOTHING:
          break;
      }
    });

    developer.log("Call listener initialized.");
  }

  /// ── Permissions ───────────────────────────────────────────────────────────

  Future<void> askPermission() async {
    try {
      final statuses = await [
        Permission.sms,
        Permission.phone,
        Permission.notification,
      ].request();
      statuses.forEach((p, s) => developer.log("Permission $p: $s"));
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      developer.log("Permission error: $e");
    }
  }

  /// ── Connectivity ──────────────────────────────────────────────────────────

  Future<void> initConnectivity() async {
    // Check immediately on startup
    await checkInternetAndSync();

    /// React only when network interface changes — no timer needed
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      final hasInterface = results.any((r) => r != ConnectivityResult.none);
      if (!hasInterface) {
        _setDisconnected();
      } else {
        // Interface changed (e.g. WiFi reconnected) — verify actual internet
        await checkInternetAndSync();
      }
    });
    _periodicInternetTimer?.cancel();
    _periodicInternetTimer = Timer.periodic(const Duration(seconds: 5), (
      _,
    ) async {
      developer.log("Periodic internet check triggered.");
      await checkInternetAndSync();
    });
  }

  Future<void> checkInternetAndSync() async {
    if (_isCheckingInternet) return;
    _isCheckingInternet = true;

    try {
      final hasInternet = await _verifyInternet();

      if (hasInternet) {
        _setConnected();

        if (!_wasConnected) {
          developer.log("Internet restored — checking failover then pipeline.");

          /// Run these concurrently — queue flush and SMS pipeline are independent
          await Future.wait([
            resolveAndStartPipeline(),
            ReceivedEventQueue.flushOnInternetRestore(),
          ]);
        }
      } else {
        _setDisconnected();
      }

      _wasConnected = hasInternet;
    } catch (e) {
      developer.log("checkInternetAndSync error: $e");
      _setDisconnected();
      _wasConnected = false;
    } finally {
      _isCheckingInternet = false;
    }
  }

  Future<bool> _verifyInternet() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasInterface = results.any((r) => r != ConnectivityResult.none);
      if (!hasInterface) return false;

      final response = await http
          .get(
            Uri.parse('https://www.gstatic.com/generate_204'),
            headers: {'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 5));

      final isSuccessful =
          response.statusCode == 204 || response.statusCode == 200;

      if (isSuccessful) {
        if (results.contains(ConnectivityResult.wifi)) {
          connectionStatus.value = "Online (WiFi)";
        } else if (results.contains(ConnectivityResult.mobile)) {
          connectionStatus.value = "Online (Mobile)";
        } else if (results.contains(ConnectivityResult.ethernet)) {
          connectionStatus.value = "Online (Ethernet)";
        } else {
          connectionStatus.value = "Online";
        }
      }

      return isSuccessful;
    } catch (e) {
      developer.log("Internet verify failed: $e");
      return false;
    }
  }

  void _setConnected() {
    if (!isConnected.value) {
      isConnected.value = true;
      developer.log("Internet connected: ${connectionStatus.value}");
    }
  }

  void _setDisconnected() {
    if (isConnected.value) {
      isConnected.value = false;
      connectionStatus.value = "Offline";
      developer.log("Internet disconnected.");
    }
  }

  /// ── Static: called from main.dart on notification receive ─────────────────
  /// Resolves any pending disk updates first, then starts the SMS pipeline.
  /// Safe to call even when controller may not be initialized yet — it uses
  /// only SharedPreferences and static smsGet, no instance state.

  static Future<void> resolveAndStartPipeline() async {
    developer.log("=== resolveAndStartPipeline called ===");
    final canProceed = await _resolveAnyPendingUpdates();

    if (!canProceed) {
      developer.log(
        "resolveAndStartPipeline: Failover unresolved. "
        "Will retry on next internet restore.",
      );
      return;
    }

    // If controller is registered (app is running), use it for full pipeline
    // so reactive UI fields (progress, campaign name etc.) update correctly
    if (Get.isRegistered<HomepageCon>()) {
      developer.log("Controller found — running full pipeline via instance.");
      await Get.find<HomepageCon>().startServerSmsPipeline();
    } else {
      // Called from main.dart before controller exists — do a lightweight
      // fetch+send without UI updates
      developer.log("Controller not registered — running headless pipeline.");
      await _headlessPipeline();
    }
  }

  /// ── Pending update helpers (static — usable from main.dart) ───────────────

  static Future<void> _savePendingUpdates(List<ServerSms> sentList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = sentList
          .map((s) => jsonEncode(s.toUpdateJson()))
          .toList();
      await prefs.setStringList(_pendingUpdateKey, encoded);
      developer.log("Saved ${encoded.length} pending updates to disk.");

      // Update reactive field if controller is alive
      if (Get.isRegistered<HomepageCon>()) {
        Get.find<HomepageCon>().hasPendingUpdates.value = encoded.isNotEmpty;
      }
    } catch (e) {
      developer.log("_savePendingUpdates error: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> _loadPendingUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getStringList(_pendingUpdateKey);
      if (encoded == null || encoded.isEmpty) return [];
      return encoded.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
    } catch (e) {
      developer.log("_loadPendingUpdates error: $e");
      return [];
    }
  }

  static Future<void> _clearPendingUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingUpdateKey);
      developer.log("Pending updates cleared from disk.");

      if (Get.isRegistered<HomepageCon>()) {
        Get.find<HomepageCon>().hasPendingUpdates.value = false;
      }
    } catch (e) {
      developer.log("_clearPendingUpdates error: $e");
    }
  }

  static Future<bool> _hasPendingUpdatesOnDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_pendingUpdateKey);
      return list != null && list.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// ── Static: resolve pending then proceed ──────────────────────────────────

  static Future<bool> _resolveAnyPendingUpdates() async {
    final hasPending = await _hasPendingUpdatesOnDisk();
    if (!hasPending) {
      developer.log("Failover: No pending updates on disk.");
      return true;
    }

    developer.log("Failover: Found pending updates — resolving before smsGet.");

    if (Get.isRegistered<HomepageCon>()) {
      Get.find<HomepageCon>().hasPendingUpdates.value = true;
    }

    final pendingList = await _loadPendingUpdates();
    if (pendingList.isEmpty) {
      await _clearPendingUpdates();
      return true;
    }

    bool updateSuccess = false;
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 2);

    while (attempt < maxAttempts && !updateSuccess) {
      attempt++;
      developer.log(
        "Failover: smsUpdate attempt $attempt/$maxAttempts "
        "for ${pendingList.length} records...",
      );

      updateSuccess = await _staticSmsUpdate(pendingList);

      if (!updateSuccess && attempt < maxAttempts) {
        developer.log(
          "Failover: Attempt $attempt failed. Retrying in ${delay.inSeconds}s...",
        );
        await Future.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * 1.5).round());
      }
    }

    if (updateSuccess) {
      await _clearPendingUpdates();
      developer.log("Failover: Resolved. Proceeding to smsGet.");
      return true;
    }

    developer.log(
      "Failover: Failed after $maxAttempts attempts. "
      "Will retry on next connection.",
    );
    return false;
  }

  /// ── Static smsUpdate (used by failover — no instance needed) ─────────────

  static Future<bool> _staticSmsUpdate(
    List<Map<String, dynamic>> detail,
  ) async {
    try {
      if (detail.isEmpty) return true;

      final jsonMap = {
        'DocType': 'UpdateSMS',
        'DocDate': DateTime.now().toString(),
        'AppType': Platform.isIOS ? 'iOS' : 'Android',
        'UserName': Constants.email,
        'Password': Constants.password,
        'Mobile': Constants.mobile,
        'AppVersion': "1.0",
        'Token': Constants.appToken,
        'ClientMobID': Constants.clientMobID,
        'Detail': detail,
      };

      final response = await Functions.sendJson(jsonMap, 'sms_update');
      if (response == null || response == '') return false;
      if (response["DocType"] == "Error") return false;

      developer.log("_staticSmsUpdate success.");
      return true;
    } catch (e) {
      developer.log("_staticSmsUpdate error: $e");
      return false;
    }
  }

  /// ── Static smsGet (callable from main.dart) ───────────────────────────────

  static Future<Map<String, dynamic>?> smsGet() async {
    try {
      final jsonMap = {
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

      if (kDebugMode) print("smsGet request: $jsonMap");

      final response = await Functions.sendJson(jsonMap, 'sms_get');

      if (kDebugMode) print("smsGet response: $response");

      if (response == null || response == '') return null;
      if (response["DocType"] == "Error") return null;
      if (response["DocType"] == "Delete Requested") return null;

      return response;
    } catch (e) {
      developer.log("smsGet error: $e");
      return null;
    }
  }

  /// ── Instance smsUpdate (used inside pipeline) ─────────────────────────────

  Future<bool> _smsUpdate(List<ServerSms> sentMessages) async {
    return await _staticSmsUpdate(
      sentMessages.map((s) => s.toUpdateJson()).toList(),
    );
  }

  /// ── Full pipeline (instance — updates reactive UI) ────────────────────────

  Future<void> startServerSmsPipeline() async {
    if (isServerSmsSending.value) {
      developer.log("Pipeline already running.");
      return;
    }

    isServerSmsSending.value = true;
    isSending.value = true;
    developer.log("=== SMS Pipeline Started ===");

    try {
      while (true) {
        final response = await smsGet();

        if (response == null) {
          developer.log("Pipeline: null response, stopping.");
          break;
        }

        final int total =
            int.tryParse(response["TotalSMS"]?.toString() ?? "0") ?? 0;

        if (total == 0) {
          developer.log("Pipeline: No pending SMS. Done.");
          break;
        }

        final List<dynamic> detailList = response["Detail"] ?? [];
        if (detailList.isEmpty) break;

        final batch = detailList
            .map((item) => ServerSms.fromJson(item as Map<String, dynamic>))
            .toList();

        serverSmsList.assignAll(batch);
        serverTotalSms.value = total;
        serverSentCount.value = 0;
        totalSMS.value = total.toString();
        sentSMS.value = "0";
        currentCampaignName.value = batch.first.campaignName;
        developer.log("Pipeline: Sending ${batch.length} SMS...");

        final sentList = await _sendServerSmsBatch(batch);

        developer.log("Pipeline: Sent ${sentList.length}/${batch.length}.");

        if (sentList.isEmpty) {
          developer.log("Pipeline: Nothing sent, stopping.");
          break;
        }

        final updateSuccess = await _smsUpdate(sentList);

        if (updateSuccess) {
          await _clearPendingUpdates();
          developer.log("Pipeline: Server updated. Disk cleared.");
        } else {
          developer.log(
            "Pipeline: Update failed — data safe on disk. Stopping.",
          );
          break;
        }

        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      developer.log("Pipeline error: $e");
    } finally {
      isServerSmsSending.value = false;
      isSending.value = false;
      serverSmsList.clear();
      developer.log("=== SMS Pipeline Finished ===");
    }
  }

  /// ── Shared SIM getter with retry — works in both instance and static context
  static Future<SimDataModel?> _getTargetSim(SimData plugin) async {
    List<SimDataModel> cards = [];

    // Retry up to 5 times — SIM data may not be ready immediately
    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        cards = await plugin.getSimData();
        if (cards.isNotEmpty) break;
        developer.log("SIM data empty, attempt ${attempt + 1}/5...");
      } catch (e) {
        developer.log("SIM fetch attempt ${attempt + 1} error: $e");
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (cards.isEmpty) {
      developer.log("Could not get SIM data after 5 attempts.");
      return null;
    }

    // Always use SIM slot 0 (SIM1) by default
    try {
      return cards.firstWhere((c) => c.simSlotIndex == 0);
    } catch (_) {
      return cards.first;
    }
  }

  /// ── Headless pipeline (no controller — called from main.dart) ─────────────
  /// No reactive UI updates, just sends and saves to disk

  static Future<void> _headlessPipeline() async {
    developer.log("=== Headless Pipeline Started ===");

    final smsStatus = await Permission.sms.status;
    final phoneStatus = await Permission.phone.status;
    if (!smsStatus.isGranted || !phoneStatus.isGranted) {
      developer.log("Headless: Missing SMS/Phone permission, aborting.");
      return;
    }

    try {
      final SimData simPlugin = SimData();
      final targetSim = await _getTargetSim(simPlugin);

      if (targetSim == null) {
        developer.log("Headless: No SIM found after retries, stopping.");
        return;
      }

      final smsSender = SmsSender();

      while (true) {
        final response = await smsGet();
        if (response == null) break;

        final int total =
            int.tryParse(response["TotalSMS"]?.toString() ?? "0") ?? 0;
        if (total == 0) break;

        final List<dynamic> detailList = response["Detail"] ?? [];
        if (detailList.isEmpty) break;

        final batch = detailList
            .map((item) => ServerSms.fromJson(item as Map<String, dynamic>))
            .toList();

        final List<ServerSms> sentList = [];

        for (int i = 0; i < batch.length; i++) {
          final sms = batch[i];
          try {
            await smsSender
                .sendSms(
                  phoneNumber: sms.mobile,
                  message: sms.smsText,
                  simSlot: targetSim.simSlotIndex,
                )
                .timeout(const Duration(seconds: 6), onTimeout: () => true);

            sms.sentTime = DateTime.now().toString();
            sentList.add(sms);
            await _savePendingUpdates(sentList);
            developer.log(
              "Headless: Dispatched to ${sms.mobile} [${sms.smsId}]",
            );

            if (i < batch.length - 1) {
              await Future.delayed(const Duration(milliseconds: 1200));
            }
          } catch (e) {
            developer.log("Headless: Failed ${sms.mobile}: $e");
          }
        }

        if (sentList.isEmpty) break;

        final updateSuccess = await _staticSmsUpdate(
          sentList.map((s) => s.toUpdateJson()).toList(),
        );

        if (updateSuccess) {
          await _clearPendingUpdates();
          developer.log("Headless: Update success. Disk cleared.");
        } else {
          developer.log("Headless: Update failed. Data on disk. Stopping.");
          break;
        }

        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      developer.log("Headless pipeline error: $e");
    }

    developer.log("=== Headless Pipeline Finished ===");
  }

  Future<bool> _hasSimPermissions() async {
    if (Platform.isAndroid) {
      final smsStatus = await Permission.sms.status;
      final phoneStatus = await Permission.phone.status;
      return smsStatus.isGranted && phoneStatus.isGranted;
    }
    return true; // iOS handles differently
  }

  /// ── Send batch (instance) ─────────────────────────────────────────────────

  Future<List<ServerSms>> _sendServerSmsBatch(List<ServerSms> batch) async {
    if (!await _hasSimPermissions()) {
      developer.log("Cannot send SMS: Missing permissions");
      return [];
    }

    final List<ServerSms> sentList = [];
    final targetSim = await _getTargetSim(_simDataPlugin);

    if (targetSim == null) {
      developer.log("No SIM available after retries.");
      return sentList;
    }

    final smsSender = SmsSender();

    developer.log(
      "Sending via SIM slot ${targetSim.simSlotIndex} "
      "(SubID: ${targetSim.subscriptionId})",
    );

    for (int i = 0; i < batch.length; i++) {
      final sms = batch[i];
      try {
        // Native multipart handling — long text goes out as one
        // concatenated message, no manual splitting needed.
        final success = await smsSender
            .sendSms(
              phoneNumber: sms.mobile,
              message: sms.smsText,
              simSlot: targetSim.simSlotIndex,
            )
            .timeout(
              const Duration(seconds: 6),
              onTimeout: () {
                developer.log(
                  "sendSms timed out for ${sms.mobile}, assuming dispatched.",
                );
                return true;
              },
            );

        developer.log(
          success
              ? "Sent OK — ${sms.mobile}"
              : "Plugin reported failure — ${sms.mobile} (marking dispatched anyway per your policy)",
        );

        // Per your requirement: mark as forwarded regardless of the
        // reported result, since the goal is "handed to the messaging app".
        sms.sentTime = DateTime.now().toString();
        sentList.add(sms);
        serverSentCount.value = sentList.length;
        sentSMS.value = sentList.length.toString();
        await _savePendingUpdates(sentList);

        developer.log(
          "Dispatched ${i + 1}/${batch.length} — ${sms.mobile} [${sms.smsId}]",
        );

        if (i < batch.length - 1) {
          await Future.delayed(const Duration(milliseconds: 1200));
        }
      } catch (e) {
        developer.log("Unexpected error for ${sms.mobile}: $e");
        sms.sentTime = DateTime.now().toString();
        sentList.add(sms);
        serverSentCount.value = sentList.length;
        sentSMS.value = sentList.length.toString();
        await _savePendingUpdates(sentList);
      }
    }

    return sentList;
  }

  /// ── SMS Reader ────────────────────────────────────────────────────────────

  Future<void> initSmsReader() async {
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;

    if (permissionsGranted ?? false) {
      await _waitForSimData();

      final messages = await telephony.getInboxSms(
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
      update();

      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          inboxMessages.insert(0, message);
          await _addMessageToCorrectSim(message);
          sim1Messages.refresh();
          sim2Messages.refresh();
          inboxMessages.refresh();
          update();
          final number = message.address ?? '';
          final text = message.body ?? '';
          if (number.isNotEmpty) {
            developer.log(
              "New SMS received from $number — enqueuing for server report.",
            );
            ReceivedEventQueue.enqueue(number, text);
          }
        },

        listenInBackground: true,
        onBackgroundMessage: backgroundMessageHandler,
      );
    }
  }

  Future<void> _waitForSimData({int maxAttempts = 5}) async {
    for (int i = 0; i < maxAttempts; i++) {
      try {
        final cards = await _simDataPlugin.getSimData();
        if (cards.isNotEmpty) {
          simCards = cards;
          isSimDataReady.value = true;
          developer.log("SIM data ready: ${cards.length} SIM(s)");
          return;
        }
      } catch (e) {
        developer.log("Attempt ${i + 1}: SIM not ready: $e");
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    developer.log("WARNING: SIM data not ready after $maxAttempts attempts");
    isSimDataReady.value = false;
  }

  Future<void> _sortMessagesBySim(List<SmsMessage> messages) async {
    sim1Messages.clear();
    sim2Messages.clear();

    if (simCards.isEmpty) await _waitForSimData();

    final subToSlot = {
      for (var e in simCards) e.subscriptionId: e.simSlotIndex,
    };

    for (var msg in messages) {
      final slot = msg.subscriptionId == null
          ? _guessSimSlotByAddress(msg.address)
          : subToSlot[msg.subscriptionId];

      if (slot == 1) {
        sim2Messages.add(msg);
      } else {
        sim1Messages.add(msg);
      }
    }

    sim1Messages.refresh();
    sim2Messages.refresh();
  }

  Future<void> _addMessageToCorrectSim(SmsMessage msg) async {
    if (simCards.isEmpty) await _waitForSimData();

    int slotIndex = 0;
    try {
      if (msg.subscriptionId != null) {
        final card = simCards.firstWhere(
          (e) => e.subscriptionId == msg.subscriptionId,
        );
        slotIndex = card.simSlotIndex;
      }
    } catch (e) {
      developer.log("Could not determine slot: $e");
    }

    if (slotIndex == 1) {
      sim2Messages.insert(0, msg);
    } else {
      sim1Messages.insert(0, msg);
    }

    sim1Messages.refresh();
    sim2Messages.refresh();
  }

  int _guessSimSlotByAddress(String? address) => 0;

  Future<void> refreshSimData() async {
    await _waitForSimData();
    await _sortMessagesBySim(inboxMessages.toList());
    update();
  }

  /// ── Manual SMS (existing local list) ──────────────────────────────────────

  void addMultipleSms(List<IndividualSms> messages) {
    smsList.addAll(messages);
  }

  void clearAllSms() => smsList.clear();

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
            'Welcome! Book your first appointment and get special discount.',
        simSlot: 0,
      ),
    ]);
  }

  Future<void> sendAllSms() async {
    if (smsList.isEmpty || isSending.value) return;
    isSending.value = true;
    int successCount = 0;
    int failCount = 0;

    try {
      final cards = await _simDataPlugin.getSimData();

      for (int i = 0; i < smsList.length; i++) {
        final sms = smsList[i];
        SimDataModel? targetSim;
        try {
          targetSim = cards.firstWhere((c) => c.simSlotIndex == sms.simSlot);
        } catch (_) {
          targetSim = cards.isNotEmpty ? cards.first : null;
        }
        if (targetSim == null) continue;

        try {
          await SmsSender()
              .sendSms(
                phoneNumber: sms.number,
                message: sms.message,
                simSlot: targetSim.simSlotIndex,
              )
              .timeout(const Duration(seconds: 6), onTimeout: () => true);

          successCount++;
          smsList[i] = sms.copyWith(status: SmsStatus.sent);

          if (i < smsList.length - 1) {
            await Future.delayed(const Duration(seconds: 5));
          }
        } catch (e) {
          failCount++;
          smsList[i] = sms.copyWith(
            status: SmsStatus.failed,
            error: e.toString(),
          );
        }
      }
    } catch (e) {
      developer.log("sendAllSms error: $e");
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
          ElevatedButton(onPressed: Get.back, child: const Text('OK')),
        ],
      ),
    );
  }

  /// ── Battery ───────────────────────────────────────────────────────────────

  Future<void> initBatteryInfo() async {
    batteryLevel.value = await battery.batteryLevel;
    batteryState = await battery.batteryState;
  }

  void startListening() {
    batterySubscription?.cancel();
    batterySubscription = battery.onBatteryStateChanged.listen((state) {
      batteryState = state;
      updateBatteryLevel();
      update();
    });
  }

  Future<void> updateBatteryLevel() async {
    batteryLevel.value = await battery.batteryLevel;
  }

  Future<int> getBatteryPercentage() async {
    try {
      return await battery.batteryLevel;
    } catch (e) {
      return -1;
    }
  }

  Future<BatteryState> getBatteryState() async => battery.batteryState;

  String getBatteryStateText(BatteryState state) {
    switch (state) {
      case BatteryState.charging:
        return 'Charging';
      case BatteryState.discharging:
        return 'Discharging';
      case BatteryState.full:
        return 'Battery Full';
      case BatteryState.connectedNotCharging:
        return 'Connected (Not Charging)';
      case BatteryState.unknown:
        return 'Unknown';
    }
  }

  Color getBatteryColor(int level) {
    if (level > 50) return Colors.green;
    if (level > 30) return Colors.orange;
    return Colors.red;
  }

  /// ── Test ──────────────────────────────────────────────────────────────────

  void testLocalNotification() async {
    const channel = AndroidNotificationChannel(
      'BullkySMS',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );
    await flutterLocalNotificationsPlugin.show(
      title: 'Test Title',
      body: 'Test Body',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(channel.id, channel.name),
      ),
      id: 12345,
    );
  }
}
