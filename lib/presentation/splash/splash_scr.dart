part of 'splash_bin.dart';

class SplashScr extends StatelessWidget {
  const SplashScr({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(SplashCon());
    final size = MediaQuery.of(context).size;
    final topHeight = size.height * 0.5;
    return Scaffold(
      body: Stack(
        children: [
          Container(color: Colors.white),
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
                    Colors.white, // fully visible
                    Colors.white, // still visible
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
                        color: Colors.white.withOpacity(0.9),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    RippleAvatar(
                      imageUrl: ImageConstant.appLogoAvatar,
                      radius: 150.0,
                      rippleColor: Colors.white,
                    ),
                    SizedBox(height: 20),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Bullky ',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: 'SMS',
                            style: TextStyle(
                              color: CColor.secondary2,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 5),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: CColor.secondary2, width: 2),
                      ),
                      padding: EdgeInsets.all(8),

                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BlinkingDot(size: 10, color: CColor.secondary2),
                          SizedBox(width: 5),
                          Text("NEXT-GEN CELLULAR SMS GATEWAY"),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  'Easiest & Cheapest Way To Approach Your Customers via SMS in ',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: 'Australia',
                              style: TextStyle(
                                color: CColor.secondary2,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Text(
                        "We are the cheapest way to promote your products & offers via SMS",
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),

                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Powered By:',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.normal,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(width: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: CColor.secondary3,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey, width: 2),
                          ),
                          padding: EdgeInsets.all(8),

                          child: Text(
                            "IT VIRTUAL HOUSE",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Obx(
                              () => Text(
                                "V${Constants.version.value}",
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w300,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(
                              Icons.gpp_good_outlined,
                              color: CColor.secondary2,
                            ),
                            SizedBox(width: 5),
                            Text(
                              "End-to-End Encrypted",
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w300,
                                fontSize: 14,
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
        ],
      ),
    );
  }
}
