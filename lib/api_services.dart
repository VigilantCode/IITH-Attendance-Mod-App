import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:math';

class ApiService {
  final Dio _dio = Dio();

  ApiService() {
    _dio.options.baseUrl = dotenv.env['BASE_URL'] ?? '';
    _dio.options.headers = {'Content-Type': 'application/json'};
  }

  Future<dynamic> login(String username, String password,
      {bool group = false}) async {
    try {
      final response = await _dio.post(
        '/GetMobileAppValidatePassword',
        data: {
          'UserID': username,
          'Password': password,
          "FCMID": group
              ? "1${generateRandomFcmToken()}"
              : "0${generateRandomFcmToken()}",
          'DeviceType': "android"
        },
      );

      if (response.statusCode == 200 && response.data[0]['errorId'] == 0) {
        return response.data;
      } else {
        return null;
      }
    } on DioException catch (e) {
      debugPrint('DioError: ${e.message}');
      return null;
    }
  }

  String generateRandomFcmToken() {
    const String chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final Random random = Random();
    return List.generate(163, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  Future<bool> isLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('user');
  }

  Future<List<dynamic>> getStudentTimeTableForAttendance(String refId) async {
    final response = await _dio.post("/GetStudentTimeTableForAttendance",
        data: {"WebIdentifier": refId});

    if (response.statusCode == 200 && response.data['table'] != null) {
      return response.data['table'];
    } else {
      throw Exception('Failed to load timetable');
    }
  }

  Future<dynamic> upsertStudentAttendanceDetails(
      String refId, String timetableId) async {
    try {
      final response = await _dio.post(
        '/UpSertStudentAttendanceDetails',
        data: {
          "Webidentifier": refId,
          "TimeTableId": timetableId,
        },
      );

      if (response.statusCode == 200) {
        return response.data['table'][0]['errorid'];
      } else {
        debugPrint('Failed to update attendance details');
      }
    } on DioException catch (e) {
      debugPrint('DioError: ${e.message}');
    }
  }

}
