// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';

// class WorkTrackingService {
//   static const String baseUrl = 'https://demo-application-api.flexiflows.co';

//   Future<Map<String, String>> _getHeaders() async {
//     final prefs = await SharedPreferences.getInstance();
//     final token = prefs.getString('token') ?? '';
//     print('Retrieved Token: $token'); // Debug line

//     return {
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $token',
//     };
//   }

//   Future<List<Map<String, dynamic>>> fetchMyProjects() async {
//     final headers = await _getHeaders();
//     final response = await http.get(
//       Uri.parse('$baseUrl/api/work-tracking/proj/find-My-Project-list'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       var body = json.decode(response.body);
//       if (body['result'] != null && body['result'] is List) {
//         return (body['result'] as List).map((item) => {
//           'project_id': item['project_id'],
//           'p_name': item['p_name'],
//           's_name': item['s_name'],
//           'precent': item['precent'],
//           'dl': item['dl'],
//           'extend': item['extend'],
//           'create_project_by': item['create_project_by'],
//           'd_name': item['d_name'],
//           'b_name': item['b_name'],
//         }).toList();
//       } else {
//         throw Exception('Unexpected response format');
//       }
//     } else {
//       throw Exception('Failed to load projects: ${response.reasonPhrase}');
//     }
//   }

//   Future<Map<String, dynamic>?> fetchLatestProject() async {
//     final projects = await fetchMyProjects();
//     if (projects.isNotEmpty) {
//       return projects.first;
//     }
//     return null;
//   }

//   Future<List<Map<String, dynamic>>> fetchAllProjects() async {
//     final headers = await _getHeaders();
//     final response = await http.post(
//       Uri.parse('$baseUrl/api/work-tracking/proj/projects'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       var body = json.decode(response.body);
//       if (body['result'] != null && body['result'] is List) {
//         return (body['result'] as List).map((item) => {
//           'project_id': item['project_id'],
//           'p_name': item['p_name'],
//           's_name': item['s_name'],
//           'precent': item['precent'],
//           'dl': item['dl'],
//           'extend': item['extend'],
//           'create_project_by': item['create_project_by'],
//           'd_name': item['d_name'],
//           'b_name': item['b_name'],
//         }).toList();
//       } else {
//         throw Exception('Unexpected response format');
//       }
//     } else {
//       throw Exception('Failed to load projects: ${response.reasonPhrase}');
//     }
//   }

//   Future<String?> addProject(Map<String, dynamic> projectData) async {
//     final headers = await _getHeaders();
//     final response = await http.post(
//       Uri.parse('$baseUrl/api/work-tracking/proj/insert'),
//       headers: headers,
//       body: jsonEncode(projectData),
//     );

//     if (response.statusCode == 201 || response.statusCode == 200) {
//       final responseBody = jsonDecode(response.body);
//       if (responseBody != null && responseBody['project_id'] != null) {
//         final String projectId = responseBody['project_id'];
//         if (kDebugMode) {
//           print('Project successfully created with ID: $projectId');
//         }
//         return projectId;
//       } else {
//         return null;
//       }
//     } else {
//       throw Exception('Failed to add project: ${response.reasonPhrase}');
//     }
//   }

//   Future<String> updateProject(String projectId, Map<String, dynamic> projectData) async {
//     final headers = await _getHeaders();
//     final response = await http.put(
//       Uri.parse('$baseUrl/api/work-tracking/proj/update/$projectId'),
//       headers: headers,
//       body: jsonEncode(projectData),
//     );

//     if (response.statusCode == 200) {
//       return 'Project successfully updated.';
//     } else {
//       if (kDebugMode) {
//         print('Error: ${response.statusCode}, ${response.body}');
//       }
//       return 'Failed to update project: ${response.reasonPhrase}. Details: ${response.body}';
//     }
//   }

//   // Fetch the list of projects and find the project to delete
//   Future<void> deleteProjectByName(String projectName) async {
//     try {
//       // Fetch the projects
//       List<Map<String, dynamic>> projects = await fetchMyProjects();

//       // Find the project by name
//       final projectToDelete = projects.firstWhere(
//             (project) => project['p_name'] == projectName,
//         orElse: () => {},
//       );

//       if (projectToDelete.isNotEmpty) {
//         final String projectId = projectToDelete['project_id'];
//         await deleteProject(projectId); // Call the deleteProject method with the project_id
//         print('Project deleted successfully.');
//       } else {
//         print('Project not found.');
//       }
//     } catch (e) {
//       throw Exception('Failed to delete project: $e');
//     }
//   }

// // Delete the project using project_id
//   Future<String> deleteProject(String projectId) async {
//     final headers = await _getHeaders();
//     final response = await http.put(
//       Uri.parse('$baseUrl/api/work-tracking/proj/delete'),
//       headers: headers,
//       body: jsonEncode({
//         "projectIDs": [
//           {"projectID": projectId}
//         ]
//       }),
//     );

//     if (response.statusCode == 200) {
//       return 'Project successfully deleted.';
//     } else {
//       if (kDebugMode) {
//         print('Error: ${response.statusCode}, ${response.body}');
//       }
//       return 'Failed to delete project: ${response.reasonPhrase}. Details: ${response.body}';
//     }
//   }

//   Future<List<Map<String, dynamic>>> fetchMembersByProjectId(String projectId) async {
//     final headers = await _getHeaders();
//     final response = await http.get(
//       Uri.parse('$baseUrl/api/work-tracking/project-member/members?project_id=$projectId'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       var body = json.decode(response.body);
//       if (body['results'] != null && body['results'] is List) {
//         return (body['results'] as List).map((item) => {
//           'id': item['member_id'],
//           'name': item['name'],
//           'surname': item['surname'],
//           'email': item['email'],
//           'isAdmin': item['member_status'] == 2,
//           'image': 'https://via.placeholder.com/150',
//           'isSelected': false,
//         }).toList();
//       } else {
//         throw Exception('Unexpected response format');
//       }
//     } else {
//       throw Exception('Failed to load project members: ${response.reasonPhrase}');
//     }
//   }

//   Future<List<Map<String, dynamic>>> fetchChatMessages(String projectId) async {
//     final headers = await _getHeaders();
//     final response = await http.get(
//       Uri.parse('$baseUrl/api/work-tracking/project-comments/comments?project_id=$projectId'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       var body = json.decode(response.body);
//       if (body['results'] != null && body['results'] is List) {
//         return List<Map<String, dynamic>>.from(body['results'].where((item) => item['project_id'] == projectId));
//       } else {
//         throw Exception('Unexpected response format');
//       }
//     } else {
//       throw Exception('Failed to load chat messages: ${response.reasonPhrase}');
//     }
//   }

//   Future<void> sendChatMessage(String projectId, String message, {String? filePath, String? fileType}) async {
//     final headers = await _getHeaders();
//     final response = await http.post(
//       Uri.parse('$baseUrl/api/work-tracking/project-comments/insert'),
//       headers: headers,
//       body: jsonEncode({
//         'project_id': projectId,
//         'comments': message,
//         'file_path': filePath,
//         'file_type': fileType,
//       }),
//     );

//     if (response.statusCode == 201) {
//       if (kDebugMode) {
//         print('Message sent successfully.');
//       }
//     } else {
//       throw Exception('Failed to send chat message: ${response.reasonPhrase}. Details: ${response.body}');
//     }
//   }

//   Future<void> addPersonToProject(String projectId, String personId) async {
//     final headers = await _getHeaders();
//     final response = await http.post(
//       Uri.parse('$baseUrl/api/work-tracking/project-member/insert'),
//       headers: headers,
//       body: jsonEncode({
//         'project_id': projectId,
//         'member_id': personId,
//         'member_status': 1,
//       }),
//     );

//     if (response.statusCode == 200) {
//       if (kDebugMode) {
//         print('Person successfully added to the project.');
//       }
//     } else {
//       throw Exception('Failed to add person to project: ${response.reasonPhrase}. Details: ${response.body}');
//     }
//   }

//   Future<List<Map<String, dynamic>>> fetchAssignments(String projectId) async {
//     final headers = await _getHeaders();
//     final response = await http.get(
//       Uri.parse('$baseUrl/api/work-tracking/ass/assignments?proj_id=$projectId'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       var body = json.decode(response.body);
//       if (body['results'] != null && body['results'] is List) {
//         return List<Map<String, dynamic>>.from(body['results']);
//       } else {
//         throw Exception('Unexpected response format');
//       }
//     } else {
//       throw Exception('Failed to load assignments: ${response.reasonPhrase}');
//     }
//   }

//   Future<String?> addAssignment(String projectId, Map<String, dynamic> assignmentData) async {
//     final headers = await _getHeaders();
//     final payload = jsonEncode({
//       'project_id': projectId,
//       ...assignmentData,
//     });

//     final response = await http.post(
//       Uri.parse('$baseUrl/api/work-tracking/ass/insert'),
//       headers: headers,
//       body: payload,
//     );

//     if (response.statusCode == 201) {
//       final responseBody = jsonDecode(response.body);
//       if (responseBody != null && responseBody['as_id'] != null) {
//         return responseBody['as_id'];  // Return as_id
//       } else {
//         throw Exception('Assignment created but no assignment ID returned.');
//       }
//     } else if (response.statusCode == 403) {
//       throw Exception('You do not have permission to add this assignment. Please check your access rights.');
//     } else {
//       throw Exception('Failed to add assignment: ${response.reasonPhrase}. Details: ${response.body}');
//     }
//   }

//   Future<void> updateAssignment(String asId, Map<String, dynamic> taskData) async {
//     final headers = await _getHeaders();
//     final response = await http.put(
//       Uri.parse('$baseUrl/api/work-tracking/ass/update/$asId'),
//       headers: headers,
//       body: jsonEncode(taskData),
//     );

//     if (response.statusCode == 200) {
//       print('Assignment successfully updated.');
//     } else {
//       print('Failed to update assignment: ${response.statusCode} ${response.reasonPhrase}. Details: ${response.body}');
//       throw Exception('Failed to update assignment: ${response.reasonPhrase}. Details: ${response.body}');
//     }
//   }

//   Future<void> deleteAssignment(String asId) async {
//     final headers = await _getHeaders();
//     final response = await http.put(
//       Uri.parse('$baseUrl/api/work-tracking/ass/delete/$asId'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       print('Assignment successfully deleted.');
//     } else if (response.statusCode == 404) {
//       print('Assignment not found: $asId');
//       throw Exception('Assignment not found.');
//     } else {
//       throw Exception('Failed to delete assignment: ${response.reasonPhrase}. Details: ${response.body}');
//     }
//   }

//   Future<void> addFilesToAssignment(String asId, List<String> fileNames) async {
//     final headers = await _getHeaders();
//     final response = await http.post(
//       Uri.parse('$baseUrl/api/work-tracking/ass/add-files/$asId'),
//       headers: headers,
//       body: jsonEncode({
//         "file_name": fileNames,
//       }),
//     );

//     if (response.statusCode == 200) {
//       if (kDebugMode) {
//         print('Files added successfully.');
//       }
//     } else {
//       throw Exception('Failed to add files to assignment: ${response.reasonPhrase}. Details: ${response.body}');
//     }
//   }

//   Future<void> deleteFileFromAssignment(String asId, String fileName) async {
//     final headers = await _getHeaders();
//     final response = await http.post(
//       Uri.parse('$baseUrl/api/work-tracking/ass/delete-file/$asId'),
//       headers: headers,
//       body: jsonEncode({
//         "file_name": fileName,
//       }),
//     );

//     if (response.statusCode == 200) {
//       if (kDebugMode) {
//         print('File deleted successfully.');
//       }
//     } else {
//       throw Exception('Failed to delete file from assignment: ${response.reasonPhrase}. Details: ${response.body}');
//     }
//   }

//   Future<List<Map<String, dynamic>>> getAllEmployees() async {
//     final headers = await _getHeaders();
//     final response = await http.get(
//       Uri.parse('$baseUrl/api/work-tracking/project-member/get-all-employees'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       final body = json.decode(response.body);
//       if (body['results'] != null && body['results'] is List) {
//         return List<Map<String, dynamic>>.from(body['results']);
//       } else {
//         throw Exception('Unexpected response format');
//       }
//     } else {
//       throw Exception('Failed to fetch employees: ${response.reasonPhrase}');
//     }
//   }

//   Future<List<Map<String, dynamic>>> getProjectMembers(String projectId) async {
//     final headers = await _getHeaders();
//     final response = await http.get(
//       Uri.parse('$baseUrl/api/work-tracking/proj/find-Member-By-ProjectId/$projectId'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       var body = json.decode(response.body);
//       if (body['results'] != null && body['results'] is List) {
//         return List<Map<String, dynamic>>.from(body['results']);
//       } else {
//         throw Exception('Unexpected response format');
//       }
//     } else {
//       throw Exception('Failed to load project members: ${response.reasonPhrase}');
//     }
//   }

//   Future<List<Map<String, dynamic>>> fetchProjectMembers(String projectId) async {
//     final headers = await _getHeaders();
//     final response = await http.get(
//       Uri.parse('$baseUrl/api/work-tracking/proj/find-Member-By-ProjectId/$projectId'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       var body = json.decode(response.body);
//       if (body is List) {
//         return (body).map((item) => {
//           'id': item['member_id'],
//           'name': item['name'],
//           'surname': item['surname'],
//           'email': item['email'],
//           'isAdmin': item['member_status'] == 2,
//           'image': item['image'],
//           'isSelected': false,
//         }).toList();
//       } else {
//         throw Exception('Unexpected response format');
//       }
//     } else {
//       throw Exception('Failed to load project members: ${response.reasonPhrase}');
//     }
//   }

//   Future<List<Map<String, dynamic>>> fetchAssignmentMembers(String asId) async {
//     final headers = await _getHeaders();
//     final response = await http.get(
//       Uri.parse('$baseUrl/api/work-tracking/assignment-members/assignment-members?as_id=$asId'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       var body = json.decode(response.body);
//       if (body['results'] != null && body['results'] is List) {
//         return (body['results'] as List).map((item) => {
//           'id': item['member_id'],
//           'name': item['name'],
//           'surname': item['surname'],
//           'email': item['email'],
//           'isSelected': false,
//         }).toList();
//       } else {
//         throw Exception('Unexpected response format');
//       }
//     } else {
//       throw Exception('Failed to load assignment members: ${response.reasonPhrase}');
//     }
//   }

//   // Future<void> addMembersToAssignment(String asId, List<Map<String, dynamic>> members) async {
//   //   final headers = await _getHeaders();
//   //   final memberData = {
//   //     "as_id": asId,
//   //     "members": members.map((member) => {"employee_id": member['employee_id']}).toList(),
//   //   };

//   //   final response = await http.post(
//   //     Uri.parse('$baseUrl/api/work-tracking/ass/add-members/$asId'),
//   //     headers: headers,
//   //     body: jsonEncode(memberData),
//   //   );

//   //   if (response.statusCode == 201 || response.statusCode == 200) {
//   //     if (kDebugMode) {
//   //       print('Members successfully added to the assignment.');
//   //     }
//   //   } else {
//   //     throw Exception('Failed to add members to the assignment: ${response.reasonPhrase}');
//   //   }
//   // }

// Future<void> addMembersToAssignment(String asId, List<Map<String, dynamic>> members) async {
//   final headers = await _getHeaders();

//   // Iterate through each member to fetch their profile image
//   for (var member in members) {
//     try {
//       // Fetch the profile image for each member
//       String? profileImageUrl = await fetchAssignmentMemberProfileImage(member['employee_id']);
//       member['profile_image'] = profileImageUrl ?? 'default_image_url'; // Use default image if none found

//     } catch (e) {
//       if (kDebugMode) {
//         print('Failed to fetch profile image for ${member['employee_id']}: $e');
//       }
//       member['profile_image'] = 'default_image_url'; // Use default image in case of failure
//     }
//   }

//   // Prepare the payload for adding members with their profile images
//   final memberData = {
//     "as_id": asId,
//     "members": members.map((member) => {
//       "employee_id": member['employee_id'],
//       "profile_image": member['profile_image'], // Include profile image URL in the payload
//     }).toList(),
//   };

//   final response = await http.post(
//     Uri.parse('$baseUrl/api/work-tracking/ass/add-members/$asId'),
//     headers: headers,
//     body: jsonEncode(memberData),
//   );

//   if (response.statusCode == 201 || response.statusCode == 200) {
//     if (kDebugMode) {
//       print('Members successfully added to the assignment.');
//     }
//   } else {
//     throw Exception('Failed to add members to the assignment: ${response.reasonPhrase}');
//   }
// }

//   // Add members to the created project
//   Future<void> addMembersToProject(String projectId, List<Map<String, dynamic>> members) async {
//     final headers = await _getHeaders();
//     final memberData = {
//       "project_id": projectId,
//       "employees_member": members.map((member) => {"employee_id": member['id']}).toList(),
//     };

//     final response = await http.post(
//       Uri.parse('$baseUrl/api/work-tracking/project-member/insert'),
//       headers: headers,
//       body: jsonEncode(memberData),
//     );

//     if (response.statusCode == 201 || response.statusCode == 200) {
//       if (kDebugMode) {
//         print('Members successfully added to the project.');
//       }
//     } else {
//       throw Exception('Failed to add members to the project: ${response.reasonPhrase}');
//     }
//   }

//   Future<String> fetchAssignmentMemberProfileImage(String employeeId) async {
//   final headers = await _getHeaders();
//   final response = await http.get(
//     Uri.parse('$baseUrl/api/profile/$employeeId'),
//     headers: headers,
//   );

//   if (response.statusCode == 200) {
//     var body = json.decode(response.body);

//     if (body['results'] != null && body['results']['images'] != null && body['results']['images'].isNotEmpty) {
//       String imageUrl = body['results']['images'];
//       // Log the fetched image URL for debugging
//       if (kDebugMode) {
//         print('Fetched image URL for employee $employeeId: $imageUrl');
//       }
//       return imageUrl;  // Return the profile image URL
//     } else {
//       // Log when the image URL is not found or empty
//       if (kDebugMode) {
//         print('No image URL found for employee $employeeId, using default avatar.');
//       }
//       return 'https://your-default-avatar-url.com/default_avatar.jpg'; // Use a default avatar if image URL is missing
//     }
//   } else {
//     throw Exception('Failed to fetch profile image: ${response.reasonPhrase}');
//   }
// }



// }


// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';

// class WorkTrackingService {
//   static const String baseUrl = 'https://demo-application-api.flexiflows.co';

//   Future<Map<String, String>> _getHeaders() async {
//     final prefs = await SharedPreferences.getInstance();
//     final token = prefs.getString('token') ?? '';
//     print('Retrieved Token: $token'); // Debug line

//     return {
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $token',
//     };
//   }

//   Future<List<Map<String, dynamic>>> fetchMyProjects() async {
//     final headers = await _getHeaders();
//     final response = await http.get(
//       Uri.parse('$baseUrl/api/work-tracking/proj/find-My-Project-list'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       var body = json.decode(response.body);
//       if (body['result'] != null && body['result'] is List) {
//         return (body['result'] as List).map((item) => {
//           'project_id': item['project_id'],
//           'p_name': item['p_name'],
//           's_name': item['s_name'],
//           'precent': item['precent'],
//           'dl': item['dl'],
//           'extend': item['extend'],
//           'create_project_by': item['create_project_by'],
//           'd_name': item['d_name'],
//           'b_name': item['b_name'],
//         }).toList();
//       } else {
//         throw Exception('Unexpected response format');
//       }
//     } else {
//       throw Exception('Failed to load projects: ${response.reasonPhrase}');
//     }
//   }

//   Future<Map<String, dynamic>?> fetchLatestProject() async {
//     final projects = await fetchMyProjects();
//     if (projects.isNotEmpty) {
//       return projects.first;
//     }
//     return null;
//   }

//   Future<List<Map<String, dynamic>>> fetchAllProjects() async {
//     final headers = await _getHeaders();
//     final response = await http.post(
//       Uri.parse('$baseUrl/api/work-tracking/proj/projects'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       var body = json.decode(response.body);
//       if (body['result'] != null && body['result'] is List) {
//         return (body['result'] as List).map((item) => {
//           'project_id': item['project_id'],
//           'p_name': item['p_name'],
//           's_name': item['s_name'],
//           'precent': item['precent'],
//           'dl': item['dl'],
//           'extend': item['extend'],
//           'create_project_by': item['create_project_by'],
//           'd_name': item['d_name'],
//           'b_name': item['b_name'],
//         }).toList();
//       } else {
//         throw Exception('Unexpected response format');
//       }
//     } else {
//       throw Exception('Failed to load projects: ${response.reasonPhrase}');
//     }
//   }

//   Future<String?> addProject(Map<String, dynamic> projectData) async {
//     final headers = await _getHeaders();
//     final response = await http.post(
//       Uri.parse('$baseUrl/api/work-tracking/proj/insert'),
//       headers: headers,
//       body: jsonEncode(projectData),
//     );

//     if (response.statusCode == 201 || response.statusCode == 200) {
//       final responseBody = jsonDecode(response.body);
//       if (responseBody != null && responseBody['project_id'] != null) {
//         final String projectId = responseBody['project_id'];
//         if (kDebugMode) {
//           print('Project successfully created with ID: $projectId');
//         }
//         return projectId;
//       } else {
//         return null;
//       }
//     } else {
//       throw Exception('Failed to add project: ${response.reasonPhrase}');
//     }
//   }

//   Future<String> updateProject(String projectId, Map<String, dynamic> projectData) async {
//     final headers = await _getHeaders();
//     final response = await http.put(
//       Uri.parse('$baseUrl/api/work-tracking/proj/update/$projectId'),
//       headers: headers,
//       body: jsonEncode(projectData),
//     );

//     if (response.statusCode == 200) {
//       return 'Project successfully updated.';
//     } else {
//       if (kDebugMode) {
//         print('Error: ${response.statusCode}, ${response.body}');
//       }
//       return 'Failed to update project: ${response.reasonPhrase}. Details: ${response.body}';
//     }
//   }

//   // Fetch the list of projects and find the project to delete
//   Future<void> deleteProjectByName(String projectName) async {
//     try {
//       // Fetch the projects
//       List<Map<String, dynamic>> projects = await fetchMyProjects();

//       // Find the project by name
//       final projectToDelete = projects.firstWhere(
//             (project) => project['p_name'] == projectName,
//         orElse: () => {},
//       );

//       if (projectToDelete.isNotEmpty) {
//         final String projectId = projectToDelete['project_id'];
//         await deleteProject(projectId); // Call the deleteProject method with the project_id
//         print('Project deleted successfully.');
//       } else {
//         print('Project not found.');
//       }
//     } catch (e) {
//       throw Exception('Failed to delete project: $e');
//     }
//   }

// // Delete the project using project_id
//   Future<String> deleteProject(String projectId) async {
//     final headers = await _getHeaders();
//     final response = await http.put(
//       Uri.parse('$baseUrl/api/work-tracking/proj/delete'),
//       headers: headers,
//       body: jsonEncode({
//         "projectIDs": [
//           {"projectID": projectId}
//         ]
//       }),
//     );

//     if (response.statusCode == 200) {
//       return 'Project successfully deleted.';
//     } else {
//       if (kDebugMode) {
//         print('Error: ${response.statusCode}, ${response.body}');
//       }
//       return 'Failed to delete project: ${response.reasonPhrase}. Details: ${response.body}';
//     }
//   }

//   Future<List<Map<String, dynamic>>> fetchMembersByProjectId(String projectId) async {
//     final headers = await _getHeaders();
//     final response = await http.get(
//       Uri.parse('$baseUrl/api/work-tracking/project-member/members?project_id=$projectId'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       var body = json.decode(response.body);
//       if (body['results'] != null && body['results'] is List) {
//         return (body['results'] as List).map((item) => {
//           'id': item['member_id'],
//           'name': item['name'],
//           'surname': item['surname'],
//           'email': item['email'],
//           'isAdmin': item['member_status'] == 2,
//           'image': 'https://via.placeholder.com/150',
//           'isSelected': false,
//         }).toList();
//       } else {
//         throw Exception('Unexpected response format');
//       }
//     } else {
//       throw Exception('Failed to load project members: ${response.reasonPhrase}');
//     }
//   }

//   Future<List<Map<String, dynamic>>> fetchChatMessages(String projectId) async {
//     final headers = await _getHeaders();
//     final response = await http.get(
//       Uri.parse('$baseUrl/api/work-tracking/project-comments/comments?project_id=$projectId'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       var body = json.decode(response.body);
//       if (body['results'] != null && body['results'] is List) {
//         return List<Map<String, dynamic>>.from(body['results'].where((item) => item['project_id'] == projectId));
//       } else {
//         throw Exception('Unexpected response format');
//       }
//     } else {
//       throw Exception('Failed to load chat messages: ${response.reasonPhrase}');
//     }
//   }

//   Future<void> sendChatMessage(String projectId, String message, {String? filePath, String? fileType}) async {
//     final headers = await _getHeaders();
//     final response = await http.post(
//       Uri.parse('$baseUrl/api/work-tracking/project-comments/insert'),
//       headers: headers,
//       body: jsonEncode({
//         'project_id': projectId,
//         'comments': message,
//         'file_path': filePath,
//         'file_type': fileType,
//       }),
//     );

//     if (response.statusCode == 201) {
//       if (kDebugMode) {
//         print('Message sent successfully.');
//       }
//     } else {
//       throw Exception('Failed to send chat message: ${response.reasonPhrase}. Details: ${response.body}');
//     }
//   }

//   Future<void> addPersonToProject(String projectId, String personId) async {
//     final headers = await _getHeaders();
//     final response = await http.post(
//       Uri.parse('$baseUrl/api/work-tracking/project-member/insert'),
//       headers: headers,
//       body: jsonEncode({
//         'project_id': projectId,
//         'member_id': personId,
//         'member_status': 1,
//       }),
//     );

//     if (response.statusCode == 200) {
//       if (kDebugMode) {
//         print('Person successfully added to the project.');
//       }
//     } else {
//       throw Exception('Failed to add person to project: ${response.reasonPhrase}. Details: ${response.body}');
//     }
//   }

//   Future<List<Map<String, dynamic>>> fetchAssignments(String projectId) async {
//     final headers = await _getHeaders();
//     final response = await http.get(
//       Uri.parse('$baseUrl/api/work-tracking/ass/assignments?proj_id=$projectId'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       var body = json.decode(response.body);
//       if (body['results'] != null && body['results'] is List) {
//         return List<Map<String, dynamic>>.from(body['results']);
//       } else {
//         throw Exception('Unexpected response format');
//       }
//     } else {
//       throw Exception('Failed to load assignments: ${response.reasonPhrase}');
//     }
//   }

//   Future<String?> addAssignment(String projectId, Map<String, dynamic> assignmentData) async {
//     final headers = await _getHeaders();
//     final payload = jsonEncode({
//       'project_id': projectId,
//       ...assignmentData,
//     });

//     final response = await http.post(
//       Uri.parse('$baseUrl/api/work-tracking/ass/insert'),
//       headers: headers,
//       body: payload,
//     );

//     if (response.statusCode == 201) {
//       final responseBody = jsonDecode(response.body);
//       if (responseBody != null && responseBody['as_id'] != null) {
//         return responseBody['as_id'];  // Return as_id
//       } else {
//         throw Exception('Assignment created but no assignment ID returned.');
//       }
//     } else if (response.statusCode == 403) {
//       throw Exception('You do not have permission to add this assignment. Please check your access rights.');
//     } else {
//       throw Exception('Failed to add assignment: ${response.reasonPhrase}. Details: ${response.body}');
//     }
//   }

//   Future<void> updateAssignment(String asId, Map<String, dynamic> taskData) async {
//     final headers = await _getHeaders();
//     final response = await http.put(
//       Uri.parse('$baseUrl/api/work-tracking/ass/update/$asId'),
//       headers: headers,
//       body: jsonEncode(taskData),
//     );

//     if (response.statusCode == 200) {
//       print('Assignment successfully updated.');
//     } else {
//       print('Failed to update assignment: ${response.statusCode} ${response.reasonPhrase}. Details: ${response.body}');
//       throw Exception('Failed to update assignment: ${response.reasonPhrase}. Details: ${response.body}');
//     }
//   }

//   Future<void> deleteAssignment(String asId) async {
//     final headers = await _getHeaders();
//     final response = await http.put(
//       Uri.parse('$baseUrl/api/work-tracking/ass/delete/$asId'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       print('Assignment successfully deleted.');
//     } else if (response.statusCode == 404) {
//       print('Assignment not found: $asId');
//       throw Exception('Assignment not found.');
//     } else {
//       throw Exception('Failed to delete assignment: ${response.reasonPhrase}. Details: ${response.body}');
//     }
//   }

//   Future<void> addFilesToAssignment(String asId, List<String> fileNames) async {
//     final headers = await _getHeaders();
//     final response = await http.post(
//       Uri.parse('$baseUrl/api/work-tracking/ass/add-files/$asId'),
//       headers: headers,
//       body: jsonEncode({
//         "file_name": fileNames,
//       }),
//     );

//     if (response.statusCode == 200) {
//       if (kDebugMode) {
//         print('Files added successfully.');
//       }
//     } else {
//       throw Exception('Failed to add files to assignment: ${response.reasonPhrase}. Details: ${response.body}');
//     }
//   }

//   Future<void> deleteFileFromAssignment(String asId, String fileName) async {
//     final headers = await _getHeaders();
//     final response = await http.post(
//       Uri.parse('$baseUrl/api/work-tracking/ass/delete-file/$asId'),
//       headers: headers,
//       body: jsonEncode({
//         "file_name": fileName,
//       }),
//     );

//     if (response.statusCode == 200) {
//       if (kDebugMode) {
//         print('File deleted successfully.');
//       }
//     } else {
//       throw Exception('Failed to delete file from assignment: ${response.reasonPhrase}. Details: ${response.body}');
//     }
//   }

//   Future<List<Map<String, dynamic>>> getAllEmployees() async {
//     final headers = await _getHeaders();
//     final response = await http.get(
//       Uri.parse('$baseUrl/api/work-tracking/project-member/get-all-employees'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       final body = json.decode(response.body);
//       if (body['results'] != null && body['results'] is List) {
//         return List<Map<String, dynamic>>.from(body['results']);
//       } else {
//         throw Exception('Unexpected response format');
//       }
//     } else {
//       throw Exception('Failed to fetch employees: ${response.reasonPhrase}');
//     }
//   }

//   Future<List<Map<String, dynamic>>> getProjectMembers(String projectId) async {
//     final headers = await _getHeaders();
//     final response = await http.get(
//       Uri.parse('$baseUrl/api/work-tracking/proj/find-Member-By-ProjectId/$projectId'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       var body = json.decode(response.body);
//       if (body['results'] != null && body['results'] is List) {
//         return List<Map<String, dynamic>>.from(body['results']);
//       } else {
//         throw Exception('Unexpected response format');
//       }
//     } else {
//       throw Exception('Failed to load project members: ${response.reasonPhrase}');
//     }
//   }

//   Future<List<Map<String, dynamic>>> fetchProjectMembers(String projectId) async {
//     final headers = await _getHeaders();
//     final response = await http.get(
//       Uri.parse('$baseUrl/api/work-tracking/proj/find-Member-By-ProjectId/$projectId'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       var body = json.decode(response.body);
//       if (body is List) {
//         return (body).map((item) => {
//           'id': item['member_id'],
//           'name': item['name'],
//           'surname': item['surname'],
//           'email': item['email'],
//           'isAdmin': item['member_status'] == 2,
//           'image': item['image'],
//           'isSelected': false,
//         }).toList();
//       } else {
//         throw Exception('Unexpected response format');
//       }
//     } else {
//       throw Exception('Failed to load project members: ${response.reasonPhrase}');
//     }
//   }

//   Future<List<Map<String, dynamic>>> fetchAssignmentMembers(String asId) async {
//     final headers = await _getHeaders();
//     final response = await http.get(
//       Uri.parse('$baseUrl/api/work-tracking/assignment-members/assignment-members?as_id=$asId'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       var body = json.decode(response.body);
//       if (body['results'] != null && body['results'] is List) {
//         return (body['results'] as List).map((item) => {
//           'id': item['member_id'],
//           'name': item['name'],
//           'surname': item['surname'],
//           'email': item['email'],
//           'isSelected': false,
//         }).toList();
//       } else {
//         throw Exception('Unexpected response format');
//       }
//     } else {
//       throw Exception('Failed to load assignment members: ${response.reasonPhrase}');
//     }
//   }

//   Future<void> addMembersToAssignment(String asId, List<Map<String, dynamic>> members) async {
//     final headers = await _getHeaders();
//     final memberData = {
//       "as_id": asId,
//       "members": members.map((member) => {"employee_id": member['employee_id']}).toList(),
//     };

//     final response = await http.post(
//       Uri.parse('$baseUrl/api/work-tracking/ass/add-members/$asId'),
//       headers: headers,
//       body: jsonEncode(memberData),
//     );

//     if (response.statusCode == 201 || response.statusCode == 200) {
//       if (kDebugMode) {
//         print('Members successfully added to the assignment.');
//       }
//     } else {
//       throw Exception('Failed to add members to the assignment: ${response.reasonPhrase}');
//     }
//   }

//   // Add members to the created project
//   Future<void> addMembersToProject(String projectId, List<Map<String, dynamic>> members) async {
//     final headers = await _getHeaders();
//     final memberData = {
//       "project_id": projectId,
//       "employees_member": members.map((member) => {"employee_id": member['id']}).toList(),
//     };

//     final response = await http.post(
//       Uri.parse('$baseUrl/api/work-tracking/project-member/insert'),
//       headers: headers,
//       body: jsonEncode(memberData),
//     );

//     if (response.statusCode == 201 || response.statusCode == 200) {
//       if (kDebugMode) {
//         print('Members successfully added to the project.');
//       }
//     } else {
//       throw Exception('Failed to add members to the project: ${response.reasonPhrase}');
//     }
//   }
// }

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WorkTrackingService {
  static const String baseUrl = 'https://demo-application-api.flexiflows.co';

  // Helper to get the headers with the auth token
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (kDebugMode) {
      print('Retrieved Token: $token');
    } // Debug line

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Fetch a list of user's projects
  Future<List<Map<String, dynamic>>> fetchMyProjects() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/work-tracking/proj/find-My-Project-list'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      var body = json.decode(response.body);
      if (body['result'] != null && body['result'] is List) {
        return (body['result'] as List).map((item) =>
        {
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
      throw Exception('Failed to load projects: ${response.reasonPhrase}');
    }
  }

  // Fetch the latest project for the current user
  Future<Map<String, dynamic>?> fetchLatestProject() async {
    final projects = await fetchMyProjects();
    if (projects.isNotEmpty) {
      return projects.first;
    }
    return null;
  }

  // Fetch all available projects
  Future<List<Map<String, dynamic>>> fetchAllProjects() async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/work-tracking/proj/projects'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      var body = json.decode(response.body);
      if (body['result'] != null && body['result'] is List) {
        return (body['result'] as List).map((item) =>
        {
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
      throw Exception('Failed to load projects: ${response.reasonPhrase}');
    }
  }

  // Add a new project
  Future<String?> addProject(Map<String, dynamic> projectData) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/work-tracking/proj/insert'),
      headers: headers,
      body: jsonEncode(projectData),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      if (responseBody != null && responseBody['project_id'] != null) {
        final String projectId = responseBody['project_id'];
        if (kDebugMode) {
          print('Project successfully created with ID: $projectId');
        }
        return projectId;
      } else {
        return null;
      }
    } else {
      throw Exception('Failed to add project: ${response.reasonPhrase}');
    }
  }

  // Update a project by its ID
  Future<String> updateProject(String projectId,
      Map<String, dynamic> projectData) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/work-tracking/proj/update/$projectId'),
      headers: headers,
      body: jsonEncode(projectData),
    );

    if (response.statusCode == 200) {
      return 'Project successfully updated.';
    } else {
      if (kDebugMode) {
        print('Error: ${response.statusCode}, ${response.body}');
      }
      return 'Failed to update project: ${response
          .reasonPhrase}. Details: ${response.body}';
    }
  }

  // Delete a project by name
  Future<void> deleteProjectByName(String projectName) async {
    try {
      // Fetch the projects
      List<Map<String, dynamic>> projects = await fetchMyProjects();

      // Find the project by name
      final projectToDelete = projects.firstWhere(
            (project) => project['p_name'] == projectName,
        orElse: () => {},
      );

      if (projectToDelete.isNotEmpty) {
        final String projectId = projectToDelete['project_id'];
        await deleteProject(
            projectId); // Call the deleteProject method with the project_id
        if (kDebugMode) {
          print('Project deleted successfully.');
        }
      } else {
        if (kDebugMode) {
          print('Project not found.');
        }
      }
    } catch (e) {
      throw Exception('Failed to delete project: $e');
    }
  }

  // Delete a project using its ID
  Future<String> deleteProject(String projectId) async {
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

    if (response.statusCode == 200) {
      return 'Project successfully deleted.';
    } else {
      if (kDebugMode) {
        print('Error: ${response.statusCode}, ${response.body}');
      }
      return 'Failed to delete project: ${response
          .reasonPhrase}. Details: ${response.body}';
    }
  }

  // Fetch and sort project members by project ID
  Future<List<Map<String, dynamic>>> fetchMembersByProjectId(
      String projectId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/work-tracking/project-member/members?project_id=$projectId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      var body = json.decode(response.body);
      if (body['results'] != null && body['results'] is List) {
        List<Map<String, dynamic>> members = (body['results'] as List)
            .map((item) => {
          'employee_id': item['employee_id'],
          'name': item['name'],
          'email': item['email'],
        })
            .toList();

        // Sort members by name
        members.sort((a, b) => a['name'].compareTo(b['name']));

        return members;
      } else {
        throw Exception('Unexpected response format');
      }
    } else {
      throw Exception('Failed to load project members: ${response.reasonPhrase}');
    }
  }

  // Fetch chat messages for a project
  Future<List<Map<String, dynamic>>> fetchChatMessages(String projectId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse(
          '$baseUrl/api/work-tracking/project-comments/comments?project_id=$projectId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      var body = json.decode(response.body);
      if (body['results'] != null && body['results'] is List) {
        return List<Map<String, dynamic>>.from(
            body['results'].where((item) => item['project_id'] == projectId));
      } else {
        throw Exception('Unexpected response format');
      }
    } else {
      throw Exception('Failed to load chat messages: ${response.reasonPhrase}');
    }
  }

  // Send a chat message to a project
  Future<void> sendChatMessage(String projectId, String message,
      {String? filePath, String? fileType}) async {
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
      if (kDebugMode) {
        print('Message sent successfully.');
      }
    } else {
      throw Exception('Failed to send chat message: ${response
          .reasonPhrase}. Details: ${response.body}');
    }
  }

// Add a person to a project
  Future<void> addPeopleToProject(String projectId,
      List<Map<String, String>> employees) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/work-tracking/project-member/insert'),
      headers: headers,
      body: jsonEncode({
        'project_id': projectId,
        'employees_member': employees,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to add people to project: ${response
          .reasonPhrase}. Details: ${response.body}');
    }
  }


  // Fetch assignments by project ID
  Future<List<Map<String, dynamic>>> fetchAssignments(String projectId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse(
          '$baseUrl/api/work-tracking/ass/assignments?proj_id=$projectId'),
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

  // Add a new assignment to a project
  Future<String?> addAssignment(String projectId,
      Map<String, dynamic> assignmentData) async {
    final headers = await _getHeaders();
    final payload = jsonEncode({
      'project_id': projectId,
      ...assignmentData,
    });

    final response = await http.post(
      Uri.parse('$baseUrl/api/work-tracking/ass/insert'),
      headers: headers,
      body: payload,
    );

    if (response.statusCode == 201) {
      final responseBody = jsonDecode(response.body);
      if (responseBody != null && responseBody['as_id'] != null) {
        return responseBody['as_id']; // Return as_id
      } else {
        throw Exception('Assignment created but no assignment ID returned.');
      }
    } else if (response.statusCode == 403) {
      throw Exception(
          'You do not have permission to add this assignment. Please check your access rights.');
    } else {
      throw Exception('Failed to add assignment: ${response
          .reasonPhrase}. Details: ${response.body}');
    }
  }

  // Update an assignment
  Future<void> updateAssignment(String asId,
      Map<String, dynamic> taskData) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/work-tracking/ass/update/$asId'),
      headers: headers,
      body: jsonEncode(taskData),
    );

    if (response.statusCode == 200) {
      if (kDebugMode) {
        print('Assignment successfully updated.');
      }
    } else {
      if (kDebugMode) {
        print('Failed to update assignment: ${response.statusCode} ${response
            .reasonPhrase}. Details: ${response.body}');
      }
      throw Exception('Failed to update assignment: ${response
          .reasonPhrase}. Details: ${response.body}');
    }
  }

  // Delete an assignment
  Future<void> deleteAssignment(String asId) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/work-tracking/ass/delete/$asId'),
      headers: headers,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (kDebugMode) {
        print('Assignment successfully deleted.');
      }
    } else if (response.statusCode == 404) {
      if (kDebugMode) {
        print('Assignment not found: $asId');
      }
      throw Exception('Assignment not found.');
    } else {
      throw Exception('Failed to delete assignment: ${response
          .reasonPhrase}. Details: ${response.body}');
    }
  }

  // Add files to an assignment
  Future<void> addFilesToAssignment(String asId, List<File> files) async {
    final headers = await _getHeaders();

    for (var file in files) {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/api/work-tracking/ass/add-files/$asId'),
      );

      request.headers.addAll(headers);
      request.files.add(await http.MultipartFile.fromPath('file_name', file.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('File uploaded successfully.');
        }
      } else {
        throw Exception('Failed to upload file: ${response.reasonPhrase}');
      }
    }
  }
  // Delete a file from an assignment
  Future<void> deleteFileFromAssignment(String asId, String fileName) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/work-tracking/ass/delete-file/$asId'),
      headers: headers,
      body: jsonEncode({
        "file_name": fileName,
      }),
    );

    if (response.statusCode == 200) {
      if (kDebugMode) {
        print('File deleted successfully.');
      }
    } else {
      throw Exception('Failed to delete file from assignment: ${response
          .reasonPhrase}. Details: ${response.body}');
    }
  }

  // Get a list of all employees (for member selection)
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
      throw Exception('Failed to fetch employees: ${response.reasonPhrase}');
    }
  }

  // Fetch members for a specific project
  Future<List<Map<String, dynamic>>> getProjectMembers(String projectId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse(
          '$baseUrl/api/work-tracking/proj/find-Member-By-ProjectId/$projectId'),
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
      throw Exception(
          'Failed to load project members: ${response.reasonPhrase}');
    }
  }

  // Fetch assignment members
  Future<List<Map<String, dynamic>>> fetchAssignmentMembers(String asId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse(
          '$baseUrl/api/work-tracking/assignment-members/assignment-members?as_id=$asId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      var body = json.decode(response.body);
      if (body['results'] != null && body['results'] is List) {
        return (body['results'] as List).map((item) =>
        {
          'id': item['member_id'],
          'name': item['name'],
          'surname': item['surname'],
          'email': item['email'],
          'isSelected': false,
        }).toList();
      } else {
        throw Exception('Unexpected response format');
      }
    } else {
      throw Exception(
          'Failed to load assignment members: ${response.reasonPhrase}');
    }
  }

  // Add members to an assignment
  Future<void> addMembersToAssignment(String asId, List<Map<String, dynamic>> members) async {
    try {
      // Get the authorization headers (you might need to implement _getHeaders)
      final headers = await _getHeaders();

      // Prepare the member data to be sent to the server
      final memberData = {
        "as_id": asId,
        "members": members.map((member) => {"employee_id": member['employee_id']}).toList(),
      };

      // Make the API call to add members to the assignment
      final response = await http.post(
        Uri.parse('$baseUrl/api/work-tracking/ass/add-members/$asId'),
        headers: headers,
        body: jsonEncode(memberData),
      );

      // Handle the response
      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Members successfully added to the assignment.');
      } else {
        throw Exception(
            'Failed to add members to the assignment: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error adding members to assignment: $e');
      throw Exception('Failed to add members to the assignment');
    }
  }

  Future<void> addMembersToProject(String projectId, List<Map<String, dynamic>> members) async {
    final headers = await _getHeaders();

    final memberData = {
      "project_id": projectId,
      "employees_member": members.map((member) {
        return {
          "employee_id": member['employee_id'],
          "member_status": member['member_status'],
        };
      }).toList(),
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/work-tracking/project-member/insert'),
        headers: headers,
        body: jsonEncode(memberData),
      );

      // Log the response for debugging purposes
      if (kDebugMode) {
        print('API Response Status Code: ${response.statusCode}');
        print('API Response Body: ${response.body}');
      }

      // Handle 201 (Created), 200 (OK), and 202 (Accepted) as success
      if (response.statusCode == 201 || response.statusCode == 200 || response.statusCode == 202) {
        if (kDebugMode) {
          print('Members successfully added to the project.');
        }
      } else {
        // If status code is not 2xx, log error details and throw an exception
        String errorMessage = 'Failed to add members to the project: Status Code ${response.statusCode}, ${response.reasonPhrase}';
        if (kDebugMode) {
          print('Error Response: ${response.body}');
        }
        throw Exception(errorMessage);
      }
    } catch (error) {
      // Log the error and throw it again so the calling function can handle it
      if (kDebugMode) {
        print('An error occurred while adding members: $error');
      }
      throw Exception('An error occurred: $error');
    }
  }

}