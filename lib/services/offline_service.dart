// services/offline_service.dart

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance_record.dart';
import 'package:flutter/foundation.dart';

class OfflineService {
  late Box<AttendanceRecord> _attendanceBox;
  final Connectivity _connectivity = Connectivity();
  late Stream<ConnectivityResult> _connectivityStream;

  void initialize() async {
    _attendanceBox = Hive.box<AttendanceRecord>('pending_attendance');
    _connectivityStream = _connectivity.onConnectivityChanged as Stream<ConnectivityResult>;
    _connectivityStream.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        _syncPendingAttendance();
      }
    });
  }

  Future<void> addPendingAttendance(AttendanceRecord record) async {
    await _attendanceBox.add(record);
  }

  Future<void> _syncPendingAttendance() async {
    if (_attendanceBox.isEmpty) return;

    List<int> keysToDelete = [];

    for (int i = 0; i < _attendanceBox.length; i++) {
      AttendanceRecord record = _attendanceBox.getAt(i)!;
      bool success = await _sendAttendance(record);
      if (success) {
        keysToDelete.add(i);
      }
    }

    // Delete successfully synced records
    for (int key in keysToDelete.reversed) {
      await _attendanceBox.deleteAt(key);
    }
  }

  Future<bool> _sendAttendance(AttendanceRecord record) async {
    String url;
    if (record.section == 'Office' || record.section == 'Home') {
      url =
      'https://demo-application-api.flexiflows.co/api/attendance/checkin-checkout/office';
    } else {
      url =
      'https://demo-application-api.flexiflows.co/api/attendance/checkin-checkout/offsite';
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(record.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 202) {
        return true;
      } else {
        if (kDebugMode) {
          print(
              'Failed to sync attendance: ${response.statusCode} - ${response.reasonPhrase}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error syncing attendance: $e');
      }
      return false;
    }
  }
}
