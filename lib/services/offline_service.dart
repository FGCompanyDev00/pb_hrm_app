// services/offline_service.dart

import 'dart:convert';
import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/hive_helper/model/add_assignment_record.dart';
import 'package:pb_hrsystem/models/qr_profile_page.dart';
import 'package:pb_hrsystem/services/local_database_service.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../hive_helper/model/attendance_record.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class OfflineProvider extends ChangeNotifier {
  late Box<AttendanceRecord> _attendanceBox;
  late Box<AddAssignmentRecord> _addAssignment;
  late Box<UserProfileRecord> _profileBox;
  late Box<QRRecord> _qrBox;
  final calendarDatabaseService = CalendarDatabaseService();
  final historyDatabaseService = HistoryDatabaseService();
  final ValueNotifier<bool> isOfflineService = ValueNotifier<bool>(false);

  // Cache for database instances
  Database? _calendarDb;
  Database? _historyDb;

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  // Flag to track initialization status
  bool _isInitializing = false;
  bool _isInitialized = false;

  //Calendar offline with improved error handling and caching
  Future<void> initializeCalendar() async {
    // Prevent multiple concurrent initializations
    if (_isInitializing) {
      debugPrint('Calendar initialization already in progress, waiting...');
      // Wait for the current initialization to complete
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    // If already initialized and database is open, return
    if (_isInitialized && _calendarDb != null && _calendarDb!.isOpen) {
      debugPrint('Calendar already initialized and open');
      return;
    }

    _isInitializing = true;

    try {
      // Close existing database if it's open
      if (_calendarDb != null && _calendarDb!.isOpen) {
        await _calendarDb!.close();
      }

      _calendarDb =
          await calendarDatabaseService.initializeDatabase('calendar');
      _isInitialized = true;
      debugPrint('Calendar database initialized successfully');
    } catch (e) {
      debugPrint('Error initializing calendar database: $e');
      // Reset initialization flags to allow retry
      _isInitialized = false;
      _calendarDb = null;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> insertCalendar(List<Events> events) async {
    if (events.isEmpty) return;

    try {
      // Ensure database is initialized and open
      if (!_isInitialized || _calendarDb == null || !_calendarDb!.isOpen) {
        await initializeCalendar();
      }

      // Create a safe copy of events and filter out any null or invalid events
      final List<Events> eventsCopy = List<Events>.from(
        events.where((event) => event != null && event.uid != null),
      );

      if (eventsCopy.isEmpty) {
        debugPrint('No valid events to insert after filtering');
        return;
      }

      await calendarDatabaseService.insertEvents(eventsCopy);
      debugPrint('Successfully inserted ${eventsCopy.length} calendar events');
    } catch (e) {
      debugPrint('Error inserting calendar events: $e');
      debugPrint('Error details: ${e.toString()}');

      // Reset initialization flag if database is closed
      if (e.toString().contains('database_closed')) {
        _isInitialized = false;
        _calendarDb = null;
        await initializeCalendar();
        // Retry insertion once after reinitializing
        if (events.isNotEmpty) {
          await calendarDatabaseService.insertEvents(events);
        }
      }
    }
  }

  Future<List<Events>> getCalendar() async {
    try {
      // Ensure database is initialized and open
      if (!_isInitialized || _calendarDb == null || !_calendarDb!.isOpen) {
        await initializeCalendar();
      }
      return await calendarDatabaseService.getListEvents();
    } catch (e) {
      debugPrint('Error fetching calendar events: $e');
      debugPrint('Error details: ${e.toString()}');

      // Reset initialization flag if database is closed
      if (e.toString().contains('database_closed')) {
        _isInitialized = false;
        _calendarDb = null;
        await initializeCalendar();
        // Retry fetch once after reinitializing
        return await calendarDatabaseService.getListEvents();
      }

      return [];
    }
  }

  //History offline with improved performance
  Future<void> initializeHistory() async {
    try {
      _historyDb = await historyDatabaseService.initializeDatabase('history');
      debugPrint('History database initialized successfully');
    } catch (e) {
      debugPrint('Error initializing history database: $e');
      // Implement proper error handling
    }
  }

  Future<void> insertHistory(List<Events> events) async {
    if (events.isEmpty) return;

    try {
      await historyDatabaseService.insertHistory(events);
      debugPrint('Successfully inserted ${events.length} history events');
    } catch (e) {
      debugPrint('Error inserting history events: $e');
      // Implement proper error handling
    }
  }

  Future<List<Events>> getHistory() async {
    try {
      return await historyDatabaseService.getListHistory();
    } catch (e) {
      debugPrint('Error fetching history events: $e');
      return [];
    }
  }

  //History Pending offline
  void initializeHistoryPending() async {
    await historyDatabaseService.initializeDatabase('history');
  }

  void insertHistoryPending(List<Events> events) async {
    await historyDatabaseService.insertHistory(events);
  }

  Future<List<Events>> getHistoryPending() async {
    return await historyDatabaseService.getListHistory();
  }

  void initialize() async {
    try {
      _attendanceBox =
          await Hive.openBox<AttendanceRecord>('pending_attendance');
      _addAssignment =
          await Hive.openBox<AddAssignmentRecord>('add_assignment');
      _profileBox = await Hive.openBox<UserProfileRecord>('user_profile');
      _qrBox = await Hive.openBox<QRRecord>('qr_profile');

      await initializeCalendar();
      await initializeHistory();

      debugPrint('All databases initialized successfully');
    } catch (e) {
      debugPrint('Error initializing databases: $e');
      // Implement proper error handling
    }
  }

  Future<void> autoOffline(bool offline) async {
    isOfflineService.value = offline;
    notifyListeners();
  }

  Future<void> addPendingAttendance(AttendanceRecord record) async {
    await _attendanceBox.add(record);
  }

  Future<void> addAssignment(AddAssignmentRecord record) async {
    await _addAssignment.add(record);
  }

  bool isExistedProfile() {
    return _profileBox.isNotEmpty;
  }

  Future<void> addProfile(UserProfileRecord record) async {
    final data = await _profileBox.add(record);
    debugPrint(data.toString());
  }

  Future<void> updateProfile(UserProfileRecord record) async {
    await _profileBox.put(1, record);
  }

  UserProfileRecord? getProfile() {
    return _profileBox.get(1);
  }

  bool isExistedQR() {
    return _qrBox.isNotEmpty;
  }

  Future<void> addQR(QRRecord record) async {
    final data = await _qrBox.add(record);
    debugPrint(data.toString());
  }

  Future<void> updateQR(QRRecord record) async {
    await _qrBox.put(1, record);
  }

  String getQR() {
    return _qrBox.get(1).toString();
  }

  Future<void> syncPendingAttendance() async {
    if (isOfflineService.value) return;
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

  Future<void> syncAddAssignment() async {
    if (isOfflineService.value) return;
    if (_addAssignment.isEmpty) return;

    List<int> keysToDelete = [];

    for (int i = 0; i < _addAssignment.length; i++) {
      AddAssignmentRecord record = _addAssignment.getAt(i)!;
      bool success = await _sendAssignment(record);
      if (success) {
        keysToDelete.add(i);
      }
    }

    // Delete successfully synced records
    for (int key in keysToDelete.reversed) {
      await _addAssignment.deleteAt(key);
    }
  }

  Future<bool> _sendAttendance(AttendanceRecord record) async {
    String url;
    if (record.section == 'Office' || record.section == 'Home') {
      url = '$baseUrl/api/attendance/checkin-checkout/office';
    } else {
      url = '$baseUrl/api/attendance/checkin-checkout/offsite';
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

  Future<bool> _sendAssignment(AddAssignmentRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // Build the request
    var uri = Uri.parse(baseUrl);
    var request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    // Fill the fields
    request.fields['project_id'] = record.projectId;
    request.fields['title'] = record.title;
    request.fields['descriptions'] = record.descriptions;
    request.fields['status_id'] = record.statusId;

    List<Map<String, String>> membersDetails = record.members
        .map((member) => {"employee_id": member['employee_id'].toString()})
        .toList();
    request.fields['memberDetails'] = jsonEncode(membersDetails);

    // If there's an image
    if (record.imagePath != null) {
      final mimeType =
          lookupMimeType(record.imagePath!) ?? 'application/octet-stream';
      final mimeSplit = mimeType.split('/');
      request.files.add(
        await http.MultipartFile.fromPath(
          'file_name',
          record.imagePath!,
          contentType: MediaType(mimeSplit[0], mimeSplit[1]),
        ),
      );
    }

    // Send the request
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    // Show success *only* if 200 <= statusCode < 300
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return true;
    } else {
      debugPrint('Failed to add item.\n\nAPI Response:\n${response.body}');
    }

    return false;
  }

  @override
  void dispose() {
    // Close databases properly when provider is disposed
    _closeAllDatabases();
    super.dispose();
  }

  // Method to properly close all databases
  Future<void> _closeAllDatabases() async {
    try {
      if (_calendarDb != null && _calendarDb!.isOpen) {
        await _calendarDb!.close();
        _calendarDb = null;
      }
      if (_historyDb != null && _historyDb!.isOpen) {
        await _historyDb!.close();
        _historyDb = null;
      }
      _isInitialized = false;
      debugPrint('All databases closed properly');
    } catch (e) {
      debugPrint('Error closing databases: $e');
    }
  }

  // Reset database connections if needed
  Future<void> resetDatabases() async {
    await _closeAllDatabases();
    _isInitialized = false;
    _isInitializing = false;
    _calendarDb = null;
    _historyDb = null;

    // Reinitialize databases
    await initializeCalendar();
    await initializeHistory();
    debugPrint('Databases reset and reinitialized');
  }
}
