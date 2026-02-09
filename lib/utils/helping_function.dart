import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:connectivity_wrapper/connectivity_wrapper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';

class Functions {
  static Future<dynamic> sendJson(jsonMap, page) async {
    if (await ConnectivityWrapper.instance.isConnected) {
      dynamic jsonData;
      dynamic response;
      var jsonError = {
        'DocType': 'Error',
        'DocDate': DateTime.now().toString(),
        'Message': 'Check Internet Connection & try again - Server Error!',
      };
      try {
        log(Constants.serverUrl + page);
        response = await http.post(
          Uri.parse(Constants.serverUrl + page),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(jsonMap),
        );
        if (kDebugMode) {
          log("-> ${response.body}");
        }
        log("StatusCode: ${response.statusCode}");
        if (response.statusCode == 200) {
          try {
            jsonData = json.decode(response.body);
            log("jsonData - $jsonData");
          } on FormatException catch (e) {
            log("Check Internet Connection & try again - ${e.message}");
            return jsonError["Message"] =
                "Check Internet Connection & try again - ${e.message}";
          }
          return jsonData;
        } else {
          log("Check Internet Connection & try again - ${response.statusCode}");
          return jsonError["Message"] =
              "Check Internet Connection & try again - ${response.statusCode}";
        }
      } catch (e) {
        if (kDebugMode) {
          log('EXP: ${e.toString()}');
        }
        return jsonError["Message"] =
            "Check Internet Connection & try again - ${e.toString()}";
      }
    } else {
      return;
    }
  }

  static bool isMobile(String number) {
    return RegExp(r'^04([0-9]{8})$').hasMatch(number);
  }

  static bool isPhone(String number) {
    return RegExp(r'^02([0-9]{8})$').hasMatch(number);
  }

  static bool isEmail(String email) {
    return RegExp(
      r"^[a-zA-Z0-9][a-zA-Z0-9._%+-]*@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(?:\.[a-zA-Z]{2,})?$",
    ).hasMatch(email);
  }

  static bool validatePassword(String value) {
    return RegExp(
      r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9]).{8,}$',
    ).hasMatch(value);
  }

  static void closeKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }
}
