// admin_approval_main_page.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/management/admin_approvals_view_page.dart';
import 'package:pb_hrsystem/management/admin_history_view_page.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../home/dashboard/dashboard.dart';

class ManagementApprovalsPage extends StatefulWidget {
  const ManagementApprovalsPage({super.key});

  @override
  _ManagementApprovalsPageState createState() =>
      _ManagementApprovalsPageState();
}

class _ManagementApprovalsPageState extends State<ManagementApprovalsPage> {
  bool _isApprovalSelected = true;
  List<Map<String, dynamic>> approvalItems = [];
  List<Map<String, dynamic>> historyItems = [];
  bool isLoading = true;
  String? token;

  // Cache for storing profile images URLs based on unique IDs
  final Map<String, String> _imageCache = {};

  @override
  void initState() {
    super.initState();
    fetchTokenAndData();
  }

  Future<void> fetchTokenAndData() async {
    await retrieveToken();
    if (token != null) {
      fetchData();
    } else {
      setState(() {
        isLoading = false;
      });
      _showErrorDialog(
          'Authentication Error', 'Token not found. Please log in again.');
    }
  }

  Future<void> retrieveToken() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      token = prefs.getString('token');
    } catch (e) {
      print('Error retrieving token: $e');
      _showErrorDialog('Error', 'Failed to retrieve token.');
    }
  }

  Future<void> fetchData() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';

    setState(() {
      isLoading = true;
    });

    approvalItems = [];
    historyItems = [];

    try {
      // Fetch Approvals data
      // Leave Requests - Waiting
      await fetchLeaveRequests(baseUrl, 'waiting', approvalItems);

      // Leave Requests - Processing
      await fetchLeaveRequests(baseUrl, 'processing', approvalItems);

      // Car Permits - Waiting
      await fetchCarPermits(baseUrl, 'waiting', approvalItems);

      // Car Permits - In-progress
      await fetchCarPermits(baseUrl, 'in-progress', approvalItems);

      // Meeting Room - Waitings
      await fetchMeetingRooms(baseUrl, 'waitings', approvalItems);

      // Meetings - All, filter 'Processing'
      await fetchMeetings(baseUrl, 'Processing', approvalItems);

      // Fetch History data
      // Leave Requests - All
      await fetchLeaveRequestsHistory(baseUrl, historyItems);

      // Car Permits - Approved
      await fetchCarPermitsHistory(baseUrl, historyItems);

      // Meeting Room - Approve
      await fetchMeetingRoomsHistory(baseUrl, 'approve', historyItems);

      // Meeting Room - Disapprove
      await fetchMeetingRoomsHistory(baseUrl, 'disapprove', historyItems);

      // Meetings - All, filter 'Finished'
      await fetchMeetings(baseUrl, 'Finished', historyItems);
    } catch (e) {
      print('Error fetching data: $e');
      _showErrorDialog(
          'Error', 'An unexpected error occurred while fetching data.');
    } finally {
      setState(() {
        isLoading = false;
      });
      print('Approval Items: $approvalItems'); // Debugging line
      print('History Items: $historyItems'); // Debugging line
    }
  }

  // Fetch methods (unchanged, except for adding 'profile_id' in _formatItem)
  Future<void> fetchLeaveRequests(
      String baseUrl, String status, List<Map<String, dynamic>> items) async {
    String endpoint = '';
    if (status == 'waiting') {
      endpoint = '/api/leave_requestwaiting';
    } else if (status == 'processing') {
      endpoint = '/api/leave_requestprocessing';
    } else {
      return;
    }

    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final dynamic data = json.decode(response.body);

      if (data is Map<String, dynamic>) {
        if (data.containsKey('results') && data['results'] is List) {
          List<dynamic> results = data['results'];

          for (var item in results) {
            item['types'] = 'leave';
            item['status'] = item['is_approve'] ?? 'Unknown';
            items.add(_formatItem(item));
          }
        } else {
          print('Expected "results" field to be a list but got: $data');
        }
      } else {
        print('Unexpected data format: $data');
      }
    } else {
      _showErrorDialog(
          'Error', 'Failed to fetch leave requests: ${response.reasonPhrase}');
    }
  }

  Future<void> fetchCarPermits(
      String baseUrl, String status, List<Map<String, dynamic>> items) async {
    String endpoint = '';
    if (status == 'waiting') {
      endpoint = '/api/office-administration/car_permits/waiting';
    } else if (status == 'in-progress') {
      endpoint = '/api/office-administration/car_permits/in-progress';
    } else {
      return;
    }

    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final dynamic data = json.decode(response.body);

      if (data is Map<String, dynamic>) {
        if (data.containsKey('results') && data['results'] is List) {
          List<dynamic> results = data['results'];

          for (var item in results) {
            item['types'] = 'car';
            item['status'] = item['status'] ?? 'Unknown';
            items.add(_formatItem(item));
          }
        } else {
          print('Expected "results" field to be a list but got: $data');
        }
      } else {
        print('Unexpected data format: $data');
      }
    } else {
      _showErrorDialog(
          'Error', 'Failed to fetch car permits: ${response.reasonPhrase}');
    }
  }

  Future<void> fetchMeetingRooms(
      String baseUrl, String status, List<Map<String, dynamic>> items) async {
    String endpoint = '';
    if (status == 'waitings') {
      endpoint = '/api/office-administration/book_meeting_room/waitings';
    } else if (status == 'approve') {
      endpoint = '/api/office-administration/book_meeting_room/approve';
    } else if (status == 'disapprove') {
      endpoint = '/api/office-administration/book_meeting_room/disapprove';
    } else {
      return;
    }

    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final dynamic data = json.decode(response.body);

      if (data is Map<String, dynamic>) {
        if (data.containsKey('results') && data['results'] is List) {
          List<dynamic> results = data['results'];

          for (var item in results) {
            item['types'] = 'meeting_room';
            item['status'] = item['status'] ?? 'Unknown';
            items.add(_formatItem(item));
          }
        } else {
          print('Expected "results" field to be a list but got: $data');
        }
      } else {
        print('Unexpected data format: $data');
      }
    } else {
      _showErrorDialog('Error',
          'Failed to fetch meeting rooms: ${response.reasonPhrase}');
    }
  }

  Future<void> fetchMeetings(
      String baseUrl, String statusFilter, List<Map<String, dynamic>> items) async {
    String endpoint = '/api/work-tracking/meeting/get-all-meeting';

    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final dynamic data = json.decode(response.body);

      if (data is Map<String, dynamic>) {
        if (data.containsKey('results') && data['results'] is List) {
          List<dynamic> results = data['results'];

          for (var item in results) {
            if (item['s_name'] == statusFilter) {
              item['types'] = 'meeting';
              item['status'] = item['s_name'] ?? 'Unknown';
              items.add(_formatItem(item));
            }
          }
        } else {
          print('Expected "results" field to be a list but got: $data');
        }
      } else {
        print('Unexpected data format: $data');
      }
    } else {
      _showErrorDialog(
          'Error', 'Failed to fetch meetings: ${response.reasonPhrase}');
    }
  }

  Future<void> fetchLeaveRequestsHistory(
      String baseUrl, List<Map<String, dynamic>> items) async {
    String endpoint = '/api/leave_requests/all';

    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final dynamic data = json.decode(response.body);

      if (data is Map<String, dynamic>) {
        if (data.containsKey('results') && data['results'] is List) {
          List<dynamic> results = data['results'];

          for (var item in results) {
            String status = item['is_approve'] ?? 'Unknown';
            if (status == 'Approved' || status == 'Rejected' || status == 'Cancel') {
              item['types'] = 'leave';
              item['status'] = status;
              items.add(_formatItem(item));
            }
          }
        } else {
          print('Expected "results" field to be a list but got: $data');
        }
      } else {
        print('Unexpected data format: $data');
      }
    } else {
      _showErrorDialog('Error',
          'Failed to fetch leave requests history: ${response.reasonPhrase}');
    }
  }

  Future<void> fetchCarPermitsHistory(
      String baseUrl, List<Map<String, dynamic>> items) async {
    String endpoint = '/api/office-administration/car_permits/approved';

    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final dynamic data = json.decode(response.body);

      if (data is Map<String, dynamic>) {
        if (data.containsKey('results') && data['results'] is List) {
          List<dynamic> results = data['results'];

          for (var item in results) {
            item['types'] = 'car';
            item['status'] = item['status'] ?? 'Unknown';
            items.add(_formatItem(item));
          }
        } else {
          print('Expected "results" field to be a list but got: $data');
        }
      } else {
        print('Unexpected data format: $data');
      }
    } else {
      _showErrorDialog('Error',
          'Failed to fetch car permits history: ${response.reasonPhrase}');
    }
  }

  Future<void> fetchMeetingRoomsHistory(
      String baseUrl, String status, List<Map<String, dynamic>> items) async {
    String endpoint = '';
    if (status == 'approve') {
      endpoint = '/api/office-administration/book_meeting_room/approve';
    } else if (status == 'disapprove') {
      endpoint = '/api/office-administration/book_meeting_room/disapprove';
    } else {
      return;
    }

    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final dynamic data = json.decode(response.body);

      if (data is Map<String, dynamic>) {
        if (data.containsKey('results') && data['results'] is List) {
          List<dynamic> results = data['results'];

          for (var item in results) {
            item['types'] = 'meeting_room';
            item['status'] = item['status'] ?? 'Unknown';
            items.add(_formatItem(item));
          }
        } else {
          print('Expected "results" field to be a list but got: $data');
        }
      } else {
        print('Unexpected data format: $data');
      }
    } else {
      _showErrorDialog('Error',
          'Failed to fetch meeting rooms history: ${response.reasonPhrase}');
    }
  }

  // Show error dialog
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Optionally, navigate back or take other actions
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getStatusForType(Map<String, dynamic> item) {
    String types = item['types'] ?? 'Unknown';
    String status = '';

    if (types == 'meeting') {
      status = item['s_name'] ?? 'Unknown';
    } else if (types == 'leave') {
      status = item['is_approve'] ?? 'Unknown';
    } else if (types == 'car' || types == 'meeting_room') {
      status = item['status'] ?? 'Unknown';
    } else {
      status = 'Unknown';
    }

    return status;
  }

  Map<String, dynamic> _formatItem(Map<String, dynamic> item) {
    String types = item['types'] ?? 'Unknown';

    String status = _getStatusForType(item);

    Map<String, dynamic> formattedItem = {
      'types': types,
      'status': status,
      'statusColor': _getStatusColor(status),
      'icon': _getStatusIcon(status), // IconData
      'iconColor': _getStatusColor(status),
      'img_name': item['img_name'] ??
          'https://via.placeholder.com/150', // Default image if not provided
    };

    // Determine profile_id based on type
    String? profileId;
    if (types == 'leave' || types == 'car') {
      profileId = item['requestor_id'] ?? item['employee_id'];
    } else if (types == 'meeting_room') {
      profileId = item['employee_id'];
    } else if (types == 'meeting') {
      profileId = item['create_by_id'];
    }

    formattedItem['profile_id'] = profileId ?? '';

    if (types == 'meeting') {
      formattedItem['title'] = item['title'] ?? 'No Title';
      formattedItem['startDate'] = item['from_date'] ?? 'N/A';
      formattedItem['endDate'] = item['to_date'] ?? 'N/A';
      formattedItem['room'] = item['room_name'] ?? 'No Room Info';
      formattedItem['details'] = item['description'] ?? 'No Details Provided';
      formattedItem['employee_name'] = item['create_by'] ?? 'N/A';
      formattedItem['uid'] = item['meeting_id'] ?? ''; // Unique ID for meeting
      formattedItem['line_manager_img'] = item['line_manager_img'] ??
          'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
      formattedItem['hr_img'] = item['hr_img'] ??
          'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
    } else if (types == 'leave') {
      formattedItem['title'] = item['take_leave_reason'] ?? 'No Title';

      formattedItem['startDate'] =
      (item['take_leave_from'] != null && item['take_leave_from'].isNotEmpty)
          ? item['take_leave_from']
          : 'N/A';

      formattedItem['endDate'] =
      (item['take_leave_to'] != null && item['take_leave_to'].isNotEmpty)
          ? item['take_leave_to']
          : 'N/A';

      formattedItem['room'] = item['room_name'] ?? 'No Place Info';
      formattedItem['details'] = item['take_leave_reason'] ?? 'No Details Provided';
      formattedItem['employee_name'] = item['requestor_name'] ?? 'N/A';
      formattedItem['take_leave_request_id'] =
          item['take_leave_request_id']?.toString() ?? ''; // ID for leave
      formattedItem['line_manager_img'] = item['line_manager_img'] ??
          'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
      formattedItem['hr_img'] = item['hr_img'] ??
          'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
      formattedItem['img_name'] = item['img_path'] ?? 'https://via.placeholder.com/150';
      formattedItem['created_at'] = item['created_at'] ?? 'N/A';
    } else if (types == 'car') {
      formattedItem['title'] = item['purpose'] ?? 'No Title';

      formattedItem['startDate'] =
      (item['date_out'] != null && item['date_out'].isNotEmpty)
          ? item['date_out']
          : 'N/A';

      formattedItem['endDate'] =
      (item['date_in'] != null && item['date_in'].isNotEmpty)
          ? item['date_in']
          : 'N/A';

      formattedItem['time'] =
      (item['time_out'] != null && item['time_out'].isNotEmpty)
          ? item['time_out']
          : 'N/A';

      formattedItem['time_end'] =
      (item['time_in'] != null && item['time_in'].isNotEmpty)
          ? item['time_in']
          : 'N/A';

      formattedItem['room'] = item['place'] ?? 'No Place Info';
      formattedItem['details'] = item['purpose'] ?? 'No Details Provided';
      formattedItem['employee_name'] = item['requestor_name'] ?? 'N/A';
      formattedItem['car_permit_id'] =
          item['uid']?.toString() ?? ''; // ID for car permit
      formattedItem['line_manager_img'] = item['line_manager_img'] ??
          'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
      formattedItem['hr_img'] = item['hr_img'] ??
          'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
    } else if (types == 'meeting_room') {
      formattedItem['title'] = item['title'] ?? 'No Title';
      formattedItem['startDate'] = item['from_date_time'] ?? 'N/A';
      formattedItem['endDate'] = item['to_date_time'] ?? 'N/A';
      formattedItem['room'] = item['room_name'] ?? 'No Room Info';
      formattedItem['details'] = item['remark'] ?? 'No Details Provided';
      formattedItem['employee_name'] = item['employee_name'] ?? 'N/A';
      formattedItem['uid'] = item['uid'] ?? ''; // Unique ID for meeting room booking
      formattedItem['line_manager_img'] = item['line_manager_img'] ??
          'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
      formattedItem['hr_img'] = item['hr_img'] ??
          'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
    } else {
      // Default processing
      formattedItem['title'] = 'Unknown Type';
    }

    return formattedItem;
  }

  // Helper function to get display name
  String _getDisplayName(String type) {
    if (type.toLowerCase() == 'meeting_room') {
      return 'Meeting Room';
    } else {
      return type[0].toUpperCase() + type.substring(1);
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return Colors.green;
      case 'meeting_room':
        return Colors.purple; // Different color for Meeting Room
      case 'leave':
        return Colors.orange;
      case 'car':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'waiting':
      case 'branch waiting':
      case 'pending':
        return Colors.amber;
      case 'approved':
      case 'approve':
      case 'finished':
        return Colors.green;
      case 'rejected':
      case 'disapproved':
      case 'cancel':
        return Colors.red;
      case 'processing':
        return Colors.blue;
      case 'unknown':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'waiting':
      case 'branch waiting':
      case 'pending':
        return Icons.hourglass_empty;
      case 'approved':
      case 'approve':
      case 'finished':
        return Icons.check_circle;
      case 'rejected':
      case 'disapproved':
      case 'cancel':
        return Icons.cancel;
      case 'processing':
        return Icons.timelapse;
      case 'unknown':
        return Icons.help_outline;
      default:
        return Icons.info;
    }
  }

  Widget getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return Image.asset('assets/calendar.png', width: 40, height: 40);
      case 'meeting_room':
        return Image.asset('assets/meeting_room.png', width: 40, height: 40);
      case 'leave':
        return Image.asset('assets/leave_calendar.png',
            width: 40, height: 40);
      case 'car':
        return Image.asset('assets/car.png', width: 40, height: 40);
      default:
        return const Icon(Icons.info_outline, size: 40, color: Colors.grey);
    }
  }

  void _openApprovalDetail(Map<String, dynamic> item) {
    String type = item['types'];
    String? id;

    switch (type) {
      case 'meeting':
        id = item['uid'];
        break;
      case 'meeting_room':
        id = item['uid'];
        break;
      case 'leave':
        id = item['take_leave_request_id'];
        break;
      case 'car':
        id = item['car_permit_id'];
        break;
      default:
        id = null;
    }

    if (id == null || id.isEmpty) {
      _showErrorDialog(
          'Invalid Data', 'The selected item has invalid or missing ID.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminApprovalsViewPage(
          item: item,
          type: type,
          id: id as String,
        ),
      ),
    );
  }

  void _openHistoryDetail(Map<String, dynamic> item) {
    // Define 'type' and 'id' similar to _openApprovalDetail
    String type = item['types'];
    String? id;

    switch (type) {
      case 'meeting':
        id = item['uid'] ?? item['meeting_id']; // Ensure consistency with _formatItem
        break;
      case 'meeting_room':
        id = item['uid'];
        break;
      case 'leave':
        id = item['take_leave_request_id'];
        break;
      case 'car':
        id = item['car_permit_id'];
        break;
      default:
        id = null;
    }

    if (id == null || id.isEmpty) {
      _showErrorDialog(
          'Invalid Data', 'The selected item has invalid or missing ID.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminHistoryViewPage(
          item: item,
          type: type,
          id: id as String,
        ),
      ),
    );
  }

  String formatDate(String? dateStr) {
    try {
      if (dateStr == null || dateStr.isEmpty) {
        return 'N/A';
      }

      // Handle different date formats based on type
      DateTime parsedDate;

      // Attempt to parse the date string
      try {
        parsedDate = DateTime.parse(dateStr);
      } catch (_) {
        // If parsing fails, return the original string
        return dateStr;
      }

      return DateFormat('dd-MM-yyyy, HH:mm').format(parsedDate);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: fetchData,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.16,
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('assets/ready_bg.png'),
                  fit: BoxFit.cover,
                ),
                color: Colors.amber[700],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 16.0, right: 16.0, top: 60.0), // Adjust top padding here
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          size: 30, color: Colors.black),
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const Dashboard()),
                              (Route<dynamic> route) => false,
                        );
                      },
                    ),
                    const Text(
                      'Approvals',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 30), // This helps balance the layout
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // TabBar Section for Approval and History tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isApprovalSelected = true;
                        });
                      },
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(vertical: 10.0),
                        decoration: BoxDecoration(
                          color: _isApprovalSelected
                              ? Colors.amber
                              : Colors.grey[300],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20.0),
                            bottomLeft: Radius.circular(20.0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.grid_view_rounded,
                                size: 24,
                                color: _isApprovalSelected
                                    ? Colors.white
                                    : Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Approval',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isApprovalSelected
                                    ? Colors.white
                                    : Colors.grey[600],
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
                        setState(() {
                          _isApprovalSelected = false;
                        });
                      },
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(vertical: 10.0),
                        decoration: BoxDecoration(
                          color: !_isApprovalSelected
                              ? Colors.amber
                              : Colors.grey[300],
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
                                color: !_isApprovalSelected
                                    ? Colors.white
                                    : Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'History',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: !_isApprovalSelected
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ListView section for displaying approval items
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                padding: const EdgeInsets.all(16.0),
                children: _isApprovalSelected
                    ? approvalItems
                    .map((item) => _buildCard(item))
                    .toList()
                    : historyItems
                    .map((item) => _buildCard(item))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final String type = item['types'] ?? 'unknown';
    final String title = item['title'] ?? 'No Title';
    final String status = item['status'] ?? 'Pending';
    final String employeeName = item['employee_name'] ?? 'N/A';
    // Determine which ID to use based on type
    final String profileId = item['profile_id'] ?? '';
    // Use cached image URL if available
    final String cachedImageUrl = _imageCache[profileId] ??
        'https://via.placeholder.com/150'; // Placeholder if not fetched yet

    final Color typeColor = _getTypeColor(type);
    final Color statusColor = _getStatusColor(status);

    final String startDate = item['startDate'] ?? 'N/A';
    final String endDate = item['endDate'] ?? 'N/A';

    String detailLabel = '';
    String detailValue = '';

    if (type == 'meeting' || type == 'meeting_room') {
      detailLabel = 'Room';
      detailValue = item['room'] ?? 'No Room Info';
    } else if (type == 'leave') {
      detailLabel = 'Created at';
      detailValue = item['created_at'] ?? 'N/A';
    } else if (type == 'car') {
      detailLabel = 'Place';
      detailValue = item['room'] ?? 'N/A';
    }

    return GestureDetector(
      onTap: () {
        if (_isApprovalSelected) {
          _openApprovalDetail(item);
        } else {
          _openHistoryDetail(item);
        }
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0), // Reduced radius for better look
          side: BorderSide(color: typeColor, width: 2),
        ),
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 80,
                decoration: BoxDecoration(
                  color: typeColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10.0),
                    bottomLeft: Radius.circular(10.0),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Use getIconForType to display type-specific icon
              getIconForType(type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type and Title
                    Row(
                      children: [
                        Text(
                          _getDisplayName(type),
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
                        color:
                        Provider.of<ThemeNotifier>(context).isDarkMode
                            ? Colors.white
                            : Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Date Range
                    Text(
                      'From: ${formatDate(startDate)}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'To: ${formatDate(endDate)}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Detail Label and Value
                    Text(
                      '$detailLabel: $detailValue',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Status
                    Row(
                      children: [
                        Text(
                          'Status: ',
                          style: TextStyle(
                            color:
                            Provider.of<ThemeNotifier>(context).isDarkMode
                                ? Colors.white
                                : Colors.black,
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
              const SizedBox(width: 12),
              // Profile Image with FutureBuilder
              FutureBuilder<String>(
                future: getImageUrl(profileId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircleAvatar(
                      backgroundImage:
                      NetworkImage('https://via.placeholder.com/150'),
                      radius: 25,
                    );
                  } else if (snapshot.hasError) {
                    return const CircleAvatar(
                      backgroundImage:
                      NetworkImage('https://via.placeholder.com/150'),
                      radius: 25,
                    );
                  } else {
                    return CircleAvatar(
                      backgroundImage: NetworkImage(snapshot.data!),
                      radius: 25,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Method to fetch image URL based on profile ID
  Future<String> getImageUrl(String id) async {
    if (id.isEmpty) {
      return 'https://via.placeholder.com/150';
    }

    // Check if the image URL is already cached
    if (_imageCache.containsKey(id)) {
      return _imageCache[id]!;
    }

    // Fetch from API
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    final String endpoint = '/api/profile/$id';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);

        if (data is Map<String, dynamic> &&
            data.containsKey('results') &&
            data['results'] is Map<String, dynamic>) {
          final String imageUrl = data['results']['images'] ??
              'https://via.placeholder.com/150';

          // Cache the image URL
          _imageCache[id] = imageUrl;

          return imageUrl;
        } else {
          print('Unexpected data format when fetching image: $data');
          return 'https://via.placeholder.com/150';
        }
      } else {
        print('Failed to fetch image for ID $id: ${response.statusCode}');
        return 'https://via.placeholder.com/150';
      }
    } catch (e) {
      print('Error fetching image for ID $id: $e');
      return 'https://via.placeholder.com/150';
    }
  }
}
