import 'dart:developer' as developer;
import 'dart:io';
import 'package:bullkysms/utils/app_routes.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/bindings_interface.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/color_constant.dart';
import '../../utils/constants.dart';
import '../../utils/db.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/helping_function.dart';
import '../../utils/image_constant.dart';
part 'login_scr.dart';
part 'login_con.dart';

class LoginBin extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LoginCon());
  }
}
