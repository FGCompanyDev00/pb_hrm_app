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
        return (body['result'] as List).map((item) => {
          'project_id': item['project_id'],
          'p_name': item['p_name'],
          's_name': item['s_name'],
          'precent': item['precent'],
          'dl': item['dl'],
          'extend': item['extend'],
          'create_project_by': item['create_project_by'],
          'd_name': item['d_name'],
          'b_name': item['b_name'],
        }).toList();
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
        return (body['result'] as List).map((item) => {
          'project_id': item['project_id'],
          'p_name': item['p_name'],
          's_name': item['s_name'],
          'precent': item['precent'],
          'dl': item['dl'],
          'extend': item['extend'],
          'create_project_by': item['create_project_by'],
          'd_name': item['d_name'],
          'b_name': item['b_name'],
        }).toList();
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
          'id': item['member_id'],
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

Future<List<Map<String, dynamic>>> fetchChatMessages(String projectId) async {
  final headers = await _getHeaders();
  final response = await http.get(
    Uri.parse('$baseUrl/api/work-tracking/project-comments/comments?project_id=$projectId'),
    headers: headers,
  );

  if (response.statusCode == 200) {
    var body = json.decode(response.body);
    if (body['results'] != null && body['results'] is List) {
      // Filter the messages to ensure they belong to the specified project
      return List<Map<String, dynamic>>.from(body['results'].where((item) => item['project_id'] == projectId));
    } else {
      throw Exception('Unexpected response format');
    }
  } else {
    print('Error: ${response.statusCode}, ${response.body}');
    throw Exception('Failed to load chat messages: ${response.reasonPhrase}');
  }
}


  Future<void> sendChatMessage(String projectId, String message, {String? filePath, String? fileType}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/work-tracking/project-comments/insert'),
      headers: headers,
      body: jsonEncode({
        'project_id': projectId,
        'comments': message,
        'file_path': filePath,
        'file_type': fileType,
      }),
    );

    if (response.statusCode == 201) {
      print('Message sent successfully.');
    } else {
      print('Error: ${response.statusCode}, ${response.body}');
      throw Exception('Failed to send chat message: ${response.reasonPhrase}');
    }
  }

  Future<void> addPersonToProject(String projectId, String personId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/work-tracking/project-member/insert'),
      headers: headers,
      body: jsonEncode({
        'project_id': projectId,
        'member_id': personId,
        'member_status': 1, // Example status
      }),
    );

    if (response.statusCode != 200) {
      print('Error: ${response.statusCode}, ${response.body}');
      throw Exception('Failed to add person to projects: ${response.reasonPhrase}');
    }
  }

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
      print('Error: ${response.statusCode}, ${response.body}');
      throw Exception('Failed to load assignments: ${response.reasonPhrase}');
    }
  }

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

    if (response.statusCode == 201) {
      print('Assignment successfully created.');
    } else {
      print('Error: ${response.statusCode}, ${response.body}');
      throw Exception('Failed to add assignment: ${response.reasonPhrase}');
    }
  }


  Future<void> updateAssignment(String assignmentId, Map<String, dynamic> taskData) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/work-tracking/ass/update/$assignmentId'),
      headers: headers,
      body: jsonEncode(taskData),
    );

    if (response.statusCode != 200) {
      print('Error: ${response.statusCode}, ${response.body}');
      throw Exception('Failed to update assignment: ${response.reasonPhrase}');
    }
  }

  Future<void> deleteAssignment(String assignmentId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/api/work-tracking/ass/delete/$assignmentId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      print('Error: ${response.statusCode}, ${response.body}');
      throw Exception('Failed to delete assignment: ${response.reasonPhrase}');
    }
  }

  Future<void> addFilesToAssignment(String assignmentId, List<String> fileNames) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/work-tracking/ass/add-files/$assignmentId'),
      headers: headers,
      body: jsonEncode({
        "file_name": fileNames,
      }),
    );

    if (response.statusCode == 200) {
      print('Files added successfully.');
    } else {
      print('Error: ${response.statusCode}, ${response.body}');
      throw Exception('Failed to add files to assignment: ${response.reasonPhrase}');
    }
  }

  Future<void> deleteFileFromAssignment(String assignmentId, String fileName) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/work-tracking/ass/delete-file/$assignmentId'),
      headers: headers,
      body: jsonEncode({
        "file_name": fileName,
      }),
    );

    if (response.statusCode == 200) {
      print('File deleted successfully.');
    } else {
      print('Error: ${response.statusCode}, ${response.body}');
      throw Exception('Failed to delete file from assignment: ${response.reasonPhrase}');
    }
  }

  // Method to fetch all employees
  Future<List<Map<String, dynamic>>> getAllEmployees() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/work-tracking/project-member/get-all-employees'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      if (body['results'] != null && body['results'] is List) {
        return List<Map<String, dynamic>>.from(body['results']);
      } else {
        throw Exception('Unexpected response format');
      }
    } else {
      print('Error: ${response.statusCode}, ${response.body}');
      throw Exception('Failed to fetch employees: ${response.reasonPhrase}');
    }
  }

  Future<List<Map<String, dynamic>>> getProjectMembers(String projectId) async {
  final headers = await _getHeaders();
  final response = await http.get(
    Uri.parse('$baseUrl/api/work-tracking/proj/find-Member-By-ProjectId/$projectId'),
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
    throw Exception('Failed to load project members: ${response.reasonPhrase}');
  }
}



}
