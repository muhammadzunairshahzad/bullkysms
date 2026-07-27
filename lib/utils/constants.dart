import 'package:get/get.dart';

class Constants extends GetxController {
  static String environment = "test";
  static String serverUrl = environment == "live"
      ? 'https://www.bullkysms.com/'
      : environment == "test"
      ? "https://www.bullkysms.com/api-v3/"
      : 'http://39.61.32.75:7681/BullkySMS/api-v2/';

  static String websiteUrl = environment == "live"
      ? 'https://www.primemedic.com.au/'
      : environment == "test"
      ? "https://test.primemedic.com.au/"
      : 'http://39.61.32.75:7681/PrimeMedic-v3/';
  static RxString version = "".obs;
  static String name = "";
  static String appToken = "";
  static String apiKey = "";
  static String userID = "";
  static String clientID = "";
  static String clientMobID = "";
  static String mobile = "";
  static String email = "";
  static String password = "";
  static String simSlotNo = "";
  static String mobileName = "";
  static bool isLogin = false;
}
