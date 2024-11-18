// processing_section.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/sections_service/add_processing.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/sections_service/edit_processing.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/sections_service/view_processing.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ProcessingSection extends StatefulWidget {
  final String projectId;
  final String baseUrl;

  const ProcessingSection({
    Key? key,
    required this.projectId,
    required this.baseUrl,
  }) : super(key: key);

  @override
  State<ProcessingSection> createState() => _ProcessingSectionState();
}

class _ProcessingSectionState extends State<ProcessingSection> {
  final WorkTrackingService _workTrackingService = WorkTrackingService();

  List<Map<String, dynamic>> _meetings = [];
  String _selectedStatus = 'All Status';
  final List<String> _statusOptions = ['All Status', 'Pending', 'Processing', 'Finished'];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchMeetingData();
  }

  Future<void> _fetchMeetingData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    print('[_ProcessingSection] Fetching meetings for projectId: ${widget.projectId}');

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
        Uri.parse('${widget.baseUrl}/api/work-tracking/meeting/get-all-meeting'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _meetings = List<Map<String, dynamic>>.from(data['results'] ?? []).where((meeting) {
            return meeting['projects_id'] == widget.projectId;
          }).toList();
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load meetings: ${response.body}')),
        );
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load meeting data: $e');
      }
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
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

  void _showAddProcessingPage() async {
    print('[_ProcessingSection] Navigating to AddProcessingPage with projectId: ${widget.projectId}');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProcessingPage(
          projectId: widget.projectId,
          baseUrl: widget.baseUrl,
        ),
      ),
    );

    if (result == true) {
      _fetchMeetingData();
    }
  }

  void _showViewProcessingPage(Map<String, dynamic> meeting) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewProcessingPage(
          meetingId: meeting['meeting_id'],
          projectId: widget.projectId,
          baseUrl: widget.baseUrl,
        ),
      ),
    );
  }

  Widget _buildProcessingTaskCard(Map<String, dynamic> meeting) {
    final fromDate = meeting['from_date'] != null
        ? DateTime.parse(meeting['from_date'])
        : DateTime.now();
    final toDate = meeting['to_date'] != null
        ? DateTime.parse(meeting['to_date'])
        : DateTime.now();
    final now = DateTime.now();
    final daysRemaining = toDate.difference(now).inDays;

    Color statusColor = _getStatusColor(meeting['s_name'] ?? 'Unknown');
    Color daysColor;
    String daysText;

    if (daysRemaining > 0) {
      daysColor = Colors.orange;
      daysText = '$daysRemaining day${daysRemaining > 1 ? 's' : ''} remaining';
    } else if (daysRemaining == 0) {
      daysColor = Colors.red;
      daysText = 'Today is the end date';
    } else {
      daysColor = Colors.red;
      daysText = 'Ended ${-daysRemaining} day${-daysRemaining > 1 ? 's' : ''} ago';
    }

    return GestureDetector(
      onTap: () {
        _showViewProcessingPage(meeting);
      },
      child: Container(
        margin: const EdgeInsets.only(top: 6.0, left: 8.0, right: 8.0, bottom: 16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.4),
              blurRadius: 6,
              spreadRadius: 1,
              offset: const Offset(1, 1),
            ),
          ],
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status and Update Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Status: ',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Icon(Icons.access_time, color: statusColor, size: 16),
                      const SizedBox(width: 3),
                      Text(
                        meeting['s_name'] ?? 'Unknown',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UpdateProcessingPage(
                                meetingId: meeting['meeting_id'],
                                projectId: widget.projectId,
                                baseUrl: widget.baseUrl,
                              ),
                            ),
                          ).then((value) {
                            if (value == true) {
                              _fetchMeetingData();
                            }
                          });
                        },
                        child: const CircleAvatar(
                          backgroundColor: Colors.green,
                          radius: 14,
                          child: Icon(Icons.notifications, color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UpdateProcessingPage(
                                meetingId: meeting['meeting_id'],
                                projectId: widget.projectId,
                                baseUrl: widget.baseUrl,
                              ),
                            ),
                          ).then((value) {
                            if (value == true) {
                              _fetchMeetingData();
                            }
                          });
                        },
                        child: const Text(
                          'Update',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Title Section
              Row(
                children: [
                  Image.asset('assets/title.png', width: 16, height: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  const Text(
                    'Title: ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      meeting['title'] ?? 'No Title',
                      style: const TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Start and End Date Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/calendar-icon.png', width: 16, height: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Start Date:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${DateFormat('yyyy-MM-dd').format(fromDate)} ${meeting['start_time'] ?? ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/box-time.png', width: 16, height: 16, color: Colors.red),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'End Date:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${DateFormat('yyyy-MM-dd').format(toDate)} ${meeting['end_time'] ?? ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Days Remaining Section
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: daysColor),
                  const SizedBox(width: 2),
                  Text(
                    daysText,
                    style: TextStyle(
                      fontSize: 12,
                      color: daysColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.bottomRight,
                child: RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Created by: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      TextSpan(
                        text: meeting['create_by'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    List<Map<String, dynamic>> filteredMeetings = _meetings.where((meeting) {
      return _selectedStatus == 'All Status' || meeting['s_name'] == _selectedStatus;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Status Dropdown
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: isDarkMode
                        ? const LinearGradient(
                      colors: [Color(0xFF424242), Color(0xFF303030)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(1, 1),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusOptions.contains(_selectedStatus)
                          ? _selectedStatus
                          : null,
                      icon: Image.asset('assets/task.png', width: 24, height: 24),
                      iconSize: 28,
                      elevation: 16,
                      dropdownColor: isDarkMode
                          ? const Color(0xFF424242)
                          : Colors.white,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedStatus = newValue!;
                        });
                      },
                      items: _statusOptions
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Row(
                            children: [
                              Icon(Icons.access_time,
                                  color: _getStatusColor(value), size: 14),
                              const SizedBox(width: 10),
                              Text(value),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Add Button
              IconButton(
                icon: Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(2.0),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 40.0,
                  ),
                ),
                onPressed: _showAddProcessingPage,
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasError
              ? Center(
            child: Text(
              'Failed to load meetings.',
              style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 16),
            ),
          )
              : filteredMeetings.isEmpty
              ? const Center(child: Text('No processing data to display'))
              : RefreshIndicator(
            onRefresh: _fetchMeetingData,
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: filteredMeetings.length,
              itemBuilder: (context, index) {
                return _buildProcessingTaskCard(filteredMeetings[index]);
              },
            ),
          ),
        ),
      ],
    );
  }
}
