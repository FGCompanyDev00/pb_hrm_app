// notification_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:pb_hrsystem/notifications/notification_detail_page.dart';
import 'package:pb_hrsystem/notifications/notification_meeting_section_detail_page.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool _isMeetingSelected = true;
  List<Map<String, dynamic>> _meetingInvites = [];
  List<Map<String, dynamic>> _pendingItems = [];
  List<Map<String, dynamic>> _historyItems = [];
  bool _isLoading = true;
  final Set<String> _knownTypes = {'meeting', 'leave', 'car'};
  Map<int, String> _leaveTypesMap = {};
  final String _imageBaseUrl =
      'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _fetchLeaveTypes();
      await Future.wait([
        _fetchPendingItems(),
        _fetchMeetingInvites(),
      ]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLeaveTypes() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String leaveTypesApiUrl = '$baseUrl/api/leave-types';

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('User not authenticated');
    }

    final leaveTypesResponse = await http.get(
      Uri.parse(leaveTypesApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (leaveTypesResponse.statusCode == 200) {
      final responseBody = jsonDecode(leaveTypesResponse.body);
      if (responseBody['statusCode'] == 200 &&
          responseBody['results'] != null) {
        final List<dynamic> leaveTypesData = responseBody['results'];
        setState(() {
          _leaveTypesMap = {
            for (var item in leaveTypesData)
              item['leave_type_id'] as int: item['name'].toString()
          };
        });
      } else {
        throw Exception(
            responseBody['message'] ?? 'Failed to load leave types');
      }
    } else {
      throw Exception(
          'Failed to load leave types: ${leaveTypesResponse.statusCode}');
    }
  }

  Future<void> _fetchPendingItems() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String pendingApiUrl = '$baseUrl/api/app/tasks/approvals/pending';

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('User not authenticated');
    }

    final pendingResponse = await http.get(
      Uri.parse(pendingApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (pendingResponse.statusCode == 200) {
      final responseBody = jsonDecode(pendingResponse.body);
      if (responseBody['statusCode'] == 200 &&
          responseBody['results'] != null) {
        final List<dynamic> pendingData = responseBody['results'];
        final List<Map<String, dynamic>> filteredData = pendingData
            .where((item) => item != null)
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) =>
        item['types'] != null &&
            _knownTypes.contains(item['types'].toString().toLowerCase()))
            .toList();

        setState(() {
          _pendingItems = filteredData;
        });
      } else {
        throw Exception(
            responseBody['message'] ?? 'Failed to load pending data');
      }
    } else {
      throw Exception(
          'Failed to load pending data: ${pendingResponse.statusCode}');
    }
  }

  Future<void> _fetchMeetingInvites() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    final String meetingInvitesApiUrl =
        '$baseUrl/api/office-administration/book_meeting_room/invites-meeting';

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await http.get(
      Uri.parse(meetingInvitesApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      if (responseBody['statusCode'] == 200 &&
          responseBody['results'] != null) {
        final List<dynamic> meetingData = responseBody['results'];
        final List<Map<String, dynamic>> formattedMeetingData =
        meetingData.map((item) {
          final Map<String, dynamic> meetingItem =
          Map<String, dynamic>.from(item);
          meetingItem['types'] = 'meeting';
          return meetingItem;
        }).toList();

        setState(() {
          _meetingInvites = formattedMeetingData;
        });
      } else {
        throw Exception(
            responseBody['message'] ?? 'Failed to load meeting invites');
      }
    } else {
      throw Exception('Failed to load meeting invites: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      body: Column(
        children: [
          _buildHeader(isDarkMode),
          const SizedBox(height: 10),
          _buildTabBar(),
          const SizedBox(height: 8),
          _isLoading
              ? const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
              : Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchInitialData,
              child: _isMeetingSelected
                  ? _meetingInvites.isEmpty
                  ? const Center(
                child: Text(
                  'No Meeting Invites',
                  style: TextStyle(fontSize: 16),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _meetingInvites.length,
                itemBuilder: (context, index) {
                  final item = _meetingInvites[index];
                  return _buildItemCard(
                    context,
                    item,
                    isHistory: false,
                  );
                },
              )
                  : _pendingItems.isEmpty && _historyItems.isEmpty
                  ? const Center(
                child: Text(
                  'No Approval Items',
                  style: TextStyle(fontSize: 16),
                ),
              )
                  : ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  ..._pendingItems.map((item) =>
                      _buildItemCard(
                        context,
                        item,
                        isHistory: false,
                      )),
                  ..._historyItems.map((item) =>
                      _buildItemCard(
                        context,
                        item,
                        isHistory: true,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png',
          ),
          fit: BoxFit.cover,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 60.0, left: 16.0, right: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back,
                  color: isDarkMode ? Colors.white : Colors.black),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const Dashboard()),
                      (Route<dynamic> route) => false,
                );
              },
            ),
            Text(
              'Notification',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isMeetingSelected) {
                  setState(() {
                    _isMeetingSelected = true;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  color: _isMeetingSelected ? Colors.amber : Colors.grey.shade300,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    bottomLeft: Radius.circular(20.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.meeting_room,
                        size: 24,
                        color: _isMeetingSelected
                            ? Colors.white
                            : Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Meeting',
                      style: TextStyle(
                        color: _isMeetingSelected
                            ? Colors.white
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 1),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isMeetingSelected) {
                  setState(() {
                    _isMeetingSelected = false;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  color: !_isMeetingSelected
                      ? Colors.amber
                      : Colors.grey.shade300,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20.0),
                    bottomRight: Radius.circular(20.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_rounded,
                        size: 24,
                        color: !_isMeetingSelected
                            ? Colors.white
                            : Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Approval',
                      style: TextStyle(
                        color: !_isMeetingSelected
                            ? Colors.white
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, Map<String, dynamic> item,
      {required bool isHistory}) {
    final themeNotifier =
    Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;

    try {
      String type =
      (item['types']?.toString().toLowerCase() ?? 'unknown').trim();
      if (!_knownTypes.contains(type)) {
        return const SizedBox.shrink();
      }

      String status = (item['status']?.toString() ?? 'Pending').trim();
      String employeeName =
      (item['employee_name']?.toString() ?? 'N/A').trim();

      String id = '';
      if (type == 'leave') {
        id = (item['take_leave_request_id']?.toString() ?? '').trim();
      } else if (type == 'meeting') {
        id = (item['uid']?.toString() ?? '').trim();
      } else {
        id = (item['uid']?.toString() ?? '').trim();
      }

      if (id.isEmpty) {
        return const SizedBox.shrink();
      }

      String imgName = (item['img_name']?.toString() ?? '').trim();
      String imgPath = (item['img_path']?.toString() ?? '').trim();

      String employeeImage;
      if (imgPath.isNotEmpty && imgPath.startsWith('http')) {
        employeeImage = imgPath;
      } else if (imgPath.isNotEmpty) {
        employeeImage = '$_imageBaseUrl$imgPath';
      } else if (imgName.isNotEmpty && imgName.startsWith('http')) {
        employeeImage = imgName;
      } else if (imgName.isNotEmpty) {
        employeeImage = '$_imageBaseUrl$imgName';
      } else {
        employeeImage = 'https://via.placeholder.com/150';
      }

      Color typeColor = _getTypeColor(type);
      Color statusColor = _getStatusColor(status);
      IconData typeIcon = _getIconForType(type);

      String title = '';
      String startDate = '';
      String endDate = '';
      String detailLabel = '';
      String detailValue = '';

      if (type == 'meeting') {
        title = item['title']?.toString() ?? 'No Title';
        startDate = item['from_date_time']?.toString() ?? '';
        endDate = item['to_date_time']?.toString() ?? '';
        detailLabel = 'Employee Name';
        detailValue = employeeName;
      } else if (type == 'leave') {
        int leaveTypeId = item['leave_type_id'] ?? 0;
        title = _leaveTypesMap[leaveTypeId] ?? 'Unknown Leave Type';
        startDate = item['take_leave_from']?.toString() ?? '';
        endDate = item['take_leave_to']?.toString() ?? '';
        detailLabel = 'Leave Type';
        detailValue = _leaveTypesMap[leaveTypeId] ?? 'N/A';
      } else if (type == 'car') {
        title = item['purpose']?.toString() ?? 'No Purpose';
        startDate = item['date_out']?.toString() ?? '';
        endDate = item['date_in']?.toString() ?? '';
        detailLabel = 'Requestor Name';
        detailValue =
            _removeDuplicateNames(item['requestor_name']?.toString() ?? 'N/A');
      } else {
        return const SizedBox.shrink();
      }

      return GestureDetector(
        onTap: () async {
          if (id.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid ID')),
            );
            return;
          }

          if (type == 'meeting') {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NotificationMeetingDetailsPage(
                  id: id,
                ),
              ),
            );

            if (result == true) {
              _fetchInitialData();
            }
          } else {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NotificationDetailPage(
                  id: id,
                  type: type,
                ),
              ),
            );

            if (result == true) {
              _fetchInitialData();
            }
          }
        },
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
            side: BorderSide(color: typeColor, width: 2),
          ),
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 100,
                decoration: BoxDecoration(
                  color: typeColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15.0),
                    bottomLeft: Radius.circular(15.0),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12.0, horizontal: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(typeIcon, color: typeColor, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            type[0].toUpperCase() + type.substring(1),
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'From: ${_formatDate(startDate)}',
                        style:
                        TextStyle(color: Colors.grey.shade700, fontSize: 14),
                      ),
                      Text(
                        'To: ${_formatDate(endDate)}',
                        style:
                        TextStyle(color: Colors.grey.shade700, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$detailLabel: $detailValue',
                        style:
                        TextStyle(color: Colors.grey.shade700, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Status: ',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Text(
                              status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _buildEmployeeAvatar(employeeImage),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  String _removeDuplicateNames(String name) {
    if (name.isEmpty) return 'N/A';
    RegExp regExp = RegExp(r'^(.*?)\1+$');
    Match? match = regExp.firstMatch(name);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }
    return name;
  }

  Widget _buildEmployeeAvatar(String imageUrl) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey.shade300,
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.person,
              color: Colors.grey,
              size: 24,
            );
          },
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    try {
      if (dateStr == null || dateStr.isEmpty) {
        return 'N/A';
      }

      DateTime parsedDate;

      if (RegExp(r"^\d{4}-\d{1,2}-\d{1,2}$").hasMatch(dateStr)) {
        List<String> dateParts = dateStr.split('-');
        int year = int.parse(dateParts[0]);
        int month = int.parse(dateParts[1]);
        int day = int.parse(dateParts[2]);

        parsedDate = DateTime(year, month, day);
      } else if (dateStr.contains('T')) {
        parsedDate = DateTime.parse(dateStr);
      } else {
        parsedDate = DateTime.parse(dateStr);
      }

      return DateFormat('dd-MM-yyyy').format(parsedDate);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'yes':
        return Colors.green;
      case 'reject':
      case 'rejected':
        return Colors.red;
      case 'waiting':
      case 'pending':
      case 'no':
        return Colors.amber;
      case 'processing':
      case 'branch processing':
        return Colors.blue;
      case 'branch waiting':
        return Colors.orange;
      case 'deleted':
        return Colors.red;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return Colors.green;
      case 'leave':
        return Colors.orange;
      case 'car':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return Icons.meeting_room;
      case 'leave':
        return Icons.event;
      case 'car':
        return Icons.directions_car;
      default:
        return Icons.info;
    }
  }
}
