import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../../../../../settings/theme_notifier.dart';

class ViewAssignmentPage extends StatefulWidget {
  final String assignmentId;
  final String projectId;
  final String baseUrl;

  const ViewAssignmentPage({
    super.key,
    required this.assignmentId,
    required this.projectId,
    required this.baseUrl,
  });

  @override
  State<ViewAssignmentPage> createState() => _ViewAssignmentPageState();
}

class _ViewAssignmentPageState extends State<ViewAssignmentPage> {
  bool _isLoading = true;
  bool _hasError = false;
  Map<String, dynamic>? _assignmentDetails;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _files = [];

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

        if (data['statusCode'] == 200 && data['result'] != null && data['result'].isNotEmpty) {
          setState(() {
            _assignmentDetails = data['result'][0];
            _members = List<Map<String, dynamic>>.from(data['members'] ?? []);
            _files = List<Map<String, dynamic>>.from(data['files'] ?? []);
            _isLoading = false;
          });

          // Fetch member images
          if (_members.isNotEmpty) {
            await _fetchMembersImages(token);
          }
        } else {
          _showError(data['message'] ?? 'Failed to load assignment details');
        }
      } else {
        _showError('Failed to load assignment details: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error fetching assignment details: $e');
    }
  }

  Future<void> _fetchMembersImages(String token) async {
    List<Future<void>> fetchTasks = _members.map((member) async {
      String empId = member['emp_id'];
      try {
        final response = await http.get(
          Uri.parse('${widget.baseUrl}/api/profile/$empId'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          String? imageUrl = data['results']?['images'];
          setState(() {
            member['image_url'] = imageUrl ?? 'https://via.placeholder.com/50';
          });
        }
      } catch (e) {
        print('Error fetching image for $empId: $e');
      }
    }).toList();

    await Future.wait(fetchTasks);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Finished':
        return Colors.green;
      case 'Error':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  Future<void> _downloadFile(String url, String originalName) async {
    final Uri fileUri = Uri.parse(url);

    if (await canLaunchUrl(fileUri)) {
      await launchUrl(fileUri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch the file URL')),
      );
    }
  }

  Widget _buildMembersList() {
    // Filter duplicates based on member names
    var uniqueMembers = <Map<String, dynamic>>[];
    var seenNames = <String>{};

    for (var member in _members) {
      String fullName = '${member['name']} ${member['surname']}';
      if (!seenNames.contains(fullName)) {
        seenNames.add(fullName);
        uniqueMembers.add(member);
      }
    }

    if (uniqueMembers.isEmpty) {
      return const Text('No members assigned.', style: TextStyle(fontSize: 14));
    }

    return Wrap(
      spacing: 12,
      children: uniqueMembers.map((member) {
        String imageUrl = member['image_url'] ?? 'https://via.placeholder.com/50';
        String memberName = '${member['name']} ${member['surname']}';

        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Selected Member'),
                  content: Text('Name: $memberName'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Close'),
                    ),
                  ],
                );
              },
            );
          },
          child: Column(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(imageUrl),
                radius: 30,
              ),
              // Remove the member name from being displayed by default
              // The name will only show when clicked.
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFilesList() {
    if (_files.isEmpty) {
      return const Text('No files attached.', style: TextStyle(fontSize: 14));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        final fileUrl = file['url'] ?? '';
        final originalName = file['name'] ?? 'Unnamed File';

        return ListTile(
          leading: const Icon(Icons.file_present, color: Colors.blue), // Modern file icon
          title: Text(originalName, style: const TextStyle(fontSize: 14)),
          trailing: IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.green), // Modern download icon
            onPressed: () => _downloadFile(fileUrl, originalName),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          'View Assignment',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, // Dynamic title color based on theme
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, // Dynamic icon color based on theme
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
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.title, color: Colors.purple),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Title:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text(
                          _assignmentDetails!['title'] ?? 'No Title',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.black),
                    const SizedBox(width: 4),
                    const Text(
                      'Status:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _assignmentDetails!['s_name'] ?? 'Pending',
                      style: TextStyle(
                        color: _getStatusColor(_assignmentDetails!['s_name']),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Members
            const Text('Member:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildMembersList(),
            const SizedBox(height: 16),

            // Description and Download Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.folder_open, color: Colors.black),
                    SizedBox(width: 8),
                    Text('Description:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {}, // Add your download logic here
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  ),
                  icon: const Icon(Icons.cloud_download, color: Colors.white),
                  label: const Text('Download', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _assignmentDetails!['description']?.isNotEmpty == true
                  ? _assignmentDetails!['description']
                  : 'No Description',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Files
            const Text('Files:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildFilesList(),
          ],
        ),
      ),
    );
  }
}
