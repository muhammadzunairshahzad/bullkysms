part of 'login_bin.dart';

class LoginScr extends StatelessWidget {
  const LoginScr({super.key});

  @override
  Widget build(BuildContext context) {
    final con = Get.put(LoginCon());
    final size = MediaQuery.of(context).size;
    final topHeight = size.height * 0.5;
    return Scaffold(
      body: Stack(
        children: [
          Container(color: Color(0xFFF1F4FA)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topHeight,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF1F4FA), // fully visible
                    Color(0xFFF1F4FA), // still visible
                    Colors.transparent, // fades out near bottom
                  ],
                  stops: [0.0, 0.55, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 0, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: CColor.backgroundGradient,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(150),
                      bottomRight: Radius.circular(150),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFF1F4FA).withOpacity(0.9),
                        blurRadius: 100,
                        spreadRadius: 100,
                        offset: const Offset(0, 100),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Obx(
              () => Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: SingleChildScrollView(
                      child: Column(
                        // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              SizedBox(height: 20),
                              Image.asset(
                                ImageConstant.appLogo,
                                color: Colors.white,
                              ),
                              SizedBox(height: 10),
                              Text(
                                "LOGIN",
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                "Connect your phone gateway device to start relaying and broadcasting SMS",
                                softWrap: true,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w300,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Color(0xFFD0D5DD),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  /// Email
                                  Padding(
                                    padding: const EdgeInsets.only(top: 15.0),
                                    child: Text(
                                      "EMAIL ADDRESS",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: double.maxFinite,
                                    height: 45,
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Color(0xFFD0D5DD),
                                        width: 2,
                                      ),
                                    ),
                                    margin: const EdgeInsets.only(top: 5),
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 0.0,
                                        right: 8,
                                        top: 0,
                                      ),
                                      child: TextFormField(
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        controller: con.emailCon,
                                        focusNode: con.emailNode,
                                        cursorColor: CColor.secondary,
                                        autovalidateMode:
                                            AutovalidateMode.onUserInteraction,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.only(
                                            top: 3.0,
                                          ),
                                          prefixIcon: Icon(
                                            Icons.email_outlined,
                                            color: Colors.grey,
                                          ),
                                          hintText: "name@company.com",
                                          hintStyle: TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                        style: TextStyle(color: Colors.black),
                                      ),
                                    ),
                                  ),
                                  Obx(
                                    () => Visibility(
                                      visible: con.emailError.value.isNotEmpty,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
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
                                      "PASSWORD / API KEY",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: double.maxFinite,
                                    height: 45,
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Color(0xFFD0D5DD),
                                        width: 2,
                                      ),
                                    ),
                                    margin: const EdgeInsets.only(top: 10),
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
                                          // contentPadding:
                                          //     const EdgeInsets.symmetric(
                                          //       vertical: 8,
                                          //     ),
                                          contentPadding: EdgeInsets.only(
                                            top: 3.0,
                                          ),
                                          prefixIcon: Icon(
                                            Icons.key,
                                            color: Colors.grey,
                                          ),
                                          hintText: "xxxxxxxx",
                                          hintStyle: TextStyle(
                                            color: Colors.grey,
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
                                  Obx(
                                    () => Visibility(
                                      visible: con.passError.value.isNotEmpty,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
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
                                      "MOBILE NUMBER",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: double.maxFinite,
                                    height: 45,
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Color(0xFFD0D5DD),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withValues(
                                            alpha: 0.2,
                                          ),
                                          spreadRadius: 0.5,
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    margin: const EdgeInsets.only(top: 5),
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 0.0,
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

                                          contentPadding: EdgeInsets.only(
                                            top: 3.0,
                                          ),
                                          prefixIcon: Icon(
                                            Icons.phone_android,
                                            color: Colors.grey,
                                          ),
                                          hintText: "61*********",
                                          hintStyle: TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                        style: TextStyle(color: Colors.black),
                                      ),
                                    ),
                                  ),
                                  Obx(
                                    () => Visibility(
                                      visible: con.mobError.value.isNotEmpty,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
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
                                              borderRadius:
                                                  BorderRadius.circular(6),
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
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
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
                          SizedBox(height: 20),
                          GestureDetector(
                            onTap: () {
                              con.launchInBrowser(
                                Uri.parse("https://www.bullkysms.com/register"),
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't Have an Account?  ",
                                  style: TextStyle(color: Colors.black),
                                ),
                                Text(
                                  'Register',
                                  style: TextStyle(
                                    color: CColor.secondary2,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (con.isLoading.value)
                    Container(color: Colors.black.withValues(alpha: 0.3)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
