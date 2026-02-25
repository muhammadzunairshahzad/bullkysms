import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:another_telephony/telephony.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:bullkysms/utils/app_routes.dart';
import 'package:bullkysms/utils/color_constant.dart';
import 'package:bullkysms/utils/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sim_data/sim_data.dart';
import 'package:flutter_sim_data/sim_data_model.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/db.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/helping_function.dart';
part 'homepage_con.dart';
part 'homepage_scr.dart';

class HomepageBin extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => HomepageCon());
  }
}
