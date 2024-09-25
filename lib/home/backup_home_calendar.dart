import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timetable/flutter_timetable.dart';
import 'package:pb_hrsystem/home/event_detail_view.dart';
import 'package:pb_hrsystem/home/office_events/office_add_event.dart';
import 'package:pb_hrsystem/home/timetable_page.dart';
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
import 'package:dotted_border/dotted_border.dart';

class HomeCalendar extends StatefulWidget {
  const HomeCalendar({super.key});

  @override
  _HomeCalendarState createState() => _HomeCalendarState();
}

class _HomeCalendarState extends State<HomeCalendar> with TickerProviderStateMixin {
  final String baseUrl = 'https://demo-application-api.flexiflows.co';
  late final ValueNotifier<Map<DateTime, List<Event>>> _events;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _singleTapSelectedDay;
  List<Event> _eventsForDay = [];
  late final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  bool _showFiltersAndSearchBar = false;
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Meetings', 'Leave Requests', 'Meeting Room Bookings', 'Car Bookings'];
  String _searchQuery = '';
  late final AnimationController _animationController;
  Timer? _doubleTapTimer;
  static const int doubleTapDelay = 300;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _events = ValueNotifier({});
    _eventsForDay = [];
    _fetchMeetingData();
    _fetchLeaveRequests();
    _fetchMeetingRoomBookings();
    _fetchCarBookings();
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _events.dispose();
    _animationController.dispose();
    _doubleTapTimer?.cancel();
    super.dispose();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _fetchLeaveRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _showErrorDialog('Authentication Error', 'Token is null. Please log in again.');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/leave_requests'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body)['results'];
        final leaveRequests = List<Map<String, dynamic>>.from(results);

        final Map<DateTime, List<Event>> approvalEvents = {};
        for (var item in leaveRequests) {
          final DateTime startDate = _normalizeDate(DateTime.parse(item['take_leave_from']));
          final DateTime endDate = _normalizeDate(DateTime.parse(item['take_leave_to']));
          final String uid = 'leave_${item['id']}';
          String status;
          switch (item['is_approve']) {
            case 'Approved':
              status = 'Approved';
              break;
            case 'Waiting':
            case 'Processing':
              status = 'Pending';
              break;
            case 'Cancel':
              status = 'Cancelled';
              break;
            default:
              status = 'Pending';
          }
          if (status == 'Cancelled') continue;
          final event = Event(
            item['name'],
            startDate,
            endDate,
            item['take_leave_reason'] ?? 'Approval Pending',
            status: status,
            isMeeting: false,
            category: 'Leave Requests',
            uid: uid,
          );
          for (var day = startDate; day.isBefore(endDate.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
            final normalizedDay = _normalizeDate(day);
            if (approvalEvents.containsKey(normalizedDay)) {
              if (!approvalEvents[normalizedDay]!.any((e) => e.uid == event.uid)) {
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
      } else {
        _showErrorDialog('Failed to Load Leave Requests', 'Server returned status code: ${response.statusCode}. Message: ${response.reasonPhrase}');
      }
    } catch (e) {
      _showErrorDialog('Error Fetching Leave Requests', 'An unexpected error occurred: $e');
    }
  }

  Future<void> _fetchMeetingData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _showErrorDialog('Authentication Error', 'Token is null. Please log in again.');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/work-tracking/out-meeting/outmeeting/my-members'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data == null || data['results'] == null || data['results'] is! List) {
          _showErrorDialog('Error Fetching Meetings', 'No meeting data available.');
          return;
        }

        final List<dynamic> results = data['results'];
        final Map<DateTime, List<Event>> meetingEvents = {};

        for (var item in results) {
          final DateTime startDate = DateTime.parse(item['fromdate']);
          final DateTime endDate = DateTime.parse(item['todate']);
          final Color eventColor = _parseColor(item['backgroundColor']);
          final String uid = item['outmeeting_uid'] ?? UniqueKey().toString();
          String status;
          switch (item['status']) {
            case 'approved':
              status = 'Approved';
              break;
            case 'waiting':
              status = 'Pending';
              break;
            case 'disapproved':
              status = 'Cancelled';
              break;
            default:
              status = 'Pending';
          }
          if (status == 'Cancelled') continue;
          final event = Event(
            item['title'],
            startDate,
            endDate,
            item['description'] ?? '',
            status: status,
            isMeeting: true,
            location: item['location'] ?? '',
            createdBy: item['created_by'] ?? '',
            imgName: item['img_name'] ?? '',
            createdAt: item['created_at'] ?? '',
            uid: uid,
            isRepeat: item['is_repeat'] ?? '',
            videoConference: item['video_conference'] ?? '',
            backgroundColor: eventColor,
            outmeetingUid: item['outmeeting_uid'] ?? '',
            category: 'Meetings',
          );
          for (var day = startDate; day.isBefore(endDate.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
            final normalizedDay = _normalizeDate(day);
            if (meetingEvents.containsKey(normalizedDay)) {
              if (!meetingEvents[normalizedDay]!.any((e) => e.uid == event.uid)) {
                meetingEvents[normalizedDay]!.add(event);
              }
            } else {
              meetingEvents[normalizedDay] = [event];
            }
          }
        }

        setState(() {
          _events.value = {..._events.value, ...meetingEvents};
          _filterAndSearchEvents();
        });
      } else {
        _showErrorDialog('Failed to Load Meetings', 'Server returned status code: ${response.statusCode}. Message: ${response.reasonPhrase}');
      }
    } catch (e) {
      _showErrorDialog('Error Fetching Meetings', 'An unexpected error occurred: $e');
    }
  }

  Future<void> _fetchMeetingRoomBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _showErrorDialog('Authentication Error', 'Token is null. Please log in again.');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/office-administration/book_meeting_room/my-requests'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body)['results'];
        final meetingRoomBookings = List<Map<String, dynamic>>.from(results);

        final Map<DateTime, List<Event>> bookingEvents = {};
        for (var item in meetingRoomBookings) {
          final DateTime startDate = _normalizeDate(DateTime.parse(item['from_date_time']));
          final DateTime endDate = _normalizeDate(DateTime.parse(item['to_date_time']));
          final String uid = 'booking_${item['uid']}';
          String status;
          switch (item['status']) {
            case 'approved':
              status = 'Approved';
              break;
            case 'waiting':
              status = 'Pending';
              break;
            case 'disapproved':
              status = 'Cancelled';
              break;
            default:
              status = 'Pending';
          }
          if (status == 'Cancelled') continue;
          final event = Event(
            item['title'],
            startDate,
            endDate,
            item['remark'] ?? 'Booking Pending',
            status: status,
            isMeeting: true,
            category: 'Meeting Room Bookings',
            uid: uid,
          );
          for (var day = startDate; day.isBefore(endDate.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
            final normalizedDay = _normalizeDate(day);
            if (bookingEvents.containsKey(normalizedDay)) {
              if (!bookingEvents[normalizedDay]!.any((e) => e.uid == event.uid)) {
                bookingEvents[normalizedDay]!.add(event);
              }
            } else {
              bookingEvents[normalizedDay] = [event];
            }
          }
        }

        setState(() {
          _events.value = {..._events.value, ...bookingEvents};
          _filterAndSearchEvents();
        });
      } else {
        _showErrorDialog('Failed to Load Meeting Room Bookings', 'Server returned status code: ${response.statusCode}. Message: ${response.reasonPhrase}');
      }
    } catch (e) {
      _showErrorDialog('Error Fetching Meeting Room Bookings', 'An unexpected error occurred: $e');
    }
  }

  Future<void> _fetchCarBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _showErrorDialog('Authentication Error', 'Token is null. Please log in again.');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/office-administration/car_permits/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body)['results'];
        final carBookings = List<Map<String, dynamic>>.from(results);

        final Map<DateTime, List<Event>> carEvents = {};
        for (var item in carBookings) {
          final DateTime startDate = _normalizeDate(DateTime.parse(item['date_out']));
          final DateTime endDate = _normalizeDate(DateTime.parse(item['date_in']));
          final String uid = 'car_${item['uid']}';
          String status;
          switch (item['status']) {
            case 'approved':
              status = 'Approved';
              break;
            case 'waiting':
              status = 'Pending';
              break;
            case 'cancel':
              status = 'Cancelled';
              break;
            default:
              status = 'Pending';
          }
          if (status == 'Cancelled') continue;
          final event = Event(
            item['purpose'],
            startDate,
            endDate,
            item['purpose'] ?? 'Car Booking Pending',
            status: status,
            isMeeting: false,
            category: 'Car Bookings',
            uid: uid,
          );
          for (var day = startDate; day.isBefore(endDate.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
            final normalizedDay = _normalizeDate(day);
            if (carEvents.containsKey(normalizedDay)) {
              if (!carEvents[normalizedDay]!.any((e) => e.uid == event.uid)) {
                carEvents[normalizedDay]!.add(event);
              }
            } else {
              carEvents[normalizedDay] = [event];
            }
          }
        }

        setState(() {
          _events.value = {..._events.value, ...carEvents};
          _filterAndSearchEvents();
        });
      } else {
        _showErrorDialog('Failed to Load Car Bookings', 'Server returned status code: ${response.statusCode}. Message: ${response.reasonPhrase}');
      }
    } catch (e) {
      _showErrorDialog('Error Fetching Car Bookings', 'An unexpected error occurred: $e');
    }
  }

  void _showEventDetailModal(Event event) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(event.title, semanticsLabel: event.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Description: ${event.description}', semanticsLabel: 'Description: ${event.description}'),
              Text('Status: ${event.status}', semanticsLabel: 'Status: ${event.status}'),
              if (event.isMeeting && event.location != null)
                Text('Location: ${event.location}', semanticsLabel: 'Location: ${event.location}'),
              if (event.isMeeting && event.createdBy != null)
                Text('Created By: ${event.createdBy}', semanticsLabel: 'Created By: ${event.createdBy}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close', semanticsLabel: 'Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onRefresh() async {
    setState(() {
      _showFiltersAndSearchBar = !_showFiltersAndSearchBar;
    });
    await _fetchMeetingData();
    await _fetchLeaveRequests();
    await _fetchMeetingRoomBookings();
    await _fetchCarBookings();
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xff')));
    } catch (_) {
      return Colors.blueAccent;
    }
  }

  List<Event> _getEventsForDay(DateTime day) {
    final normalizedDay = _normalizeDate(day);
    return _events.value[normalizedDay] ?? [];
  }

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
    if (kDebugMode) {
      print('Filtered Events: $_eventsForDay');
    }
  }

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

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title, semanticsLabel: title),
          content: Text(message, semanticsLabel: message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK', semanticsLabel: 'OK'),
            ),
          ],
        );
      },
    );
  }

  final Map<String, Color> categoryColors = {
    'Meetings': Colors.blue,
    'Leave Requests': Colors.red,
    'Meeting Room Bookings': Colors.green,
    'Car Bookings': Colors.orange,
  };

  Color getEventColor(Event event) {
    return categoryColors[event.category] ?? Colors.grey;
  }

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
          newEvent['title'],
          DateTime.parse(newEvent['startDateTime']),
          DateTime.parse(newEvent['endDateTime']),
          newEvent['description'] ?? '',
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

  void _addEvent(
      String title,
      DateTime startDateTime,
      DateTime endDateTime,
      String description, {
        required String status,
        required bool isMeeting,
        required String category,
        required String uid,
      }) {
    final newEvent = Event(
      title,
      startDateTime,
      endDateTime,
      description,
      status: status,
      isMeeting: isMeeting,
      category: category,
      uid: uid,
    );
    final normalizedDay = _normalizeDate(startDateTime);
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
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _onRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildCalendarHeader(isDarkMode),
                  if (_showFiltersAndSearchBar) _buildFilters(),
                  if (_showFiltersAndSearchBar) _buildSearchBar(),
                  _buildCalendar(isDarkMode),
                  _buildSectionSeparator(),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: _buildCalendarView(context, _eventsForDay),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader(bool isDarkMode) {
    return Container(
      width: double.infinity,
      height: 140,
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
                const SizedBox(height: 60),
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
            top: 60,
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
            selectedColor: getEventColor(Event('', DateTime.now(), DateTime.now(), '', status: '', isMeeting: false, category: category, uid: '')),
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: _selectedCategory == category ? Colors.white : Colors.black,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TextField(
        decoration: InputDecoration(
          labelText: 'Search Events',
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

  Widget _buildCalendar(bool isDarkMode) {
    return Container(
      height: 250,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: TableCalendar<Event>(
        rowHeight: 35,
        firstDay: DateTime.utc(2010, 10, 16),
        lastDay: DateTime.utc(2030, 3, 14),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        availableCalendarFormats: const {CalendarFormat.month: 'Month'},
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          if (_singleTapSelectedDay != null && isSameDay(_singleTapSelectedDay, selectedDay)) {
            _showDayView(selectedDay);
            _singleTapSelectedDay = null;
          } else {
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
            setState(() => _calendarFormat = CalendarFormat.month);
          }
        },
        onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
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
        ),
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left,
            size: 14,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            size: 14,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isNotEmpty) {
              final eventSpans = events.take(3).toList();
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
      ),
    );
  }

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

  Widget _buildCalendarView(BuildContext context, List<Event> events) {
    String selectedDateString = DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!);
    return Column(
      children: [
        Center(
          child: Text(
            selectedDateString,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Scrollbar(
            child: ListView.builder(
              itemCount: 11,
              itemBuilder: (context, index) {
                final hour = 7 + index;
                final startTime = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day, hour, 0);
                final endTime = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day, hour + 1, 0);
                final hourEvents = events.where((event) {
                  return (event.startDateTime.hour <= hour && event.endDateTime.hour > hour) ||
                      (!event.isMeeting && event.startDateTime.hour == 0 && event.endDateTime.hour == 0);
                }).toList();
                return Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            DateFormat.j().format(startTime),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
                              ),
                            ),
                            child: hourEvents.isEmpty
                                ? const SizedBox()
                                : Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: hourEvents.map((event) {
                                return GestureDetector(
                                  onTap: () {
                                    _showEventDetailModal(event);
                                  },
                                  child: Container(
                                    width: MediaQuery.of(context).size.width - 80,
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      color: getEventColor(event).withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      event.title,
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class GradientAnimationLine extends StatefulWidget {
  const GradientAnimationLine({super.key});

  @override
  _GradientAnimationLineState createState() => _GradientAnimationLineState();
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
          margin: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 2.0),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildSectionSeparator();
  }
}

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

  Event(
      this.title,
      this.startDateTime,
      this.endDateTime,
      this.description, {
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
      });

  String get formattedTime => DateFormat.jm().format(startDateTime);

  @override
  String toString() =>
      '$title ($status) from ${DateFormat.yMMMd().format(startDateTime)} to ${DateFormat.yMMMd().format(endDateTime)}';
}

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
