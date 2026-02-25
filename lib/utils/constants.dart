import 'package:get/get.dart';

class Constants extends GetxController {
  static String environment = "local";
  static String serverUrl = environment == "live"
      ? 'https://www.primemedic.com.au/ajaxs/patient_app_v5/'
      : environment == "test"
      ? "https://test.primemedic.com.au/ajaxs/patient_app_v5/"
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
}
