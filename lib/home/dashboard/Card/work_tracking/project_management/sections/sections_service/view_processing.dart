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
  List<Map<String, dynamic>>? _files;
  List<Map<String, dynamic>>? _members;

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
          _meeting = (data['result'] is List && data['result'].isNotEmpty)
              ? data['result'][0] as Map<String, dynamic>
              : (data['result'] is Map) ? data['result'] as Map<String, dynamic> : null;
          _files = _parseFiles(data['files']);
          _members = _parseMembers(data['members']);
          _isLoading = false;
        });

        // Fetch images for each member
        if (_members != null && _members!.isNotEmpty) {
          await _fetchMembersImages(token);
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load meeting details: ${response.body}')),
        );
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching meeting details: $e')),
      );
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  List<Map<String, dynamic>> _parseFiles(dynamic filesData) {
    if (filesData == null) return [];
    List<Map<String, dynamic>> files = [];

    if (filesData is List) {
      for (var file in filesData) {
        if (file is Map<String, dynamic>) {
          files.add({
            'file_name': file['file_name']?.toString() ?? 'Unnamed File',
            'file_url': file['file_url']?.toString() ?? '',
          });
        }
      }
    }
    return files;
  }

  List<Map<String, dynamic>> _parseMembers(dynamic membersData) {
    if (membersData == null) return [];
    return membersData is List ? membersData.cast<Map<String, dynamic>>() : [];
  }

  Future<void> _fetchMembersImages(String token) async {
    List<Future<void>> imageFetchFutures = _members!.map((member) async {
      String employeeId = member['employee_id'].toString();
      String? imageUrl = await _fetchMemberImage(employeeId, token);
      setState(() {
        member['image_url'] = imageUrl;
      });
    }).toList();

    await Future.wait(imageFetchFutures);
  }

  Future<String?> _fetchMemberImage(String employeeId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/profile/$employeeId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['results']?['images']?.toString();
      }
    } catch (e) {
      print('Error fetching image for $employeeId: $e');
    }
    return null;
  }

  Future<void> _downloadAll() async {
    await _downloadDescription();
    await _downloadFiles();
  }

  Future<void> _downloadDescription() async {
    if (_meeting == null) return;
    String description = _meeting!['description'] ?? '';
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/description.txt';
      final file = File(path);
      await file.writeAsString(description);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Description downloaded to $path')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download description: $e')),
      );
    }
  }

  Future<void> _downloadFiles() async {
    if (_files == null || _files!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No files to download')),
      );
      return;
    }

    bool allSuccess = true;

    for (var file in _files!) {
      String fileUrl = file['file_url']?.toString() ?? '';
      String fileName = file['file_name']?.toString() ?? 'unknown_file';

      if (fileUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid URL for file: $fileName')),
        );
        allSuccess = false;
        continue;
      }

      try {
        final response = await http.get(Uri.parse(fileUrl));
        if (response.statusCode == 200) {
          final directory = await getApplicationDocumentsDirectory();
          final path = '${directory.path}/$fileName';
          final fileToSave = File(path);
          await fileToSave.writeAsBytes(response.bodyBytes);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to download $fileName')),
          );
          allSuccess = false;
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading $fileName: $e')),
        );
        allSuccess = false;
      }
    }

    if (allSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All files downloaded successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Some files failed to download')),
      );
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
        'Processing or Details',
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
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'finished':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError || _meeting == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: Text('Failed to load meeting details')),
      );
    }

    final status = _meeting!['s_name']?.toString() ?? 'Unknown';
    final statusColor = _getStatusColor(status);
    final title = _meeting!['title']?.toString() ?? 'No Title';
    final fromDate = _meeting!['from_date'] != null
        ? DateTime.tryParse(_meeting!['from_date'].toString()) ?? DateTime.now()
        : DateTime.now();
    final toDate = _meeting!['to_date'] != null
        ? DateTime.tryParse(_meeting!['to_date'].toString()) ?? DateTime.now()
        : DateTime.now();
    final startTime = _meeting!['start_time']?.toString() ?? '';
    final endTime = _meeting!['end_time']?.toString() ?? '';
    final description = _meeting!['description']?.toString() ?? '';

    return Scaffold(
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.title, color: Colors.blue),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Title:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text(title, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.black),
                    const SizedBox(width: 4),
                    const Text(
                      'Status: ',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14),
                    ),
                    Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Date Range
            Row(
              children: [
                const Icon(Icons.date_range, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Date: ${DateFormat('yyyy-MM-dd').format(fromDate)} - ${DateFormat('yyyy-MM-dd').format(toDate)}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Time
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Time: $startTime - $endTime',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Members
            const Text(
              'Members:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _members != null && _members!.isNotEmpty
                ? Wrap(
              spacing: 12,
              children: _members!.map((member) {
                String imageUrl = member['image_url']?.toString() ?? 'https://via.placeholder.com/50';
                String memberName = member['name']?.toString() ?? 'Member';
                return Column(
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(imageUrl),
                      radius: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      memberName,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              }).toList(),
            )
                : const Text('No members assigned'),
            const SizedBox(height: 20),

            // Description and Download Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.folder_open, color: Colors.black),
                    SizedBox(width: 8),
                    Text(
                      'Description:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _downloadAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  ),
                  icon: const Icon(Icons.cloud_download, color: Colors.white),
                  label: const Text('Download', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(description, style: const TextStyle(fontSize: 14)),

            // Files
            const SizedBox(height: 20),
            const Text(
              'Files:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _files != null && _files!.isNotEmpty
                ? Column(
              children: _files!.map((file) {
                return ListTile(
                  leading: const Icon(Icons.file_present, color: Colors.blue), // Modern file icon
                  title: Text(file['file_name'] ?? 'File', style: const TextStyle(fontSize: 14)),
                  trailing: IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.green), // Modern download icon
                    onPressed: _downloadFiles,
                  ),
                );
              }).toList(),
            )
                : const Text('No files available'),
          ],
        ),
      ),
    );
  }
}
