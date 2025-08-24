// ignore_for_file: empty_catches, use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'dart:async';
import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart';
import 'package:pb_hrsystem/core/standard/color.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/core/standard/extension.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/core/widgets/calendar_day/calendar_day_switch_view.dart';
import 'package:pb_hrsystem/core/widgets/snackbar/snackbar.dart';
import 'package:pb_hrsystem/core/widgets/linear_loading_indicator.dart';
import 'package:pb_hrsystem/home/office_events/office_add_event.dart';
import 'package:pb_hrsystem/home/timetable_page.dart';
import 'package:pb_hrsystem/login/date.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:pb_hrsystem/services/http_service.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:pb_hrsystem/home/leave_request_page.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pb_hrsystem/l10n/app_localizations.dart';

abstract class Refreshable {
  void refresh();
  void forceCompleteRefresh();
}

class HomeCalendar extends StatefulWidget {
  const HomeCalendar({super.key});

  @override
  HomeCalendarState createState() => HomeCalendarState();
}

// Global key for accessing HomeCalendar state
final GlobalKey<HomeCalendarState> homeCalendarGlobalKey =
    GlobalKey<HomeCalendarState>();

class HomeCalendarState extends State<HomeCalendar>
    with TickerProviderStateMixin
    implements Refreshable {
  late Box eventsBox;

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  // ValueNotifier to hold events mapped by date
  final selectedSlot = ValueNotifier(1);
  final switchTime = ValueNotifier(false);

  // Calendar properties
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now().toLocal();
  DateTime? _selectedDay;
  DateTime? _singleTapSelectedDay;

  // Notifications
  late final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  // Filters and Search
  final String _selectedCategory = 'All';
  final String _searchQuery = '';

  // Animation Controller
  late final AnimationController _animationController;

  // Double Tap Timer
  Timer? _doubleTapTimer;
  static const int doubleTapDelay = 300;

  // Loading States
  bool _isBackgroundLoading = false;

  // Add at the top of the class after other variables
  final _eventCountsCache = <DateTime, Map<String, int>>{};
  final _processedEventsCache = <DateTime, List<Events>>{};

  // Performance optimization will be used in future iterations

  // Animasi untuk ikon plus
  late AnimationController _plusIconController;
  late Animation<double> _plusIconRotation;

  // Animasi untuk teks "No events for this day"
  late AnimationController _typingController;
  late Animation<double> _typingAnimation;

  /// Handles pull-to-refresh action with update information
  Key _refreshKey = UniqueKey();

  // Activation flag to ensure background work only runs when navigated to
  bool _activated = false;

  // Static accessor for parent to get state
  static HomeCalendarState? of(BuildContext context) {
    return context.findAncestorStateOfType<HomeCalendarState>();
  }

  @override
  void initState() {
    super.initState();
    // Only initialize animation controllers and variables, NO data loading or listeners
    _selectedDay = _focusedDay;
    switchTime.value =
        (_focusedDay.hour < 18 && _focusedDay.hour > 6) ? false : true;
    eventsForDay = [];
    eventsForAll = [];
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _plusIconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _plusIconRotation = Tween<double>(begin: 0, end: 0.05).animate(
      CurvedAnimation(
        parent: _plusIconController,
        curve: Curves.easeInOut,
      ),
    );
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _typingAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _typingController,
        curve: Curves.easeInOut,
      ),
    );
    _isBackgroundLoading = false;
    // NO data loading, cache, or listeners here!
  }

  /// Call this when the user navigates to the calendar page.
  void activateCalendarPage() {
    if (_activated) return;
    _activated = true;

    // Check if this is first time user (no local storage data)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkFirstTimeUserAndLoad();
    });

    // Handle connectivity changes smoothly - with mounted checks
    connectivityResult.onConnectivityChanged.listen((source) async {
      if (!mounted) return;
      if (source.contains(ConnectivityResult.none)) {
        await _loadLocalData();
      } else {
        // No longer doing silent background refresh - data is loaded on demand
        debugPrint(
            'Connectivity restored - data will be loaded on next navigation');
      }
    });
  }

  /// Check if first time user and load data accordingly
  Future<void> _checkFirstTimeUserAndLoad() async {
    try {
      // Check if we have local storage data
      final hasLocalData = await _hasLocalStorageData();

      if (hasLocalData) {
        // Returning user - load from local storage instantly
        debugPrint('🔄 Returning user - loading from local storage');
        await _loadLocalDataInstantly();
        _isFirstTimeUser = false;
      } else {
        // First time user - show loading modal and fetch from API
        debugPrint(
            '🆕 First time user - showing loading modal and fetching from API');
        _isFirstTimeUser = true;
        _isBackgroundLoading = true;

        if (mounted) {
          setState(() {});
        }

        // Fetch all data from API and save to local storage
        await _fetchAndSaveAllData();

        _isFirstTimeUser = false;
        _isBackgroundLoading = false;

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error in first time user check: $e');
      // Fallback to local data if available
      await _loadLocalData();
    }
  }

  /// Check if local storage has data
  Future<bool> _hasLocalStorageData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCachedEvents = prefs.getString('cached_calendar_events') != null;
      final hasLocalEvents = await offlineProvider.getCalendar();

      return hasCachedEvents || hasLocalEvents.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking local storage: $e');
      return false;
    }
  }

  /// Load data from local storage instantly (no loading indicators)
  Future<void> _loadLocalDataInstantly() async {
    try {
      // Try SharedPreferences first
      final prefs = await SharedPreferences.getInstance();
      final cachedEventsJson = prefs.getString('cached_calendar_events');

      if (cachedEventsJson != null && cachedEventsJson.isNotEmpty) {
        try {
          final List<dynamic> eventsList = jsonDecode(cachedEventsJson);
          final List<Events> parsedEvents = [];

          for (var item in eventsList) {
            try {
              final Map<String, dynamic> eventData =
                  Map<String, dynamic>.from(item);
              final event = Events.fromJson(eventData);
              parsedEvents.add(event);
            } catch (e) {
              debugPrint('Error parsing individual event: $e');
              debugPrint('Problematic event data: ${jsonEncode(item)}');
              // Continue with other events
            }
          }

          if (parsedEvents.isNotEmpty) {
            eventsForAll.clear();
            events.value.clear();
            eventsForAll.addAll(parsedEvents);
            addEventOffline(parsedEvents);

            debugPrint(
                '⚡ Loaded ${parsedEvents.length} events from SharedPreferences');

            // Debug: Count events by category
            final Map<String, int> categoryCounts = {};
            for (final event in parsedEvents) {
              categoryCounts[event.category] =
                  (categoryCounts[event.category] ?? 0) + 1;
            }
            debugPrint('📊 Events by category: $categoryCounts');

            // Mark as loaded from local storage to prevent duplicate insertions
            _hasLoadedFromLocalStorage = true;

            return;
          }
        } catch (e) {
          debugPrint('Error parsing cached events JSON: $e');
        }
      }

      // Fallback to offline provider
      try {
        final localEvents = await offlineProvider.getCalendar();
        if (localEvents.isNotEmpty) {
          eventsForAll.clear();
          events.value.clear();
          eventsForAll.addAll(localEvents);
          addEventOffline(localEvents);

          debugPrint(
              '⚡ Loaded ${localEvents.length} events from offline provider');
        }
      } catch (e) {
        debugPrint('Error loading from offline provider: $e');
      }
    } catch (e) {
      debugPrint('Error loading local data instantly: $e');
    }
  }

  /// Fetch all data from API and save to local storage
  Future<void> _fetchAndSaveAllData() async {
    try {
      // Clear current data
      eventsForAll.clear();
      events.value.clear();

      // Fetch all data concurrently
      await Future.wait([
        _fetchMeetingData(),
        _fetchLeaveRequests(),
        _fetchMeetingRoomBookings(),
        _fetchMeetingRoomInvite(),
        _fetchCarBookings(),
        _fetchCarBookingsInvite(),
        _fetchMinutesOfMeeting(),
        _fetchMeetingMembers(),
      ]);

      // Save to local storage
      if (eventsForAll.isNotEmpty) {
        await _saveToLocalStorage();
        // Only insert to offline provider if not already loaded from local storage
        if (!_hasLoadedFromLocalStorage) {
          await offlineProvider.insertCalendar(eventsForAll);
        }
        debugPrint('💾 Saved ${eventsForAll.length} events to local storage');
      }
    } catch (e) {
      debugPrint('Error fetching and saving data: $e');
    }
  }

  /// Save events to local storage
  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> eventsJson = eventsForAll.map((event) {
        return event.toJson();
      }).toList();

      await prefs.setString('cached_calendar_events', jsonEncode(eventsJson));
      await prefs.setInt(
          'calendar_cache_timestamp', DateTime.now().millisecondsSinceEpoch);

      debugPrint('💾 Events saved to SharedPreferences');
    } catch (e) {
      debugPrint('Error saving to local storage: $e');
    }
  }

  /// Process events in background to avoid UI lag
  void _processEventsInBackground() {
    // Use Future.microtask to process on next frame, avoiding UI blocking
    Future.microtask(() {
      if (!mounted) return;
      _filterAndSearchEvents();
    });
  }

  /// Smooth UI update without causing lag
  void _smoothUIUpdate() {
    // Use addPostFrameCallback to ensure smooth updating
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Only call setState if widget is still mounted and stable
      setState(() {
        // Minimal state change to trigger rebuild
      });
    });
  }

  @override
  void dispose() {
    _eventCountsCache.clear();
    _processedEventsCache.clear();
    _animationController.dispose();
    _doubleTapTimer?.cancel();
    _plusIconController.dispose();
    _typingController.dispose();
    super.dispose();
  }

  void addEvent(DateTime date, Events event) {
    if (date.year == _selectedDay?.year) {
      eventsForAll.add(event);
    }

    final detectDate = normalizeDate(date);
    if (events.value.containsKey(detectDate)) {
      // If the date already has events, add to the list
      if (events.value[detectDate]!
          .where((desc) => desc.desc == event.desc)
          .isEmpty) {
        events.value[detectDate]!.add(event);
      } else {
        event.members?.forEach(
          (e) => events.value[detectDate]!
              .where((desc) => desc.desc == event.desc)
              .first
              .members
              ?.add(e),
        );
      }
    } else {
      // Otherwise, create a new list with this event
      events.value[detectDate] = [event];
    }
  }

  void addEventOffline(List<Events> eventOffline) {
    for (var i in eventOffline) {
      final normalizedStartDay = normalizeDate(i.start);
      final normalizedEndDay = normalizeDate(i.end);

      for (var day = normalizedStartDay;
          !day.isAfter(normalizedEndDay);
          day = day.add(const Duration(days: 1))) {
        final detectDate = normalizeDate(day);

        if (events.value.containsKey(detectDate)) {
          // If the date already has events, add to the list
          if (events.value[detectDate]!
              .where((desc) => desc.desc == i.desc)
              .isEmpty) {
            events.value[detectDate]!.add(i);
          } else {
            i.members?.forEach(
              (e) => events.value[detectDate]!
                  .where((desc) => desc.desc == i.desc)
                  .first
                  .members
                  ?.add(e),
            );
          }
        } else {
          // Otherwise, create a new list with this event
          events.value[detectDate] = [i];
        }
      }
    }
    // Only call _eventsOffline() if we have a selected day
    if (_selectedDay != null) {
      _eventsOffline();
    }
  }

  /// Smart caching strategy for calendar data (legacy method - now using new loading strategy)
  // ignore: unused_element
  Future<void> _fetchCalendarData() async {
    // This method is kept for compatibility but now just calls the new loading strategy
    await _checkFirstTimeUserAndLoad();
  }

  /// Fetches all required data concurrently
  Future<void> fetchData({bool showUpdateInfo = false}) async {
    try {
      // Store previous event count to compare after fetching
      final Set<String> previousEventIds =
          eventsForAll.map((e) => e.uid).toSet();

      // Clear previous data before fetching new data
      _clearCaches();

      // Empty the events list to avoid duplication
      eventsForAll.clear();
      events.value.clear();

      await Future.wait([
        _fetchMeetingData(),
        _fetchLeaveRequests(),
        _fetchMeetingRoomBookings(),
        _fetchMeetingRoomInvite(),
        _fetchCarBookings(),
        _fetchCarBookingsInvite(),
        _fetchMinutesOfMeeting(),
        _fetchMeetingMembers(),
      ]);

      // Calculate new events statistics
      final int newEventCount = eventsForAll.length;
      final Set<String> currentEventIds =
          eventsForAll.map((e) => e.uid).toSet();
      final Set<String> newEventIds =
          currentEventIds.difference(previousEventIds);
      final int updatedEventCount = newEventIds.length;

      // Count events by category
      final Map<String, int> updatedEventsByCategory = {};
      for (final event in eventsForAll) {
        if (newEventIds.contains(event.uid)) {
          updatedEventsByCategory[event.category] =
              (updatedEventsByCategory[event.category] ?? 0) + 1;
        }
      }

      // Save to local storage (both SharedPreferences and offline provider)
      if (eventsForAll.isNotEmpty) {
        await _saveToLocalStorage();
        // Reset flag since this is fresh data from API
        _hasLoadedFromLocalStorage = false;
        await offlineProvider.insertCalendar(eventsForAll);
        debugPrint('💾 Saved ${eventsForAll.length} events to local storage');

        // Show update info if requested and there are updates
        if (showUpdateInfo && mounted && updatedEventCount > 0) {
          _showUpdateInfoSnackbar(
              updatedEventCount: updatedEventCount,
              totalEventCount: newEventCount,
              updatedEventsByCategory: updatedEventsByCategory);
        }
      }
    } catch (e) {
      debugPrint('Error fetching calendar data: $e');
      // If fetch fails, load from local storage as fallback
      await _loadLocalData();
    } finally {
      // Process events in background to avoid UI lag
      _processEventsInBackground();

      // Smooth UI update only if mounted
      if (mounted) {
        _smoothUIUpdate();
      }
    }
  }

  /// Fetches all required data concurrently
  Future<void> fetchDataPass() async {
    try {
      // Use Future.wait to fetch all data in parallel for better performance
      await Future.wait([
        _fetchMeetingData()
            .catchError((e) => debugPrint('Error fetching meeting data: $e')),
        _fetchLeaveRequests()
            .catchError((e) => debugPrint('Error fetching leave requests: $e')),
        _fetchMeetingRoomBookings().catchError(
            (e) => debugPrint('Error fetching meeting room bookings: $e')),
        _fetchMeetingRoomInvite().catchError(
            (e) => debugPrint('Error fetching meeting room invites: $e')),
        _fetchCarBookings()
            .catchError((e) => debugPrint('Error fetching car bookings: $e')),
        _fetchCarBookingsInvite().catchError(
            (e) => debugPrint('Error fetching car booking invites: $e')),
        _fetchMinutesOfMeeting().catchError(
            (e) => debugPrint('Error fetching minutes of meeting: $e')),
        _fetchMeetingMembers().catchError(
            (e) => debugPrint('Error fetching meeting members: $e')),
      ]);

      // Apply filters and search after all data is loaded in background
      _processEventsInBackground();
    } catch (e) {
      debugPrint('Error during fetchDataPass: $e');
    } finally {
      // Smooth UI update only if mounted
      if (mounted) {
        _smoothUIUpdate();
      }
    }
  }

  @override
  void refresh() async {
    await fetchDataPass(); // Refresh data when triggered from the bottom navigation bar
  }

  @override
  void forceCompleteRefresh() async {
    // Force a complete refresh of all data sources
    debugPrint('Forcing complete calendar data refresh');

    // Reset refresh state
    _isRefreshing = false;

    // Start by clearing any cached data
    try {
      if (eventsBox.isOpen) {
        await eventsBox.clear();
      }
      events.value.clear();
      eventsForDay.clear();
      eventsForAll.clear();

      // Clear the caches
      _clearCaches();

      // Fetch everything fresh from APIs without showing loading states
      await fetchData(showUpdateInfo: false);
    } catch (e) {
      debugPrint('Error during forced calendar refresh: $e');
    }
  }

  /// Fetches leave requests from the API
  Future<void> _fetchLeaveRequests() async {
    final response = await getRequest('/api/leave_requests');
    if (response == null) return;

    try {
      final List<dynamic> results = json.decode(response.body)['results'];
      final leaveRequests = List<Map<String, dynamic>>.from(results);
      // List<dynamic> resultType;
      String? leaveType;
      for (var item in leaveRequests) {
        // final responseType = await getRequest(context, '/api/leave-type/${item['leave_type_id']}');
        // if (responseType != null) {
        //   resultType = json.decode(responseType.body)['results'];
        //   leaveType = resultType.firstOrNull['name'];
        // }

        final DateTime startDate = item['take_leave_from'] != null
            ? normalizeDate(DateTime.parse(item['take_leave_from']))
            : normalizeDate(DateTime.now());
        final DateTime endDate = item['take_leave_to'] != null
            ? normalizeDate(DateTime.parse(item['take_leave_to']))
            : normalizeDate(DateTime.now());
        final String uid = 'leave_${item['id']}';
        double days;

        if (item['days'].runtimeType == int) {
          days = double.parse(item['days'].toString());
        } else {
          days = item['days'];
        }

        String status = item['is_approve'] != null
            ? _mapLeaveStatus(item['is_approve'].toString())
            : 'Pending';

        if (status == 'Cancelled') continue;

        final event = Events(
          title: item['name'] ?? 'Leave',
          start: startDate,
          end: endDate,
          desc: item['take_leave_reason'] ?? 'Approval Pending',
          status: status,
          isMeeting: false,
          category: 'Leave',
          uid: uid,
          imgName: item['img_name'],
          createdAt: item['updated_at'],
          createdBy: item['requestor_id'],
          days: days,
          leaveType: leaveType,
        );

        for (var day = startDate;
            day.isBefore(endDate.add(const Duration(days: 1)));
            day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {}
  }

  /// Maps API leave status to human-readable status
  String _mapLeaveStatus(String apiStatus) {
    switch (apiStatus.toLowerCase()) {
      case 'approved':
        return 'Approved';
      case 'waiting':
      case 'processing':
        return 'Pending';
      case 'cancel':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  /// Fetches meeting data from the API
  Future<void> _fetchMinutesOfMeeting() async {
    final response =
        await getRequest('/api/work-tracking/meeting/get-all-meeting');
    if (response == null) return;

    try {
      final data = json.decode(response.body);

      if (data == null || data['results'] == null || data['results'] is! List) {
        return;
      }

      final List<dynamic> results = data['results'];

      for (var item in results) {
        // Ensure necessary fields are present
        if (item['from_date'] == null ||
            item['to_date'] == null ||
            item['start_time'] == null ||
            item['end_time'] == null) {
          showSnackBar('Missing date or time fields in meeting data.');
          continue;
        }

        final responseMember = await getRequest(
            '/api/work-tracking/meeting/Meetig-Member/${item['id']}');

        dynamic dataMember;
        List<dynamic> resultsMember = [];
        if (responseMember != null) {
          dataMember = json.decode(responseMember.body);
          resultsMember = dataMember['results'] ?? [];
        }

        // Filter duplicates by employee_id for meeting members
        final seenEmployeeIds = <dynamic>{};
        final uniqueMembers = <Map<String, dynamic>>[];

        for (var member in resultsMember) {
          if (member['employee_id'] != null &&
              !seenEmployeeIds.contains(member['employee_id'])) {
            seenEmployeeIds.add(member['employee_id']);
            uniqueMembers.add(Map<String, dynamic>.from(member));
          }
        }

        // Combine 'from_date' with 'start_time' and 'to_date' with 'end_time'
        DateTime startDateTime;
        DateTime endDateTime;
        try {
          // Parse 'from_date' and 'start_time' separately and combine
          DateTime fromDate = DateTime.parse(item['from_date']);
          List<String> startTimeParts = item['start_time'] != ""
              ? item['start_time'].split(':')
              : ["00", "00"];
          if (startTimeParts.length == 3) startTimeParts.removeLast();
          if (startTimeParts.length != 2) {
            throw const FormatException('Invalid start_time format');
          }
          startDateTime = DateTime(
            fromDate.year,
            fromDate.month,
            fromDate.day,
            int.parse(startTimeParts[0]),
            int.parse(startTimeParts[1]),
          );

          // Parse 'to_date' and 'end_time' separately and combine
          DateTime toDate = DateTime.parse(item['to_date']);
          List<String> endTimeParts = item['end_time'] != ""
              ? item['end_time'].split(':')
              : ["00", "00"];
          if (endTimeParts.length == 3) endTimeParts.removeLast();
          if (endTimeParts.length != 2) {
            throw const FormatException('Invalid end_time format');
          }
          endDateTime = DateTime(
            toDate.year,
            toDate.month,
            toDate.day,
            int.parse(endTimeParts[0]),
            int.parse(endTimeParts[1]),
          );
        } catch (e) {
          showSnackBar('Error parsing meeting dates or times: $e');
          continue;
        }

        final String uid =
            item['meeting_id']?.toString() ?? UniqueKey().toString();
        String status = item['s_name'] != null
            ? mapEventStatus(item['s_name'].toString())
            : 'Pending';
        if (status == 'Cancelled') continue;

        final event = Events(
          title: item['title'] ?? 'Minutes Of Meeting',
          start: startDateTime,
          end: endDateTime,
          desc: item['description'] ?? '',
          status: status,
          isMeeting: true,
          location: item['location'] ?? '',
          createdBy: item['create_by'] ?? '',
          createdAt: item['created_at'] ?? '',
          uid: uid,
          isRepeat: item['is_repeat']?.toString(),
          videoConference: item['video_conference']?.toString(),
          backgroundColor: item['backgroundColor'] != null
              ? parseColor(item['backgroundColor'])
              : Colors.blue,
          outmeetingUid: item['meeting_id']?.toString(),
          category: 'Minutes Of Meeting',
          fileName: item['file_name'],
          members: uniqueMembers, // Use filtered unique members list
        );

        // Normalize the start and end dates for event mapping
        final normalizedStartDay = normalizeDate(startDateTime);
        final normalizedEndDay = normalizeDate(endDateTime);

        for (var day = normalizedStartDay;
            !day.isAfter(normalizedEndDay);
            day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar(
          'We\'re unable to process your request at the moment. Please contact IT support for assistance.');
    }
  }

  /// Fetches meeting out data from the API
  Future<void> _fetchMeetingData() async {
    final response =
        await getRequest('/api/work-tracking/out-meeting/out-meeting');
    if (response == null) return;

    try {
      final data = json.decode(response.body);
      debugPrint('=== Add Meeting API Response ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Raw Response: ${response.body}');
      debugPrint('Decoded Data: $data');

      if (data == null || data['results'] == null || data['results'] is! List) {
        debugPrint('Invalid data format or empty results');
        return;
      }

      final List<dynamic> results = data['results'];
      debugPrint('Number of meetings: ${results.length}');

      for (var item in results) {
        debugPrint('\n=== Processing Meeting ===');
        debugPrint('Meeting ID: ${item['meeting_id']}');
        debugPrint('Title: ${item['title']}');
        debugPrint('Description: ${item['description']}');
        debugPrint('From Date: ${item['fromdate']}');
        debugPrint('To Date: ${item['todate']}');
        debugPrint('Status: ${item['s_name']}');
        debugPrint('Location: ${item['location']}');
        debugPrint('Created By: ${item['created_by_name']}');
        debugPrint('Members: ${item['guests']}');

        // Ensure necessary fields are present
        if (item['fromdate'] == null || item['todate'] == null) {
          showSnackBar('Missing date or time fields in meeting data.');
          continue;
        }

        // Combine 'from_date' with 'start_time' and 'to_date' with 'end_time'
        DateTime startDateTime;
        DateTime endDateTime;
        try {
          // Parse 'from_date' and 'start_time' separately and combine
          DateTime fromDate = DateTime.parse(item['fromdate']);

          startDateTime = DateTime(
            fromDate.year,
            fromDate.month,
            fromDate.day,
            fromDate.hour,
            fromDate.minute,
          );

          // Parse 'to_date' and 'end_time' separately and combine
          DateTime toDate = DateTime.parse(item['todate']);
          endDateTime = DateTime(
            toDate.year,
            toDate.month,
            toDate.day,
            toDate.hour,
            toDate.minute,
          );
        } catch (e) {
          showSnackBar('Error parsing meeting dates or times: $e');
          continue;
        }

        // Handle possible nulls with default values
        final String uid =
            item['outmeeting_uid']?.toString() ?? UniqueKey().toString();

        String status = item['s_name'] != null
            ? mapEventStatus(item['s_name'].toString())
            : 'Pending';

        if (status == 'Cancelled') continue;

        final event = Events(
          title: item['title'] ?? 'Add Meeting',
          start: startDateTime,
          end: endDateTime,
          desc: item['description'] ?? '',
          status: status,
          isMeeting: true,
          location: item['location'] ?? '',
          createdBy: item['created_by_name'] ?? item['create_by'] ?? '',
          imgName: item['img_name'] ?? item['file_name'] ?? '',
          createdAt: item['created_at'] ?? '',
          uid: uid,
          isRepeat: item['is_repeat']?.toString(),
          videoConference: item['video_conference']?.toString(),
          backgroundColor: item['backgroundColor'] != null
              ? parseColor(item['backgroundColor'])
              : Colors.blue,
          outmeetingUid: item['outmeeting_uid']?.toString(),
          category: 'Add Meeting',
          members: item['guests'] != null
              ? List<Map<String, dynamic>>.from(item['guests'])
              : [],
        );

        // Normalize the start and end dates for event mapping
        final normalizedStartDay = normalizeDate(startDateTime);
        final normalizedEndDay = normalizeDate(endDateTime);

        for (var day = normalizedStartDay;
            !day.isAfter(normalizedEndDay);
            day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar(
          'We\'re unable to process your request at the moment. Please contact IT support for assistance.');
    }

    return;
  }

  /// Fetches meeting out data from the API
  Future<void> _fetchMeetingMembers() async {
    final response = await getRequest(
        '/api/work-tracking/out-meeting/outmeeting/my-members');
    if (response == null) return;

    try {
      final data = json.decode(response.body);

      if (data == null || data['results'] == null || data['results'] is! List) {
        return;
      }

      final List<dynamic> results = data['results'];

      for (var item in results) {
        if (item['fromdate'] == null || item['todate'] == null) {
          showSnackBar('Missing date fields in meeting data.');
          continue;
        }

        DateTime startDateTime;
        DateTime endDateTime;
        try {
          DateTime fromDate = DateTime.parse(item['fromdate']);
          startDateTime = DateTime(
            fromDate.year,
            fromDate.month,
            fromDate.day,
            fromDate.hour,
            fromDate.minute,
          );

          DateTime toDate = DateTime.parse(item['todate']);
          endDateTime = DateTime(
            toDate.year,
            toDate.month,
            toDate.day,
            toDate.hour,
            toDate.minute,
          );
        } catch (e) {
          showSnackBar('Error parsing meeting dates or times: $e');
          continue;
        }

        final String uid =
            item['meeting_id']?.toString() ?? UniqueKey().toString();
        String status = item['status'] != null
            ? mapEventStatus(item['status'].toString())
            : 'Pending';
        if (status == 'Cancelled') continue;

        // Filter duplicates by employee_id for minutes of meeting members
        List<Map<String, dynamic>> membersList = item['members'] != null
            ? List<Map<String, dynamic>>.from(item['members'])
            : [];
        final seenEmployeeIds = <dynamic>{};
        final uniqueMembers = <Map<String, dynamic>>[];
        for (var member in membersList) {
          if (member['employee_id'] != null &&
              !seenEmployeeIds.contains(member['employee_id'])) {
            seenEmployeeIds.add(member['employee_id']);
            uniqueMembers.add(member);
          }
        }

        final event = Events(
          title: item['title'] ?? 'Minutes Of Meeting',
          start: startDateTime,
          end: endDateTime,
          desc: item['description'] ?? '',
          status: status,
          isMeeting: true,
          location: item['location'] ?? '',
          createdBy: item['create_by'] ?? '',
          imgName: item['file_name'] ?? '',
          createdAt: item['created_at'] ?? '',
          uid: uid,
          isRepeat: item['is_repeat']?.toString(),
          videoConference: item['video_conference']?.toString(),
          backgroundColor: item['backgroundColor'] != null
              ? parseColor(item['backgroundColor'])
              : Colors.blue,
          outmeetingUid: item['meeting_id']?.toString(),
          category: 'Minutes Of Meeting',
          members: uniqueMembers, // Use filtered unique members list
        );

        final normalizedStartDay = normalizeDate(startDateTime);
        final normalizedEndDay = normalizeDate(endDateTime);

        for (var day = normalizedStartDay;
            !day.isAfter(normalizedEndDay);
            day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar(
          'We\'re unable to process your request at the moment. Please contact IT support for assistance.');
    }
  }

  /// Fetches meeting room bookings from the API
  Future<void> _fetchMeetingRoomInvite() async {
    final response = await getRequest(
        '/api/office-administration/book_meeting_room/invites-meeting');
    if (response == null) return;

    try {
      final List<dynamic> results = json.decode(response.body)['results'] ?? [];
      final minutesMeeting = List<Map<String, dynamic>>.from(results);

      for (var item in minutesMeeting) {
        // final DateTime? startDateTime = item['from_date'] != null ? DateTime.parse(item['from_date']) : null;
        // final DateTime? endDateTime = item['to_date'] != null ? DateTime.parse(item['to_date']) : null;

        String dateFrom = formatDateString(item['from_date_time'].toString());
        String dateTo = formatDateString(item['to_date_time'].toString());
        // String startTime = item['start_time'] != "" ? item['start_time'].toString() : '00:00';
        // String endTime = item['end_time'] != "" ? item['end_time'].toString() : '23:59';

        if (dateFrom.isEmpty || dateTo.isEmpty) {
          debugPrint('Missing from_date or to_date in minutes of meeting.');
          continue;
        }

        DateTime? startDateTime;
        DateTime? endDateTime;

        try {
          // Combine date and time properly
          DateTime fromDate = DateTime.parse(dateFrom);
          // List<String> timeOutParts = startTime.split(':');
          // if (timeOutParts.length == 3) timeOutParts.removeLast();
          // if (timeOutParts.length != 2) {
          //   throw const FormatException('Invalid time_out format');
          // }
          startDateTime = DateTime(
            fromDate.year,
            fromDate.month,
            fromDate.day,
            fromDate.hour,
            fromDate.minute,
          );

          DateTime inDate = DateTime.parse(dateTo);

          endDateTime = DateTime(
            inDate.year,
            inDate.month,
            inDate.day,
            inDate.hour,
            inDate.minute,
          );
        } catch (e) {
          debugPrint('Error parsing car booking dates: $e');
          continue;
        }

        final String uid =
            item['project_id']?.toString() ?? UniqueKey().toString();

        String status = item['statuss'] != null
            ? item['statuss'] == 1
                ? 'Success'
                : 'Pending'
            : 'Pending';

        if (status == 'Cancelled') continue;

        Events? event;
        event = Events(
          title: item['project_name'] ?? 'Minutes  Of Meeting',
          start: startDateTime,
          end: endDateTime,
          desc: item['descriptions'] ?? 'Minutes Of Meeting Pending',
          status: status,
          isMeeting: true,
          category: 'Minutes Of Meeting',
          uid: uid,
          imgName: item['img_name'],
          createdBy: item['member_name'],
          createdAt: item['updated_at'],
          // members: List<Map<String, dynamic>>.from(resultMembers),
        );

        for (var day = normalizeDate(startDateTime);
            !day.isAfter(normalizeDate(endDateTime));
            day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar(
          'We\'re unable to process your request at the moment. Please contact IT support for assistance.');
    }
    return;
  }

  /// Fetches meeting room bookings from the API
  Future<void> _fetchMeetingRoomBookings() async {
    final response = await getRequest(
        '/api/office-administration/book_meeting_room/my-requests');
    if (response == null) return;

    try {
      final List<dynamic> results = json.decode(response.body)['results'] ?? [];
      final meetingRoomBookings = List<Map<String, dynamic>>.from(results);

      for (var item in meetingRoomBookings) {
        final DateTime? startDateTime = item['from_date_time'] != null
            ? DateTime.parse(item['from_date_time'])
            : null;
        final DateTime? endDateTime = item['to_date_time'] != null
            ? DateTime.parse(item['to_date_time'])
            : null;

        if (startDateTime == null || endDateTime == null) {
          showSnackBar(
              'Missing from_date_time or to_date_time in meeting room booking.');
          continue;
        }

        final String uid = item['uid']?.toString() ?? UniqueKey().toString();
        String status = item['status'] != null
            ? mapEventStatus(item['status'].toString())
            : 'Pending';
        if (status == 'Cancelled') continue;

        // Filter duplicates by employee_id for meeting room members
        List<Map<String, dynamic>> membersList = item['members'] != null
            ? List<Map<String, dynamic>>.from(item['members'])
            : [];
        final seenEmployeeIds = <dynamic>{};
        final uniqueMembers = <Map<String, dynamic>>[];
        for (var member in membersList) {
          if (member['employee_id'] != null &&
              !seenEmployeeIds.contains(member['employee_id'])) {
            seenEmployeeIds.add(member['employee_id']);
            uniqueMembers.add(member);
          }
        }

        final event = Events(
          title: item['title'] ??
              AppLocalizations.of(context)!.meetingRoomBookings,
          start: startDateTime,
          end: endDateTime,
          desc: item['remark'] ?? 'Booking Pending',
          status: status,
          isMeeting: true,
          category: 'Meeting Room Bookings',
          uid: uid,
          imgName: item['img_name'],
          createdBy: item['employee_name'],
          createdAt: item['date_create'],
          location: item['room_name'] ?? 'Meeting Room',
          members: uniqueMembers, // Use filtered unique members list
        );

        for (var day = normalizeDate(startDateTime);
            !day.isAfter(normalizeDate(endDateTime));
            day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar(
          'We\'re unable to process your request at the moment. Please contact IT support for assistance.');
    }
  }

  /// Fetches car bookings from the API
  Future<void> _fetchCarBookings() async {
    final response =
        await getRequest('/api/office-administration/car_permits/me');
    if (response == null) return;

    try {
      final List<dynamic> results = json.decode(response.body)['results'] ?? [];
      final carBookings = List<Map<String, dynamic>>.from(results);

      for (var item in carBookings) {
        if (item['date_out'] == null || item['date_in'] == null) {
          showSnackBar('Missing date_out or date_in in car booking.');
          continue;
        }

        String dateOutStr = formatDateString(item['date_out'].toString());
        String dateInStr = formatDateString(item['date_in'].toString());
        String timeOutStr = item['time_out']?.toString() ?? '00:00';
        String timeInStr = item['time_in']?.toString() ?? '23:59';

        DateTime? startDateTime;
        DateTime? endDateTime;

        try {
          // Combine date and time properly
          DateTime outDate = DateTime.parse(dateOutStr);
          List<String> timeOutParts = timeOutStr.split(':');
          if (timeOutParts.length == 3) timeOutParts.removeLast();
          if (timeOutParts.length != 2) {
            throw const FormatException('Invalid time_out format');
          }

          endDateTime = DateTime(
            outDate.year,
            outDate.month,
            outDate.day,
            int.parse(timeOutParts[0]),
            int.parse(timeOutParts[1]),
          );

          DateTime inDate = DateTime.parse(dateInStr);
          List<String> timeInParts = timeInStr.split(':');
          if (timeInParts.length == 3) timeInParts.removeLast();
          if (timeInParts.length != 2) {
            throw const FormatException('Invalid time_in format');
          }
          startDateTime = DateTime(
            inDate.year,
            inDate.month,
            inDate.day,
            int.parse(timeInParts[0]),
            int.parse(timeInParts[1]),
          );
        } catch (e) {
          showSnackBar('Error parsing car booking dates: $e');
          continue;
        }

        final String uid =
            'car_${item['uid']?.toString() ?? UniqueKey().toString()}';

        String status = item['status'] != null
            ? mapEventStatus(item['status'].toString())
            : 'Pending';

        if (status == 'Cancelled') continue;

        Events? event;

        event = Events(
          title: item['purpose'] ?? AppLocalizations.of(context)!.noTitle,
          start: startDateTime,
          end: endDateTime,
          desc: item['desc'] ?? 'Car Booking Pending',
          status: status,
          isMeeting: false,
          category: 'Booking Car',
          uid: uid,
          location: item['place'] ?? '',
          imgName: item['img_name'],
          createdBy: item['requestor_name'],
          createdAt: item['updated_at'],
        );

        for (var day = normalizeDate(startDateTime);
            !day.isAfter(normalizeDate(endDateTime));
            day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar(
          'We\'re unable to process your request at the moment. Please contact IT support for assistance.');
    }
    return;
  }

  /// Fetches car bookings from the API
  Future<void> _fetchCarBookingsInvite() async {
    final response = await getRequest(
        '/api/office-administration/car_permits/invites-car-member');
    if (response == null) return;

    try {
      final List<dynamic> results = json.decode(response.body)['results'] ?? [];
      final carBookings = List<Map<String, dynamic>>.from(results);

      for (var item in carBookings) {
        if (item['date_out'] == null || item['date_in'] == null) {
          showSnackBar('Missing date_out or date_in in car booking.');
          continue;
        }

        String dateOutStr = formatDateString(item['date_out'].toString());
        String dateInStr = formatDateString(item['date_in'].toString());
        String timeOutStr = item['time_out']?.toString() ?? '00:00';
        String timeInStr = item['time_in']?.toString() ?? '23:59';

        DateTime? startDateTime;
        DateTime? endDateTime;

        try {
          DateTime outDate = DateTime.parse(dateOutStr);
          List<String> timeOutParts = timeOutStr.split(':');
          if (timeOutParts.length == 3) timeOutParts.removeLast();
          if (timeOutParts.length != 2) {
            throw const FormatException('Invalid time_out format');
          }

          endDateTime = DateTime(
            outDate.year,
            outDate.month,
            outDate.day,
            int.parse(timeOutParts[0]),
            int.parse(timeOutParts[1]),
          );

          DateTime inDate = DateTime.parse(dateInStr);
          List<String> timeInParts = timeInStr.split(':');
          if (timeInParts.length == 3) timeInParts.removeLast();
          if (timeInParts.length != 2) {
            throw const FormatException('Invalid time_in format');
          }
          startDateTime = DateTime(
            inDate.year,
            inDate.month,
            inDate.day,
            int.parse(timeInParts[0]),
            int.parse(timeInParts[1]),
          );
        } catch (e) {
          showSnackBar('Error parsing car booking dates: $e');
          continue;
        }

        final String uid =
            'car_${item['uid']?.toString() ?? UniqueKey().toString()}';
        String status = item['status'] != null
            ? mapEventStatus(item['status'].toString())
            : 'Pending';
        if (status == 'Cancelled') continue;

        // Filter duplicates by employee_id for car booking members
        List<Map<String, dynamic>> membersList = item['members'] != null
            ? List<Map<String, dynamic>>.from(item['members'])
            : [];
        final seenEmployeeIds = <dynamic>{};
        final uniqueMembers = <Map<String, dynamic>>[];
        for (var member in membersList) {
          if (member['employee_id'] != null &&
              !seenEmployeeIds.contains(member['employee_id'])) {
            seenEmployeeIds.add(member['employee_id']);
            uniqueMembers.add(member);
          }
        }

        final event = Events(
          title: item['purpose'] ?? AppLocalizations.of(context)!.noTitle,
          start: startDateTime,
          end: endDateTime,
          desc: item['place'] ?? 'Car Booking Pending',
          status: status,
          isMeeting: false,
          category: 'Booking Car',
          uid: uid,
          location: item['place'] ?? '',
          imgName: item['img_name'],
          createdBy: item['requestor_name'],
          createdAt: item['updated_at'],
          members: uniqueMembers, // Use filtered unique members list
        );

        for (var day = normalizeDate(startDateTime);
            !day.isAfter(normalizeDate(endDateTime));
            day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar(
          'We\'re unable to process your request at the moment. Please contact IT support for assistance.');
    }
  }

  // Add new state variables for pull-to-refresh with cached data first
  bool _isRefreshing = false;
  bool _hasLoadedFromLocalStorage =
      false; // Track if we've loaded from local storage

  bool _isFirstTimeUser = false; // Track if this is first time user

  /// Handles pull-to-refresh action - manual refresh only
  Future<void> _onRefresh() async {
    // Don't start another refresh if one is already in progress
    if (_isRefreshing) return;

    try {
      // Set refresh state and show loading indicator
      _isRefreshing = true;
      _isBackgroundLoading = true;

      if (mounted) {
        setState(() {});
      }

      debugPrint('🔄 Starting manual pull-to-refresh');

      // Clear current data and fetch fresh data from APIs
      await fetchData(showUpdateInfo: true);

      if (mounted) {
        // Update refresh key
        _refreshKey = UniqueKey();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Calendar refreshed successfully",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Smooth UI update
        _smoothUIUpdate();
      }
    } catch (e) {
      debugPrint('Error during refresh: $e');
    } finally {
      _isRefreshing = false;
      _isBackgroundLoading = false;

      if (mounted) {
        setState(() {});
      }
    }
  }

  // Temporary fetch methods that don't affect current UI









  /// Loads calendar data from local storage
  Future<bool> _loadLocalData() async {
    try {
      // Load events from local storage without triggering loading state
      final localEvents = await offlineProvider.getCalendar();

      if (localEvents.isNotEmpty) {
        addEventOffline(localEvents);
        _processEventsInBackground();
        return true; // Data was loaded successfully
      }
      return false; // No local data available
    } catch (e) {
      debugPrint('Error loading local data: $e');
      return false; // Error occurred, no data loaded
    }
  }

  /// Updates the calendar data after user login
  Future<void> updateCalendarAfterLogin() async {
    // Use fetch method without showing update information
    await fetchData(showUpdateInfo: false);
  }

  /// Shows a snackbar with update information
  void _showUpdateInfoSnackbar(
      {required int updatedEventCount,
      required int totalEventCount,
      required Map<String, int> updatedEventsByCategory}) {
    if (!mounted) return;

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            Icons.update,
            color: isDarkMode ? Colors.green[300] : Colors.green[700],
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Calendar successfully updated",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'OK',
        textColor: ColorStandardization().colorDarkGold,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }


  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      key: _refreshKey,
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(160),
        child: _buildCalendarHeader(isDarkMode),
      ),
      body: Column(
        children: [
          // Linear Loading Indicator under header - only show for background loading
          LinearLoadingIndicator(
            isLoading: _isBackgroundLoading,
            color: isDarkMode ? Colors.amber : Colors.green,
          ),

          // Main content - always show calendar instantly
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildCalendar(context, isDarkMode),
                    _buildSectionSeparator(),
                    Center(
                      child: Transform.translate(
                        offset: const Offset(0, -14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('EEEE')
                                  .format(_selectedDay ?? DateTime.now()),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              ', ${DateFormat('dd MMMM yyyy').format(_selectedDay ?? DateTime.now())}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -32),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.50,
                        child: _isFirstTimeUser && eventsForDay.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isDarkMode
                                            ? Colors.amber
                                            : Colors.green,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Loading your calendar...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: isDarkMode
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'This may take a moment on first launch',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDarkMode
                                            ? Colors.grey.shade500
                                            : Colors.grey.shade600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : eventsForDay.isEmpty
                                ? Center(
                                    child: AnimatedBuilder(
                                      animation: _typingAnimation,
                                      builder: (context, child) {
                                        final String message =
                                            AppLocalizations.of(context)!
                                                .noEventsForThisDay;
                                        final int length = (message.length *
                                                _typingAnimation.value)
                                            .round();
                                        return Text(
                                          message.substring(0,
                                              length.clamp(0, message.length)),
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: isDarkMode
                                                ? Colors.grey.shade300
                                                : Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.center,
                                        );
                                      },
                                    ),
                                  )
                                : CalendarDaySwitchView(
                                    selectedDay: _selectedDay,
                                    passDefaultCurrentHour: 0,
                                    passDefaultEndHour: 25,
                                    eventsCalendar: eventsForDay,
                                  ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Note: Initial loading state removed - calendar now shows instantly with cached data

  /// Builds the calendar header with background and add button
  Widget _buildCalendarHeader(bool isDarkMode) {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
              isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
          fit: BoxFit.cover,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Stack(
        children: [
          // Info icon at top left
          Positioned(
            top: 90,
            left: 18,
            child: Tooltip(
              message:
                  'Please pull to refresh in order to get the latest calendar data.',
              preferBelow: false,
              verticalOffset: 24,
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor:
                            isDarkMode ? Colors.grey[900] : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Color.fromARGB(255, 255, 0, 0),
                                  size: 28),
                              const SizedBox(width: 14),
                              Flexible(
                                child: Text(
                                  'Please pull to refresh in order to get the latest calendar data.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                child: const Icon(
                  Icons.info_outline,
                  color: Color.fromARGB(255, 207, 16, 16),
                  size: 22,
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 60),
                Text(
                  AppLocalizations.of(context)!.calendar,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 60,
            right: 15,
            child: AnimatedBuilder(
              animation: _plusIconController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _plusIconRotation.value,
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return SweepGradient(
                        colors: const [
                          Colors.green,
                          Color(0xFF4CAF50),
                          Color(0xFF8BC34A),
                          Color(0xFF4CAF50),
                          Colors.green,
                        ],
                        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                        transform: GradientRotation(
                            _plusIconController.value * 2 * 3.14159),
                      ).createShader(bounds);
                    },
                    child: IconButton(
                      icon: Icon(
                        Icons.add_circle,
                        size: 55,
                        color: Colors.white, // Base color for shader mask
                        semanticLabel: AppLocalizations.of(context)!.addEvent,
                      ),
                      onPressed: showAddEventOptionsPopup,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the TableCalendar widget with customized navigation arrows
  Widget _buildCalendar(BuildContext context, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black38 : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCustomHeader(isDarkMode),
          Consumer2<DateProvider, LanguageNotifier>(
            builder: (context, dateProvider, languageNotifier, child) {
              return TableCalendar<Events>(
                rowHeight: 35,
                firstDay: DateTime.utc(2010, 10, 16),
                lastDay: DateTime.utc(2030, 3, 14),
                focusedDay: dateProvider.selectedDate,
                locale: languageNotifier.currentLocale.languageCode,
                calendarFormat: _calendarFormat,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                },
                headerVisible: false,
                selectedDayPredicate: (day) {
                  return isSameDay(dateProvider.selectedDate, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  if (_singleTapSelectedDay != null &&
                      isSameDay(_singleTapSelectedDay, selectedDay)) {
                    _showDayView(selectedDay);
                    _singleTapSelectedDay = null;
                  } else {
                    dateProvider.updateSelectedDate(selectedDay);
                    setState(() {
                      _singleTapSelectedDay = selectedDay;
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                      _filterAndSearchEvents();
                    });

                    // Show event counts snackbar
                    _showEventCountsSnackbar(selectedDay, isDarkMode);
                  }
                },
                onFormatChanged: (format) {
                  if (format != CalendarFormat.month) {
                    setState(() {
                      _calendarFormat = CalendarFormat.month;
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                    dateProvider.updateSelectedDate(focusedDay);
                  });
                },
                eventLoader: _getDubplicateEventsForDay,
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: ColorStandardization().colorDarkGold,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.green.withOpacity(1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  defaultDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  weekendDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  outsideDaysVisible: false,
                  weekendTextStyle: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                  defaultTextStyle: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isNotEmpty) {
                      final sortedEvents = events
                        ..sort((a, b) => b.start.compareTo(a.start));
                      final latestEvents = sortedEvents.take(3).toList();
                      final eventSpans = latestEvents.where((event) {
                        return date.isAfter(event.start
                                .subtract(const Duration(days: 1))) &&
                            date.isBefore(
                                event.end.add(const Duration(days: 1)));
                      }).toList();

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: eventSpans.map((event) {
                          final totalDays = event.end.difference(event.start);
                          return Container(
                            height: 2,
                            margin: EdgeInsets.symmetric(
                                vertical: 1,
                                horizontal: totalDays.inDays > 0 ? 0 : 20),
                            decoration: BoxDecoration(
                              color: ColorStandardization().colorDarkGreen,
                              shape: BoxShape.rectangle,
                            ),
                          );
                        }).toList(),
                      );
                    }
                    return child;
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Builds a custom header with bordered navigation arrows
  Widget _buildCustomHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Month Arrow with Border
          GestureDetector(
            onTap: () {
              final previousMonth = DateTime(
                  _focusedDay.year, _focusedDay.month - 1, _focusedDay.day);
              _focusedDay = previousMonth;
              Provider.of<DateProvider>(context, listen: false)
                  .updateSelectedDate(previousMonth);
              setState(() {
                _selectedDay = previousMonth;
                _filterAndSearchEvents();
              });
            },
            child: Container(
              decoration: BoxDecoration(
                border:
                    Border.all(color: isDarkMode ? Colors.white : Colors.grey),
                borderRadius: BorderRadius.circular(7.0),
              ),
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.chevron_left,
                size: 18,
                color: isDarkMode ? Colors.white : Colors.black,
                semanticLabel: AppLocalizations.of(context)!.previousMonth,
              ),
            ),
          ),
          // Current Month and Year
          Consumer<DateProvider>(
            builder: (context, dateProvider, child) {
              return Text(
                DateFormat.MMMM(
                        sl<UserPreferences>().getLocalizeSupport().languageCode)
                    .format(dateProvider.selectedDate),
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              );
            },
          ),
          // Next Month Arrow with Border
          GestureDetector(
            onTap: () {
              final nextMonth = DateTime(
                  _focusedDay.year, _focusedDay.month + 1, _focusedDay.day);
              _focusedDay = nextMonth;
              Provider.of<DateProvider>(context, listen: false)
                  .updateSelectedDate(nextMonth);
              setState(() {
                _selectedDay = nextMonth;
                _filterAndSearchEvents();
              });
            },
            child: Container(
              decoration: BoxDecoration(
                border:
                    Border.all(color: isDarkMode ? Colors.white : Colors.grey),
                borderRadius: BorderRadius.circular(7.0),
              ),
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: isDarkMode ? Colors.white : Colors.black,
                semanticLabel: AppLocalizations.of(context)!.nextMonth,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a gradient animated line as a section separator
  Widget _buildSectionSeparator() {
    return const GradientAnimationLine();
  }

  /// Clear caches when data is updated (optimized version)
  void _clearCaches() {
    _eventCountsCache.clear();
    _processedEventsCache.clear();
  }

  /// Optimized filter and search with better performance - no setState
  void _filterAndSearchEvents() {
    if (_selectedDay == null) return;

    // Only clear caches if we have new data
    if (eventsForAll.isNotEmpty) {
      _clearCaches();
    }

    final dayEvents = _getEventsForDay(_selectedDay!);
    List<Events> filteredEvents = dayEvents;

    if (_selectedCategory != 'All') {
      filteredEvents = filteredEvents
          .where((event) => event.category == _selectedCategory)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredEvents = filteredEvents.where((event) {
        final title = event.title.toLowerCase();
        final description = event.desc.toLowerCase();
        return title.contains(query) || description.contains(query);
      }).toList();
    }

    // Update data without setState to avoid lag
    eventsForDay = filteredEvents;
  }

  void _eventsOffline() async {
    if (_selectedDay == null) return;

    List<Events> dayEvents = _getEventsForDay(_selectedDay!);
    if (_selectedCategory != 'All') {
      dayEvents = dayEvents
          .where((event) => event.category == _selectedCategory)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      dayEvents = dayEvents.where((event) {
        final eventTitle = event.title.toLowerCase();
        final eventDescription = event.desc.toLowerCase();
        return eventTitle.contains(_searchQuery.toLowerCase()) ||
            eventDescription.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Update data without setState for smoother performance
    eventsForDay = dayEvents;

    // Only trigger UI update if mounted and necessary
    if (mounted) {
      _smoothUIUpdate();
    }
  }

  /// Navigates to day view when a day is double-tapped
  void _showDayView(DateTime selectedDay) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TimetablePage(date: selectedDay),
      ),
    );
  }

  /// Displays a popup to choose between adding personal or office events
  void showAddEventOptionsPopup() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return Stack(
          children: [
            Positioned(
              top: 75,
              right: 40,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  width: 160,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.grey[850]
                        : Colors.white, // Dark mode background
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withOpacity(0.6)
                            : Colors.black.withOpacity(
                                0.2), // Darker shadow for dark mode
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPopupOption(
                        icon: Icons.person,
                        label: '1. ${AppLocalizations.of(context)!.personal}',
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToAddEvent('Personal');
                        },
                        isDarkMode: isDarkMode, // Passing dark mode flag
                      ),
                      const Divider(height: 1),
                      _buildPopupOption(
                        icon: Icons.work,
                        label: '2. ${AppLocalizations.of(context)!.office}',
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToAddEvent('Office');
                        },
                        isDarkMode: isDarkMode, // Passing dark mode flag
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds individual popup options
  Widget _buildPopupOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDarkMode, // Added the 'isDarkMode' parameter here
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon color changes based on dark mode
            Icon(
              icon,
              size: 20,
              color: isDarkMode
                  ? Colors.white70
                  : Colors.black54, // Dark mode: white, Light mode: black
              semanticLabel: label,
            ),
            const SizedBox(width: 12),
            // Text color changes based on dark mode
            Text(
              label,
              style: TextStyle(
                color: isDarkMode
                    ? Colors.white
                    : Colors.black87, // Dark mode: white, Light mode: black
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Navigates to the appropriate event addition page
  void _navigateToAddEvent(String eventType) async {
    if (eventType == 'Personal') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LeaveManagementPage(),
        ),
      );
    } else {
      final newEvent = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => const OfficeAddEventPage(),
        ),
      );
      if (newEvent != null) {
        _addEvent(
          title: newEvent['title'] ?? 'New Event',
          startDateTime: DateTime.parse(newEvent['startDateTime']),
          endDateTime: DateTime.parse(newEvent['endDateTime']),
          description: newEvent['description'] ?? '',
          status: 'Pending',
          isMeeting: true,
          category: 'Meetings',
          uid: newEvent['uid'] ?? UniqueKey().toString(),
        );
        Fluttertoast.showToast(
          msg: "Event Created Successfully",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green[600],
          textColor: Colors.white,
        );
      }
    }
  }

  /// Adds a new event to the calendar
  void _addEvent({
    required String title,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required String description,
    required String status,
    required bool isMeeting,
    required String category,
    required String uid,
  }) {
    final newEvent = Events(
      title: title,
      start: startDateTime,
      end: endDateTime,
      desc: description,
      status: status,
      isMeeting: isMeeting,
      category: category,
      uid: uid,
    );
    final normalizedDay = normalizeDate(startDateTime);
    setState(() {
      if (events.value.containsKey(normalizedDay)) {
        if (!events.value[normalizedDay]!.any((e) => e.uid == uid)) {
          events.value[normalizedDay]!.add(newEvent);
        }
      } else {
        events.value[normalizedDay] = [newEvent];
      }
      _filterAndSearchEvents();
      _animationController.forward(from: 0.0);
    });
  }

  /// Retrieves events for a specific day with duplicates filtered
  List<Events> _getDubplicateEventsForDay(DateTime day) {
    final normalizedDay = normalizeDate(day);
    final listEvent = events.value[normalizedDay] ?? [];
    List<Events> updateEvents = [];
    if (listEvent.length > 4) {
      for (var i in listEvent) {
        if (updateEvents.isEmpty) {
          updateEvents.add(i);
        } else if (updateEvents.any((u) => u.category.contains(i.category))) {
          // Skip duplicate categories
        } else {
          updateEvents.add(i);
        }
      }
    } else {
      updateEvents = listEvent;
    }

    return updateEvents;
  }

  /// Shows a modern snackbar with event counts
  void _showEventCountsSnackbar(DateTime day, bool isDarkMode) {
    final counts = _getEventCountsByCategory(day);
    if (counts.isEmpty) return;

    final formattedDate = DateFormat('EEE, dd MMM').format(day);

    const categoryOrder = {
      'Add Meeting': 1,
      'Meeting Room Bookings': 2,
      'Booking Car': 3,
      'Minutes Of Meeting': 4,
      'Leave': 5,
    };

    final sortedCounts = counts.entries.toList()
      ..sort((a, b) =>
          (categoryOrder[a.key] ?? 99).compareTo(categoryOrder[b.key] ?? 99));

    final snackBar = SnackBar(
      content: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ColorStandardization().colorDarkGold,
                    ColorStandardization().colorDarkGreen,
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sortedCounts.map((entry) {
                      final category = entry.key;
                      final count = entry.value;
                      final color = categoryColors[category] ?? Colors.grey;
                      String displayCategory = '';

                      switch (category) {
                        case 'Add Meeting':
                          displayCategory =
                              AppLocalizations.of(context)!.meetingTitle;
                        case 'Leave':
                          displayCategory = AppLocalizations.of(context)!.leave;
                        case 'Meeting Room Bookings':
                          displayCategory =
                              AppLocalizations.of(context)!.meetingRoomBookings;
                        case 'Booking Car':
                          displayCategory =
                              AppLocalizations.of(context)!.bookingCar;
                        case 'Minutes Of Meeting':
                          displayCategory =
                              AppLocalizations.of(context)!.minutesOfMeeting;
                        default:
                          displayCategory = category;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          border: Border.all(
                              color: color.withOpacity(0.3), width: 1),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              categoryIcon[category] != null
                                  ? Icons.circle
                                  : Icons.event,
                              size: 8,
                              color: color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              displayCategory,
                              style: TextStyle(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.9)
                                    : Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                count.toString(),
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),

      margin: const EdgeInsets.fromLTRB(12, 50, 12, 30), // Top: 50, Bottom: 12
      duration: const Duration(seconds: 4),
      animation: CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
        reverseCurve: Curves.easeOut,
      ),
      elevation: isDarkMode ? 8 : 4,
      action: SnackBarAction(
        label: 'OK',
        textColor: ColorStandardization().colorDarkGold,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
    _animationController.forward(from: 0.0);
  }

  /// Optimized event retrieval with caching
  List<Events> _getEventsForDay(DateTime day) {
    final normalizedDay = normalizeDate(day);
    if (_processedEventsCache.containsKey(normalizedDay)) {
      return _processedEventsCache[normalizedDay]!;
    }
    final result = events.value[normalizedDay] ?? [];
    _processedEventsCache[normalizedDay] = result;
    return result;
  }

  /// Optimized event counts with caching
  Map<String, int> _getEventCountsByCategory(DateTime day) {
    final normalizedDay = normalizeDate(day);
    if (_eventCountsCache.containsKey(normalizedDay)) {
      return _eventCountsCache[normalizedDay]!;
    }

    final events = _getEventsForDay(day);
    final counts = <String, int>{};

    for (var event in events) {
      counts[event.category] = (counts[event.category] ?? 0) + 1;
    }

    _eventCountsCache[normalizedDay] = counts;
    return counts;
  }
}

/// Gradient animated line widget
class GradientAnimationLine extends StatefulWidget {
  const GradientAnimationLine({super.key});

  @override
  GradientAnimationLineState createState() => GradientAnimationLineState();
}

class GradientAnimationLineState extends State<GradientAnimationLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorAnimation1;
  late final Animation<Color?> _colorAnimation2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _colorAnimation1 = ColorTween(
      begin: Colors.deepOrange,
      end: Colors.orange,
    ).animate(_controller);
    _colorAnimation2 = ColorTween(
      begin: Colors.orange,
      end: const Color(0xFFDBB342),
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Builds the animated gradient line
  Widget _buildSectionSeparator() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: 5.0,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                _colorAnimation1.value!,
                _colorAnimation2.value!,
              ],
            ),
          ),
          margin: const EdgeInsets.only(
              bottom: 22.0, left: 15.0, right: 15.0, top: 20.0),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildSectionSeparator();
  }
}

/// Function to use the animated line as a separator
Widget buildSectionSeparator() {
  return const Column(
    children: [
      GradientAnimationLine(),
      SizedBox(height: 5),
    ],
  );
}
