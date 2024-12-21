// history_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:pb_hrsystem/home/dashboard/history/history_details_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pb_hrsystem/settings/theme_notifier.dart';

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
          _leaveTypes = {for (var lt in leaveTypesData) lt['leave_type_id']: lt['name']};
        } else {
          throw Exception(leaveTypesBody['message'] ?? 'Failed to load leave types');
        }
      } else {
        throw Exception('Failed to load leave types: ${leaveTypesResponse.statusCode}');
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
          tempPendingItems.addAll(pendingData.map((item) => _formatItem(item as Map<String, dynamic>)));
        } else {
          throw Exception(responseBody['message'] ?? 'Failed to load pending data');
        }
      } else {
        throw Exception('Failed to load pending data: ${pendingResponse.statusCode}');
      }

      // Process History Response
      if (historyResponse.statusCode == 200) {
        final responseBody = jsonDecode(historyResponse.body);
        if (responseBody['statusCode'] == 200) {
          final List<dynamic> historyData = responseBody['results'];
          tempHistoryItems.addAll(historyData.map((item) => _formatItem(item as Map<String, dynamic>)));
        } else {
          throw Exception(responseBody['message'] ?? 'Failed to load history data');
        }
      } else {
        throw Exception('Failed to load history data: ${historyResponse.statusCode}');
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
      'timestamp': DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
      'img_name': item['img_name'] ?? 'https://via.placeholder.com/150', // Placeholder image
      'img_path': item['img_path'] ?? '', // Add img_path if available
    };

    switch (type) {
      case 'meeting':
        formattedItem.addAll({
          'title': item['title'] ?? 'No Title',
          'startDate': item['from_date_time'] ?? '',
          'endDate': item['to_date_time'] ?? '',
          'room': item['room_name'] ?? 'No Room Info',
          'employee_name': item['employee_name'] ?? 'N/A',
          'id': item['uid']?.toString() ?? '',
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
        });
        break;
      case 'car':
        debugPrint('Car Item Data: $item');

        formattedItem.addAll({
          'title': item['purpose'] ?? 'No Purpose',
          'startDate': item['date_out'] ?? '',
          'endDate': item['date_in'] ?? '',
          'employee_name': item['requestor_name'] ?? 'N/A',
          'employee_tel': item['employee_tel']?.toString() ?? 'No phone number',
          'id': item['uid']?.toString() ?? '',
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

    return WillPopScope(
        onWillPop: () async {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Dashboard()),
            (route) => false,
      );
      return false;
    },
    child: Scaffold(
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
    ));
  }

  /// Builds the header section with background image and title
  Widget _buildHeader(bool isDarkMode, Size screenSize) {
    return Container(
      height: screenSize.height * 0.17,
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
                onPressed: () => Navigator.maybePop(context),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.03,
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
                  vertical: screenSize.height * 0.008,
                ),
                decoration: BoxDecoration(
                  color: _isPendingSelected ? (isDarkMode ? Colors.amber[700] : Colors.amber) : (isDarkMode ? Colors.grey[800] : Colors.grey[300]),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    bottomLeft: Radius.circular(20.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/pending.png',
                      width: screenSize.width * 0.07,
                      height: screenSize.width * 0.07,
                      color: _isPendingSelected ? Colors.white : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    SizedBox(width: screenSize.width * 0.02),
                    Text(
                      'Pending',
                      style: TextStyle(
                        color: _isPendingSelected ? Colors.white : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                        fontWeight: FontWeight.bold,
                        fontSize: screenSize.width * 0.04,
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
                  vertical: screenSize.height * 0.008,
                ),
                decoration: BoxDecoration(
                  color: !_isPendingSelected ? (isDarkMode ? Colors.amber[700] : Colors.amber) : (isDarkMode ? Colors.grey[800] : Colors.grey[300]),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20.0),
                    bottomRight: Radius.circular(20.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/history.png',
                      width: screenSize.width * 0.07,
                      height: screenSize.width * 0.07,
                      color: !_isPendingSelected ? Colors.white : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    SizedBox(width: screenSize.width * 0.02),
                    Text(
                      'History',
                      style: TextStyle(
                        color: !_isPendingSelected ? Colors.white : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                        fontWeight: FontWeight.bold,
                        fontSize: screenSize.width * 0.04,
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
  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> item, {required bool isHistory, required Size screenSize}) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final String type = item['type'] ?? 'unknown';

    Color titleColor;
    String detailText;
    Color detailTextColor = Colors.grey;
    String detailLabel;
    Color statusColor = _getStatusColor(item['status']);
    Color typeColor = _getTypeColor(type);

    String formatDate(String dateStr) {
      try {
        DateTime date;
        if (dateStr.contains('T')) {
          date = DateTime.parse(dateStr);
        } else {
          date = DateFormat('yyyy-M-d').parse(dateStr);
        }
        return DateFormat('dd-MM-yyyy HH:mm').format(date);
      } catch (e) {
        return 'Invalid Date';
      }
    }

    switch (type) {
      case 'meeting':
        titleColor = Colors.green;
        detailLabel = 'Room:';
        detailText = item['room'] ?? 'N/A';
        detailTextColor = Colors.orange;
        break;
      case 'leave':
        titleColor = Colors.orange;
        detailLabel = 'Type:';
        detailText = item['leave_type'] ?? 'N/A';
        detailTextColor = Colors.orange;
        break;
      case 'car':
        titleColor = Colors.blue;
        detailLabel = 'Tel:';
        detailText = item['employee_tel']?.toString() ?? 'No phone number';
        detailTextColor = Colors.grey;
        break;
      default:
        titleColor = Colors.grey;
        detailLabel = 'Info:';
        detailText = 'N/A';
    }

    String startDate = item['startDate'] != null ? formatDate(item['startDate']) : 'N/A';
    String endDate = item['endDate'] != null ? formatDate(item['endDate']) : 'N/A';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsPage(
              types: type,
              id: item['id'] ?? '',
              status: item['status'] ?? 'pending',
            ),
          ),
        );
      },
      child: Card(
        color: isDarkMode ? Colors.grey[850] : Colors.white, // Card color changes based on theme
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenSize.width * 0.03),
          side: BorderSide(color: typeColor, width: screenSize.width * 0.001),
        ),
        margin: EdgeInsets.symmetric(vertical: screenSize.height * 0.008),
        child: Stack(
          children: [
            Positioned(
              top: screenSize.height * 0.01,
              bottom: screenSize.height * 0.01,
              left: screenSize.width * 0.001,
              child: Container(
                width: screenSize.width * 0.005,
                color: typeColor,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: screenSize.height * 0.01,
                horizontal: screenSize.width * 0.03,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item['icon'],
                        color: typeColor,
                        size: screenSize.width * 0.08,
                      ),
                      SizedBox(height: screenSize.height * 0.003),
                      Text(
                        type == 'meeting' ? 'Room' : type[0].toUpperCase() + type.substring(1),
                        style: TextStyle(
                          color: typeColor,
                          fontSize: screenSize.width * 0.03,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: screenSize.width * 0.03),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['employee_name'] ?? 'No Name',
                          style: TextStyle(
                            color: titleColor,
                            fontSize: screenSize.width * 0.038,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: screenSize.height * 0.005),
                        Text(
                          'Date: $startDate',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.grey[700],
                            fontSize: screenSize.width * 0.03,
                          ),
                        ),
                        Text(
                          'To: $endDate',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.grey[700],
                            fontSize: screenSize.width * 0.03,
                          ),
                        ),
                        SizedBox(height: screenSize.height * 0.005),
                        Text(
                          '$detailLabel $detailText',
                          style: TextStyle(
                            color: detailTextColor,
                            fontSize: screenSize.width * 0.03,
                          ),
                        ),
                        SizedBox(height: screenSize.height * 0.006),
                        Row(
                          children: [
                            Text(
                              'Status: ',
                              style: TextStyle(
                                fontSize: screenSize.width * 0.03,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenSize.width * 0.015,
                                vertical: screenSize.height * 0.003,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(
                                  screenSize.width * 0.02,
                                ),
                              ),
                              child: Text(
                                item['status'].toString().toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenSize.width * 0.03,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.only(
                  right: screenSize.width * 0.015,
                  bottom: screenSize.height * 0.02,
                ),
                child: CircleAvatar(
                  backgroundImage: NetworkImage(item['img_name']),
                  radius: screenSize.width * 0.06,
                  backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                ),
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
