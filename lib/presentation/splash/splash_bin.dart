import 'dart:developer' as developer;

import 'package:bullkysms/utils/color_constant.dart';
import 'package:bullkysms/utils/image_constant.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../utils/app_routes.dart';
import '../../utils/constants.dart';

part 'splash_scr.dart';
part 'splash_con.dart';

class SplashBin extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => SplashCon());
  }
}
