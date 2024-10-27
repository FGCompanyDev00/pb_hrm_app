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
    Key? key,
    required this.meetingId,
    required this.projectId,
    required this.baseUrl,
  }) : super(key: key);

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
        print('API Response: $data'); // Debugging

        // Handle 'result' as either a Map or List
        if (data['result'] is List) {
          setState(() {
            _meeting = data['result'].isNotEmpty ? data['result'][0] : null;
            _files = data['files'] ?? [];
            _members = data['members'] ?? [];
            _isLoading = false;
          });
        } else if (data['result'] is Map) {
          setState(() {
            _meeting = data['result'];
            _files = data['files'] ?? [];
            _members = data['members'] ?? [];
            _isLoading = false;
          });
        } else {
          throw Exception('Unexpected data format for "result"');
        }

        // Fetch images for each member
        if (_members != null && _members!.isNotEmpty) {
          await _fetchMembersImages(token);
        }
      } else {
        print('Error: ${response.statusCode} - ${response.body}'); // Debugging
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
      print('Exception: $e'); // Debugging
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

  Future<void> _fetchMembersImages(String token) async {
    List<Future<void>> imageFetchFutures = _members!.map((member) async {
      String employeeId = member['employee_id'];
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
        if (data['results'] != null && data['results']['images'] != null) {
          return data['results']['images'];
        }
      } else {
        print('Failed to fetch image for $employeeId: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception while fetching image for $employeeId: $e');
    }
    return null;
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
      String fileUrl = file['file_url'] ?? '';
      String fileName = file['file_name'] ?? 'unknown_file';

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

  Future<void> _downloadAll() async {
    await _downloadDescription();
    await _downloadFiles();
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
    );
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

    // Extracting meeting details with null safety
    final status = _meeting!['s_name'] ?? 'Unknown';
    final statusColor = _getStatusColor(status);
    final title = _meeting!['title'] ?? 'No Title';
    final fromDate = _meeting!['from_date'] != null
        ? DateTime.tryParse(_meeting!['from_date']) ?? DateTime.now()
        : DateTime.now();
    final toDate = _meeting!['to_date'] != null
        ? DateTime.tryParse(_meeting!['to_date']) ?? DateTime.now()
        : DateTime.now();
    final startTime = _meeting!['start_time'] ?? '';
    final endTime = _meeting!['end_time'] ?? '';
    final description = _meeting!['description'] ?? '';
    final daysRemaining = toDate.difference(DateTime.now()).inDays;
    final isNearDue = daysRemaining <= 5;

    return Scaffold(
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Status Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Image.asset('assets/title.png', width: 24, height: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Title: $title',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 12, // Increased size for better visibility
                      height: 12,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6), // Increased spacing
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
            const SizedBox(height: 24), // Increased spacing between sections

            // From Date and Start Time
            _buildDateTimeRow(
              iconPath: 'assets/calendar-icon.png',
              dateLabel: 'From: ',
              dateValue: DateFormat('yyyy-MM-dd').format(fromDate),
              timeLabel: 'Start: ',
              timeValue: startTime,
            ),
            const SizedBox(height: 16),

            // To Date and End Time
            _buildDateTimeRow(
              iconPath: 'assets/calendar-icon.png',
              dateLabel: 'To: ',
              dateValue: DateFormat('yyyy-MM-dd').format(toDate),
              timeLabel: 'End: ',
              timeValue: endTime,
            ),
            const SizedBox(height: 24),

            // Days Remaining
            Row(
              children: [
                const Icon(Icons.timer, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Days Remaining: ',
                  style: TextStyle(
                    fontSize: 16,
                    color: isNearDue ? Colors.red : Colors.orange[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$daysRemaining',
                  style: TextStyle(
                    fontSize: 16,
                    color: isNearDue ? Colors.red : Colors.orange[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Members
            const Text(
              'Members:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _members != null && _members!.isNotEmpty
                ? Wrap(
              spacing: 12.0, // Increased spacing between avatars
              runSpacing: 12.0,
              children: _members!.map<Widget>((member) {
                String imageUrl = member['image_url'] ??
                    'https://via.placeholder.com/150'; // Default image
                String memberName = member['name'] ?? 'Member';
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(imageUrl),
                      radius: 30, // Increased size for better visibility
                      onBackgroundImageError: (_, __) {},
                      backgroundColor: Colors.grey[200],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 70, // Fixed width for consistency
                      child: Text(
                        memberName,
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              }).toList(),
            )
                : const Text('No members assigned'),
            const SizedBox(height: 24),

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
                ElevatedButton.icon(
                  onPressed: _downloadAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  icon: const Icon(Icons.download, color: Colors.black, size: 18),
                  label: const Text(
                    'Download',
                    style: TextStyle(
                      color: Colors.black,

                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                description.isNotEmpty
                    ? description.replaceAll(RegExp(r'<[^>]*>'), '')
                    : 'No Description',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                ),
                textAlign: TextAlign.justify,
              ),
            ),
            const SizedBox(height: 24),

            // Files Section (Optional)
            _files != null && _files!.isNotEmpty
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Files:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _files!.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    var file = _files![index];
                    String fileName = file['file_name'] ?? 'Unnamed File';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0.0),
                      leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                      title: Text(
                        fileName,
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.download, color: Colors.green),
                        onPressed: () async {
                          String fileUrl = file['file_url'] ?? '';
                          if (fileUrl.isNotEmpty) {
                            try {
                              final response = await http.get(Uri.parse(fileUrl));
                              if (response.statusCode == 200) {
                                final directory = await getApplicationDocumentsDirectory();
                                final path = '${directory.path}/$fileName';
                                final fileToSave = File(path);
                                await fileToSave.writeAsBytes(response.bodyBytes);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$fileName downloaded to $path')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to download $fileName')),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error downloading $fileName: $e')),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invalid file URL')),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ],
            )
                : const SizedBox(),
          ],
        ),
      ),
    );
  }

  // Helper method to build Date and Time rows
  Widget _buildDateTimeRow({
    required String iconPath,
    required String dateLabel,
    required String dateValue,
    required String timeLabel,
    required String timeValue,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(iconPath, width: 20, height: 20),
        const SizedBox(width: 12), // Increased spacing
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  text: dateLabel,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: dateValue,
                      style: const TextStyle(
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  text: timeLabel,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: timeValue,
                      style: const TextStyle(
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
