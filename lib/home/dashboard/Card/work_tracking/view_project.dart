import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../settings/theme_notifier.dart';

class ViewProjectPage extends StatefulWidget {
  final Map<String, dynamic> project;

  const ViewProjectPage({super.key, required this.project});

  @override
  ViewProjectPageState createState() => ViewProjectPageState();
}

class ViewProjectPageState extends State<ViewProjectPage> {
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
    final url = 'https://demo-application-api.flexiflows.co/api/work-tracking/proj/find-Member-By-ProjectId/$projectId';

    try {
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

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

        if (data.isNotEmpty) {
          for (var member in data) {
            final employeeId = member['employee_id'].toString();

            final profileImageUrl = await _fetchMemberProfileImage(employeeId, headers);

            String name = '';

            if (member['name'] != null && member['surname'] != null) {
              name = '${member['name']} ${member['surname']}';
            } else if (member['name'] != null) {
              name = member['name'];
            } else if (member['surname'] != null) {
              name = member['surname'];
            } else if (member['created_by'] != null) {
              name = '${member['created_by']} (${member['employee_id']})';
            } else {
              name = 'Unknown (${member['employee_id']})';
            }

            setState(() {
              projectMembers.add({
                'name': name,
                'profileImage': profileImageUrl,
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

  Future<String> _fetchMemberProfileImage(String employeeId, Map<String, String> headers) async {
    final url = 'https://demo-application-api.flexiflows.co/api/profile/$employeeId';
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['results']?['images'] ?? 'https://via.placeholder.com/150';
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
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
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
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  isDarkMode ? 'assets/darkbg.png' : 'assets/background.png',
                ),
                fit: BoxFit.cover,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // *** Project Info Card ***
            _buildProjectInfoCard(),

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
                    style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                  )
                : _buildProjectMembersGrid(projectMembers),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectInfoCard() {
    final status = widget.project['s_name'] ?? '';
    final statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row containing: Name of Project (left) and Status (right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name of Project
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Name of Project',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.project['p_name'] ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              // Status on the right
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Status:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Branch & Department in row
          Row(
            children: [
              Expanded(
                child: _buildLabelAndValue(
                  label: 'Branch',
                  value: widget.project['b_name'],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLabelAndValue(
                  label: 'Department',
                  value: widget.project['d_name'],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Deadline & Extended Deadline in row
          Row(
            children: [
              Expanded(
                child: _buildLabelAndValue(
                  label: 'Dead-line',
                  value: widget.project['dl'],
                  icon: Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLabelAndValue(
                  label: 'Dead-line 2',
                  value: widget.project['extend'],
                  icon: Icons.calendar_today,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Created by
          _buildLabelAndValue(
            label: 'Created by',
            value: widget.project['create_project_by'],
          ),
        ],
      ),
    );
  }

  /// Simple helper for consistent label:value pairs.
  Widget _buildLabelAndValue({
    required String label,
    required String? value,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                value ?? '',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Returns a color based on the project status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        // Orange/yellow for Pending
        return Colors.orange;
      case 'processing':
        // Blue for Processing
        return Colors.blue;
      case 'finished':
        // Green for Finished
        return Colors.green;
      default:
        // Gray if unknown status
        return Colors.grey;
    }
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
            minHeight: 8.0,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${progress.toStringAsFixed(0)}%',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  /// Builds a grid of project members
  Widget _buildProjectMembersGrid(List<Map<String, dynamic>> members) {
    int crossAxisCount = MediaQuery.of(context).size.width > 600 ? 6 : 4;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12.0,
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
                  member['profileImage'] ?? 'https://via.placeholder.com/150',
                ),
                radius: 22,
              ),
              const SizedBox(height: 4),
              Text(
                member['name'] ?? 'Unknown',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
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
