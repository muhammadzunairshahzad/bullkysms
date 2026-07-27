import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:another_telephony/telephony.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:bullkysms/presentation/homepage/widgets/foreground_services.dart';
import 'package:bullkysms/presentation/homepage/widgets/individualSMS.dart';
import 'package:bullkysms/presentation/homepage/widgets/received_event_queue.dart';
import 'package:bullkysms/presentation/homepage/widgets/serverSMS.dart';
import 'package:bullkysms/utils/app_routes.dart';
import 'package:bullkysms/utils/color_constant.dart';
import 'package:bullkysms/utils/constants.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/ui/with_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_sim_data/sim_data.dart';
import 'package:flutter_sim_data/sim_data_model.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_state/phone_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_sender_background/sms_sender.dart';
import '../../main.dart';
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
