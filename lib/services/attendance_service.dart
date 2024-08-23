import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceService {
  final String baseUrl = 'https://demo-application-api.flexiflows.co';

  Future<void> checkInOrCheckOut(bool isCheckIn, Map<String, dynamic> attendanceData) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('User not authenticated');
    }

    try {

      final endpoint = '$baseUrl/api/attendance/checkin-checkout/clock-in-out';

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(attendanceData),
      );

      if (response.statusCode == 403) {
        throw Exception('403 Forbidden: Access denied. Check your token or permissions.');
      } else if (response.statusCode == 404) {
        throw Exception('404 Not Found: The endpoint was not found.');
      } else if (response.statusCode != 201) {
        throw Exception('Failed to submit attendance. Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error during the API call: $e');
    }
  }

  Future<void> checkInOrCheckOutOffsite(bool isCheckIn, Map<String, dynamic> attendanceData) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Separate endpoint for Offsite check-in or check-out
      final endpoint = '$baseUrl/api/attendance/checkin-checkout/offsite';

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(attendanceData),
      );

      if (response.statusCode == 403) {
        throw Exception('403 Forbidden: Access denied. Check your token or permissions.');
      } else if (response.statusCode == 404) {
        throw Exception('404 Not Found: The endpoint was not found.');
      } else if (response.statusCode != 201) {
        throw Exception('Failed to submit attendance. Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error during the API call: $e');
    }
  }
}
