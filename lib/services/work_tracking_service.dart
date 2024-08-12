import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WorkTrackingService {
  static const String baseUrl = 'https://demo-application-api.flexiflows.co';

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> fetchMyProjects() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/work-tracking/proj/find-My-Project-list'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      var body = json.decode(response.body);
      if (body['result'] != null && body['result'] is List) {
        return (body['result'] as List)
            .map((item) => {
                  'project_id': item['project_id'],
                  'p_name': item['p_name'],
                  's_name': item['s_name'],
                  'precent': item['precent'],
                  'dl': item['dl'],
                  'extend': item['extend'],
                  'create_project_by': item['create_project_by'],
                  'd_name': item['d_name'],
                  'b_name': item['b_name'],
                })
            .toList();
      } else {
        throw Exception('Unexpected response format');
      }
    } else {
      print('Error: ${response.statusCode}, ${response.body}');
      throw Exception('Failed to load projects: ${response.reasonPhrase}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllProjects() async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/work-tracking/proj/projects'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      var body = json.decode(response.body);
      if (body['result'] != null && body['result'] is List) {
        return (body['result'] as List)
            .map((item) => {
                  'project_id': item['project_id'],
                  'p_name': item['p_name'],
                  's_name': item['s_name'],
                  'precent': item['precent'],
                  'dl': item['dl'],
                  'extend': item['extend'],
                  'create_project_by': item['create_project_by'],
                  'd_name': item['d_name'],
                  'b_name': item['b_name'],
                })
            .toList();
      } else {
        throw Exception('Unexpected response format');
      }
    } else {
      print('Error: ${response.statusCode}, ${response.body}');
      throw Exception('Failed to load projects: ${response.reasonPhrase}');
    }
  }

  Future<void> addProject(Map<String, dynamic> projectData) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/work-tracking/proj/insert'),
      headers: headers,
      body: jsonEncode(projectData),
    );

    if (response.statusCode == 201) {
      print('Project successfully created.');
    } else {
      print('Error: ${response.statusCode}, ${response.body}');
      throw Exception('Failed to add project: ${response.reasonPhrase}');
    }
  }

  Future<void> updateProject(String projectId, Map<String, dynamic> projectData) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/work-tracking/proj/update/$projectId'),
      headers: headers,
      body: jsonEncode(projectData),
    );

    if (response.statusCode != 200) {
      print('Error: ${response.statusCode}, ${response.body}');
      throw Exception('Failed to update project: ${response.reasonPhrase}');
    }
  }

  Future<void> deleteProject(String projectId) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/work-tracking/proj/delete'),
      headers: headers,
      body: jsonEncode({
        "projectIDs": [
          {"projectID": projectId}
        ]
      }),
    );

    if (response.statusCode != 200) {
      print('Error: ${response.statusCode}, ${response.body}');
      throw Exception('Failed to delete project: ${response.reasonPhrase}');
    }
  }

Future<List<Map<String, dynamic>>> fetchMembersByProjectId(String projectId) async {
  final headers = await _getHeaders();
  final response = await http.get(
    Uri.parse('$baseUrl/api/work-tracking/project-member/members?project_id=$projectId'),
    headers: headers,
  );

  if (response.statusCode == 200) {
    var body = json.decode(response.body);
    if (body['results'] != null && body['results'] is List) {
      return (body['results'] as List).map((item) => {
            'name': item['name'],
            'surname': item['surname'],
            'email': item['email'],
            'isAdmin': item['member_status'] == 2,
            'image': 'https://via.placeholder.com/150', // Default image
            'isSelected': false,
          }).toList();
    } else {
      throw Exception('Unexpected response format');
    }
  } else {
    print('Error: ${response.statusCode}, ${response.body}');
    throw Exception('Failed to load project members: ${response.reasonPhrase}');
  }
}

}
