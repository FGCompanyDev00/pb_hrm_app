import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
    final url = 'https://demo-application-api.flexiflows.co/api/work-tracking/proj//find-Member-By-ProjectId/$projectId';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          projectMembers = data.map((member) => {
            'name': member['name'],
            'profileImage': member['profile_image_url'], // Assuming the API returns a URL for the profile image
          }).toList();
        });
      } else {
        // Handle error response
        if (kDebugMode) {
          print('Failed to load project members: ${response.statusCode}');
        }
      }
    } catch (e) {
      // Handle network errors
      if (kDebugMode) {
        print('Failed to load project members: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'View Project',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
        return Column(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(member['profileImage']),
              radius: 25,
            ),
            const SizedBox(height: 5),
            Text(
              member['name'] ?? 'Unknown',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}
