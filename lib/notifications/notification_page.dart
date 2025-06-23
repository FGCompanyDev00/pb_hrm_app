// notification_page.dart

// ignore_for_file: unused_element, use_build_context_synchronously, curly_braces_in_flow_control_structures

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/notifications/notification_approvals_details_page.dart';
import 'package:pb_hrsystem/notifications/notification_meeting_section_detail_page.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pb_hrsystem/core/utils/auth_utils.dart';
import 'package:pb_hrsystem/core/widgets/linear_loading_indicator.dart';
import 'package:pb_hrsystem/services/notification_cache_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  NotificationPageState createState() => NotificationPageState();
}

class NotificationPageState extends State<NotificationPage> {
  bool _isMeetingSelected = true;
  List<Map<String, dynamic>> _meetingInvites = [];
  List<Map<String, dynamic>> _pendingItems = [];
  List<Map<String, dynamic>> _historyItems = [];
  bool _isLoading = true;
  bool _isBackgroundLoading = false; // For silent background updates
  Map<int, String> _leaveTypesMap = {};

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  // State variables for expansion
  bool _isMeetingExpanded = false;
  bool _isApprovalExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  /// Initializes data fetching with smart caching - displays cached data immediately, updates silently
  Future<void> _fetchInitialData() async {
    // Check if we have cached data
    final hasCachedData = await NotificationCacheService.hasCachedData();

    if (hasCachedData) {
      // Load cached data immediately for fast display
      await _loadCachedData();
      setState(() {
        _isLoading = false; // Show UI immediately with cached data
        _isBackgroundLoading = true; // Start background loading
      });

      // Fetch fresh data silently in background
      _fetchFreshDataInBackground();
    } else {
      // No cached data, show loading and fetch everything
      setState(() {
        _isLoading = true;
        _isMeetingExpanded = false;
        _isApprovalExpanded = false;
      });

      await _fetchAllDataAndCache();

      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Load cached data for immediate display
  Future<void> _loadCachedData() async {
    try {
      // Load cached leave types
      final cachedLeaveTypes =
          await NotificationCacheService.getCachedLeaveTypes();
      if (cachedLeaveTypes != null) {
        setState(() {
          _leaveTypesMap = cachedLeaveTypes;
        });
      }

      // Load cached meeting invites
      final cachedMeetings =
          await NotificationCacheService.getCachedMeetingInvites();
      if (cachedMeetings != null) {
        setState(() {
          _meetingInvites = cachedMeetings;
        });
      }

      // Load cached pending items
      final cachedPending =
          await NotificationCacheService.getCachedPendingItems();
      if (cachedPending != null) {
        setState(() {
          _pendingItems = cachedPending;
        });
      }

      // Load cached history items
      final cachedHistory =
          await NotificationCacheService.getCachedHistoryItems();
      if (cachedHistory != null) {
        setState(() {
          _historyItems = cachedHistory;
        });
      }

      if (kDebugMode) {
        debugPrint('Cached data loaded successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading cached data: $e');
      }
    }
  }

  /// Fetch fresh data in background and update cache
  Future<void> _fetchFreshDataInBackground() async {
    try {
      await _fetchAllDataAndCache();

      setState(() {
        _isBackgroundLoading = false;
      });

      if (kDebugMode) {
        debugPrint('Background data update completed');
      }
    } catch (e) {
      setState(() {
        _isBackgroundLoading = false;
      });

      if (kDebugMode) {
        debugPrint('Background data update failed: $e');
      }
    }
  }

  /// Fetch all data and update cache
  Future<void> _fetchAllDataAndCache() async {
    try {
      await _fetchLeaveTypes();
      await Future.wait([
        _fetchPendingItems(),
        _fetchMeetingInvites(),
        _fetchHistoryItems(),
      ]);

      // Update cache with fresh data
      await _updateAllCaches();

      if (kDebugMode) {
        debugPrint('All data fetched and cached successfully.');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Error fetching data: $e');
        debugPrint(stackTrace.toString());
      }
      rethrow;
    }
  }

  /// Update all caches with current data
  Future<void> _updateAllCaches() async {
    try {
      await Future.wait([
        NotificationCacheService.cacheLeaveTypes(_leaveTypesMap),
        NotificationCacheService.cacheMeetingInvites(_meetingInvites),
        NotificationCacheService.cachePendingItems(_pendingItems),
        NotificationCacheService.cacheHistoryItems(_historyItems),
      ]);

      if (kDebugMode) {
        debugPrint('All caches updated successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating caches: $e');
      }
    }
  }

  /// Fetches leave types from the API and populates the _leaveTypesMap
  Future<void> _fetchLeaveTypes() async {
    String leaveTypesApiUrl = '$baseUrl/api/leave-types';

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // Use centralized auth validation with redirect
      if (!await AuthUtils.validateTokenAndRedirect(token)) {
        throw Exception('User not authenticated');
      }

      // Fetch directly and update state (cache is handled in _updateAllCaches)
      await _fetchAndCacheLeaveTypes(prefs, token!, leaveTypesApiUrl);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Error fetching leave types: $e');
      }
      if (kDebugMode) {
        debugPrint(stackTrace.toString());
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching leave types: $e')),
      );
      rethrow; // So that _fetchInitialData catches and handles
    }
  }

  /// Fetches leave types from API and updates state
  Future<void> _fetchAndCacheLeaveTypes(
      SharedPreferences prefs, String token, String leaveTypesApiUrl) async {
    try {
      final leaveTypesResponse = await http.get(
        Uri.parse(leaveTypesApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (kDebugMode) {
        debugPrint(
            'Fetching leave types: Status Code ${leaveTypesResponse.statusCode}');
      }

      if (leaveTypesResponse.statusCode == 200) {
        final responseBody = jsonDecode(leaveTypesResponse.body);
        if (responseBody['statusCode'] == 200 &&
            responseBody['results'] != null) {
          final List<dynamic> leaveTypesData = responseBody['results'];
          final Map<int, String> newLeaveTypesMap = {
            for (var item in leaveTypesData)
              item['leave_type_id'] as int: item['name'].toString()
          };

          setState(() {
            _leaveTypesMap = newLeaveTypesMap;
          });

          if (kDebugMode) {
            debugPrint('Leave types loaded: $_leaveTypesMap');
          }
        } else {
          throw Exception(
              responseBody['message'] ?? 'Failed to load leave types');
        }
      } else {
        throw Exception('Failed to load leave types');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in _fetchAndCacheLeaveTypes: $e');
      }
      rethrow; // Rethrow to be handled by caller
    }
  }

  /// Fetches all pending approval items without pagination
  Future<void> _fetchPendingItems() async {
    String meetingEndpoint =
        '$baseUrl/api/office-administration/book_meeting_room/invites-meeting';
    String carEndpoint =
        '$baseUrl/api/office-administration/car_permits/invites-car-member';

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // Use centralized auth validation with redirect
      if (!await AuthUtils.validateTokenAndRedirect(token)) {
        throw Exception('User not authenticated');
      }

      List<Map<String, dynamic>> allPendingItems = [];

      // Fetch Meeting invites
      await _fetchDataFromEndpoint(
          meetingEndpoint, token!, allPendingItems, 'meeting');

      // Fetch Car permits
      await _fetchDataFromEndpoint(carEndpoint, token, allPendingItems, 'car');

      setState(() {
        _pendingItems = allPendingItems;
      });

      if (kDebugMode) {
        debugPrint('Pending items loaded: ${_pendingItems.length} items.');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Error fetching pending data: $e');
      }
      if (kDebugMode) {
        debugPrint(stackTrace.toString());
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching pending data: $e')),
      );
      rethrow;
    }
  }

  /// Helper method to fetch data from a specific endpoint
  Future<void> _fetchDataFromEndpoint(String url, String token,
      List<Map<String, dynamic>> itemsList, String itemType) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (kDebugMode) {
        debugPrint('Fetching from $url: Status Code ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['statusCode'] == 200 &&
            responseBody['results'] != null) {
          final List<dynamic> dataItems = responseBody['results'];

          // Get current user ID to filter out own events
          final prefs = await SharedPreferences.getInstance();
          final currentUserId = prefs.getString('employee_id');

          if (kDebugMode) {
            debugPrint('Current user ID: $currentUserId');
          }

          for (var item in dataItems) {
            final Map<String, dynamic> dataItem =
                Map<String, dynamic>.from(item);

            // Check if this item is created by current user
            bool isCreatedByCurrentUser = false;
            String creatorId = '';

            if (itemType == 'car') {
              creatorId = dataItem['requestor_id']?.toString() ?? '';
            } else {
              creatorId = dataItem['employee_id']?.toString() ?? '';
            }

            isCreatedByCurrentUser = creatorId == currentUserId;

            // Only add items NOT created by current user (notifications are for invitations from others)
            if (!isCreatedByCurrentUser) {
              // Add type to distinguish different items
              dataItem['types'] = itemType;
              itemsList.add(dataItem);
            }
          }

          if (kDebugMode) {
            debugPrint(
                'Loaded ${itemsList.length} $itemType items after filtering');
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching from $url: $e');
    }
  }

  /// Fetches all history approval items without pagination
  Future<void> _fetchHistoryItems() async {
    String meetingEndpoint =
        '$baseUrl/api/office-administration/book_meeting_room/invites-meeting';
    String carEndpoint =
        '$baseUrl/api/office-administration/car_permits/invites-car-member';

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('User not authenticated');
      }

      List<Map<String, dynamic>> allHistoryItems = [];

      // Fetch Meeting history
      await _fetchDataFromEndpoint(
          meetingEndpoint, token, allHistoryItems, 'meeting');

      // Fetch Car history
      await _fetchDataFromEndpoint(carEndpoint, token, allHistoryItems, 'car');

      // Filter to only include completed/history items
      allHistoryItems = allHistoryItems.where((item) {
        String status = (item['status']?.toString() ?? '').toLowerCase();
        return status == 'approved' ||
            status == 'rejected' ||
            status == 'completed' ||
            status == 'disapproved';
      }).toList();

      setState(() {
        _historyItems = allHistoryItems;
      });

      if (kDebugMode) {
        debugPrint('History items loaded: ${_historyItems.length} items.');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Error fetching history data: $e');
      }
      if (kDebugMode) {
        debugPrint(stackTrace.toString());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching history data: $e')),
        );
      }
      rethrow;
    }
  }

  /// Fetches all meeting invites without pagination
  Future<void> _fetchMeetingInvites() async {
    String meetingInvitesApiUrl =
        '$baseUrl/api/office-administration/book_meeting_room/invites-meeting';
    String outMeetingApiUrl =
        '$baseUrl/api/work-tracking/out-meeting/outmeeting/my-members';

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('User not authenticated');
      }

      List<Map<String, dynamic>> allMeetings = [];

      // Fetch Meeting and Booking Room Invites
      await _fetchMeetingsFromUrl(
          meetingInvitesApiUrl, token, allMeetings, 'meeting');

      // Fetch Out Meeting Invites
      await _fetchMeetingsFromUrl(
          outMeetingApiUrl, token, allMeetings, 'out-meeting');

      setState(() {
        _meetingInvites = allMeetings;
      });

      if (kDebugMode) {
        debugPrint('Total meeting invites loaded: ${_meetingInvites.length}');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Error fetching meeting invites: $e');
        debugPrint(stackTrace.toString());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No meeting invites',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      rethrow;
    }
  }

  Future<void> _fetchMeetingsFromUrl(String url, String token,
      List<Map<String, dynamic>> allMeetings, String type) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (kDebugMode) {
        debugPrint('Fetching from $url: Status Code ${response.statusCode}');
        if (response.statusCode == 200) {
          final responseBody = jsonDecode(response.body);
          debugPrint('Response data structure: ${responseBody.keys}');
          if (responseBody['results'] != null) {
            debugPrint('Results count: ${responseBody['results'].length}');
          }
        }
      }

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['statusCode'] == 200 &&
            responseBody['results'] != null) {
          final List<dynamic> meetingData = responseBody['results'];

          // Get current user ID to filter out own events
          final prefs = await SharedPreferences.getInstance();
          final currentUserId = prefs.getString('employee_id');

          if (kDebugMode) {
            debugPrint(
                'Found ${meetingData.length} items for $type before filtering');
            debugPrint('Current user ID: $currentUserId');
          }

          int addedCount = 0;
          for (var item in meetingData) {
            final Map<String, dynamic> meetingItem =
                Map<String, dynamic>.from(item);

            // Check if this meeting is created by current user
            bool isCreatedByCurrentUser = false;
            String creatorId = '';

            if (type == 'meeting') {
              creatorId = meetingItem['employee_id']?.toString() ?? '';
            } else if (type == 'out-meeting') {
              creatorId = meetingItem['created_by']?.toString() ?? '';
            }

            isCreatedByCurrentUser = creatorId == currentUserId;

            // Only add meetings NOT created by current user
            if (!isCreatedByCurrentUser) {
              meetingItem['types'] = type;
              // Add display type label based on the endpoint
              if (type == 'meeting') {
                meetingItem['display_type'] =
                    'Meeting and Booking Meeting Room';
              } else if (type == 'out-meeting') {
                meetingItem['display_type'] = 'Add Meeting';
                // For out-meeting, add UID to ensure we have an ID to click on
                if (meetingItem['uid'] == null &&
                    meetingItem['outmeeting_uid'] != null) {
                  meetingItem['uid'] = meetingItem['outmeeting_uid'];
                }
              }
              allMeetings.add(meetingItem);
              addedCount++;

              if (kDebugMode && type == 'out-meeting') {
                debugPrint(
                    'Out-meeting item added: ${meetingItem['title']} - ID: ${meetingItem['uid'] ?? meetingItem['outmeeting_uid']}');
              }
            }
          }

          if (kDebugMode) {
            debugPrint('Added $addedCount items for $type after filtering');
          }
        } else {
          if (kDebugMode) {
            debugPrint(
                'Failed to load data from $url: ${responseBody['message']}');
          }
          throw Exception(responseBody['message'] ?? 'Failed to load');
        }
      } else {
        if (kDebugMode) {
          debugPrint(
              'HTTP Error from $url: ${response.statusCode} - ${response.reasonPhrase}');
          debugPrint('Response body: ${response.body}');
        }
        throw Exception('Failed to load');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in _fetchMeetingsFromUrl for $url: $e');
      }
      // Don't rethrow here to allow other endpoints to still work
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
          // Linear loading indicator under header
          LinearLoadingIndicator(
            isLoading: _isLoading || _isBackgroundLoading,
            color: isDarkMode ? Colors.amber.shade700 : Colors.amber,
            height: 3.0,
          ),
          SizedBox(height: screenSize.height * 0.01),
          _buildTabBar(screenSize),
          SizedBox(height: screenSize.height * 0.008),
          _isLoading
              ? Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          size: screenSize.width * 0.15,
                          color: isDarkMode
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                        ),
                        SizedBox(height: screenSize.height * 0.02),
                        Text(
                          'Loading notifications...',
                          style: TextStyle(
                            fontSize: screenSize.width * 0.04,
                            color: isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      // Clear cache and fetch fresh data for manual refresh
                      await NotificationCacheService.clearAllCache();
                      await _fetchInitialData();
                    },
                    child: _isMeetingSelected
                        ? _meetingInvites.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.meeting_room_outlined,
                                      size: screenSize.width * 0.15,
                                      color: isDarkMode
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade400,
                                    ),
                                    SizedBox(height: screenSize.height * 0.02),
                                    Text(
                                      'No Meeting Invites',
                                      style: TextStyle(
                                        fontSize: screenSize.width * 0.045,
                                        color: isDarkMode
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _buildMeetingList(screenSize)
                        : (_pendingItems.isEmpty && _historyItems.isEmpty)
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.approval_outlined,
                                      size: screenSize.width * 0.15,
                                      color: isDarkMode
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade400,
                                    ),
                                    SizedBox(height: screenSize.height * 0.02),
                                    Text(
                                      'No Approval',
                                      style: TextStyle(
                                        fontSize: screenSize.width * 0.045,
                                        color: isDarkMode
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
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
    // Change from 30 to 15 for initial display, and limit max to 40 items
    int itemCount = _isMeetingExpanded
        ? (_meetingInvites.length > 40 ? 40 : _meetingInvites.length)
        : (_meetingInvites.length > 15 ? 15 : _meetingInvites.length);

    // Show View More if there are more than 15 items and not expanded
    bool showViewMore = _meetingInvites.length > 15 && !_isMeetingExpanded;

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
    List<Map<String, dynamic>> combinedApprovalItems = [
      ..._pendingItems,
      ..._historyItems
    ];

    // If no items, display centered message
    if (combinedApprovalItems.isEmpty) {
      return Center(
        child: Text(
          'No Approval Invitation',
          style: TextStyle(
            fontSize: screenSize.width * 0.045,
          ),
        ),
      );
    }

    // Change from 30 to 15 for initial display, and limit max to 40 items
    int itemCount = _isApprovalExpanded
        ? (combinedApprovalItems.length > 40
            ? 40
            : combinedApprovalItems.length)
        : (combinedApprovalItems.length > 15
            ? 15
            : combinedApprovalItems.length);

    // Show View More if there are more than 15 items and not expanded
    bool showViewMore =
        combinedApprovalItems.length > 15 && !_isApprovalExpanded;

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
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;

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
                  color: _isMeetingSelected
                      ? (isDarkMode ? Colors.amber.shade700 : Colors.amber)
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
                    Icon(
                      Icons.meeting_room,
                      size: screenSize.width * 0.07,
                      color: _isMeetingSelected
                          ? Colors.white
                          : (isDarkMode
                              ? Colors.grey.shade300
                              : Colors.grey.shade600),
                    ),
                    SizedBox(width: screenSize.width * 0.02),
                    Text(
                      'Meeting',
                      style: TextStyle(
                        color: _isMeetingSelected
                            ? Colors.white
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
                  color: !_isMeetingSelected
                      ? (isDarkMode ? Colors.amber.shade700 : Colors.amber)
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
                      'assets/pending.png',
                      width: screenSize.width * 0.07,
                      height: screenSize.width * 0.07,
                      color: !_isMeetingSelected
                          ? Colors.white
                          : (isDarkMode
                              ? Colors.grey.shade300
                              : Colors.grey.shade600),
                    ),
                    SizedBox(width: screenSize.width * 0.02),
                    Text(
                      'Approval',
                      style: TextStyle(
                        color: !_isMeetingSelected
                            ? Colors.white
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

  /// Builds each item card for Meeting or Approval.
  Widget _buildItemCard(BuildContext context, Map<String, dynamic> item,
      {required bool isHistory, required Size screenSize}) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;

    String type = (item['types']?.toString().toLowerCase() ?? 'unknown').trim();
    String displayType = (item['display_type']?.toString() ?? type).trim();
    String status = (item['status']?.toString() ?? 'Pending').trim();
    String employeeName = (item['employee_name']?.toString() ?? 'N/A').trim();
    String requestorName = (item['requestor_name']?.toString() ?? 'N/A').trim();

    // For out-meeting, use created_by_name instead of employee_name
    if (type == 'out-meeting' && item['created_by_name'] != null) {
      employeeName = (item['created_by_name']?.toString() ?? 'N/A').trim();
    }

    if (status.toLowerCase() == 'branch approved') {
      status = 'Approved';
    } else if (status.toLowerCase() == 'branch waiting') status = 'Waiting';

    String id = (item['uid']?.toString() ?? '').trim();
    // For out-meeting, use outmeeting_uid if uid is empty
    if (id.isEmpty && type == 'out-meeting') {
      id = (item['outmeeting_uid']?.toString() ?? '').trim();
    }

    if (id.isEmpty) return const SizedBox.shrink();

    String imgName = item['img_name']?.toString().trim() ?? '';
    String imgPath = item['img_path']?.toString().trim() ?? '';

    // Determine employee image URL
    String employeeImage = (imgPath.isNotEmpty && imgPath.startsWith('http'))
        ? imgPath
        : (imgName.isNotEmpty && imgName.startsWith('http'))
            ? imgName
            : 'https://via.placeholder.com/150';

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
        detailLabel = 'Employee';
        detailValue = employeeName;
        break;
      case 'out-meeting':
        title = item['title']?.toString() ?? 'No Title';
        startDate = item['fromdate']?.toString() ?? '';
        endDate = item['todate']?.toString() ?? '';
        detailLabel = 'Created By';
        detailValue = employeeName;
        break;
      case 'leave':
        int leaveTypeId = item['leave_type_id'] ?? 0;
        title = _leaveTypesMap[leaveTypeId] ?? 'Unknown Leave';
        startDate = item['take_leave_from']?.toString() ?? '';
        endDate = item['take_leave_to']?.toString() ?? '';
        detailLabel = 'Leave Type';
        detailValue = title;
        break;
      case 'car':
        title = item['purpose']?.toString() ?? 'No Purpose';
        startDate = item['date_out']?.toString() ?? '';
        endDate = item['date_in']?.toString() ?? '';
        detailLabel = 'Requestor';
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

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              if (type == 'out-meeting' && _isMeetingSelected) {
                return NotificationMeetingDetailsPage(
                    id: id, isOutMeeting: true);
              } else if (type == 'meeting' && _isMeetingSelected) {
                return NotificationMeetingDetailsPage(id: id);
              } else {
                return NotificationApprovalsDetailsPage(id: id, type: type);
              }
            },
          ),
        );

        if (result == true) _fetchInitialData();
      },
      child: Card(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenSize.width * 0.04),
          side: BorderSide(color: typeColor, width: screenSize.width * 0.004),
        ),
        margin: EdgeInsets.symmetric(vertical: screenSize.height * 0.005),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: screenSize.height * 0.008,
            horizontal: screenSize.width * 0.02,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Fixed Icon Section to maintain alignment
              SizedBox(
                width: screenSize.width * 0.14,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(typeIcon,
                        color: typeColor, size: screenSize.width * 0.08),
                    SizedBox(height: screenSize.height * 0.002),
                    Text(
                      displayType.length > 12
                          ? '${displayType.substring(0, 12)}...' // Truncate if too long
                          : displayType,
                      style: TextStyle(
                        color: typeColor,
                        fontSize: screenSize.width * 0.025,
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
                    SizedBox(height: screenSize.height * 0.003),
                    if (startDate.isNotEmpty && endDate.isNotEmpty)
                      Text(
                        '${_formatDate(startDate)} → ${_formatDate(endDate)}',
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.white70
                              : Colors.grey.shade700,
                          fontSize: screenSize.width * 0.028,
                        ),
                      ),
                    SizedBox(height: screenSize.height * 0.002),
                    Text(
                      '$detailLabel: $detailValue',
                      style: TextStyle(
                        color:
                            isDarkMode ? Colors.white70 : Colors.grey.shade700,
                        fontSize: screenSize.width * 0.028,
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.005),
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
              debugPrint('Error loading employee image from $imageUrl: $error');
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
      debugPrint('Date parsing error for "$dateStr": $e');
      if (kDebugMode) {
        debugPrint(stackTrace.toString());
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
      case 'public':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Returns color based on type
  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return Colors.green;
      case 'out-meeting':
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
      case 'out-meeting':
        return Icons.event_available;
      case 'leave':
        return Icons.event;
      case 'car':
        return Icons.directions_car;
      default:
        return Icons.info;
    }
  }
}
