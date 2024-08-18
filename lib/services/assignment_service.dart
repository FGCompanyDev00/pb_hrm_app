import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AssignmentService {
  static const String baseUrl = 'https://demo-application-api.flexiflows.co';

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Fetch assignments for a specific project
  Future<List<Map<String, dynamic>>> fetchAssignments(String projectId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/work-tracking/ass/assignments?proj_id=$projectId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      var body = json.decode(response.body);
      if (body['results'] != null && body['results'] is List) {
        return List<Map<String, dynamic>>.from(body['results']);
      } else {
        throw Exception('Unexpected response format');
      }
    } else {
      throw Exception('Failed to load assignments: ${response.reasonPhrase}');
    }
  }

  // Add a new assignment
  Future<void> addAssignment(String projectId, Map<String, dynamic> taskData) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/work-tracking/ass/insert'),
      headers: headers,
      body: jsonEncode({
        'project_id': projectId,
        ...taskData,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add assignment: ${response.reasonPhrase}');
    }
  }



  // Delete an assignment
  Future<void> deleteAssignment(String assignmentId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/api/work-tracking/ass/delete/$assignmentId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete assignment: ${response.reasonPhrase}');
    }
  }

  // Add files to an assignment
  Future<void> addFilesToAssignment(String assignmentId, List<String> fileNames) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/work-tracking/ass/add-files/$assignmentId'),
      headers: headers,
      body: jsonEncode({
        "file_name": fileNames,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to add files to assignment: ${response.reasonPhrase}');
    }
  }

  // Delete a file from an assignment
  Future<void> deleteFileFromAssignment(String assignmentId, String fileName) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/work-tracking/ass/delete-file/$assignmentId'),
      headers: headers,
      body: jsonEncode({
        "file_name": fileName,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete file from assignment: ${response.reasonPhrase}');
    }
  }
}
