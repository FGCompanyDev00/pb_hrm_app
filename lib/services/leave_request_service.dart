import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/core/utils/auth_utils.dart';

class LeaveRequestService {
  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  Future<void> addLeaveRequest(Map<String, dynamic> leaveRequestData) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // Use centralized auth validation with redirect
    if (!await AuthUtils.validateTokenAndRedirect(token)) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/leave-type'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(leaveRequestData),
      );

      if (response.statusCode == 403) {
        throw Exception(
            '403 Forbidden: Access denied. Check your token or permissions.');
      } else if (response.statusCode != 200) {
        throw Exception(
            'Failed to submit leave request. Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error during the API call: $e');
    }
  }
}
