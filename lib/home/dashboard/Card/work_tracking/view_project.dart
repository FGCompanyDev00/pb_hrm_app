// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  String? token;

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

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
    final url =
        '$baseUrl/api/work-tracking/proj/find-Member-By-ProjectId/$projectId';

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
          List<Map<String, dynamic>> fetchedMembers = [];

          for (var member in data) {
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

            // Use the img_name field directly from the API response
            final profileImageUrl =
                member['img_name'] ?? 'https://via.placeholder.com/150';

            fetchedMembers.add({
              'name': name,
              'profileImage': profileImageUrl,
            });
          }

          setState(() {
            projectMembers = fetchedMembers;
          });
        }
      } else {
        if (kDebugMode) {
          print('Failed to load project members');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load project members');
      }
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
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final status = widget.project['s_name'] ?? '';
    final statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDarkMode
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Name of Project',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.project['p_name'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Status:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? statusColor.withOpacity(0.15)
                          : statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withOpacity(isDarkMode ? 0.3 : 0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? statusColor.withOpacity(0.9)
                            : statusColor,
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
    final bool isDarkMode = Provider.of<ThemeNotifier>(context).isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                value ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Returns a color based on the project status
  Color _getStatusColor(String status) {
    final bool isDarkMode = Provider.of<ThemeNotifier>(context).isDarkMode;
    switch (status.toLowerCase()) {
      case 'pending':
        return isDarkMode ? Colors.amber[300]! : Colors.orange;
      case 'processing':
        return isDarkMode ? Colors.blue[300]! : Colors.blue;
      case 'finished':
        return isDarkMode ? Colors.green[300]! : Colors.green;
      default:
        return isDarkMode ? Colors.grey[400]! : Colors.grey;
    }
  }

  Widget _buildProgressBar(String? progressStr) {
    final bool isDarkMode = Provider.of<ThemeNotifier>(context).isDarkMode;
    double progress = double.tryParse(progressStr ?? '0.0') ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress / 100,
                backgroundColor: Colors.transparent,
                color: isDarkMode ? const Color(0xFFFFD700) : Colors.amber,
                minHeight: 8.0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${progress.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  /// Builds a grid of project members
  Widget _buildProjectMembersGrid(List<Map<String, dynamic>> members) {
    final bool isDarkMode = Provider.of<ThemeNotifier>(context).isDarkMode;
    int crossAxisCount = MediaQuery.of(context).size.width > 600 ? 6 : 4;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
      ),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return GestureDetector(
          onTap: () => _showMemberNameDialog(context, member['name']),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? Colors.black.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  backgroundImage: NetworkImage(
                    member['profileImage'] ?? 'https://via.placeholder.com/150',
                  ),
                  radius: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                member['name'] ?? 'Unknown',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMemberNameDialog(BuildContext context, String name) {
    final bool isDarkMode =
        Provider.of<ThemeNotifier>(context, listen: false).isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Member Name',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          name,
          style: TextStyle(
            color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDarkMode ? Colors.blue[300] : Colors.blue,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
