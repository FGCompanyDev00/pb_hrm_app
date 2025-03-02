// approvals_main_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approvals_page/approvals_details_page.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApprovalsMainPage extends StatefulWidget {
  const ApprovalsMainPage({super.key});

  @override
  ApprovalsMainPageState createState() => ApprovalsMainPageState();
}

class ApprovalsMainPageState extends State<ApprovalsMainPage> {
  // Tab selection flag: true for Approvals, false for History
  bool _isPendingSelected = true;

  // Data lists
  List<Map<String, dynamic>> _pendingItems = [];
  List<Map<String, dynamic>> _historyItems = [];

  // Loading state
  bool _isLoading = true;

  // Variables to control the number of items displayed
  int _pendingItemsToShow = 15;
  int _historyItemsToShow = 15;
  final int _maxItemsToShow = 40;

  // Scroll controllers to detect when user is near the end
  final ScrollController _pendingScrollController = ScrollController();
  final ScrollController _historyScrollController = ScrollController();

  // Variables to control button visibility
  bool _showPendingViewMoreButton = false;
  bool _showHistoryViewMoreButton = false;

  // Known types
  final Set<String> _knownTypes = {'meeting', 'leave', 'car'};

  // Leave Types Map: leave_type_id -> name
  Map<int, String> _leaveTypesMap = {};

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();

    // Add scroll listeners
    _pendingScrollController.addListener(_checkPendingScrollPosition);
    _historyScrollController.addListener(_checkHistoryScrollPosition);
  }

  @override
  void dispose() {
    _pendingScrollController.dispose();
    _historyScrollController.dispose();
    super.dispose();
  }

  // Check if user has scrolled near the end of pending items
  void _checkPendingScrollPosition() {
    if (_pendingItems.length <= _pendingItemsToShow ||
        _pendingItemsToShow >= _maxItemsToShow) {
      setState(() {
        _showPendingViewMoreButton = false;
      });
      return;
    }

    // Show button when user has scrolled to about 80% of the visible content
    if (_pendingScrollController.position.pixels >
        _pendingScrollController.position.maxScrollExtent * 0.8) {
      if (!_showPendingViewMoreButton) {
        setState(() {
          _showPendingViewMoreButton = true;
        });
      }
    } else {
      if (_showPendingViewMoreButton) {
        setState(() {
          _showPendingViewMoreButton = false;
        });
      }
    }
  }

  // Check if user has scrolled near the end of history items
  void _checkHistoryScrollPosition() {
    if (_historyItems.length <= _historyItemsToShow ||
        _historyItemsToShow >= _maxItemsToShow) {
      setState(() {
        _showHistoryViewMoreButton = false;
      });
      return;
    }

    // Show button when user has scrolled to about 80% of the visible content
    if (_historyScrollController.position.pixels >
        _historyScrollController.position.maxScrollExtent * 0.8) {
      if (!_showHistoryViewMoreButton) {
        setState(() {
          _showHistoryViewMoreButton = true;
        });
      }
    } else {
      if (_showHistoryViewMoreButton) {
        setState(() {
          _showHistoryViewMoreButton = false;
        });
      }
    }
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
      debugPrint('Initial data fetched successfully.');
    } catch (e, stackTrace) {
      debugPrint('Error during initial data fetch: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching data: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Fetches leave types from the API and populates the _leaveTypesMap
  Future<void> _fetchLeaveTypes() async {
    final String leaveTypesApiUrl = '$baseUrl/api/leave-types';

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

      debugPrint(
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
          debugPrint('Leave types loaded: $_leaveTypesMap');
        } else {
          throw Exception(
              responseBody['message'] ?? 'Failed to load leave types');
        }
      } else {
        throw Exception(
            'Failed to load leave types: ${leaveTypesResponse.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching leave types: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching leave types: $e')),
        );
      }
      rethrow; // So that _fetchInitialData catches and handles
    }
  }

  /// Fetches all pending approval items without pagination
  Future<void> _fetchPendingItems() async {
    final String pendingApiUrl = '$baseUrl/api/app/tasks/approvals/pending';

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

      debugPrint(
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

          // Sort the filtered data by 'updated_at' in descending order
          filteredData.sort((a, b) {
            DateTime aDate = DateTime.tryParse(a['updated_at'] ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            DateTime bDate = DateTime.tryParse(b['updated_at'] ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate); // Descending order
          });

          setState(() {
            _pendingItems = filteredData;
          });
          debugPrint(
              'Pending items loaded and sorted: ${_pendingItems.length} items.');
        } else {
          throw Exception(
              responseBody['message'] ?? 'Failed to load pending data');
        }
      } else {
        throw Exception(
            'Failed to load pending data: ${pendingResponse.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching pending data: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching pending data: $e')),
        );
      }
      rethrow;
    }
  }

  /// Fetches all history items without pagination
  Future<void> _fetchHistoryItems() async {
    final String historyApiUrl = '$baseUrl/api/app/tasks/approvals/history';

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

      debugPrint(
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

          // Sort the filtered data by 'updated_at' in descending order
          filteredData.sort((a, b) {
            DateTime aDate = DateTime.tryParse(a['updated_at'] ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            DateTime bDate = DateTime.tryParse(b['updated_at'] ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate); // Descending order
          });

          setState(() {
            _historyItems = filteredData;
          });
          debugPrint(
              'History items loaded and sorted: ${_historyItems.length} items.');
        } else {
          throw Exception(
              responseBody['message'] ?? 'Failed to load history data');
        }
      } else {
        throw Exception(
            'Failed to load history data: ${historyResponse.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching history data: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching history data: $e')),
        );
      }
      rethrow;
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
                        onRefresh: _fetchInitialData, // Refreshes all data
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
                                : Stack(
                                    children: [
                                      ListView.builder(
                                        controller: _pendingScrollController,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: screenSize.width * 0.04,
                                          vertical: screenSize.height * 0.008,
                                        ),
                                        // Only show the limited number of items
                                        itemCount: _pendingItems.length >
                                                _pendingItemsToShow
                                            ? _pendingItemsToShow
                                            : _pendingItems.length,
                                        itemBuilder: (context, index) {
                                          final item = _pendingItems[index];
                                          return _buildItemCard(
                                            context,
                                            item,
                                            isHistory: false,
                                            screenSize: screenSize,
                                          );
                                        },
                                      ),
                                      // Show "View More" button if there are more items and user has scrolled near the end
                                      if (_pendingItems.length >
                                              _pendingItemsToShow &&
                                          _pendingItemsToShow < _maxItemsToShow)
                                        AnimatedPositioned(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                          bottom: _showPendingViewMoreButton
                                              ? 20
                                              : -60,
                                          left: 0,
                                          right: 0,
                                          child: Center(
                                            child: _buildViewMoreButton(
                                              onPressed: () {
                                                setState(() {
                                                  _pendingItemsToShow =
                                                      _maxItemsToShow;
                                                  _showPendingViewMoreButton =
                                                      false;
                                                });
                                              },
                                              screenSize: screenSize,
                                              isDarkMode: isDarkMode,
                                            ),
                                          ),
                                        ),
                                    ],
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
                                : Stack(
                                    children: [
                                      ListView.builder(
                                        controller: _historyScrollController,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: screenSize.width * 0.04,
                                          vertical: screenSize.height * 0.008,
                                        ),
                                        // Only show the limited number of items
                                        itemCount: _historyItems.length >
                                                _historyItemsToShow
                                            ? _historyItemsToShow
                                            : _historyItems.length,
                                        itemBuilder: (context, index) {
                                          final item = _historyItems[index];
                                          return _buildItemCard(
                                            context,
                                            item,
                                            isHistory: true,
                                            screenSize: screenSize,
                                          );
                                        },
                                      ),
                                      // Show "View More" button if there are more items and user has scrolled near the end
                                      if (_historyItems.length >
                                              _historyItemsToShow &&
                                          _historyItemsToShow < _maxItemsToShow)
                                        AnimatedPositioned(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                          bottom: _showHistoryViewMoreButton
                                              ? 20
                                              : -60,
                                          left: 0,
                                          right: 0,
                                          child: Center(
                                            child: _buildViewMoreButton(
                                              onPressed: () {
                                                setState(() {
                                                  _historyItemsToShow =
                                                      _maxItemsToShow;
                                                  _showHistoryViewMoreButton =
                                                      false;
                                                });
                                              },
                                              screenSize: screenSize,
                                              isDarkMode: isDarkMode,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                      ),
                    ),
            ],
          ),
        ));
  }

  /// Builds the header section with background image and title.
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
                  'Approvals',
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
        ));
  }

  /// Builds the tab bar for toggling between Approvals and History.
  Widget _buildTabBar(Size screenSize) {
    final isDarkMode = Theme.of(context).brightness ==
        Brightness.dark; // Check if dark mode is enabled

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.02,
        vertical: screenSize.height * 0.004,
      ),
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
                padding: EdgeInsets.symmetric(
                  vertical: screenSize.height * 0.008,
                ),
                decoration: BoxDecoration(
                  color: _isPendingSelected
                      ? (isDarkMode
                          ? Colors.orangeAccent
                          : Colors.amber) // Adjust for dark mode
                      : (isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade300),
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
                      color: _isPendingSelected
                          ? (isDarkMode ? Colors.white : Colors.white)
                          : (isDarkMode
                              ? Colors.grey.shade300
                              : Colors.grey.shade600),
                    ),
                    SizedBox(width: screenSize.width * 0.02),
                    Text(
                      'Approvals',
                      style: TextStyle(
                        color: _isPendingSelected
                            ? (isDarkMode ? Colors.white : Colors.white)
                            : (isDarkMode
                                ? Colors.grey.shade300
                                : Colors.grey.shade600),
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
                if (_isPendingSelected) {
                  setState(() {
                    _isPendingSelected = false;
                  });
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: screenSize.height * 0.008,
                ),
                decoration: BoxDecoration(
                  color: !_isPendingSelected
                      ? (isDarkMode
                          ? Colors.orangeAccent
                          : Colors.amber) // Adjust for dark mode
                      : (isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade300),
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
                      color: !_isPendingSelected
                          ? (isDarkMode ? Colors.white : Colors.white)
                          : (isDarkMode
                              ? Colors.grey.shade300
                              : Colors.grey.shade600),
                    ),
                    SizedBox(width: screenSize.width * 0.02),
                    Text(
                      'History',
                      style: TextStyle(
                        color: !_isPendingSelected
                            ? (isDarkMode ? Colors.white : Colors.white)
                            : (isDarkMode
                                ? Colors.grey.shade300
                                : Colors.grey.shade600),
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

  /// Builds each item card for Approvals or History.
  Widget _buildItemCard(BuildContext context, Map<String, dynamic> item,
      {required bool isHistory, required Size screenSize}) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;

    String type = (item['types']?.toString().toLowerCase() ?? 'unknown').trim();
    String status = (item['status']?.toString() ??
            item['is_approve']?.toString() ??
            'Pending')
        .trim();

    if (status == 'Branch Waiting')
      status = 'Waiting';
    else if (status == 'Branch Approved') status = 'Approved';

    String employeeName = (item['employee_name']?.toString() ?? 'N/A').trim();
    String requestorName = (item['requestor_name']?.toString() ?? 'N/A').trim();
    String imgName = item['img_name']?.toString().trim() ?? '';
    String imgPath = item['img_path']?.toString().trim() ?? '';

    String employeeImage = (imgPath.isNotEmpty && imgPath.startsWith('http'))
        ? imgPath
        : (imgName.isNotEmpty && imgName.startsWith('http'))
            ? imgName
            : 'https://via.placeholder.com/150'; // Fallback image

    Color typeColor = _getTypeColor(type);
    Color statusColor = _getStatusColor(status);
    IconData typeIcon = _getIconForType(type);

    String title = '';
    String dateRange = '';
    String detailLabel = '';
    String detailValue = '';

    switch (type) {
      case 'meeting':
        title = item['title']?.toString() ?? 'No Title';
        dateRange =
            _formatDateRange(item['from_date_time'], item['to_date_time']);
        detailLabel = 'Employee';
        detailValue = employeeName;
        break;
      case 'leave':
        title = _leaveTypesMap[item['leave_type_id']] ?? 'Unknown Leave';
        dateRange = _formatDateRange(
            item['take_leave_from'], item['take_leave_to'],
            alwaysShowTime: true);
        detailLabel = 'Leave Type';
        detailValue = title;
        break;
      case 'car':
        title = item['purpose']?.toString() ?? 'No Purpose';
        dateRange = _formatDateRange('${item['date_in']} ${item['time_in']}',
            '${item['date_out']} ${item['time_out']}');
        detailLabel = 'Requestor';
        detailValue = requestorName;
        break;
    }

    return GestureDetector(
      onTap: () {
        String itemId = (type == 'leave')
            ? item['take_leave_request_id']?.toString() ?? ''
            : item['uid']?.toString() ?? '';

        if (itemId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid ID')),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ApprovalsDetailsPage(id: itemId, type: type),
          ),
        );
      },
      child: Card(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenSize.width * 0.04),
          side: BorderSide(color: typeColor, width: screenSize.width * 0.003),
        ),
        margin: EdgeInsets.symmetric(vertical: screenSize.height * 0.006),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: screenSize.height * 0.007,
            horizontal: screenSize.width * 0.025,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Fixed-sized Icon Section to align properly
              SizedBox(
                width: screenSize.width * 0.12,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(typeIcon,
                        color: typeColor, size: screenSize.width * 0.06),
                    SizedBox(height: screenSize.height * 0.002),
                    Text(
                      type[0].toUpperCase() + type.substring(1),
                      style: TextStyle(
                        color: typeColor,
                        fontSize: screenSize.width * 0.028,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(width: screenSize.width * 0.02),

              // Information Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: screenSize.width * 0.033,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (dateRange.isNotEmpty)
                      Text(
                        dateRange,
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.white70
                              : Colors.grey.shade700,
                          fontSize: screenSize.width * 0.028,
                        ),
                      ),
                    SizedBox(height: screenSize.height * 0.003),
                    Text(
                      '$detailLabel: $detailValue',
                      style: TextStyle(
                        color:
                            isDarkMode ? Colors.white70 : Colors.grey.shade700,
                        fontSize: screenSize.width * 0.028,
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.006),
                    Row(
                      children: [
                        Text(
                          'Status: ',
                          style: TextStyle(
                            fontSize: screenSize.width * 0.028,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenSize.width * 0.012,
                            vertical: screenSize.height * 0.002,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius:
                                BorderRadius.circular(screenSize.width * 0.015),
                          ),
                          child: Text(
                            status[0].toUpperCase() + status.substring(1),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: screenSize.width * 0.028,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: screenSize.width * 0.015),

              // Profile Image
              CircleAvatar(
                radius: screenSize.width * 0.05,
                backgroundColor:
                    isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                backgroundImage: NetworkImage(employeeImage),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateRange(String? start, String? end,
      {bool alwaysShowTime = false}) {
    String formatDateTime(String? dateTime, bool forceTime) {
      if (dateTime == null || dateTime.isEmpty) return '';

      try {
        // First try to parse with standard format
        DateTime? parsedDate;

        // Handle different date formats
        if (dateTime.contains('T')) {
          // ISO format
          parsedDate = DateTime.parse(dateTime);
        } else {
          // Custom format YYYY-M-DD HH:mm
          final parts = dateTime.split(' ');
          if (parts.length == 2) {
            final dateParts = parts[0].split('-');
            final timeParts = parts[1].split(':');

            if (dateParts.length == 3 && timeParts.length >= 2) {
              parsedDate = DateTime(
                  int.parse(dateParts[0]), // year
                  int.parse(dateParts[1]), // month
                  int.parse(dateParts[2]), // day
                  int.parse(timeParts[0]), // hour
                  int.parse(timeParts[1]), // minute
                  timeParts.length > 2 ? int.parse(timeParts[2]) : 0 // seconds
                  );
            }
          }
        }

        if (parsedDate == null) {
          debugPrint('Could not parse date: $dateTime');
          return '';
        }

        // If forceTime is false and the time is 00:00, remove it
        if (!forceTime && parsedDate.hour == 0 && parsedDate.minute == 0) {
          return DateFormat('dd-MM-yyyy').format(parsedDate);
        }

        return DateFormat('dd-MM-yyyy HH:mm').format(parsedDate);
      } catch (e) {
        debugPrint('Error parsing date: $dateTime -> $e');
        return '';
      }
    }

    String formattedStart = formatDateTime(start, alwaysShowTime);
    String formattedEnd = formatDateTime(end, alwaysShowTime);

    if (formattedStart.isNotEmpty && formattedEnd.isNotEmpty) {
      return '$formattedStart → $formattedEnd';
    } else if (formattedStart.isNotEmpty) {
      return formattedStart;
    } else if (formattedEnd.isNotEmpty) {
      return formattedEnd;
    }

    return 'N/A'; // Show 'N/A' if both are missing
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
      case 'branch waiting':
      case 'waiting for approval':
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

  // Enhanced method to build the "View More" button
  Widget _buildViewMoreButton({
    required VoidCallback onPressed,
    required Size screenSize,
    required bool isDarkMode,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: screenSize.width * 0.4, // More compact width
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: screenSize.height * 0.012,
                  horizontal: screenSize.width * 0.03,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(screenSize.width * 0.05),
                  side: BorderSide(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                elevation: 5,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View More',
                    style: TextStyle(
                      fontSize: screenSize.width * 0.035,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: screenSize.width * 0.02),
                  Icon(
                    Icons.arrow_downward,
                    size: screenSize.width * 0.04,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
