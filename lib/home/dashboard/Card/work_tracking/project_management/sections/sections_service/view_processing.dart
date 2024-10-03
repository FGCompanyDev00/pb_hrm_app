// view_processing.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class ViewProcessingPage extends StatefulWidget {
  final String meetingId;
  final String projectId;
  final String baseUrl;

  const ViewProcessingPage({
    super.key,
    required this.meetingId,
    required this.projectId,
    required this.baseUrl,
  });

  @override
  _ViewProcessingPageState createState() => _ViewProcessingPageState();
}

class _ViewProcessingPageState extends State<ViewProcessingPage> {
  bool _isLoading = true;
  bool _hasError = false;
  Map<String, dynamic>? _meeting;
  List<dynamic>? _files;
  List<dynamic>? _members;

  @override
  void initState() {
    super.initState();
    _fetchMeetingDetails();
  }

  Future<void> _fetchMeetingDetails() async {
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
        Uri.parse('${widget.baseUrl}/api/work-tracking/meeting/get-meeting/${widget.meetingId}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _meeting = data['results'];
          _files = data['files'];
          _members = data['members'];
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load meeting details')),
        );
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching meeting details')),
      );
    }
  }

  Color _getStatusColor(String status) {
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

  Future<void> _downloadDescription() async {
    if (_meeting == null) return;
    String description = _meeting!['description'] ?? '';
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/description.txt';
    final file = File(path);
    await file.writeAsString(description);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Description downloaded to $path')),
    );
  }

  Future<void> _downloadFiles() async {
    if (_files == null || _files!.isEmpty) return;
    for (var file in _files!) {
      String fileUrl = file['file_url'];
      String fileName = file['file_name'];
      try {
        final response = await http.get(Uri.parse(fileUrl));
        if (response.statusCode == 200) {
          final directory = await getApplicationDocumentsDirectory();
          final path = '${directory.path}/$fileName';
          final fileToSave = File(path);
          await fileToSave.writeAsBytes(response.bodyBytes);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download $fileName')),
        );
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Files downloaded successfully')),
    );
  }

  Future<void> _downloadAll() async {
    await _downloadDescription();
    if (_files != null && _files!.isNotEmpty) {
      await _downloadFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
            'View Processing',
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError || _meeting == null) {
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
            'View Processing',
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
        body: const Center(child: Text('Failed to load meeting details')),
      );
    }

    final status = _meeting!['s_name'] ?? 'Unknown';
    final statusColor = _getStatusColor(status);
    final title = _meeting!['title'] ?? 'No Title';
    final fromDate = _meeting!['from_date'] != null ? DateTime.parse(_meeting!['from_date']) : DateTime.now();
    final toDate = _meeting!['to_date'] != null ? DateTime.parse(_meeting!['to_date']) : DateTime.now();
    final startTime = _meeting!['start_time'] ?? '';
    final endTime = _meeting!['end_time'] ?? '';
    final description = _meeting!['description'] ?? '';
    final createdBy = _meeting!['create_by'] ?? 'Unknown';
    final daysRemaining = toDate.difference(DateTime.now()).inDays;
    final isNearDue = daysRemaining <= 5;

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
          'View Processing',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Status Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset('assets/title.png', width: 24, height: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Title: $title',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Status: $status',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Date and Time
            Row(
              children: [
                Image.asset('assets/calendar-icon.png', width: 18, height: 18),
                const SizedBox(width: 8),
                Text(
                  'Date: ${DateFormat('yyyy-MM-dd').format(fromDate)}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 16),
                Image.asset('assets/box-time.png', width: 18, height: 18),
                const SizedBox(width: 8),
                Text(
                  'Time: $startTime',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Image.asset('assets/calendar-icon.png', width: 18, height: 18),
                const SizedBox(width: 8),
                Text(
                  'Date: ${DateFormat('yyyy-MM-dd').format(toDate)}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 16),
                Image.asset('assets/box-time.png', width: 18, height: 18),
                const SizedBox(width: 8),
                Text(
                  'Time: $endTime',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Days Remaining
            Row(
              children: [
                const Text(
                  'Days Remaining: ',
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  '$daysRemaining',
                  style: TextStyle(
                    fontSize: 16,
                    color: isNearDue ? Colors.red : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Members
            const Text(
              'Members:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _members != null && _members!.isNotEmpty
                ? Row(
              children: _members!.map<Widget>((member) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: CircleAvatar(
                    backgroundImage: member['profile_image'] != null
                        ? NetworkImage(member['profile_image'])
                        : const AssetImage('assets/default_profile.png') as ImageProvider,
                    radius: 20,
                  ),
                );
              }).toList(),
            )
                : const Text('No members assigned'),
            const SizedBox(height: 16),
            // Description and Download Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Description:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton(
                  onPressed: _downloadAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text(
                    'Download',
                    style: TextStyle(
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description.isNotEmpty ? description.replaceAll(RegExp(r'<[^>]*>'), '') : 'No Description',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            // Description Details
            const Text(
              'Details:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description.isNotEmpty ? description : 'No Details Available',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
