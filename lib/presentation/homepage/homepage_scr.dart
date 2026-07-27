part of 'homepage_bin.dart';

class HomepageScr extends StatelessWidget {
  const HomepageScr({super.key});

  @override
  Widget build(BuildContext context) {
    final con = Get.put(HomepageCon());
    return WithForegroundTask(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: CColor.red,
          title: Image.asset(
            "assets/images/logo.png",
            color: Colors.white,
            height: 55,
          ),
          actions: [
            Obx(
              () => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: con.isConnected.value ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        con.isConnected.value ? Icons.wifi : Icons.wifi_off,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        con.isConnected.value
                            ? con.connectionStatus.value
                            : "Offline",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () async {
                if (!con.isConnected.value) {
                  Get.snackbar(
                    'No Internet',
                    'Please check your internet connection',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                  return;
                }
                if (con.isSending.value) {
                  Get.snackbar(
                    'Already Running',
                    'SMS pipeline is already in progress',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.orange,
                    colorText: Colors.white,
                  );
                  return;
                }
                await con.startServerSmsPipeline();
              },
              icon: Icon(Icons.refresh, color: Colors.white),
            ),
            IconButton(
              onPressed: () async {
                if (con.isSending.value) {
                  Get.snackbar(
                    'Already Running',
                    'SMS pipeline is already in progress',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.orange,
                    colorText: Colors.white,
                  );
                  return;
                }
                final db = await SQLite.instance.database;
                await db.rawQuery("""
        UPDATE User SET
        Email = '',
        Password = '',
        Mobile = '',
        APIKey = '',
        AppKey = ''
        WHERE UserID = 0
        """);
                Get.offAllNamed(AppRoutes.login);
              },
              icon: Icon(Icons.logout, color: Colors.white),
            ),
          ],
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.withAlpha(120)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "+${Constants.mobile}",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    Constants.mobileName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.sim_card, color: Colors.red),
                                  Text("Sim 1", style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 5),
                          Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: Get.width / 1.6,
                                child: Obx(
                                  () => RichText(
                                    textAlign: TextAlign.start,
                                    text: TextSpan(
                                      text: 'Campaign Name: ',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: con.isSending.value
                                              ? con.currentCampaignName.value
                                              : con.campaignName.value,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 14,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              SizedBox(
                                width: Get.width / 4.4,
                                child: Obx(
                                  () => Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 60,
                                        height: 50,
                                        child: con.isSending.value
                                            ? Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: Lottie.asset(
                                                  "assets/anim/send.json",
                                                  fit: BoxFit.contain,
                                                  height: 80,
                                                ),
                                              )
                                            : Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Container(
                                                    width: 32,
                                                    height: 32,
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: Colors.yellow,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                  ),
                                                  Lottie.asset(
                                                    "assets/anim/sand.json",
                                                    fit: BoxFit.contain,
                                                    height: 60,
                                                  ),
                                                ],
                                              ),
                                      ),
                                      con.isSending.value
                                          ? RichText(
                                              textAlign: TextAlign.center,
                                              text: TextSpan(
                                                text: 'Sent: ',
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                                children: [
                                                  TextSpan(
                                                    text:
                                                        "${con.serverSentCount.value}/${con.serverTotalSms.value}",
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.normal,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : Text(
                                              "Awaiting SMS",
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0.5,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                        child: Container(height: 6, color: CColor.secondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            Spacer(),
            Obx(
              () => Center(
                child: Text(
                  "Version: ${Constants.version.value}",
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w300,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
