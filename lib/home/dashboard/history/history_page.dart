// history_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/dashboard/history/history_details_page.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pb_hrsystem/theme/theme.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _isPendingSelected = true;
  List<Map<String, dynamic>> _pendingItems = [];
  List<Map<String, dynamic>> _historyItems = [];
  Map<int, String> _leaveTypes = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistoryData();
  }

  /// Fetches leave types, pending items, and history items from the API
  Future<void> _fetchHistoryData() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String pendingApiUrl = '$baseUrl/api/app/users/history/pending';
    const String historyApiUrl = '$baseUrl/api/app/users/history';
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

      // Initialize temporary lists
      final List<Map<String, dynamic>> tempPendingItems = [];
      final List<Map<String, dynamic>> tempHistoryItems = [];

      // Process Pending Response
      if (pendingResponse.statusCode == 200) {
        final responseBody = jsonDecode(pendingResponse.body);
        if (responseBody['statusCode'] == 200) {
          final List<dynamic> pendingData = responseBody['results'];
          tempPendingItems.addAll(
              pendingData.map((item) => _formatItem(item as Map<String, dynamic>)));
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
        if (responseBody['statusCode'] == 200) {
          final List<dynamic> historyData = responseBody['results'];
          tempHistoryItems.addAll(
              historyData.map((item) => _formatItem(item as Map<String, dynamic>)));
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

  /// Formats each item based on its type
  Map<String, dynamic> _formatItem(Map<String, dynamic> item) {
    String type = item['types']?.toLowerCase() ?? 'unknown';
    Map<String, dynamic> formattedItem = {
      'type': type,
      'status': _getItemStatus(type, item),
      'statusColor': _getStatusColor(_getItemStatus(type, item)),
      'icon': _getIconForType(type),
      'iconColor': _getTypeColor(type),
      'timestamp':
      DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
      'img_name': item['img_name'] ??
          'https://via.placeholder.com/150', // Placeholder image
      'img_path': item['img_path'] ?? '', // Add img_path if available
    };

    // Add type-specific fields and ensure 'id' is consistent
    switch (type) {
      case 'meeting':
        formattedItem.addAll({
          'title': item['title'] ?? 'No Title',
          'startDate': item['from_date_time'] ?? '',
          'endDate': item['to_date_time'] ?? '',
          'room': item['room_name'] ?? 'No Room Info',
          'employee_name': item['employee_name'] ?? 'N/A',
          'id': item['uid']?.toString() ?? '',
          'status': _getItemStatus(type, item),
          'remark': item['remark'] ?? '',
        });
        break;
      case 'leave':
        int leaveTypeId = item['leave_type_id'] ?? 0;
        String leaveTypeName = _leaveTypes[leaveTypeId] ?? 'Unknown';
        formattedItem.addAll({
          'title': item['name'] ?? 'No Title',
          'startDate': item['take_leave_from'] ?? '',
          'endDate': item['take_leave_to'] ?? '',
          'leave_type': leaveTypeName,
          'employee_name': item['requestor_name'] ?? 'N/A',
          'id': item['take_leave_request_id']?.toString() ?? '',
          'status': _getItemStatus(type, item),
        });
        break;
      case 'car':
        formattedItem.addAll({
          'title': item['purpose'] ?? 'No Purpose',
          'startDate': item['date_out'] ?? '',
          'endDate': item['date_in'] ?? '',
          'employee_name': item['requestor_name'] ?? 'N/A',
          'id': item['uid']?.toString() ?? '',
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
    return (item['status'] ?? 'waiting').toString().toLowerCase();
  }

  /// Returns color based on status
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
      case 'branch waiting':
        return Colors.amber;
      case 'processing':
        return Colors.blue;
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
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      body: Column(
        children: [
          _buildHeader(isDarkMode, screenSize),
          SizedBox(height: screenSize.height * 0.005),
          _buildTabBar(screenSize),
          SizedBox(height: screenSize.height * 0.005),
          _isLoading
              ? const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
              : Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchHistoryData, // This function will refresh data
              child: _isPendingSelected
                  ? _pendingItems.isEmpty
                  ? Center(
                child: Text(
                  'No Pending Items',
                  style: TextStyle(
                    fontSize: screenSize.width * 0.04,
                  ),
                ),
              )
                  : ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: screenSize.width * 0.04,
                  vertical: screenSize.height * 0.008,
                ),
                itemCount: _pendingItems.length,
                itemBuilder: (context, index) {
                  final item = _pendingItems[index];
                  return _buildHistoryCard(
                    context,
                    item,
                    isHistory: false,
                    screenSize: screenSize,
                  );
                },
              )
                  : _historyItems.isEmpty
                  ? Center(
                child: Text(
                  'No History Items',
                  style: TextStyle(
                    fontSize: screenSize.width * 0.04,
                  ),
                ),
              )
                  : ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: screenSize.width * 0.04,
                  vertical: screenSize.height * 0.008,
                ),
                itemCount: _historyItems.length,
                itemBuilder: (context, index) {
                  final item = _historyItems[index];
                  return _buildHistoryCard(
                    context,
                    item,
                    isHistory: true,
                    screenSize: screenSize,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the header section with background image and title
  Widget _buildHeader(bool isDarkMode, Size screenSize) {
    return Container(
      height: screenSize.height * 0.2, // 20% of screen height
      width: double.infinity,
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
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.04,
            vertical: screenSize.height * 0.015,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: screenSize.width * 0.07,
                ),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const Dashboard()),
                        (Route<dynamic> route) => false,
                  );
                },
              ),
              Text(
                'My History',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: screenSize.width * 0.06,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: screenSize.width * 0.12), // Placeholder for alignment
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the tab bar for toggling between Pending and History
  Widget _buildTabBar(Size screenSize) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.04,
        vertical: screenSize.height * 0.003,
      ),
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
                padding: EdgeInsets.symmetric(
                  vertical: screenSize.height * 0.012,
                ),
                decoration: BoxDecoration(
                  color: _isPendingSelected
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
                    Icon(
                      Icons.hourglass_empty_rounded,
                      size: screenSize.width * 0.07,
                      color: _isPendingSelected
                          ? Colors.white
                          : Colors.grey[600],
                    ),
                    SizedBox(width: screenSize.width * 0.02),
                    Text(
                      'Pending',
                      style: TextStyle(
                        color: _isPendingSelected
                            ? Colors.white
                            : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: screenSize.width * 0.045,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: screenSize.width * 0.002),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isPendingSelected = false;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: screenSize.height * 0.012,
                ),
                decoration: BoxDecoration(
                  color: !_isPendingSelected
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
                    Icon(
                      Icons.history_rounded,
                      size: screenSize.width * 0.07,
                      color: !_isPendingSelected
                          ? Colors.white
                          : Colors.grey[600],
                    ),
                    SizedBox(width: screenSize.width * 0.02),
                    Text(
                      'History',
                      style: TextStyle(
                        color: !_isPendingSelected
                            ? Colors.white
                            : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: screenSize.width * 0.045,
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

  /// Builds each history/pending card
  Widget _buildHistoryCard(
      BuildContext context, Map<String, dynamic> item,
      {required bool isHistory, required Size screenSize}) {
    final themeNotifier =
    Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final String type = item['type'] ?? 'unknown';

    String title = item['title'] ?? 'No Title';
    String status = item['status'] ?? 'Pending';
    String employeeName = item['employee_name'] ?? 'N/A';
    String employeeImage = item['img_path'].isNotEmpty
        ? item['img_path']
        : item['img_name'] ??
        'https://via.placeholder.com/150'; // Prefer img_path
    Color typeColor = _getTypeColor(type);
    Color statusColor = _getStatusColor(status);

    String startDate = item['startDate'] ?? '';
    String endDate = item['endDate'] ?? '';

    String detailLabel = '';
    String detailValue = '';

    // Determine detail label and value based on type
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

    /// Formats date strings
    String formatDate(String? dateStr) {
      try {
        if (dateStr == null || dateStr.isEmpty) {
          return 'N/A';
        }
        // Handle both date and datetime formats
        DateTime parsedDate;
        if (dateStr.contains('T')) {
          parsedDate = DateTime.parse(dateStr);
        } else if (dateStr.contains(' ')) {
          parsedDate = DateTime.parse(dateStr);
        } else {
          parsedDate = DateTime.parse('${dateStr}T00:00:00.000Z');
        }
        return DateFormat('dd-MM-yyyy, HH:mm').format(parsedDate);
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
            builder: (context) => DetailsPage(
              types: types,
              id: id,
              status: status,
            ),
          ),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenSize.width * 0.08),
          side: BorderSide(color: typeColor, width: screenSize.width * 0.003),
        ),
        elevation: 1.5,
        margin: EdgeInsets.symmetric(
          vertical: screenSize.height * 0.008,
        ),
        child: Row(
          children: [
            // Colored side bar indicating type
            Container(
              width: screenSize.width * 0.008, // 1.2% of screen width
              height: screenSize.height * 0.10, // 12% of screen height
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15.0),
                  bottomLeft: Radius.circular(15.0),
                ),
              ),
            ),
            SizedBox(width: screenSize.width * 0.03),
            // Main content of the card
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: screenSize.height * 0.012,
                  horizontal: screenSize.width * 0.02,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type Icon and Title
                    Row(
                      children: [
                        Icon(
                          item['icon'],
                          color: typeColor,
                          size: screenSize.width * 0.07,
                        ),
                        SizedBox(width: screenSize.width * 0.02),
                        Text(
                          type[0].toUpperCase() + type.substring(1),
                          style: TextStyle(
                            color: typeColor,
                            fontSize: screenSize.width * 0.05,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenSize.height * 0.005),
                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: screenSize.width * 0.05,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.003),
                    // From and To Dates
                    Text(
                      'From: ${formatDate(startDate)}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: screenSize.width * 0.035,
                      ),
                    ),
                    Text(
                      'To: ${formatDate(endDate)}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: screenSize.width * 0.035,
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.003),
                    // Detail Label and Value
                    Text(
                      '$detailLabel: $detailValue',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: screenSize.width * 0.035,
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.005),
                    // Status Indicator
                    Row(
                      children: [
                        Text(
                          'Status: ',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: screenSize.width * 0.035,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenSize.width * 0.02,
                            vertical: screenSize.height * 0.005,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius:
                            BorderRadius.circular(screenSize.width * 0.03),
                          ),
                          child: Text(
                            status[0].toUpperCase() +
                                status.substring(1),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: screenSize.width * 0.035,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Employee Avatar
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.width * 0.02,
              ),
              child: CircleAvatar(
                backgroundImage: NetworkImage(employeeImage),
                radius: screenSize.width * 0.07, // Responsive radius
                onBackgroundImageError: (_, __) {},
                backgroundColor: Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper method to get a default avatar URL
  String _defaultAvatarUrl() {
    // Replace with a publicly accessible image URL
    return 'https://www.w3schools.com/howto/img_avatar.png';
  }
}
