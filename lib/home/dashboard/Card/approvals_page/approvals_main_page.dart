import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approvals_page/approvals_details_page.dart';
import 'package:pb_hrsystem/home/dashboard/history/history_details_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';

class ApprovalsMainPage extends StatefulWidget {
  const ApprovalsMainPage({super.key});

  @override
  _ApprovalsMainPageState createState() => _ApprovalsMainPageState();
}

class _ApprovalsMainPageState extends State<ApprovalsMainPage> {
  bool _isPendingSelected = true;
  List<Map<String, dynamic>> _pendingItems = [];
  List<Map<String, dynamic>> _historyItems = [];
  Map<int, String> _leaveTypes = {};
  bool _isLoading = true;

  String formatDate(String? dateStr) {
    try {
      if (dateStr == null || dateStr.isEmpty) {
        return 'N/A';
      }

      DateTime parsedDate;

      // Handle the case where the date is in 'YYYY-MM-DD' or 'YYYY-M-D' format
      if (RegExp(r"^\d{4}-\d{1,2}-\d{1,2}$").hasMatch(dateStr)) {
        List<String> dateParts = dateStr.split('-');
        int year = int.parse(dateParts[0]);
        int month = int.parse(dateParts[1]);
        int day = int.parse(dateParts[2]);

        parsedDate = DateTime(year, month, day);
      }
      // Handle ISO 8601 formatted dates like '2024-04-25T00:00:00.000Z'
      else if (dateStr.contains('T')) {
        parsedDate = DateTime.parse(dateStr);
      }
      // Default fallback for unsupported formats
      else {
        parsedDate = DateTime.parse(dateStr);
      }

      // Format the date to 'dd-MM-yyyy' or modify as needed
      return DateFormat('dd-MM-yyyy').format(parsedDate);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchHistoryData();
  }

  Future<void> _fetchHistoryData() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String pendingApiUrl = '$baseUrl/api/app/tasks/approvals/pending';
    const String historyApiUrl = '$baseUrl/api/app/tasks/approvals/history';
    const String leaveTypesUrl = '$baseUrl/api/leave-types';

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('User not authenticated');
      }

      // Fetch Leave Types
      final leaveTypesResponse = await http.get(
        Uri.parse(leaveTypesUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (leaveTypesResponse.statusCode == 200) {
        final leaveTypesBody = jsonDecode(leaveTypesResponse.body);
        if (leaveTypesBody['statusCode'] == 200) {
          final List<dynamic> leaveTypesData = leaveTypesBody['results'];
          _leaveTypes = {
            for (var lt in leaveTypesData) lt['leave_type_id']: lt['name']
          };
        } else {
          throw Exception(
              leaveTypesBody['message'] ?? 'Failed to load leave types');
        }
      } else {
        throw Exception(
            'Failed to load leave types: ${leaveTypesResponse.statusCode}');
      }

      // Fetch Pending Items
      final pendingResponse = await http.get(
        Uri.parse(pendingApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Fetch History Items
      final historyResponse = await http.get(
        Uri.parse(historyApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final List<Map<String, dynamic>> tempPendingItems = [];
      final List<Map<String, dynamic>> tempHistoryItems = [];

      // Process Pending Response
      if (pendingResponse.statusCode == 200) {
        final responseBody = jsonDecode(pendingResponse.body);
        if (responseBody['statusCode'] == 200 && responseBody['results'] != null) {
          final List<dynamic> pendingData = responseBody['results'];
          tempPendingItems.addAll(
              pendingData.where((item) => item != null).map((item) => _formatItem(item as Map<String, dynamic>)));
        } else {
          throw Exception(
              responseBody['message'] ?? 'Failed to load pending data');
        }
      } else {
        throw Exception(
            'Failed to load pending data: ${pendingResponse.statusCode}');
      }

// Process History Response
      if (historyResponse.statusCode == 200) {
        final responseBody = jsonDecode(historyResponse.body);
        if (responseBody['statusCode'] == 200 && responseBody['results'] != null) {
          final List<dynamic> historyData = responseBody['results'];
          tempHistoryItems.addAll(
              historyData.where((item) => item != null).map((item) => _formatItem(item as Map<String, dynamic>)));
        } else {
          throw Exception(
              responseBody['message'] ?? 'Failed to load history data');
        }
      } else {
        throw Exception(
            'Failed to load history data: ${historyResponse.statusCode}');
      }

      // Update State
      setState(() {
        _pendingItems = tempPendingItems;
        _historyItems = tempHistoryItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
    }
  }

  Map<String, dynamic> _formatItem(Map<String, dynamic> item) {
    String type = item['types']?.toLowerCase() ?? 'unknown';
    String status = _getItemStatus(type, item);

    Map<String, dynamic> formattedItem = {
      'type': type,
      'status': status,
      'statusColor': _getStatusColor(status),
      'icon': _getIconForType(type),
      'iconColor': _getTypeColor(type),
      'timestamp': DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
      'img_name': item['img_name'] ?? 'https://via.placeholder.com/150', // Placeholder image
      'img_path': item['img_path'] ?? '', // Add img_path if available
    };

    // Add type-specific fields and ensure 'id' is consistent
    switch (type) {
      case 'meeting':
        formattedItem.addAll({
          'title': item['title'] ?? 'No Title',  // Use title for meeting
          'startDate': item['from_date_time'] ?? '',  // Correct field for start date
          'endDate': item['to_date_time'] ?? '',  // Correct field for end date
          'room': item['room_name'] ?? 'No Room Info',  // Room info
          'employee_name': item['employee_name'] ?? 'N/A',  // Employee name
          'id': item['uid']?.toString() ?? '',  // Use uid for the ID
          'remark': item['remark'] ?? '',  // Additional remark
        });
        break;

      case 'leave':
        int leaveTypeId = item['leave_type_id'] ?? 0;
        String leaveTypeName = _leaveTypes[leaveTypeId] ??
            item['leave_type_name'] ?? 'Unknown';  // Fallback for leave type name
        formattedItem.addAll({
          'title': item['name'] ?? item['leave_type_name'] ?? 'No Title',  // Check both fields for title
          'startDate': item['take_leave_from'] ?? '',  // Correct field for start date
          'endDate': item['take_leave_to'] ?? '',  // Correct field for end date
          'leave_type': leaveTypeName,  // Leave type name
          'employee_name': item['requestor_name'] ?? 'N/A',  // Employee name
          'id': item['take_leave_request_id']?.toString() ?? '',  // Leave request ID
          'status': item['is_approve']?.toString().toLowerCase() ?? 'waiting',  // Approval status
        });
        break;

      case 'car':
        formattedItem.addAll({
          'title': item['purpose'] ?? 'No Purpose', // Fetch the purpose field for car
          'startDate': formatDate(item['date_out']), // Correct field for date out
          'endDate': formatDate(item['date_in']), // Correct field for date in
          'employee_name': item['requestor_name'] ?? 'N/A', // Requestor name field
          'id': item['uid']?.toString() ?? '', // Car request ID field
          'status': _getItemStatus(type, item),
        });
        break;

      default:
      // Handle unknown types if necessary
        break;
    }

    return formattedItem;
  }

  String _getItemStatus(String type, Map<String, dynamic> item) {
    if (type == 'leave') {
      return (item['is_approve'] ?? 'waiting').toString().toLowerCase();
    } else if (type == 'car') {
      // Convert status to lowercase for consistent comparison
      String status = (item['status']?.toString() ?? 'waiting').toLowerCase();
      if (status == 'branch processing') {
        return 'branch processing';
      } else if (status == 'branch waiting') {
        return 'branch waiting';
      } else {
        return status;
      }
    } else {
      return (item['status'] ?? 'waiting').toString().toLowerCase();
    }
  }

  /// Return appropriate color based on the status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'disapproved':
      case 'rejected':
      case 'cancel':
        return Colors.red;
      case 'pending':
      case 'waiting':
        return Colors.amber;
      case 'processing':
        return Colors.blue;
      case 'branch waiting':
        return Colors.orange;  // Special color for branch waiting
      case 'branch processing':
        return Colors.blue;  // Special color for branch processing
      case 'deleted':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Returns color based on type
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

  /// Returns icon based on type
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
              onRefresh: _fetchHistoryData, // This function will refresh data
              child: _isPendingSelected
                  ? _pendingItems.isEmpty
                  ? const Center(
                child: Text(
                  'No Pending Items',
                  style: TextStyle(fontSize: 16),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _pendingItems.length,
                itemBuilder: (context, index) {
                  final item = _pendingItems[index];
                  return _buildHistoryCard(
                    context,
                    item,
                    isHistory: false,
                  );
                },
              )
                  : _historyItems.isEmpty
                  ? const Center(
                child: Text(
                  'No History Items',
                  style: TextStyle(fontSize: 16),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _historyItems.length,
                itemBuilder: (context, index) {
                  final item = _historyItems[index];
                  return _buildHistoryCard(
                    context,
                    item,
                    isHistory: true,
                  );
                },
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
              icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const Dashboard()),
                      (Route<dynamic> route) => false,
                );
              },
            ),
            Text(
              'Approvals',
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
                setState(() {
                  _isPendingSelected = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  color: _isPendingSelected ? Colors.amber : Colors.grey[300],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    bottomLeft: Radius.circular(20.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hourglass_empty_rounded, size: 24, color: _isPendingSelected ? Colors.white : Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Approvals',
                      style: TextStyle(
                        color: _isPendingSelected ? Colors.white : Colors.grey[600],
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
                setState(() {
                  _isPendingSelected = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  color: !_isPendingSelected ? Colors.amber : Colors.grey[300],
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20.0),
                    bottomRight: Radius.circular(20.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_rounded, size: 24, color: !_isPendingSelected ? Colors.white : Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'History',
                      style: TextStyle(
                        color: !_isPendingSelected ? Colors.white : Colors.grey[600],
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

  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> item, {required bool isHistory}) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final String type = item['type'] ?? 'unknown';

    String title = item['title'] ?? 'No Title';
    String status = item['status'] ?? 'Pending';
    String employeeName = item['employee_name'] ?? 'N/A';
    String employeeImage = item['img_path'].isNotEmpty
        ? item['img_path']
        : item['img_name'] ?? 'https://via.placeholder.com/150';
    Color typeColor = _getTypeColor(type);
    Color statusColor = _getStatusColor(status);

    String startDate = item['startDate'] ?? '';
    String endDate = item['endDate'] ?? '';

    String detailLabel = '';
    String detailValue = '';

    switch (type) {
      case 'meeting':
        detailLabel = 'Employee Name';
        detailValue = item['employee_name'] ?? 'N/A';
        break;
      case 'leave':
        detailLabel = 'Type';
        detailValue = item['leave_type'] ?? 'N/A';
        break;
      case 'car':
        detailLabel = 'Requestor Name';
        detailValue = item['employee_name'] ?? 'N/A';
        break;
      default:
        detailLabel = 'Detail';
        detailValue = 'N/A';
    }

    String formatDate(String? dateStr) {
      try {
        if (dateStr == null || dateStr.isEmpty) {
          return 'N/A';
        }

        DateTime parsedDate;

        // Handle the case where the date is in 'YYYY-MM-DD' or 'YYYY-M-D' format
        if (RegExp(r"^\d{4}-\d{1,2}-\d{1,2}$").hasMatch(dateStr)) {
          List<String> dateParts = dateStr.split('-');
          int year = int.parse(dateParts[0]);
          int month = int.parse(dateParts[1]);
          int day = int.parse(dateParts[2]);

          parsedDate = DateTime(year, month, day);
        }
        // Handle ISO 8601 formatted dates like '2024-04-25T00:00:00.000Z'
        else if (dateStr.contains('T')) {
          parsedDate = DateTime.parse(dateStr);
        }
        // Default fallback for unsupported formats
        else {
          parsedDate = DateTime.parse(dateStr);
        }

        // Format the date to 'dd-MM-yyyy' or modify as needed
        return DateFormat('dd-MM-yyyy').format(parsedDate);
      } catch (e) {
        return 'Invalid Date';
      }
    }

    return GestureDetector(
      onTap: () {
        String types = type;
        String id = item['id'] ?? '';
        String status = item['status'] ?? 'pending';

        if (id.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid ID')),
          );
          return;
        }

        // Navigate to DetailsPage with required parameters
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ApprovalsDetailsPage(
              types: types,
              id: id,
              status: status,
            ),
          ),
        );
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
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(item['icon'], color: typeColor, size: 24),
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
                      'From: ${formatDate(startDate)}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                    Text(
                      'To: ${formatDate(endDate)}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$detailLabel: $detailValue',
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Text(
                            status[0].toUpperCase() + status.substring(1),
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
              child: CircleAvatar(
                backgroundImage: NetworkImage(employeeImage),
                radius: 24,
                onBackgroundImageError: (_, __) {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
