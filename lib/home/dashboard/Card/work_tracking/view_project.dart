// view_project.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ViewProjectPage extends StatefulWidget {
  final Map<String, dynamic> project;

  const ViewProjectPage({super.key, required this.project});

  @override
  _ViewProjectPageState createState() => _ViewProjectPageState();
}

class _ViewProjectPageState extends State<ViewProjectPage> {
  List<Map<String, dynamic>> projectMembers = [];
  String? token; // Store the token once

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _retrieveToken();
    await _fetchProjectMembers();
  }

  Future<void> _retrieveToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');

    if (token == null) {
      if (kDebugMode) {
        print('No token found.');
      }
      // You might want to navigate to login or show an error message
    }
  }

  Future<void> _fetchProjectMembers() async {
    if (token == null) {
      if (kDebugMode) {
        print('Cannot fetch members without a token.');
      }
      return;
    }

    final projectId = widget.project['project_id'];
    final url =
        'https://demo-application-api.flexiflows.co/api/work-tracking/proj/find-Member-By-ProjectId/$projectId';

    try {
      // Set up headers with Authorization token
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      // Make the GET request with headers
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (kDebugMode) {
          print('API Response: $responseBody');
        }

        final data = responseBody['Members'] as List;
        if (kDebugMode) {
          print('Members Data: $data');
        }

        // Check if data is not empty
        if (data.isNotEmpty) {
          for (var member in data) {
            final employeeId = member['employee_id'].toString();

            // Ensure employee_id is in the expected format
            // If not, handle accordingly
            // For example, if the API expects 'PSV-00-137852' but you have '1',
            // you might need to map or adjust accordingly.

            final profileImageUrl =
            await _fetchMemberProfileImage(employeeId, headers);

            // Construct the name by combining available fields
            String name = '';

            if (member['name'] != null && member['surname'] != null) {
              name = '${member['name']} ${member['surname']}';
            } else if (member['name'] != null) {
              name = member['name'];
            } else if (member['surname'] != null) {
              name = member['surname'];
            } else if (member['created_by'] != null) {
              // To avoid duplication, append employee_id or member_id
              name = '${member['created_by']} (${member['employee_id']})';
            } else {
              name = 'Unknown (${member['employee_id']})';
            }

            setState(() {
              projectMembers.add({
                'name': name,
                'profileImage': profileImageUrl, // Use consistent key
              });
            });
          }
        }
      } else {
        if (kDebugMode) {
          print('Failed to load project members: ${response.statusCode}');
        }
        // Optionally, handle different status codes here
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load project members: $e');
      }
      // Optionally, show a user-friendly error message
    }
  }

  // Fetching profile images for each member with Authorization headers
  Future<String> _fetchMemberProfileImage(
      String employeeId, Map<String, String> headers) async {
    final url =
        'https://demo-application-api.flexiflows.co/api/profile/$employeeId';
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Adjust according to actual API response structure
        return data['results']?['images'] ??
            'https://via.placeholder.com/150'; // Use null-aware operator
      } else {
        if (kDebugMode) {
          print('Failed to load profile image: ${response.statusCode}');
        }
        return 'https://via.placeholder.com/150';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load profile image: $e');
      }
      return 'https://via.placeholder.com/150';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          leading: Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 24.0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
          title: const Padding(
            padding: EdgeInsets.only(top: 30.0),
            child: Text('View Project'),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/ready_bg.png'),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0), // Reduced padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20), // Reduced height
              _buildTextField(
                  'Created by', widget.project['create_project_by']),
              const SizedBox(height: 12),
              _buildTextField('Name of Project', widget.project['p_name']),
              const SizedBox(height: 12),
              _buildTextField('Department', widget.project['d_name']),
              const SizedBox(height: 12),
              _buildTextField('Branch', widget.project['b_name']),
              const SizedBox(height: 12),
              _buildTextField('Status', widget.project['s_name']),
              const SizedBox(height: 12),
              _buildDateField('Deadline', widget.project['dl']),
              const SizedBox(height: 12),
              _buildDateField('Extended Deadline', widget.project['extend']),
              const SizedBox(height: 20),
              const Text(
                'Progress',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildProgressBar(widget.project['precent']),
              const SizedBox(height: 25),
              const Text(
                'Project Members',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              projectMembers.isEmpty
                  ? const Text(
                'No project members found',
                style:
                TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              )
                  : _buildProjectMembersGrid(projectMembers),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
          const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4), // Reduced height
        TextField(
          controller: TextEditingController(text: value ?? ''),
          readOnly: true,
          decoration: InputDecoration(
            contentPadding:
            const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0), // Optimized padding
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, String? date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
          const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4), // Reduced height
        TextField(
          controller: TextEditingController(text: date ?? ''),
          readOnly: true,
          decoration: InputDecoration(
            suffixIcon: const Icon(Icons.calendar_today, size: 20),
            contentPadding:
            const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0), // Optimized padding
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(String? progressStr) {
    double progress = double.tryParse(progressStr ?? '0.0') ?? 0.0;
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: progress / 100,
            color: Colors.yellow,
            backgroundColor: Colors.grey.shade300,
            minHeight: 8.0, // Slightly thicker for better visibility
          ),
        ),
        const SizedBox(width: 8), // Reduced width
        Text(
          '${progress.toStringAsFixed(0)}%',
          style: const TextStyle(
            fontSize: 14, // Slightly smaller font
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectMembersGrid(List<Map<String, dynamic>> members) {
    // Determine the crossAxisCount based on screen width for responsiveness
    int crossAxisCount = MediaQuery.of(context).size.width > 600 ? 6 : 4;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.8, // Adjusted for better fit
        crossAxisSpacing: 12.0, // Reduced spacing
      ),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return GestureDetector(
          onTap: () => _showMemberNameDialog(context, member['name']),
          child: Column(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(
                    member['profileImage'] ??
                        'https://via.placeholder.com/150'),
                radius: 22, // Reduced radius
              ),
              const SizedBox(height: 4), // Reduced height
              Text(
                member['name'] ?? 'Unknown',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis, // Handle long names gracefully
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMemberNameDialog(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Member Name'),
        content: Text(name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
