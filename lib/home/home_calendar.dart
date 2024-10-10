import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_timetable/flutter_timetable.dart';
import 'package:pb_hrsystem/home/event_detail_view.dart';
import 'package:pb_hrsystem/home/office_events/office_add_event.dart';
import 'package:pb_hrsystem/home/timetable_page.dart';
import 'package:pb_hrsystem/login/date.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:pb_hrsystem/home/leave_request_page.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';

class HomeCalendar extends StatefulWidget {
  const HomeCalendar({super.key});

  @override
  _HomeCalendarState createState() => _HomeCalendarState();
}

class _HomeCalendarState extends State<HomeCalendar>
    with TickerProviderStateMixin {
  // Base URL for API endpoints
  final String baseUrl = 'https://demo-application-api.flexiflows.co';

  // ValueNotifier to hold events mapped by date
  late final ValueNotifier<Map<DateTime, List<Event>>> _events;

  // Calendar properties
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _singleTapSelectedDay;
  List<Event> _eventsForDay = [];

  // Notifications
  late final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  // Filters and Search
  bool _showFiltersAndSearchBar = false;
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Meetings',
    'Leave Requests',
    'Meeting Room Bookings',
    'Car Bookings'
  ];
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

    // Initialize local notifications
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Initialize Animation Controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Fetch initial data
    _fetchData();
  }

  @override
  void dispose() {
    _events.dispose();
    _animationController.dispose();
    _doubleTapTimer?.cancel();
    super.dispose();
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
      ]);
    } catch (e) {
      _showSnackBar('Error fetching data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Retrieves the authentication token from SharedPreferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// Helper method to handle HTTP GET requests with error handling
  Future<http.Response?> _getRequest(String endpoint) async {
    final token = await _getToken();
    if (token == null) {
      _showSnackBar(
          'Authentication Error: Token is null. Please log in again.');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return response;
      } else {
        _showSnackBar(
            'Failed to load data. Status Code: ${response.statusCode}. Message: ${response.reasonPhrase}');
        return null;
      }
    } catch (e) {
      _showSnackBar('Network Error: $e');
      return null;
    }
  }

  /// Displays a SnackBar with the provided message
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  /// Normalizes the date by removing the time component
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Fetches leave requests from the API
  Future<void> _fetchLeaveRequests() async {
    final response = await _getRequest('/api/leave_requests');
    if (response == null) return;

    try {
      final List<dynamic> results = json.decode(response.body)['results'];
      final leaveRequests = List<Map<String, dynamic>>.from(results);

      final Map<DateTime, List<Event>> approvalEvents = {};
      for (var item in leaveRequests) {
        // Adjusted field names to match API response
        final DateTime startDate = item['take_leave_from'] != null
            ? _normalizeDate(DateTime.parse(item['take_leave_from']))
            : _normalizeDate(DateTime.now());
        final DateTime endDate = item['take_leave_to'] != null
            ? _normalizeDate(DateTime.parse(item['take_leave_to']))
            : _normalizeDate(DateTime.now());
        final String uid = 'leave_${item['id']}';

        String status = item['is_approve'] != null
            ? _mapLeaveStatus(item['is_approve'].toString())
            : 'Pending';

        if (status == 'Cancelled') continue;

        final event = Event(
          title: item['name'] ?? 'Leave Request',
          startDateTime: startDate,
          endDateTime: endDate,
          description: item['take_leave_reason'] ?? 'Approval Pending',
          status: status,
          isMeeting: false,
          category: 'Leave Requests',
          uid: uid,
        );

        for (var day = startDate;
        day.isBefore(endDate.add(const Duration(days: 1)));
        day = day.add(const Duration(days: 1))) {
          final normalizedDay = _normalizeDate(day);
          if (approvalEvents.containsKey(normalizedDay)) {
            if (!approvalEvents[normalizedDay]!
                .any((e) => e.uid == event.uid)) {
              approvalEvents[normalizedDay]!.add(event);
            }
          } else {
            approvalEvents[normalizedDay] = [event];
          }
        }
      }

      setState(() {
        _events.value = {..._events.value, ...approvalEvents};
        _filterAndSearchEvents();
      });
    } catch (e) {
      _showSnackBar('Error parsing leave requests: $e');
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
    final response = await _getRequest(
        '/api/work-tracking/out-meeting/outmeeting/my-members');
    if (response == null) return;

    try {
      final data = json.decode(response.body);

      if (data == null ||
          data['results'] == null ||
          data['results'] is! List) {
        _showSnackBar('Invalid meeting data format.');
        return;
      }

      final List<dynamic> results = data['results'];
      final Map<DateTime, List<Event>> meetingEvents = {};

      for (var item in results) {
        // Adjusted field names to match API response
        final DateTime startDate = item['from_date'] != null
            ? DateTime.parse(item['from_date'])
            : DateTime.now();
        final DateTime endDate = item['to_date'] != null
            ? DateTime.parse(item['to_date'])
            : DateTime.now();

        // Handle possible nulls with default values
        final String uid =
            item['meeting_id']?.toString() ?? UniqueKey().toString();

        String status = item['s_name'] != null
            ? _mapMeetingStatus(item['s_name'].toString())
            : 'Pending';

        if (status == 'Cancelled') continue;

        final event = Event(
          title: item['title'] ?? 'Meeting',
          startDateTime: startDate,
          endDateTime: endDate,
          description: item['description'] ?? '',
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
              ? _parseColor(item['backgroundColor'])
              : Colors.blue,
          outmeetingUid: item['meeting_id']?.toString(),
          category: 'Meetings',
          members: item['members'] != null
              ? List<Map<String, dynamic>>.from(item['members'])
              : [],
        );

        for (var day = _normalizeDate(startDate);
        !day.isAfter(_normalizeDate(endDate));
        day = day.add(const Duration(days: 1))) {
          if (meetingEvents.containsKey(day)) {
            if (!meetingEvents[day]!.any((e) => e.uid == event.uid)) {
              meetingEvents[day]!.add(event);
            }
          } else {
            meetingEvents[day] = [event];
          }
        }
      }

      setState(() {
        _events.value = {..._events.value, ...meetingEvents};
        _filterAndSearchEvents();
      });
    } catch (e) {
      _showSnackBar('Error parsing meeting data: $e');
    }
  }

  /// Maps API meeting status to human-readable status
  String _mapMeetingStatus(String apiStatus) {
    switch (apiStatus.toLowerCase()) {
      case 'approved':
        return 'Approved';
      case 'processing':
      case 'waiting':
        return 'Pending';
      case 'disapproved':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  /// Fetches meeting room bookings from the API
  Future<void> _fetchMeetingRoomBookings() async {
    final response = await _getRequest(
        '/api/office-administration/book_meeting_room/my-requests');
    if (response == null) return;

    try {
      final List<dynamic> results =
          json.decode(response.body)['results'] ?? [];
      final meetingRoomBookings =
      List<Map<String, dynamic>>.from(results);

      final Map<DateTime, List<Event>> bookingEvents = {};
      for (var item in meetingRoomBookings) {
        final DateTime? startDateTime = item['from_date_time'] != null
            ? DateTime.parse(item['from_date_time'])
            : null;
        final DateTime? endDateTime = item['to_date_time'] != null
            ? DateTime.parse(item['to_date_time'])
            : null;

        if (startDateTime == null || endDateTime == null) {
          _showSnackBar(
              'Missing from_date_time or to_date_time in meeting room booking.');
          continue;
        }

        final String uid = item['uid']?.toString() ?? UniqueKey().toString();

        String status = item['status'] != null
            ? _mapBookingStatus(item['status'].toString())
            : 'Pending';

        if (status == 'Cancelled') continue;

        final event = Event(
          title: item['title'] ?? 'Meeting Room Booking',
          startDateTime: startDateTime,
          endDateTime: endDateTime,
          description: item['remark'] ?? 'Booking Pending',
          status: status,
          isMeeting: true,
          category: 'Meeting Room Bookings',
          uid: uid,
          location: item['room_name'] ?? 'Meeting Room',
          members: item['members'] != null
              ? List<Map<String, dynamic>>.from(item['members'])
              : [],
        );

        for (var day = _normalizeDate(startDateTime);
        !day.isAfter(_normalizeDate(endDateTime));
        day = day.add(const Duration(days: 1))) {
          if (bookingEvents.containsKey(day)) {
            if (!bookingEvents[day]!.any((e) => e.uid == event.uid)) {
              bookingEvents[day]!.add(event);
            }
          } else {
            bookingEvents[day] = [event];
          }
        }
      }

      setState(() {
        _events.value = {..._events.value, ...bookingEvents};
        _filterAndSearchEvents();
      });
    } catch (e) {
      _showSnackBar('Error parsing meeting room bookings: $e');
    }
  }

  /// Maps API booking status to human-readable status
  String _mapBookingStatus(String apiStatus) {
    switch (apiStatus.toLowerCase()) {
      case 'approved':
        return 'Approved';
      case 'waiting':
        return 'Pending';
      case 'disapproved':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  /// Fetches car bookings from the API
  Future<void> _fetchCarBookings() async {
    final response =
    await _getRequest('/api/office-administration/car_permits/me');
    if (response == null) return;

    try {
      final List<dynamic> results =
          json.decode(response.body)['results'] ?? [];
      final carBookings = List<Map<String, dynamic>>.from(results);

      final Map<DateTime, List<Event>> carEvents = {};
      for (var item in carBookings) {
        if (item['date_out'] == null || item['date_in'] == null) {
          _showSnackBar('Missing date_out or date_in in car booking.');
          continue;
        }

        String dateOutStr = _formatDateString(item['date_out'].toString());
        String dateInStr = _formatDateString(item['date_in'].toString());
        String timeOutStr = item['time_out']?.toString() ?? '00:00';
        String timeInStr = item['time_in']?.toString() ?? '23:59';

        DateTime? startDateTime;
        DateTime? endDateTime;

        try {
          startDateTime = DateTime.parse('$dateOutStr $timeOutStr:00');
          endDateTime = DateTime.parse('$dateInStr $timeInStr:00');
        } catch (e) {
          _showSnackBar('Error parsing car booking dates: $e');
          continue;
        }

        final String uid = 'car_${item['uid']?.toString() ?? UniqueKey().toString()}';

        String status = item['status'] != null
            ? _mapCarStatus(item['status'].toString())
            : 'Pending';

        if (status == 'Cancelled') continue;

        final event = Event(
          title: item['purpose'] ?? 'No Title',
          startDateTime: startDateTime,
          endDateTime: endDateTime,
          description: item['place'] ?? 'Car Booking Pending',
          status: status,
          isMeeting: false,
          category: 'Car Bookings',
          uid: uid,
          location: item['place'] ?? '',
        );

        for (var day = _normalizeDate(startDateTime);
        !day.isAfter(_normalizeDate(endDateTime));
        day = day.add(const Duration(days: 1))) {
          if (carEvents.containsKey(day)) {
            if (!carEvents[day]!.any((e) => e.uid == event.uid)) {
              carEvents[day]!.add(event);
            }
          } else {
            carEvents[day] = [event];
          }
        }
      }

      setState(() {
        _events.value = {..._events.value, ...carEvents};
        _filterAndSearchEvents();
      });
    } catch (e) {
      _showSnackBar('Error parsing car bookings: $e');
    }
  }

  /// Maps API car status to human-readable status
  String _mapCarStatus(String apiStatus) {
    switch (apiStatus.toLowerCase()) {
      case 'approved':
        return 'Approved';
      case 'waiting':
        return 'Pending';
      case 'cancel':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  /// Formats date strings to ensure consistency
  String _formatDateString(String dateStr) {
    try {
      DateTime parsedDate = DateFormat('yyyy-M-d').parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(parsedDate);
    } catch (e) {
      _showSnackBar('Error formatting date string: $e');
      return dateStr;
    }
  }

  /// Handles pull-to-refresh action
  Future<void> _onRefresh() async {
    await _fetchData();
    setState(() {
      _showFiltersAndSearchBar = !_showFiltersAndSearchBar;
    });
  }

  /// Parses color from hex string
  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xff')));
    } catch (_) {
      return Colors.blueAccent;
    }
  }

  /// Retrieves events for a specific day
  List<Event> _getEventsForDay(DateTime day) {
    final normalizedDay = _normalizeDate(day);
    return _events.value[normalizedDay] ?? [];
  }

  /// Filters and searches events based on selected category and search query
  void _filterAndSearchEvents() {
    if (_selectedDay == null) return;
    List<Event> dayEvents = _getEventsForDay(_selectedDay!);
    if (_selectedCategory != 'All') {
      dayEvents = dayEvents.where((event) {
        return event.category == _selectedCategory;
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      dayEvents = dayEvents.where((event) {
        final eventTitle = event.title.toLowerCase();
        final eventDescription = event.description.toLowerCase();
        return eventTitle.contains(_searchQuery.toLowerCase()) ||
            eventDescription.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    setState(() {
      _eventsForDay = dayEvents;
    });
  }

  /// Navigates to day view when a day is double-tapped
  void _showDayView(DateTime selectedDay) {
    final List<Event> dayEvents = _getEventsForDay(selectedDay);
    final List<TimetableItem<String>> timetableItems = dayEvents.map((event) {
      return TimetableItem<String>(
        event.startDateTime,
        event.endDateTime,
        data: event.title,
      );
    }).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TimetablePage(
          date: selectedDay,
          events: timetableItems,
        ),
      ),
    );
  }

  /// Retrieves the color associated with an event category
  Color getEventColor(Event event) {
    return categoryColors[event.category] ?? Colors.grey;
  }

  // Category colors mapping
  final Map<String, Color> categoryColors = {
    'Meetings': Colors.blue,
    'Leave Requests': Colors.red,
    'Meeting Room Bookings': Colors.green,
    'Car Bookings': Colors.purple,
  };

  /// Displays a popup to choose between adding personal or office events
  void _showAddEventOptionsPopup() {
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
                        label: '1. Personal',
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToAddEvent('Personal');
                        },
                      ),
                      const Divider(height: 1),
                      _buildPopupOption(
                        icon: Icons.work,
                        label: '2. Office',
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
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon,
                size: 20, color: Colors.black54, semanticLabel: label),
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
    final newEvent = Event(
      title: title,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      description: description,
      status: status,
      isMeeting: isMeeting,
      category: category,
      uid: uid,
    );
    final normalizedDay = _normalizeDate(startDateTime);
    setState(() {
      if (_events.value.containsKey(normalizedDay)) {
        if (!_events.value[normalizedDay]!
            .any((e) => e.uid == uid)) {
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
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _onRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                // Ensures all children are centered horizontally
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildCalendarHeader(isDarkMode),
                  if (_showFiltersAndSearchBar) _buildFilters(),
                  if (_showFiltersAndSearchBar) _buildSearchBar(),
                  _buildCalendar(context, isDarkMode),
                  _buildSectionSeparator(),
                  _buildCalendarView(context, _eventsForDay), // Removed SizedBox
                ],
              ),
            ),
          ),
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  /// Builds the calendar header with background and add button
  Widget _buildCalendarHeader(bool isDarkMode) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(isDarkMode
              ? 'assets/darkbg.png'
              : 'assets/ready_bg.png'),
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
                const SizedBox(height: 40),
                Text(
                  'Calendar',
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
            top: 42,
            right: 10,
            child: IconButton(
              icon: const Icon(
                Icons.add_circle,
                size: 55,
                color: Colors.green,
                semanticLabel: 'Add Event',
              ),
              onPressed: _showAddEventOptionsPopup,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the filter chips for event categories
  Widget _buildFilters() {
    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
              Event(
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
              color:
              _selectedCategory == category ? Colors.white : Colors.black,
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
          labelText: 'Search Events',
          prefixIcon: const Icon(Icons.search),
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
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
      margin: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Custom Header
          _buildCustomHeader(isDarkMode),
          // TableCalendar without the default header
          Consumer<DateProvider>(
            builder: (context, dateProvider, child) {
              return TableCalendar<Event>(
                rowHeight: 38,
                firstDay: DateTime.utc(2010, 10, 16),
                lastDay: DateTime.utc(2030, 3, 14),
                focusedDay: dateProvider.selectedDate,
                calendarFormat: _calendarFormat,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                },
                headerVisible: false, // Hide the default header
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
                eventLoader: _getEventsForDay,
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.7),
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
                      final sortedEvents = events
                        ..sort((a, b) =>
                            b.startDateTime.compareTo(a.startDateTime));
                      final latestEvents = sortedEvents.take(3).toList();
                      final eventSpans = latestEvents.where((event) {
                        return date.isAfter(
                            event.startDateTime.subtract(const Duration(days: 1))) &&
                            date.isBefore(
                                event.endDateTime.add(const Duration(days: 1)));
                      }).toList();

                      return Align(
                        alignment: Alignment.bottomCenter,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: eventSpans.map((event) {
                            return Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
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
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
                border: Border.all(
                    color: isDarkMode ? Colors.white : Colors.black),
                borderRadius: BorderRadius.circular(4.0),
              ),
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.chevron_left,
                size: 20,
                color: isDarkMode ? Colors.white : Colors.black,
                semanticLabel: 'Previous Month',
              ),
            ),
          ),
          // Current Month and Year
          Consumer<DateProvider>(
            builder: (context, dateProvider, child) {
              return Text(
                DateFormat.yMMMM().format(dateProvider.selectedDate),
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
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
                border: Border.all(
                    color: isDarkMode ? Colors.white : Colors.black),
                borderRadius: BorderRadius.circular(4.0),
              ),
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: isDarkMode ? Colors.white : Colors.black,
                semanticLabel: 'Next Month',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a gradient animated line as a section separator
  Widget _buildSectionSeparator() {
    return const Column(
      children: [
        GradientAnimationLine(),
        SizedBox(
          height: 18,
        ),
      ],
    );
  }

  /// Builds the list view for events on the selected day
  Widget _buildCalendarView(BuildContext context, List<Event> events) {
    if (_selectedDay == null) return const SizedBox.shrink();
    String selectedDateString =
    DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Centered alignment
        children: [
          Text(
            selectedDateString,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center, // Centered text
          ),
          const SizedBox(height: 10),
          events.isEmpty
              ? const Text(
            'No events for this day.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center, // Centered text
          )
              : ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: events.length,
            separatorBuilder: (context, index) =>
            const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final event = events[index];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailView(
                        event: {
                          'title': event.title,
                          'description': event.description,
                          'startDateTime':
                          event.startDateTime.toString(),
                          'endDateTime': event.endDateTime.toString(),
                          'isMeeting': event.isMeeting,
                          'createdBy': event.createdBy ?? '',
                          'location': event.location ?? '',
                          'status': event.status,
                          'img_name': event.imgName ?? '',
                          'created_at': event.createdAt ?? '',
                          'is_repeat': event.isRepeat ?? '',
                          'video_conference': event.videoConference ?? '',
                          'uid': event.uid,
                          'members': event.members ?? [],
                          'category': event.category,
                        },
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: getEventColor(event).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color:
                        getEventColor(event).withOpacity(0.3),
                        offset: const Offset(0, 4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    title: Text(
                      event.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat.Hm().format(event.startDateTime)} - ${DateFormat.Hm().format(event.endDateTime)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        if (event.location != null &&
                            event.location!.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: Colors.white70, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  event.location!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        Text(
                          event.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Gradient animated line widget
class GradientAnimationLine extends StatefulWidget {
  const GradientAnimationLine({super.key});

  @override
  _GradientAnimationLineState createState() =>
      _GradientAnimationLineState();
}

class _GradientAnimationLineState extends State<GradientAnimationLine>
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
      begin: Colors.yellow,
      end: Colors.orange,
    ).animate(_controller);
    _colorAnimation2 = ColorTween(
      begin: Colors.orange,
      end: Colors.yellow,
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
          height: 8.0,
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
          margin:
          const EdgeInsets.symmetric(horizontal: 15.0, vertical: 2.0),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildSectionSeparator();
  }
}

/// Event model class
class Event {
  final String title;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String description;
  final String status;
  final bool isMeeting;
  final String? location;
  final String? createdBy;
  final String? imgName;
  final String? createdAt;
  final String uid;
  final String? isRepeat;
  final String? videoConference;
  final Color? backgroundColor;
  final String? outmeetingUid;
  final String category;
  final List<Map<String, dynamic>>? members;

  Event({
    required this.title,
    required this.startDateTime,
    required this.endDateTime,
    required this.description,
    required this.status,
    required this.isMeeting,
    this.location,
    this.createdBy,
    this.imgName,
    this.createdAt,
    required this.uid,
    this.isRepeat,
    this.videoConference,
    this.backgroundColor,
    this.outmeetingUid,
    required this.category,
    this.members,
  });

  /// Returns formatted time for display
  String get formattedTime => DateFormat.jm().format(startDateTime);

  @override
  String toString() =>
      '$title ($status) from ${DateFormat.yMMMd().format(startDateTime)} to ${DateFormat.yMMMd().format(endDateTime)}';
}

/// Data source for Syncfusion Calendar
class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Event> source) {
    appointments = source;
  }

  @override
  DateTime getStartTime(int index) {
    return appointments![index].startDateTime;
  }

  @override
  DateTime getEndTime(int index) {
    return appointments![index].endDateTime;
  }

  @override
  String getSubject(int index) {
    return appointments![index].title;
  }

  @override
  Color getColor(int index) {
    return appointments![index].backgroundColor ?? Colors.blueAccent;
  }

  @override
  bool isAllDay(int index) {
    return false;
  }
}
