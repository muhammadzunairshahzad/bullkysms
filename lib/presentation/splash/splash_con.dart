part of 'splash_bin.dart';

class SplashCon extends GetxController {
  RxString version = "".obs;
  late PackageInfo packageInfo;
  @override
  void onInit() async {
    super.onInit();
    packageInfo = await PackageInfo.fromPlatform();
    Constants.version.value = packageInfo.version;
    FirebaseMessaging.instance
        .getToken(
    ).then((s) {
      Constants.appToken = s!;
      developer.log("AppToken: ${Constants.appToken}");
    });
    Future.delayed(const Duration(seconds: 2), () {
      Get.offAllNamed(AppRoutes.login);
    });
  }
}
