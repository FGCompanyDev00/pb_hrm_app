
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

  @override
  void initState() {
    super.initState();
    _fetchProjectMembers();
  }

Future<void> _fetchProjectMembers() async {
  final projectId = widget.project['project_id'];
  final url = 'https://demo-application-api.flexiflows.co/api/work-tracking/proj/find-Member-By-ProjectId/$projectId';

  try {
    // Retrieve the token from SharedPreferences
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    if (token == null) {
      print('No token found.');
      return;
    }

    // Set up headers with Authorization token
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    // Make the GET request with headers
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      print('API Response: $responseBody');  // Log the API response to check

      final data = responseBody['Members'] as List;
      print('Members Data: $data');

      // Check if data is not empty
      if (data.isNotEmpty) {
        for (var member in data) {
          final profileImageUrl = await _fetchMemberProfileImage(member['employee_id']);
          setState(() {
            projectMembers.add({
              'name': member['employee_name'],
              'images': profileImageUrl,
            });
          });
        }
      }
    } else {
      if (kDebugMode) {
        print('Failed to load project members: ${response.statusCode}');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Failed to load project members: $e');
    }
  }
}

  // Fetching profile images for each member
  Future<String> _fetchMemberProfileImage(String employeeId) async {
    final url = 'https://demo-application-api.flexiflows.co/api/profile/$employeeId';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['images'] ?? 'https://via.placeholder.com/150';
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
      appBar: AppBar(
        title: const Text('View Project'),
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField('Created by', widget.project['create_project_by']),
              const SizedBox(height: 10),
              _buildTextField('Name of Project', widget.project['p_name']),
              const SizedBox(height: 10),
              _buildTextField('Department', widget.project['d_name']),
              const SizedBox(height: 10),
              _buildTextField('Branch', widget.project['b_name']),
              const SizedBox(height: 10),
              _buildTextField('Status', widget.project['s_name']),
              const SizedBox(height: 10),
              _buildDateField('Deadline', widget.project['dl']),
              const SizedBox(height: 10),
              _buildDateField('Extended Deadline', widget.project['extend']),
              const SizedBox(height: 20),
              const Text(
                'Progress',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildProgressBar(widget.project['precent']),
              const SizedBox(height: 20),
              const Text(
                'Project Members',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              projectMembers.isEmpty
                  ? const Text(
                      'No project members found',
                      style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: TextEditingController(text: value ?? ''),
          readOnly: true,
          decoration: InputDecoration(
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: TextEditingController(text: date ?? ''),
          readOnly: true,
          decoration: InputDecoration(
            suffixIcon: const Icon(Icons.calendar_today),
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
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${progress.toStringAsFixed(0)}%',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectMembersGrid(List<Map<String, dynamic>> members) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1,
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
                radius: 25,
              ),
              const SizedBox(height: 5),
              Text(
                member['name'] ?? 'Unknown',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
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
