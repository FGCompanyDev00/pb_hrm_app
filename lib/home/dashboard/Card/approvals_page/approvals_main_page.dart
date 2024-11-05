// approvals_main_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approvals_page/approvals_details_page.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApprovalsMainPage extends StatefulWidget {
  const ApprovalsMainPage({super.key});

  @override
  _ApprovalsMainPageState createState() => _ApprovalsMainPageState();
}

class _ApprovalsMainPageState extends State<ApprovalsMainPage> {
  // Tab selection flag: true for Approvals, false for History
  bool _isPendingSelected = true;

  // Data lists
  List<Map<String, dynamic>> _pendingItems = [];
  List<Map<String, dynamic>> _historyItems = [];

  // Loading state
  bool _isLoading = true;

  // Known types
  final Set<String> _knownTypes = {'meeting', 'leave', 'car'};

  // Leave Types Map: leave_type_id -> name
  Map<int, String> _leaveTypesMap = {};

  // Base URL for images
  final String _imageBaseUrl =
      'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  /// Initializes data fetching for leave types, pending items, and history items
  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _fetchLeaveTypes();
      await Future.wait([
        _fetchPendingItems(),
        _fetchHistoryItems(),
      ]);
      print('Initial data fetched successfully.');
    } catch (e, stackTrace) {
      print('Error during initial data fetch: $e');
      print(stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Fetches leave types from the API and populates the _leaveTypesMap
  Future<void> _fetchLeaveTypes() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String leaveTypesApiUrl = '$baseUrl/api/leave-types';

    try {
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

      print(
          'Fetching leave types: Status Code ${leaveTypesResponse.statusCode}');

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
          print('Leave types loaded: $_leaveTypesMap');
        } else {
          throw Exception(
              responseBody['message'] ?? 'Failed to load leave types');
        }
      } else {
        throw Exception(
            'Failed to load leave types: ${leaveTypesResponse.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Error fetching leave types: $e');
      print(stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching leave types: $e')),
      );
      rethrow; // So that _fetchInitialData catches and handles
    }
  }

  /// Fetches all pending approval items without pagination
  Future<void> _fetchPendingItems() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String pendingApiUrl = '$baseUrl/api/app/tasks/approvals/pending';

    try {
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

      print(
          'Fetching pending items: Status Code ${pendingResponse.statusCode}');

      if (pendingResponse.statusCode == 200) {
        final responseBody = jsonDecode(pendingResponse.body);
        if (responseBody['statusCode'] == 200 &&
            responseBody['results'] != null) {
          final List<dynamic> pendingData = responseBody['results'];

          // Filter out null items and unknown types
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
          print('Pending items loaded: ${_pendingItems.length} items.');
        } else {
          throw Exception(
              responseBody['message'] ?? 'Failed to load pending data');
        }
      } else {
        throw Exception(
            'Failed to load pending data: ${pendingResponse.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Error fetching pending data: $e');
      print(stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching pending data: $e')),
      );
      rethrow;
    }
  }

  /// Fetches all history items without pagination
  Future<void> _fetchHistoryItems() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String historyApiUrl = '$baseUrl/api/app/tasks/approvals/history';

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('User not authenticated');
      }

      final historyResponse = await http.get(
        Uri.parse(historyApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print(
          'Fetching history items: Status Code ${historyResponse.statusCode}');

      if (historyResponse.statusCode == 200) {
        final responseBody = jsonDecode(historyResponse.body);
        if (responseBody['statusCode'] == 200 &&
            responseBody['results'] != null) {
          final List<dynamic> historyData = responseBody['results'];

          // Filter out null items and unknown types
          final List<Map<String, dynamic>> filteredData = historyData
              .where((item) => item != null)
              .map((item) => Map<String, dynamic>.from(item))
              .where((item) =>
          item['types'] != null &&
              _knownTypes.contains(item['types'].toString().toLowerCase()))
              .toList();

          setState(() {
            _historyItems = filteredData;
          });
          print('History items loaded: ${_historyItems.length} items.');
        } else {
          throw Exception(
              responseBody['message'] ?? 'Failed to load history data');
        }
      } else {
        throw Exception(
            'Failed to load history data: ${historyResponse.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Error fetching history data: $e');
      print(stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching history data: $e')),
      );
      rethrow;
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
              onRefresh: _fetchInitialData, // Refreshes all data
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
                  return _buildItemCard(
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
                  return _buildItemCard(
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

  /// Builds the header section with background image and title.
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
              'Approvals',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 48), // Placeholder for alignment
          ],
        ),
      ),
    );
  }

  /// Builds the tab bar for toggling between Approvals and History.
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isPendingSelected) {
                  setState(() {
                    _isPendingSelected = true;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  color:
                  _isPendingSelected ? Colors.amber : Colors.grey.shade300,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    bottomLeft: Radius.circular(20.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hourglass_empty_rounded,
                        size: 24,
                        color: _isPendingSelected
                            ? Colors.white
                            : Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Approvals',
                      style: TextStyle(
                        color: _isPendingSelected
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
                if (_isPendingSelected) {
                  setState(() {
                    _isPendingSelected = false;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  color: !_isPendingSelected
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
                        color: !_isPendingSelected
                            ? Colors.white
                            : Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'History',
                      style: TextStyle(
                        color: !_isPendingSelected
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

  /// Builds each item card for Approvals or History.
  Widget _buildItemCard(BuildContext context, Map<String, dynamic> item,
      {required bool isHistory}) {
    final themeNotifier =
    Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;

    try {
      // Extract and validate common fields
      String type =
      (item['types']?.toString().toLowerCase() ?? 'unknown').trim();
      if (!_knownTypes.contains(type)) {
        // Unknown type, do not display
        print('Unknown type encountered: $type');
        return const SizedBox.shrink();
      }

      String status = (item['status']?.toString() ??
          item['is_approve']?.toString() ??
          'Pending')
          .trim();
      String employeeName =
      (item['employee_name']?.toString() ?? 'N/A').trim();
      String requestorName =
      (item['requestor_name']?.toString() ?? 'N/A').trim();

      // Treat specific status values for "car" type
      if (type == 'car') {
        if (status.toLowerCase() == 'branch waiting') {
          status = 'Waiting';
        } else if (status.toLowerCase() == 'branch approved') {
          status = 'Approved';
        }
      }

      // Correct ID usage based on type
      String id = '';
      if (type == 'leave') {
        id = (item['take_leave_request_id']?.toString() ?? '').trim();
      } else if (type == 'car') {
        id = (item['uid']?.toString() ?? '').trim(); // Use 'id' for car
      } else if (type == 'meeting') {
        id = (item['uid']?.toString() ?? '').trim(); // Use 'uid' for meeting
      }

      if (id.isEmpty) {
        print('Item with type $type has empty id.');
        return const SizedBox.shrink();
      }

      String imgName = (item['img_name']?.toString() ?? '').trim();
      String imgPath = (item['img_path']?.toString() ?? '').trim();

      // Determine employee image URL
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
        // Use default placeholder image
        employeeImage =
        'https://via.placeholder.com/150'; // Ensure this URL is accessible
      }

      // Determine colors and icons based on type
      Color typeColor = _getTypeColor(type);
      Color statusColor = _getStatusColor(status);
      IconData typeIcon = _getIconForType(type);

      // Determine title and dates based on type
      String title = '';
      String startDate = '';
      String endDate = '';
      String detailLabel = '';
      String detailValue = '';

      switch (type) {
        case 'meeting':
          title = item['title']?.toString() ?? 'No Title';
          startDate = item['from_date_time']?.toString() ?? '';
          endDate = item['to_date_time']?.toString() ?? '';
          detailLabel = 'Employee Name';
          detailValue = employeeName;
          break;
        case 'leave':
          int leaveTypeId = item['leave_type_id'] ?? 0;
          title = _leaveTypesMap[leaveTypeId] ?? 'Unknown Leave Type';
          startDate = item['take_leave_from']?.toString() ?? '';
          endDate = item['take_leave_to']?.toString() ?? '';
          detailLabel = 'Leave Type';
          detailValue = _leaveTypesMap[leaveTypeId] ?? 'N/A';
          break;
        case 'car':
          title = item['purpose']?.toString() ?? 'No Purpose';
          startDate = item['date_out']?.toString() ?? '';
          endDate = item['date_in']?.toString() ?? '';
          detailLabel = 'Requestor Name';
          detailValue = _removeDuplicateNames(requestorName);
          break;
        default:
          print('Unhandled type: $type');
          return const SizedBox.shrink();
      }

      return GestureDetector(
        onTap: () {
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
                id: id,
                type: type, // Pass the type explicitly
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
              // Colored side bar
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
              // Content
              Expanded(
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type and Icon
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
                      // Title
                      Text(
                        title,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Dates
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
                      // Detail
                      Text(
                        '$detailLabel: $detailValue',
                        style:
                        TextStyle(color: Colors.grey.shade700, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      // Status
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
              // Employee Image with Error Handling
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _buildEmployeeAvatar(employeeImage),
              ),
            ],
          ),
        ),
      );
    } catch (e, stackTrace) {
      print('Error building item card: $e');
      print(stackTrace);
      return const SizedBox.shrink();
    }
  }

  /// Removes duplicate parts from the requestor name
  String _removeDuplicateNames(String name) {
    if (name.isEmpty) return 'N/A';
    // Example: "UserHQ1UserHQ1" -> "UserHQ1"
    // This can be adjusted based on the duplication pattern
    RegExp regExp = RegExp(r'^(.*?)\1+$');
    Match? match = regExp.firstMatch(name);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }
    return name;
  }

  /// Builds the employee avatar with error handling
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
            print('Error loading employee image from $imageUrl: $error');
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

  /// Formats the date string to 'dd-MM-yyyy'. Handles various date formats.
  String _formatDate(String? dateStr) {
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
    } catch (e, stackTrace) {
      print('Date parsing error for "$dateStr": $e');
      print(stackTrace);
      return 'Invalid Date';
    }
  }

  /// Returns appropriate color based on the status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'reject':
      case 'rejected':
        return Colors.red;
      case 'waiting':
      case 'pending':
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
}
