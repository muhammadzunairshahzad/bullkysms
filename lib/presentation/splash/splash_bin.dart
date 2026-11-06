import 'dart:developer' as developer;
import 'dart:ui';

import 'package:bullkysms/utils/color_constant.dart';
import 'package:bullkysms/utils/image_constant.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../utils/app_routes.dart';
import '../../utils/constants.dart';
import '../../utils/ripple_avatar.dart';
import '../homepage/widgets/blinking_dot.dart';

part 'splash_con.dart';
part 'splash_scr.dart';

class SplashBin extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => SplashCon());
  }
}
