// notification_page.dart

import 'package:flutter/foundation.dart';
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
  final String _imageBaseUrl = 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/';

  // State variables for expansion
  bool _isMeetingExpanded = false;
  bool _isApprovalExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  /// Initializes data fetching for leave types, pending items, meeting invites, and history items
  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
      // Reset expansion states when refreshing data
      _isMeetingExpanded = false;
      _isApprovalExpanded = false;
    });

    try {
      await _fetchLeaveTypes();
      await Future.wait([
        _fetchPendingItems(),
        _fetchMeetingInvites(),
        _fetchHistoryItems(),
      ]);
      if (kDebugMode) {
        print('Initial data fetched successfully.');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error during initial data fetch: $e');
      }
      if (kDebugMode) {
        print(stackTrace);
      }
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

      if (kDebugMode) {
        print('Fetching leave types: Status Code ${leaveTypesResponse.statusCode}');
      }

      if (leaveTypesResponse.statusCode == 200) {
        final responseBody = jsonDecode(leaveTypesResponse.body);
        if (responseBody['statusCode'] == 200 && responseBody['results'] != null) {
          final List<dynamic> leaveTypesData = responseBody['results'];
          setState(() {
            _leaveTypesMap = {for (var item in leaveTypesData) item['leave_type_id'] as int: item['name'].toString()};
          });
          if (kDebugMode) {
            print('Leave types loaded: $_leaveTypesMap');
          }
        } else {
          throw Exception(responseBody['message'] ?? 'Failed to load leave types');
        }
      } else {
        throw Exception('Failed to load leave types: ${leaveTypesResponse.statusCode}');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error fetching leave types: $e');
      }
      if (kDebugMode) {
        print(stackTrace);
      }
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

      if (kDebugMode) {
        print('Fetching pending items: Status Code ${pendingResponse.statusCode}');
      }

      if (pendingResponse.statusCode == 200) {
        final responseBody = jsonDecode(pendingResponse.body);
        if (responseBody['statusCode'] == 200 && responseBody['results'] != null) {
          final List<dynamic> pendingData = responseBody['results'];

          // Filter out null items and unknown types
          final List<Map<String, dynamic>> filteredData = pendingData.where((item) => item != null).map((item) => Map<String, dynamic>.from(item)).where((item) => item['types'] != null && _knownTypes.contains(item['types'].toString().toLowerCase())).toList();

          setState(() {
            _pendingItems = filteredData;
          });
          if (kDebugMode) {
            print('Pending items loaded: ${_pendingItems.length} items.');
          }
        } else {
          throw Exception(responseBody['message'] ?? 'Failed to load pending data');
        }
      } else {
        throw Exception('Failed to load pending data: ${pendingResponse.statusCode}');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error fetching pending data: $e');
      }
      if (kDebugMode) {
        print(stackTrace);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching pending data: $e')),
      );
      rethrow;
    }
  }

  /// Fetches all history approval items without pagination
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

      if (kDebugMode) {
        print('Fetching history items: Status Code ${historyResponse.statusCode}');
      }

      if (historyResponse.statusCode == 200) {
        final responseBody = jsonDecode(historyResponse.body);
        if (responseBody['statusCode'] == 200 && responseBody['results'] != null) {
          final List<dynamic> historyData = responseBody['results'];

          // Filter out null items and unknown types
          final List<Map<String, dynamic>> filteredData = historyData.where((item) => item != null).map((item) => Map<String, dynamic>.from(item)).where((item) => item['types'] != null && _knownTypes.contains(item['types'].toString().toLowerCase())).toList();

          setState(() {
            _historyItems = filteredData;
          });
          if (kDebugMode) {
            print('History items loaded: ${_historyItems.length} items.');
          }
        } else {
          throw Exception(responseBody['message'] ?? 'Failed to load history data');
        }
      } else {
        throw Exception('Failed to load history data: ${historyResponse.statusCode}');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error fetching history data: $e');
      }
      if (kDebugMode) {
        print(stackTrace);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching history data: $e')),
      );
      rethrow;
    }
  }

  /// Fetches all meeting invites without pagination
  Future<void> _fetchMeetingInvites() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String meetingInvitesApiUrl = '$baseUrl/api/office-administration/book_meeting_room/invites-meeting';

    try {
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

      if (kDebugMode) {
        print('Fetching meeting invites: Status Code ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['statusCode'] == 200 && responseBody['results'] != null) {
          final List<dynamic> meetingData = responseBody['results'];
          final List<Map<String, dynamic>> formattedMeetingData = meetingData.map((item) {
            final Map<String, dynamic> meetingItem = Map<String, dynamic>.from(item);
            meetingItem['types'] = 'meeting';
            return meetingItem;
          }).toList();

          setState(() {
            _meetingInvites = formattedMeetingData;
          });
          print('Meeting invites loaded: ${_meetingInvites.length} items.');
        } else {
          throw Exception(responseBody['message'] ?? 'Failed to load meeting invites');
        }
      } else {
        throw Exception('Failed to load meeting invites: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Error fetching meeting invites: $e');
      print(stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching meeting invites: $e')),
      );
      rethrow;
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
          SizedBox(height: screenSize.height * 0.01),
          _buildTabBar(screenSize),
          SizedBox(height: screenSize.height * 0.008),
          _isLoading
              ? const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              : Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchInitialData, // Refreshes all data
                    child: _isMeetingSelected
                        ? _meetingInvites.isEmpty
                            ? Center(
                                child: Text(
                                  'No Meeting Invites',
                                  style: TextStyle(
                                    fontSize: screenSize.width * 0.045,
                                  ),
                                ),
                              )
                            : _buildMeetingList(screenSize)
                        : (_pendingItems.isEmpty && _historyItems.isEmpty)
                            ? Center(
                                child: Text(
                                  'No Approval Items',
                                  style: TextStyle(
                                    fontSize: screenSize.width * 0.045,
                                  ),
                                ),
                              )
                            : _buildApprovalList(screenSize),
                  ),
                ),
        ],
      ),
    );
  }

  /// Builds the Meeting list with View More functionality
  Widget _buildMeetingList(Size screenSize) {
    int itemCount = _isMeetingExpanded ? _meetingInvites.length : (_meetingInvites.length > 30 ? 30 : _meetingInvites.length);

    bool showViewMore = _meetingInvites.length > 30 && !_isMeetingExpanded;

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.04,
        vertical: screenSize.height * 0.008,
      ),
      itemCount: showViewMore ? itemCount + 1 : itemCount,
      itemBuilder: (context, index) {
        if (showViewMore && index == itemCount) {
          return Center(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _isMeetingExpanded = true;
                });
              },
              child: const Text('View More'),
            ),
          );
        }

        final item = _meetingInvites[index];
        return _buildItemCard(
          context,
          item,
          isHistory: false,
          screenSize: screenSize,
        );
      },
    );
  }

  /// Builds the Approval list with View More functionality
  Widget _buildApprovalList(Size screenSize) {
    List<Map<String, dynamic>> combinedApprovalItems = [..._pendingItems, ..._historyItems];

    int itemCount = _isApprovalExpanded ? combinedApprovalItems.length : (combinedApprovalItems.length > 30 ? 30 : combinedApprovalItems.length);

    bool showViewMore = combinedApprovalItems.length > 30 && !_isApprovalExpanded;

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.04,
        vertical: screenSize.height * 0.008,
      ),
      itemCount: showViewMore ? itemCount + 1 : itemCount,
      itemBuilder: (context, index) {
        if (showViewMore && index == itemCount) {
          return Center(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _isApprovalExpanded = true;
                });
              },
              child: const Text('View More'),
            ),
          );
        }

        final item = combinedApprovalItems[index];
        bool isHistory = index >= _pendingItems.length;
        return _buildItemCard(
          context,
          item,
          isHistory: isHistory,
          screenSize: screenSize,
        );
      },
    );
  }

  /// Builds the header section with background image and title.
  Widget _buildHeader(bool isDarkMode, Size screenSize) {
    return Container(
      height: screenSize.height * 0.18,
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
                'Notification',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: screenSize.width * 0.06,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: screenSize.width * 0.12),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the tab bar for toggling between Meeting and Approval sections.
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
                if (!_isMeetingSelected) {
                  setState(() {
                    _isMeetingSelected = true;
                  });
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: screenSize.height * 0.010,
                ),
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
                    Icon(
                      Icons.meeting_room,
                      size: screenSize.width * 0.07,
                      color: _isMeetingSelected ? Colors.white : Colors.grey.shade600,
                    ),
                    SizedBox(width: screenSize.width * 0.02),
                    Text(
                      'Meeting',
                      style: TextStyle(
                        color: _isMeetingSelected ? Colors.white : Colors.grey.shade600,
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
                if (_isMeetingSelected) {
                  setState(() {
                    _isMeetingSelected = false;
                  });
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: screenSize.height * 0.010,
                ),
                decoration: BoxDecoration(
                  color: !_isMeetingSelected ? Colors.amber : Colors.grey.shade300,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20.0),
                    bottomRight: Radius.circular(20.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/pending.png',
                      width: screenSize.width * 0.07,
                      height: screenSize.width * 0.07,
                      color: !_isMeetingSelected ? Colors.white : Colors.grey.shade600,
                    ),
                    SizedBox(width: screenSize.width * 0.02),
                    Text(
                      'Approval',
                      style: TextStyle(
                        color: !_isMeetingSelected ? Colors.white : Colors.grey.shade600,
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

  /// Builds each item card for Meeting or Approval.
  Widget _buildItemCard(BuildContext context, Map<String, dynamic> item, {required bool isHistory, required Size screenSize}) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;

    String type = (item['types']?.toString().toLowerCase() ?? 'unknown').trim();
    String status = (item['status']?.toString() ?? 'Pending').trim();
    String employeeName = (item['employee_name']?.toString() ?? 'N/A').trim();
    String requestorName = (item['requestor_name']?.toString() ?? 'N/A').trim();

    if (status.toLowerCase() == 'branch approved') {
      status = 'Approved';
    } else if (status.toLowerCase() == 'branch waiting') {
      status = 'Waiting';
    }

    String id = (item['uid']?.toString() ?? '').trim();
    if (id.isEmpty) {
      return const SizedBox.shrink();
    }

    String imgName = item['img_name']?.toString().trim() ?? '';
    String imgPath = item['img_path']?.toString().trim() ?? '';

    // Determine the employee image URL
    String employeeImage;
    if (imgPath.isNotEmpty && imgPath.startsWith('http')) {
      employeeImage = imgPath;
    } else if (imgName.isNotEmpty && imgName.startsWith('http')) {
      employeeImage = imgName;
    } else if (imgName.isNotEmpty) {
      employeeImage = 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/$imgName';
    } else {
      employeeImage = 'https://via.placeholder.com/150'; // Placeholder
    }

    Color typeColor = _getTypeColor(type);
    Color statusColor = _getStatusColor(status);
    IconData typeIcon = _getIconForType(type);

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
        detailValue = title;
        break;
      case 'car':
        title = item['purpose']?.toString() ?? 'No Purpose';
        startDate = item['date_out']?.toString() ?? '';
        endDate = item['date_in']?.toString() ?? '';
        detailLabel = 'Requestor Name';
        detailValue = requestorName;
        break;
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
              builder: (context) => NotificationMeetingDetailsPage(id: id),
            ),
          );

          if (result == true) {
            _fetchInitialData();
          }
        } else {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NotificationDetailPage(id: id, type: type),
            ),
          );

          if (result == true) {
            _fetchInitialData();
          }
        }
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenSize.width * 0.03),
          side: BorderSide(color: typeColor, width: screenSize.width * 0.002),
        ),
        elevation: 1.5,
        margin: EdgeInsets.symmetric(vertical: screenSize.height * 0.008),
        child: Stack(
          children: [
            Positioned(
              top: screenSize.height * 0.01,
              bottom: screenSize.height * 0.01,
              left: screenSize.width * 0.005,
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
                        typeIcon,
                        color: typeColor,
                        size: screenSize.width * 0.07,
                      ),
                      SizedBox(height: screenSize.height * 0.003),
                      Text(
                        type[0].toUpperCase() + type.substring(1),
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
                          title,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontSize: screenSize.width * 0.04,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: screenSize.height * 0.003),
                        Text(
                          'Date: ${_formatDate(startDate)}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: screenSize.width * 0.03,
                          ),
                        ),
                        Text(
                          'To: ${_formatDate(endDate)}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: screenSize.width * 0.03,
                          ),
                        ),
                        SizedBox(height: screenSize.height * 0.003),
                        Text(
                          '$detailLabel: $detailValue',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: screenSize.width * 0.03,
                          ),
                        ),
                        SizedBox(height: screenSize.height * 0.003),
                        Row(
                          children: [
                            Text(
                              'Status: ',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: screenSize.width * 0.03,
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
                                  screenSize.width * 0.03,
                                ),
                              ),
                              child: Text(
                                status[0].toUpperCase() + status.substring(1),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: screenSize.width * 0.03,
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
                  radius: screenSize.width * 0.07,
                  backgroundColor: Colors.grey.shade300,
                  child: ClipOval(
                    child: Image.network(
                      employeeImage,
                      width: screenSize.width * 0.14,
                      height: screenSize.width * 0.14,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person,
                          color: Colors.grey.shade600,
                          size: screenSize.width * 0.07,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Removes duplicate parts from the requestor name
  String _removeDuplicateNames(String name) {
    if (name.isEmpty) return 'N/A';
    // Example: "UserHQ1UserHQ1" -> "UserHQ1"
    RegExp regExp = RegExp(r'^(.*?)\1+$');
    Match? match = regExp.firstMatch(name);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }
    return name;
  }

  /// Builds the employee avatar with error handling
  Widget _buildEmployeeAvatar(String imageUrl, Size screenSize) {
    return CircleAvatar(
      radius: screenSize.width * 0.07, // Responsive radius
      backgroundColor: Colors.grey.shade300,
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: screenSize.width * 0.14, // 14% of screen width
          height: screenSize.width * 0.14, // 14% of screen width
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            if (kDebugMode) {
              print('Error loading employee image from $imageUrl: $error');
            }
            return Icon(
              Icons.person,
              color: Colors.grey.shade600,
              size: screenSize.width * 0.07,
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
      if (kDebugMode) {
        print(stackTrace);
      }
      return 'Invalid Date';
    }
  }

  /// Returns appropriate color based on the status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'yes':
        return Colors.green;
      case 'reject':
      case 'rejected':
      case 'no':
        return Colors.red;
      case 'waiting':
      case 'pending':
      case 'branch waiting':
        return Colors.amber;
      case 'processing':
      case 'branch processing':
        return Colors.blue;
      case 'completed':
        return Colors.orange;
      case 'deleted':
      case 'disapproved':
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
}
