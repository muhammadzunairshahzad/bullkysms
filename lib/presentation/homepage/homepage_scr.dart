part of 'homepage_bin.dart';

class HomepageScr extends StatelessWidget {
  const HomepageScr({super.key});

  @override
  Widget build(BuildContext context) {
    final con = Get.put(HomepageCon());
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: CColor.red,
        title: Text(
          "Bullky SMS: ${Constants.mobile}",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () {
              con.isSending.value = !con.isSending.value;
            },
            icon: Icon(Icons.refresh, color: Colors.white),
          ),
          IconButton(
            onPressed: () async {
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Obx(
            () => con.isSending.value
                ? Image.asset(
                    "assets/anim/animate.gif",
                    width: Get.width,
                    height: 280,
                  )
                : Lottie.asset(
                    "assets/anim/sand.json",
                    width: Get.width - 100,
                    height: 280,
                  ),
          ),
          Center(
            child: Obx(
              () => Text(
                con.isSending.value ? "Sending SMS..." : "Awaiting SMS...",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () async {
              con.sendAllSms();
            },
            icon: Icon(Icons.add),
          ),
          Obx(
            () => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Positioned(
                      right: -12,
                      child: Container(
                        width: 10,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      width: 100 * (con.batteryLevel.value / 100),
                      height: 50,
                      decoration: BoxDecoration(
                        color: con.getBatteryColor(con.batteryLevel.value),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Text(
                      '${con.batteryLevel.value}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: con.batteryLevel.value > 30
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30),
                Text(
                  con.getBatteryStateText(con.batteryState),
                  style: TextStyle(
                    fontSize: 20,
                    color: con.batteryState == BatteryState.charging
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: con.initBatteryInfo,
                  child: Text('Refresh Battery Info'),
                ),
              ],
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    labelColor: Colors.red,
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(text: "SIM 1", icon: Icon(Icons.sim_card)),
                      Tab(text: "SIM 2", icon: Icon(Icons.sim_card)),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildSmsList(con.sim1Messages),
                        _buildSmsList(con.sim2Messages),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expanded(
          //   child: Obx(() => ListView.builder(
          //     itemCount: con.inboxMessages.length,
          //     padding: EdgeInsets.symmetric(horizontal: 10),
          //     itemBuilder: (context, index) {
          //       final msg = con.inboxMessages[index];
          //       return Card(
          //         elevation: 0.5,
          //         margin: EdgeInsets.symmetric(vertical: 5),
          //         child: ListTile(
          //           leading: CircleAvatar(
          //             backgroundColor: CColor.red.withOpacity(0.1),
          //             child: Icon(Icons.sms, color: CColor.red),
          //           ),
          //           title: Text(
          //             msg.address,
          //             style: TextStyle(fontWeight: FontWeight.bold),
          //           ),
          //           subtitle: Text(msg.body),
          //           trailing: Text(
          //             _formatDate(msg.date),
          //             style: TextStyle(fontSize: 10, color: Colors.grey),
          //           ),
          //         ),
          //       );
          //     },
          //   )),
          // ),
        ],
      ),
    );
  }

  Widget _buildSmsList(RxList<SmsMessage> list) {
    return Obx(
      () => list.isEmpty
          ? Center(child: Text("No messages for this SIM"))
          : ListView.builder(
              itemCount: list.length,
              padding: const EdgeInsets.all(10),
              itemBuilder: (context, index) {
                final msg = list[index];
                return Card(
                  child: ListTile(
                    title: Text(
                      msg.address ?? "Unknown",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(msg.body ?? "Unknow"),
                  ),
                );
              },
            ),
    );
  }
}
