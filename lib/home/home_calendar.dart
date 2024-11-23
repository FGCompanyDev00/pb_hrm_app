import 'dart:convert';
import 'dart:async';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/core/standard/extension.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/core/widgets/calendar_day/calendar_day_veiw_card.dart';
import 'package:pb_hrsystem/core/widgets/snackbar/snackbar.dart';
import 'package:pb_hrsystem/home/office_events/office_add_event.dart';
import 'package:pb_hrsystem/home/timetable_page.dart';
import 'package:pb_hrsystem/login/date.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:pb_hrsystem/models/calendar_events_list_record.dart';
import 'package:pb_hrsystem/models/event_record.dart';
import 'package:pb_hrsystem/services/http_service.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:pb_hrsystem/home/leave_request_page.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class HomeCalendar extends StatefulWidget {
  const HomeCalendar({super.key});

  @override
  HomeCalendarState createState() => HomeCalendarState();
}

class HomeCalendarState extends State<HomeCalendar> with TickerProviderStateMixin {
  late Box eventsBox;

  // ValueNotifier to hold events mapped by date
  late final ValueNotifier<Map<DateTime, List<EventRecord>>> _events;
  final selectedSlot = ValueNotifier(1);

  // Calendar properties
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _singleTapSelectedDay;
  List<EventRecord> _eventsForDay = [];

  // Notifications
  late final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  // Filters and Search
  bool _showFiltersAndSearchBar = false;
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Add Meeting', 'Leave', 'Meeting Room Bookings', 'Booking Car'];
  String _searchQuery = '';

  // Animation Controller
  late final AnimationController _animationController;

  // Double Tap Timer
  Timer? _doubleTapTimer;
  static const int doubleTapDelay = 300;

  // Loading State
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _events = ValueNotifier({});
    _eventsForDay = [];

    // Initialize Animation Controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Fetch initial data
    _fetchData();

    connectivityResult.onConnectivityChanged.listen((source) {
      if (source.contains(ConnectivityResult.none)) offlineProvider.getEventsCalendar();
    });
  }

  @override
  void dispose() {
    _events.dispose();
    _animationController.dispose();
    _doubleTapTimer?.cancel();
    super.dispose();
  }

  void addEvent(DateTime date, EventRecord event) {
    final detectDate = normalizeDate(date);
    if (_events.value.containsKey(detectDate)) {
      // If the date already has events, add to the list
      if (_events.value[detectDate]!.where((desc) => desc.description == event.description).isEmpty) {
        _events.value[detectDate]!.add(event);
      } else {
        event.members?.forEach(
          (e) => _events.value[detectDate]!.where((desc) => desc.description == event.description).first.members?.add(e),
        );
      }
    } else {
      // Otherwise, create a new list with this event
      _events.value[detectDate] = [event];
    }
  }

  /// Fetches all required data concurrently
  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await Future.wait([
        _fetchMeetingData(),
        _fetchLeaveRequests(),
        _fetchMeetingRoomBookings(),
        _fetchCarBookings(),
        _fetchMinutesOfMeeting(),
      ]).whenComplete(() => _filterAndSearchEvents());
    } catch (e) {
      showSnackBar('Error fetching data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
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

        // Adjusted field names to match API response
        final DateTime startDate = item['take_leave_from'] != null ? normalizeDate(DateTime.parse(item['take_leave_from'])) : normalizeDate(DateTime.now());
        final DateTime endDate = item['take_leave_to'] != null ? normalizeDate(DateTime.parse(item['take_leave_to'])) : normalizeDate(DateTime.now());
        final String uid = 'leave_${item['id']}';
        double days;

        if (item['days'].runtimeType == int) {
          days = double.parse(item['days'].toString());
        } else {
          days = item['days'];
        }

        String status = item['is_approve'] != null ? _mapLeaveStatus(item['is_approve'].toString()) : 'Pending';

        if (status == 'Cancelled') continue;

        final event = EventRecord(
          title: item['name'] ?? 'Leave',
          startDateTime: startDate,
          endDateTime: endDate,
          description: item['take_leave_reason'] ?? 'Approval Pending',
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

        for (var day = startDate; day.isBefore(endDate.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar('Error parsing leave requests: $e');
    }
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
  Future<void> _fetchMeetingData() async {
    final response = await getRequest('/api/work-tracking/meeting/get-all-meeting');
    if (response == null) return;

    try {
      final data = json.decode(response.body);

      if (data == null || data['results'] == null || data['results'] is! List) {
        showSnackBar('Invalid meeting data format.');
        return;
      }

      final List<dynamic> results = data['results'];

      for (var item in results) {
        // Ensure necessary fields are present
        if (item['from_date'] == null || item['to_date'] == null || item['start_time'] == null || item['end_time'] == null) {
          showSnackBar('Missing date or time fields in meeting data.');
          continue;
        }

        // Combine 'from_date' with 'start_time' and 'to_date' with 'end_time'
        DateTime startDateTime;
        DateTime endDateTime;
        try {
          // Parse 'from_date' and 'start_time' separately and combine
          DateTime fromDate = DateTime.parse(item['from_date']);
          List<String> startTimeParts = item['start_time'] != "" ? item['start_time'].split(':') : ["00", "00"];
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
          List<String> endTimeParts = item['end_time'] != "" ? item['end_time'].split(':') : ["00", "00"];
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

        // Handle possible nulls with default values
        final String uid = item['meeting_id']?.toString() ?? UniqueKey().toString();

        String status = item['s_name'] != null ? mapEventStatus(item['s_name'].toString()) : 'Pending';

        if (status == 'Cancelled') continue;

        final event = EventRecord(
          title: item['title'] ?? 'Add Meeting',
          startDateTime: startDateTime,
          endDateTime: endDateTime,
          description: item['description'] ?? '',
          status: status,
          isMeeting: true,
          location: item['location'] ?? '', // Assuming 'location' field exists
          createdBy: item['create_by'] ?? '',
          imgName: item['file_name'] ?? '',
          createdAt: item['created_at'] ?? '',
          uid: uid,
          isRepeat: item['is_repeat']?.toString(),
          videoConference: item['video_conference']?.toString(),
          backgroundColor: item['backgroundColor'] != null ? parseColor(item['backgroundColor']) : Colors.blue,
          outmeetingUid: item['meeting_id']?.toString(),
          category: 'Add Meeting',
          members: item['members'] != null ? List<Map<String, dynamic>>.from(item['members']) : [],
        );

        // Normalize the start and end dates for event mapping
        final normalizedStartDay = normalizeDate(startDateTime);
        final normalizedEndDay = normalizeDate(endDateTime);

        for (var day = normalizedStartDay; !day.isAfter(normalizedEndDay); day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar('Error parsing meeting data: $e');
    }

    return;
  }

  /// Fetches meeting room bookings from the API
  Future<void> _fetchMinutesOfMeeting() async {
    final response = await getRequest('/api/work-tracking/meeting/assignment/my-metting');
    if (response == null) return;

    try {
      final List<dynamic> results = json.decode(response.body)['results'] ?? [];
      final minutesMeeting = List<Map<String, dynamic>>.from(results);

      for (var item in minutesMeeting) {
        // final DateTime? startDateTime = item['from_date'] != null ? DateTime.parse(item['from_date']) : null;
        // final DateTime? endDateTime = item['to_date'] != null ? DateTime.parse(item['to_date']) : null;

        String dateFrom = formatDateString(item['from_date'].toString());
        String dateTo = formatDateString(item['to_date'].toString());
        String startTime = item['start_time'] != "" ? item['start_time'].toString() : '00:00';
        String endTime = item['end_time'] != "" ? item['end_time'].toString() : '23:59';

        if (dateFrom.isEmpty || dateTo.isEmpty) {
          showSnackBar('Missing from_date or to_date in minutes of meeting.');
          continue;
        }

        DateTime? startDateTime;
        DateTime? endDateTime;

        try {
          // Combine date and time properly
          DateTime fromDate = DateTime.parse(dateFrom);
          List<String> timeOutParts = startTime.split(':');
          if (timeOutParts.length == 3) timeOutParts.removeLast();
          if (timeOutParts.length != 2) {
            throw const FormatException('Invalid time_out format');
          }
          startDateTime = DateTime(
            fromDate.year,
            fromDate.month,
            fromDate.day,
            int.parse(timeOutParts[0]),
            int.parse(timeOutParts[1]),
          );

          DateTime inDate = DateTime.parse(dateTo);
          List<String> timeInParts = endTime.split(':');
          if (timeInParts.length == 3) timeInParts.removeLast();
          if (timeInParts.length != 2) {
            throw const FormatException('Invalid time_in format');
          }
          endDateTime = DateTime(
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

        final String uid = item['project_id']?.toString() ?? UniqueKey().toString();

        String status = item['statuss'] != null
            ? item['statuss'] == 1
                ? 'Success'
                : 'Pending'
            : 'Pending';

        if (status == 'Cancelled') continue;

        EventRecord? event;
        if (mounted) {
          event = EventRecord(
            title: item['project_name'] ?? 'Minutes Of Meeting',
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            description: item['descriptions'] ?? 'Minutes Of Meeting Pending',
            status: status,
            isMeeting: true,
            category: 'Minutes Of Meeting',
            uid: uid,
            imgName: item['img_name'],
            createdBy: item['member_name'],
            createdAt: item['updated_at'],
            // members: List<Map<String, dynamic>>.from(resultMembers),
          );
        }

        for (var day = normalizeDate(startDateTime); !day.isAfter(normalizeDate(endDateTime)); day = day.add(const Duration(days: 1))) {
          addEvent(day, event!);
        }
      }
    } catch (e) {
      showSnackBar('Error parsing meeting room bookings: $e');
    }
    return;
  }

  /// Fetches meeting room bookings from the API
  Future<void> _fetchMeetingRoomBookings() async {
    final response = await getRequest('/api/office-administration/book_meeting_room/my-requests');
    if (response == null) return;

    try {
      final List<dynamic> results = json.decode(response.body)['results'] ?? [];
      final meetingRoomBookings = List<Map<String, dynamic>>.from(results);

      for (var item in meetingRoomBookings) {
        final DateTime? startDateTime = item['from_date_time'] != null ? DateTime.parse(item['from_date_time']) : null;
        final DateTime? endDateTime = item['to_date_time'] != null ? DateTime.parse(item['to_date_time']) : null;

        if (startDateTime == null || endDateTime == null) {
          showSnackBar('Missing from_date_time or to_date_time in meeting room booking.');
          continue;
        }

        final String uid = item['uid']?.toString() ?? UniqueKey().toString();

        String status = item['status'] != null ? mapEventStatus(item['status'].toString()) : 'Pending';

        if (status == 'Cancelled') continue;

        EventRecord? event;
        if (mounted) {
          event = EventRecord(
            title: item['title'] ?? AppLocalizations.of(context)!.meetingRoomBookings,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            description: item['remark'] ?? 'Booking Pending',
            status: status,
            isMeeting: true,
            category: 'Meeting Room Bookings',
            uid: uid,
            imgName: item['img_name'],
            createdBy: item['employee_name'],
            createdAt: item['date_create'],
            location: item['room_name'] ?? 'Meeting Room',
            members: item['members'] != null ? List<Map<String, dynamic>>.from(item['members']) : [],
          );
        }

        for (var day = normalizeDate(startDateTime); !day.isAfter(normalizeDate(endDateTime)); day = day.add(const Duration(days: 1))) {
          addEvent(day, event!);
        }
      }
    } catch (e) {
      showSnackBar('Error parsing meeting room bookings: $e');
    }
    return;
  }

  /// Fetches car bookings from the API
  Future<void> _fetchCarBookings() async {
    final response = await getRequest('/api/office-administration/car_permits/me');
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
          if (timeOutParts.length != 2) {
            throw const FormatException('Invalid time_out format');
          }
          startDateTime = DateTime(
            outDate.year,
            outDate.month,
            outDate.day,
            int.parse(timeOutParts[0]),
            int.parse(timeOutParts[1]),
          );

          DateTime inDate = DateTime.parse(dateInStr);
          List<String> timeInParts = timeInStr.split(':');
          if (timeInParts.length != 2) {
            throw const FormatException('Invalid time_in format');
          }
          endDateTime = DateTime(
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

        final String uid = 'car_${item['uid']?.toString() ?? UniqueKey().toString()}';

        String status = item['status'] != null ? mapEventStatus(item['status'].toString()) : 'Pending';

        if (status == 'Cancelled') continue;

        EventRecord? event;

        if (mounted) {
          event = EventRecord(
            title: item['purpose'] ?? AppLocalizations.of(context)!.noTitle,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            description: item['place'] ?? 'Car Booking Pending',
            status: status,
            isMeeting: false,
            category: 'Booking Car',
            uid: uid,
            location: item['place'] ?? '',
            imgName: item['img_name'],
            createdBy: item['requestor_name'],
            createdAt: item['updated_at'],
          );
        }

        for (var day = normalizeDate(startDateTime); !day.isAfter(normalizeDate(endDateTime)); day = day.add(const Duration(days: 1))) {
          addEvent(day, event!);
        }
      }
    } catch (e) {
      showSnackBar('Error parsing booking car: $e');
    }
    return;
  }

  /// Handles pull-to-refresh action
  Future<void> _onRefresh() async {
    await _fetchData();
    setState(() {
      _showFiltersAndSearchBar = !_showFiltersAndSearchBar;
    });
  }

  int liveHour() {
    int hour = _selectedDay?.hour ?? 7;

    if (hour < 11) {
      return 0;
    } else if (hour < 14) {
      return 1;
    } else if (hour < 18) {
      return 2;
    } else {
      return 1;
    }
  }

  /// Retrieves events for a specific day
  List<EventRecord> _getEventsForDay(DateTime day) {
    final normalizedDay = normalizeDate(day);
    return _events.value[normalizedDay] ?? [];
  }

  /// Retrieves events for a specific day
  List<EventRecord> _getDubplicateEventsForDay(DateTime day) {
    final normalizedDay = normalizeDate(day);
    final listEvent = _events.value[normalizedDay] ?? [];
    List<EventRecord> updateEvents = [];
    if (listEvent.length > 4) {
      for (var i in listEvent) {
        if (updateEvents.isEmpty) {
          updateEvents.add(i);
        } else if (updateEvents.any((u) => u.category.contains(i.category))) {
        } else {
          updateEvents.add(i);
        }
      }
    } else {
      updateEvents = listEvent;
    }

    return updateEvents;
  }

  /// Filters and searches events based on selected category and search query
  void _filterAndSearchEvents() {
    if (_selectedDay == null) return;
    offlineProvider.addEventsCalendar(CalendarEventsListRecord(listEvents: _events.value));
    List<EventRecord> dayEvents = _getEventsForDay(_selectedDay!);
    if (_selectedCategory != 'All') {
      dayEvents = dayEvents.where((event) {
        return event.category == _selectedCategory;
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      dayEvents = dayEvents.where((event) {
        final eventTitle = event.title.toLowerCase();
        final eventDescription = event.description.toLowerCase();
        return eventTitle.contains(_searchQuery.toLowerCase()) || eventDescription.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    setState(() {
      _eventsForDay = dayEvents;
    });
  }

  /// Navigates to day view when a day is double-tapped
  void _showDayView(DateTime selectedDay) {
    // final List<EventRecord> dayEvents = _getEventsForDay(selectedDay);

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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
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
                      ),
                      const Divider(height: 1),
                      _buildPopupOption(
                        icon: Icons.work,
                        label: '2. ${AppLocalizations.of(context)!.office}',
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToAddEvent('Office');
                        },
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
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black54, semanticLabel: label),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.black87)),
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
    final newEvent = EventRecord(
      title: title,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      description: description,
      status: status,
      isMeeting: isMeeting,
      category: category,
      uid: uid,
    );
    final normalizedDay = normalizeDate(startDateTime);
    setState(() {
      if (_events.value.containsKey(normalizedDay)) {
        if (!_events.value[normalizedDay]!.any((e) => e.uid == uid)) {
          _events.value[normalizedDay]!.add(newEvent);
        }
      } else {
        _events.value[normalizedDay] = [newEvent];
      }
      _filterAndSearchEvents();
      _animationController.forward(from: 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(130),
        child: _buildCalendarHeader(isDarkMode),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_showFiltersAndSearchBar) _buildFilters(),
              if (_showFiltersAndSearchBar) _buildSearchBar(),
              _buildCalendar(context, isDarkMode),
              const SizedBox(height: 2),
              _buildSectionSeparator(),
              _eventsForDay.isEmpty
                  ? SizedBox(
                      height: sizeScreen(context).height * 0.20,
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.noEventsForThisDay,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : CarouselSlider(
                      options: CarouselOptions(
                        autoPlay: false,
                        viewportFraction: 1,
                        initialPage: liveHour(),
                        scrollDirection: Axis.vertical,
                        height: fullHeight * 0.40,
                        aspectRatio: 0,
                      ),
                      items: [
                        CalendarDayWidgetCard(
                          selectedDay: _selectedDay,
                          eventsCalendar: _eventsForDay,
                          selectedSlotTime: 1,
                          heightTime: (fullHeight * 0.25) / 150,
                        ),
                        CalendarDayWidgetCard(
                          selectedDay: _selectedDay,
                          eventsCalendar: _eventsForDay,
                          selectedSlotTime: 2,
                          heightTime: (fullHeight * 0.25) / 150,
                        ),
                        CalendarDayWidgetCard(
                          selectedDay: _selectedDay,
                          eventsCalendar: _eventsForDay,
                          selectedSlotTime: 3,
                          heightTime: (fullHeight * 0.25) / 190,
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the calendar header with background and add button
  Widget _buildCalendarHeader(bool isDarkMode) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 45),
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
                top: 45,
                right: 15,
                child: IconButton(
                  icon: Icon(
                    Icons.add_circle,
                    size: 55,
                    color: Colors.green,
                    semanticLabel: AppLocalizations.of(context)!.addEvent,
                  ),
                  onPressed: showAddEventOptionsPopup,
                ),
              ),
            ],
          ),
        ),
        if (_isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              backgroundColor: Colors.blue,
            ),
          ),
      ],
    );
  }

  /// Builds the filter chips for event categories
  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        spacing: 8.0,
        children: _categories.map((category) {
          return FilterChip(
            label: Text(category),
            selected: _selectedCategory == category,
            onSelected: (bool selected) {
              setState(() {
                _selectedCategory = category;
                _filterAndSearchEvents();
              });
            },
            selectedColor: getEventColor(
              EventRecord(
                title: '',
                startDateTime: DateTime.now(),
                endDateTime: DateTime.now(),
                description: '',
                status: '',
                isMeeting: false,
                category: category,
                uid: '',
              ),
            ),
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: _selectedCategory == category ? Colors.white : Colors.black,
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Builds the search bar for filtering events
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TextField(
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.searchEvents,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _filterAndSearchEvents();
          });
        },
      ),
    );
  }

  /// Builds the TableCalendar widget with customized navigation arrows
  Widget _buildCalendar(BuildContext context, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCustomHeader(isDarkMode),
          Consumer2<DateProvider, LanguageNotifier>(
            builder: (context, dateProvider, languageNotifier, child) {
              return TableCalendar<EventRecord>(
                rowHeight: 34,
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
                  if (_singleTapSelectedDay != null && isSameDay(_singleTapSelectedDay, selectedDay)) {
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
                    color: Colors.orangeAccent.withOpacity(1),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.green.withOpacity(1),
                    shape: BoxShape.circle,
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
                      final sortedEvents = events..sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
                      final latestEvents = sortedEvents.take(3).toList();
                      final eventSpans = latestEvents.where((event) {
                        return date.isAfter(event.startDateTime.subtract(const Duration(days: 1))) && date.isBefore(event.endDateTime.add(const Duration(days: 1)));
                      }).toList();

                      return Align(
                        alignment: Alignment.bottomCenter,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: eventSpans.map((event) {
                            return Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: getEventColor(event),
                                shape: BoxShape.circle,
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }
                    return null;
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
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Month Arrow with Border
          GestureDetector(
            onTap: () {
              final previousMonth = DateTime(_focusedDay.year, _focusedDay.month - 1, _focusedDay.day);
              _focusedDay = previousMonth;
              Provider.of<DateProvider>(context, listen: false).updateSelectedDate(previousMonth);
              setState(() {
                _selectedDay = previousMonth;
                _filterAndSearchEvents();
              });
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: isDarkMode ? Colors.white : Colors.grey),
                borderRadius: BorderRadius.circular(7.0),
              ),
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.chevron_left,
                size: 15,
                color: isDarkMode ? Colors.white : Colors.black,
                semanticLabel: AppLocalizations.of(context)!.previousMonth,
              ),
            ),
          ),
          // Current Month and Year
          Consumer<DateProvider>(
            builder: (context, dateProvider, child) {
              return Text(
                DateFormat.MMMM(sl<UserPreferences>().getLocalizeSupport().languageCode).format(dateProvider.selectedDate),
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
              final nextMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, _focusedDay.day);
              _focusedDay = nextMonth;
              Provider.of<DateProvider>(context, listen: false).updateSelectedDate(nextMonth);
              setState(() {
                _selectedDay = nextMonth;
                _filterAndSearchEvents();
              });
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: isDarkMode ? Colors.white : Colors.grey),
                borderRadius: BorderRadius.circular(7.0),
              ),
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.chevron_right,
                size: 15,
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
}

/// Gradient animated line widget
class GradientAnimationLine extends StatefulWidget {
  const GradientAnimationLine({super.key});

  @override
  GradientAnimationLineState createState() => GradientAnimationLineState();
}

class GradientAnimationLineState extends State<GradientAnimationLine> with SingleTickerProviderStateMixin {
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
      begin: Colors.yellow,
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
          margin: const EdgeInsets.only(bottom: 20.0, left: 15.0, right: 15.0),
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
