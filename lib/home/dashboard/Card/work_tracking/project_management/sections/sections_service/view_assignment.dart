// view_assignment.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewAssignmentPage extends StatefulWidget {
  final String assignmentId;
  final String projectId;
  final String baseUrl;

  const ViewAssignmentPage({
    Key? key,
    required this.assignmentId,
    required this.projectId,
    required this.baseUrl,
  }) : super(key: key);

  @override
  State<ViewAssignmentPage> createState() => _ViewAssignmentPageState();
}

class _ViewAssignmentPageState extends State<ViewAssignmentPage> {
  bool _isLoading = true;
  bool _hasError = false;
  Map<String, dynamic>? _assignmentDetails;
  List<Map<String, dynamic>> _files = [];
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _fetchAssignmentDetails();
  }

  Future<void> _fetchAssignmentDetails() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token is null. Please log in again.')),
      );
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/work-tracking/ass/get-assignment/${widget.assignmentId}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _assignmentDetails = data;
          _files = List<Map<String, dynamic>>.from(data['files'] ?? []);
          _members = List<Map<String, dynamic>>.from(data['members'] ?? []);
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load assignment details')),
        );
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load assignment details: $e');
      }
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Finished':
        return Colors.green;
      default:
        return Colors.black;
    }
  }

  Future<void> _downloadFile(String url, String originalName) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch the file URL')),
      );
    }
  }

  Widget _buildFileList() {
    if (_files.isEmpty) {
      return const Center(child: Text('No files attached.'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        final fileUrl = file['images'] != null && file['images'].isNotEmpty
            ? file['images'][0]
            : null;
        final originalName = file['originalname'] ?? 'No Name';

        return ListTile(
          leading: const Icon(Icons.attach_file, color: Colors.green),
          title: Text(originalName),
          trailing: IconButton(
            icon: const Icon(Icons.download, color: Colors.blue),
            onPressed: fileUrl != null
                ? () => _downloadFile(fileUrl, originalName)
                : null,
          ),
        );
      },
    );
  }

  Widget _buildMembersList() {
    if (_members.isEmpty) {
      return const Center(child: Text('No members assigned.'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final fullName = '${member['name'] ?? ''} ${member['surname'] ?? ''}';
        final email = member['email'] ?? 'No Email';

        return ListTile(
          leading: const Icon(Icons.person, color: Colors.blue),
          title: Text(fullName),
          subtitle: Text(email),
        );
      },
    );
  }

  Widget _buildAssignmentDetails() {
    if (_assignmentDetails == null) {
      return const Center(child: Text('No assignment details available.'));
    }

    final createdAt = _assignmentDetails!['created_at'] != null
        ? DateTime.parse(_assignmentDetails!['created_at'])
        : DateTime.now();
    final updatedAt = _assignmentDetails!['updated_at'] != null
        ? DateTime.parse(_assignmentDetails!['updated_at'])
        : DateTime.now();
    final status = _assignmentDetails!['s_name'] ?? 'Unknown';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status and Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, color: _getStatusColor(status)),
                  const SizedBox(width: 8),
                  Text(
                    status,
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              Text(
                'ID: ${_assignmentDetails!['as_id'] ?? 'N/A'}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Title
          Row(
            children: [
              Image.asset('assets/title.png', width: 20, height: 20),
              const SizedBox(width: 8),
              const Text(
                'Title: ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  _assignmentDetails!['title'] ?? 'No Title',
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Description
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _assignmentDetails!['description'] ?? 'No Description',
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Created By and Created At
          Row(
            children: [
              const Icon(Icons.person, size: 20, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Created by: ${_assignmentDetails!['create_by'] ?? 'Unknown'}',
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Created at: ${DateFormat('yyyy-MM-dd – kk:mm').format(createdAt)}',
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.update, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Updated at: ${DateFormat('yyyy-MM-dd – kk:mm').format(updatedAt)}',
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Files Section
          const Text(
            'Attached Files:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildFileList(),
          const SizedBox(height: 24),
          // Members Section
          const Text(
            'Assigned Members:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildMembersList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'View Assignment',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        toolbarHeight: 80,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? const Center(child: Text('Failed to load assignment details'))
          : _buildAssignmentDetails(),
    );
  }
}
