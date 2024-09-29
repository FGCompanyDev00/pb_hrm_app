// processing_section.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/sections_service/add_processing.dart';
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

  const ProcessingSection({super.key, required this.projectId, required this.baseUrl});

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

  // Fetch meeting data from the new API endpoint
  Future<void> _fetchMeetingData() async {
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
          const SnackBar(content: Text('Failed to load meetings')),
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

  // Get color based on status
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

  // Show add processing page
  void _showAddProcessingPage() async {
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

  // Show view meeting modal
  void _showViewMeetingModal(Map<String, dynamic> meeting) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(meeting['title'] ?? 'No Title'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${meeting['s_name'] ?? 'Unknown'}', style: TextStyle(color: _getStatusColor(meeting['s_name'] ?? 'Unknown'))),
                const SizedBox(height: 10),
                Text('Start Date: ${meeting['from_date'] != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(meeting['from_date'])) : 'N/A'}'),
                const SizedBox(height: 10),
                Text('Due Date: ${meeting['to_date'] != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(meeting['to_date'])) : 'N/A'}'),
                const SizedBox(height: 10),
                const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(meeting['description'] ?? 'No Description'),
                const SizedBox(height: 10),
                // Attachments and Assigned Members can be added here if available
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmation(String meetingId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Meeting'),
          content: const Text('Are you sure you want to delete this meeting?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteMeeting(meetingId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // Delete a meeting
  Future<void> _deleteMeeting(String meetingId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token is null. Please log in again.')),
      );
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('${widget.baseUrl}/api/work-tracking/meeting/delete/$meetingId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meeting deleted successfully')),
        );
        _fetchMeetingData();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete meeting')),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting meeting: $e');
      }
    }
  }

  // Build processing task card UI
  Widget _buildProcessingTaskCard(Map<String, dynamic> meeting) {
    final progressColors = {
      'Pending': Colors.orange,
      'Processing': Colors.blue,
      'Finished': Colors.green,
    };

    final fromDate = meeting['from_date'] != null ? DateTime.parse(meeting['from_date']) : DateTime.now();
    final toDate = meeting['to_date'] != null ? DateTime.parse(meeting['to_date']) : DateTime.now();
    final daysRemaining = toDate.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE0E0F0),
            Color(0xFFF7F7FF),
            Color(0xFFFFFFFF),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(4, 4),
          ),
        ],
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: ListTile(
        onTap: () => _showViewMeetingModal(meeting),
        title: Text(
          meeting['title'] ?? 'No Title',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${meeting['s_name'] ?? 'Unknown'}', style: TextStyle(color: _getStatusColor(meeting['s_name'] ?? 'Unknown'))),
            Text('From: ${DateFormat('yyyy-MM-dd').format(fromDate)}'),
            Text('To: ${DateFormat('yyyy-MM-dd').format(toDate)}'),
            Text('Days Remaining: $daysRemaining'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'Delete') {
              _showDeleteConfirmation(meeting['meeting_id']);
            } else if (value == 'View') {
              _showViewMeetingModal(meeting);
            }
          },
          itemBuilder: (BuildContext context) {
            return ['View', 'Delete'].map((String choice) {
              return PopupMenuItem<String>(
                value: choice,
                child: Text(choice),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  // Build icon and text row
  Widget _buildIconTextRow({required IconData icon, required String label, required Color iconColor}) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
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
        // Status filter and add button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
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
                      value: _statusOptions.contains(_selectedStatus) ? _selectedStatus : null,
                      icon: const Icon(Icons.arrow_downward, color: Colors.amber),
                      iconSize: 28,
                      elevation: 16,
                      dropdownColor: isDarkMode ? const Color(0xFF424242) : Colors.white,
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
                      items: _statusOptions.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Row(
                            children: [
                              Icon(Icons.circle, color: _getStatusColor(value), size: 14),
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
              IconButton(
                icon: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.greenAccent, Colors.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10.0),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 20.0,
                  ),
                ),
                onPressed: _showAddProcessingPage,
              ),
            ],
          ),
        ),
        // Meeting list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasError
              ? const Center(child: Text('Failed to load meetings'))
              : filteredMeetings.isEmpty
              ? const Center(child: Text('No processing data to display'))
              : RefreshIndicator(
            onRefresh: _fetchMeetingData,
            child: ListView.builder(
              padding: const EdgeInsets.all(12.0),
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
