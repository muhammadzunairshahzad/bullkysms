import 'package:get/get.dart';

import '../presentation/homepage/homepage_bin.dart';
import '../presentation/login/login_bin.dart';
import '../presentation/splash/splash_bin.dart';

class AppRoutes {
  static String login = '/login_screen';
  static String home = '/home_screen';
  static String initialRoute = '/initialRoute';

  static List<GetPage> pages = [
    GetPage(
      name: initialRoute,
      page: () => const SplashScr(),
      bindings: [SplashBin()],
    ),

    GetPage(name: login, page: () => const LoginScr(), bindings: [SplashBin()]),
    GetPage(
      name: home,
      page: () => const HomepageScr(),
      bindings: [SplashBin()],
    ),
  ];
}
