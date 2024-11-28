// services/offline_service.dart

import 'dart:convert';
import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/services/local_database_service.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import '../hive_helper/model/attendance_record.dart';
import 'package:flutter/foundation.dart';

class OfflineProvider extends ChangeNotifier {
  late Box<AttendanceRecord> _attendanceBox;
  LocalDatabaseService localDatabaseService = LocalDatabaseService();

  // late Box<CalendarEventsListRecord> _calendarEventsBox;

  void initializeCalendar() async {
    await localDatabaseService.initializeDatabase('calendar');
  }

  void insertCalendar(List<Events> events) async {
    await localDatabaseService.insertEvents(events);
  }

  Future<List<Events>> getCalendar() async {
    return await localDatabaseService.getListEvents();
  }

  void initialize() async {
    _attendanceBox = Hive.box<AttendanceRecord>('pending_attendance');
    // _calendarEventsBox = Hive.box<CalendarEventsListRecord>('store_events_calendar');
  }

  // Future<void> addEventsCalendar(CalendarEventsListRecord events) async {
  //   await _calendarEventsBox.add(events);
  //   debugPrint('calendar ${_calendarEventsBox.values.first.listEvents.length}');
  // }

  // CalendarEventsListRecord? getEventsCalendar() {
  //   if (_calendarEventsBox.isNotEmpty) return _calendarEventsBox.values.first;
  //   return null;
  // }

  Future<void> addPendingAttendance(AttendanceRecord record) async {
    await _attendanceBox.add(record);
  }

  Future<void> syncPendingAttendance() async {
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
      url = 'https://demo-application-api.flexiflows.co/api/attendance/checkin-checkout/office';
    } else {
      url = 'https://demo-application-api.flexiflows.co/api/attendance/checkin-checkout/offsite';
    }

    String? token = sl<UserPreferences>().getToken();

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
          print('Failed to sync attendance: ${response.statusCode} - ${response.reasonPhrase}');
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
