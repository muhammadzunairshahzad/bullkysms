part of 'login_bin.dart';

class LoginScr extends StatelessWidget {
  const LoginScr({super.key});

  @override
  Widget build(BuildContext context) {
    final con = Get.put(LoginCon());
    return Scaffold(
      body: Container(
        height: Get.height,
        width: Get.width,
        decoration: BoxDecoration(gradient: CColor.backgroundGradient),
        child: SafeArea(
          child: Obx(
            () => Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      SizedBox(height: 60),
                      Image.asset(ImageConstant.appLogo),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 60),
                              Text(
                                "Login to your account",
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),

                              /// Email
                              Padding(
                                padding: const EdgeInsets.only(top: 15.0),
                                child: Text(
                                  "Email:",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Container(
                                width: double.maxFinite,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(0xFFD0D5DD)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withValues(alpha: 0.2),
                                      spreadRadius: 0.5,
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                margin: const EdgeInsets.only(top: 5),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8.0,
                                    right: 8,
                                    top: 0,
                                  ),
                                  child: TextFormField(
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    controller: con.emailCon,
                                    focusNode: con.emailNode,
                                    cursorColor: CColor.secondary,
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.all(0.0),
                                    ),
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ),
                              ),
                              Obx(
                                () => Visibility(
                                  visible: con.emailError.value.isNotEmpty,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(height: 5),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 6.0,
                                        ),
                                        child: Text(
                                          con.emailError.value,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.red.shade300,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              /// Password
                              Padding(
                                padding: EdgeInsets.only(top: 15),
                                child: Text(
                                  "Password / API Key:",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Container(
                                width: double.maxFinite,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(0xFFD0D5DD)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withValues(alpha: 0.2),
                                      spreadRadius: 0.5,
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                margin: const EdgeInsets.only(top: 10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Obx(
                                    () => TextFormField(
                                      controller: con.passCon,
                                      focusNode: con.passNode,
                                      autocorrect: false,
                                      showCursor: true,
                                      cursorColor: CColor.secondary,
                                      textInputAction: TextInputAction.next,
                                      keyboardType:
                                          TextInputType.visiblePassword,
                                      obscureText: con.obscureText.value,
                                      obscuringCharacter: '●',
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                        suffixIcon: Padding(
                                          padding: const EdgeInsets.only(
                                            right: 0.0,
                                            left: 0.0,
                                          ),
                                          child: IconButton(
                                            icon: Icon(
                                              con.obscureText.value
                                                  ? CupertinoIcons.eye
                                                  : CupertinoIcons.eye_slash,
                                              size: 26,
                                              color: Colors.black,
                                            ),
                                            onPressed: () {
                                              debugPrint(
                                                "${con.obscureText.value}",
                                              );

                                              con.obscureText.value =
                                                  !con.obscureText.value;
                                            },
                                          ),
                                        ),
                                      ),
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                ),
                              ),
                              Obx(
                                () => Visibility(
                                  visible: con.passError.value.isNotEmpty,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(height: 5),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 6.0,
                                        ),
                                        child: Text(
                                          con.passError.value,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.red.shade300,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              /// Mobile
                              Padding(
                                padding: const EdgeInsets.only(top: 15),
                                child: Text(
                                  "Mobile Number:",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Container(
                                width: double.maxFinite,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(0xFFD0D5DD)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withValues(alpha: 0.2),
                                      spreadRadius: 0.5,
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                margin: const EdgeInsets.only(top: 5),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8.0,
                                    right: 8,
                                    top: 0,
                                  ),
                                  child: TextFormField(
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.next,
                                    controller: con.mobCon,
                                    focusNode: con.mobNode,
                                    cursorColor: CColor.secondary,
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.all(0.0),
                                    ),
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ),
                              ),
                              Obx(
                                () => Visibility(
                                  visible: con.mobError.value.isNotEmpty,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(height: 5),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 6.0,
                                        ),
                                        child: Text(
                                          con.mobError.value,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.red.shade300,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              MaterialButton(
                                onPressed: () {
                                  if (con.isLoading.value == false) {
                                    con.checkLogin();
                                  }
                                },
                                color: Color(0xFFE30000),
                                splashColor: CColor.secondary,
                                minWidth: Get.width,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                height: 50,
                                padding: EdgeInsets.only(right: 4),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Color(0xFFE30000),
                                        ),
                                      ),
                                    ),
                                    Obx(
                                      () => Align(
                                        alignment: Alignment.center,
                                        child: con.isLoading.value
                                            ? SizedBox(
                                                height: 25,
                                                width: 25,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : Text(
                                                'LOGIN',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 20),
                              GestureDetector(
                                onTap: () {
                                  con.launchInBrowser(
                                    Uri.parse(
                                      "https://www.bullkysms.com/register",
                                    ),
                                  );
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Don't Have an Account?  ",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    Text(
                                      'Register',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (con.isLoading.value)
                  Container(color: Colors.black.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
