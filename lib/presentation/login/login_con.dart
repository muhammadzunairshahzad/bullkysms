part of 'login_bin.dart';

class LoginCon extends GetxController {
  TextEditingController emailCon = TextEditingController();
  TextEditingController passCon = TextEditingController();
  TextEditingController mobCon = TextEditingController();
  FocusNode emailNode = FocusNode();
  FocusNode passNode = FocusNode();
  FocusNode mobNode = FocusNode();
  RxString emailError = "".obs;
  RxString passError = "".obs;
  RxString mobError = "".obs;
  RxBool obscureText = true.obs;
  RxBool isLoading = false.obs;
  @override
  Future<void> onInit() async {
    super.onInit();
    await autoLogin();
  }
  Future<void> launchInBrowser(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> checkLogin() async {
    Get.offAllNamed(AppRoutes.home);
    return;
    if (Functions.isEmail(emailCon.text.toString()) == false) {
      emailError.value = "Must Enter Valid Email";
      emailNode.requestFocus();
      return;
    } else {
      emailError.value = "";
    }
    if (passCon.text.toString().length < 8) {
      passError.value = "Must Enter Valid Password / API Key";
      passNode.requestFocus();
      return;
    } else {
      passError.value = "";
    }
    if (mobCon.text.toString().length < 5) {
      mobError.value = "Must Enter Valid Password / API Key";
      mobNode.requestFocus();
      return;
    } else {
      mobError.value = "";
    }
    Functions.closeKeyboard();
    isLoading.value = true;
    var msgResult = "";
    dynamic response;
    try {
      var jsonMap = {
        'DocType': 'SignIn',
        'DocDate': DateTime.now().toString(),
        'AppType': Platform.isIOS ? 'iOS' : 'Android',
        'UserName': emailCon.text.trim(),
        'Password': passCon.text.trim(),
        'Token': Constants.appToken,
      };
      if (kDebugMode) {
        print(jsonMap);
      }
      response = await Functions.sendJson(jsonMap, 'login');
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
      isLoading.value = false;
      if (msgResult == 'Success') {
        final db = await SQLite.instance.database;
        await db.rawQuery("""
        UPDATE User SET
        UserID = ${response["PatientID"]},
        Email = '${emailCon.text.trim()}',
        Password = '${passCon.text.trim()}',
        Mobile = '${mobCon.text.trim()}',
        AppKey = '${response["AppKey"]}'
        WHERE UserID = 0
        """);

        // Constants.userID = int.parse(response["UserID"]);
        Constants.appKey = response["AppKey"];
        Constants.mobile = mobCon.text.trim();

        if (kDebugMode) {
          print("${Constants.appKey} - ${Constants.userID}");
        }
        passCon.text = "";
        Get.offAllNamed(AppRoutes.home);
      } else {
        DialogUtils.errorDialog(msgResult);
        passCon.text = "";
      }
    }
  }

  Future<void> autoLogin() async {
    try {
      final db = await SQLite.instance.database;
      final queryData = await db.rawQuery(
        "SELECT Email, Password, Mobile FROM User WHERE UserID = 0",
      );

      if (queryData.isNotEmpty) {
        final row = queryData[0];
        final email = row["Email"]?.toString() ?? "";
        final password = row["Password"]?.toString() ?? "";
        final mobile = row["Mobile"]?.toString() ?? "";

        if (email.isNotEmpty && password.isNotEmpty && mobile.isNotEmpty) {
          emailCon.text = email;
          passCon.text = password;
          mobCon.text = mobile;
          // await Future.delayed(const Duration(milliseconds: 300));
          await checkLogin();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Auto login error: $e");
      }
    }
  }
}
