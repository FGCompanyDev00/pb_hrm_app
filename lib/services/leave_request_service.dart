import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LeaveRequestService {
  static const String baseUrl = 'https://demo-application-api.flexiflows.co';

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> fetchLeaveRequests() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/leave_requests'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      var body = json.decode(response.body);
      if (body['results'] != null && body['results'] is List) {
        return (body['results'] as List)
            .map((item) => {
              'leave_request_id': item['leave_request_id'],
              'leave_type_id': item['leave_type_id'],
              'take_leave_reason': item['take_leave_reason'],
              'take_leave_from': item['take_leave_from'],
              'take_leave_to': item['take_leave_to'],
              'days': item['days'],
              'status': item['status'],
            })
            .toList();
      } else {
        throw Exception('Unexpected response format');
      }
    } else {
      print('Error: ${response.statusCode}, ${response.body}');
      throw Exception('Failed to load leave requests: ${response.reasonPhrase}');
    }
  }

  Future<void> addLeaveRequest(Map<String, dynamic> leaveRequestData) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/leave_requests'),
      headers: headers,
      body: jsonEncode(leaveRequestData),
    );

    if (response.statusCode == 201) {
      print('Leave request successfully created.');
    } else {
      print('Error: ${response.statusCode}, ${response.body}');
      throw Exception('Failed to add leave request: ${response.reasonPhrase}');
    }
  }

  Future<void> updateLeaveRequest(String leaveRequestId, Map<String, dynamic> leaveRequestData) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/leave_requests/$leaveRequestId'),
      headers: headers,
      body: jsonEncode(leaveRequestData),
    );

    if (response.statusCode != 200) {
      print('Error: ${response.statusCode}, ${response.body}');
      throw Exception('Failed to update leave request: ${response.reasonPhrase}');
    }
  }

  Future<void> deleteLeaveRequest(String leaveRequestId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/api/leave_requests/$leaveRequestId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      print('Error: ${response.statusCode}, ${response.body}');
      throw Exception('Failed to delete leave request: ${response.reasonPhrase}');
    }
  }
}
