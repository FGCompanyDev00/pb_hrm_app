import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceService {
  final String baseUrl = 'https://demo-application-api.flexiflows.co';

  Future<void> checkInOrCheckOut(bool isCheckIn, String deviceId, double latitude, double longitude) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Determine which endpoint to use
      final String endpoint = isCheckIn ? '$baseUrl/api/attendance/checkin-checkout/office' : '$baseUrl/api/attendance/checkin-checkout/offsite';

      // Construct the payload
      final Map<String, dynamic> attendanceData = {"device_id": deviceId, "latitude": latitude.toString(), "longitude": longitude.toString()};

      // debugPrint the payload for debugging
      debugPrint('API Payload: $attendanceData');

      // Make the POST request
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(attendanceData),
      );

      // debugPrint the response for debugging
      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 202) {
        debugPrint('Check-In/Out successful.');
      } else {
        throw Exception('Failed with status code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error during the API call: $e');
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
