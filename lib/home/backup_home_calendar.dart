import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_timetable/flutter_timetable.dart';
import 'package:pb_hrsystem/home/event_detail_view.dart';
import 'package:pb_hrsystem/home/office_events/office_add_event.dart';
import 'package:pb_hrsystem/home/timetable_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:pb_hrsystem/home/leave_request_page.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:fluttertoast/fluttertoast.dart';

class HomeCalendar extends StatefulWidget {
  const HomeCalendar({super.key});

  @override
  _HomeCalendarState createState() => _HomeCalendarState();
}

class _HomeCalendarState extends State<HomeCalendar> with TickerProviderStateMixin {
  late final ValueNotifier<Map<DateTime, List<Event>>> _events;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _singleTapSelectedDay;
  List<Event> _eventsForDay = [];
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  // Filtering and Search
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Meetings', 'Leave Requests'];
  String _searchQuery = '';

  // Animation Controller
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _events = ValueNotifier({});
    _eventsForDay = [];
    _fetchMeetingData();
    _fetchLeaveRequests();

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
        Uri.parse('https://demo-application-api.flexiflows.co/api/leave_requests'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body)['results'];
        final leaveRequests = List<Map<String, dynamic>>.from(results);

        final Map<DateTime, List<Event>> approvalEvents = {};
        for (var item in leaveRequests) {
          final DateTime startDate = _normalizeDate(DateTime.parse(item['take_leave_from']));
          final DateTime endDate = _normalizeDate(DateTime.parse(item['take_leave_to']));
          final String uid = 'leave_${item['id'] ?? UniqueKey().toString()}'; // Ensure unique UID

          final event = Event(
            item['name'],
            startDate,
            endDate,
            item['take_leave_reason'] ?? 'Approval Pending',
            status: item['is_approve'] == 1 ? 'Approved' : 'Waiting',
            isMeeting: false,
            category: 'Leave Requests',
            uid: uid,
          );

          for (var day = startDate;
          day.isBefore(endDate.add(const Duration(days: 1)));
          day = day.add(const Duration(days: 1))) {
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
        _showErrorDialog('Failed to Load Leave Requests',
            'Server returned status code: ${response.statusCode}. Message: ${response.reasonPhrase}');
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
        Uri.parse(
            'https://demo-application-api.flexiflows.co/api/work-tracking/out-meeting/outmeeting/my-members'),
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
          final String uid = item['outmeeting_uid'] ?? UniqueKey().toString(); // Ensure unique UID

          final event = Event(
            item['title'],
            startDate,
            endDate,
            item['description'] ?? '',
            status: item['status'] ?? '',
            isMeeting: true,
            location: item['location'] ?? '',
            createdBy: item['created_by_name'] ?? '',
            imgName: item['img_name'] ?? '',
            createdAt: item['created_at'] ?? '',
            uid: uid,
            isRepeat: item['is_repeat'] ?? '',
            videoConference: item['video_conference'] ?? '',
            backgroundColor: eventColor,
            outmeetingUid: item['outmeeting_uid'] ?? '',
            category: 'Meetings',
          );

          for (var day = startDate;
          day.isBefore(endDate.add(const Duration(days: 1)));
          day = day.add(const Duration(days: 1))) {
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
        _showErrorDialog('Failed to Load Meetings',
            'Server returned status code: ${response.statusCode}. Message: ${response.reasonPhrase}');
      }
    } catch (e) {
      _showErrorDialog('Error Fetching Meetings', 'An unexpected error occurred: $e');
    }
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
      dayEvents = dayEvents.where((event) => event.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      dayEvents = dayEvents
          .where((event) =>
      event.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          event.description.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    setState(() {
      _eventsForDay = dayEvents;
    });
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

  final List<Color> colors = [
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.purpleAccent,
    Colors.orangeAccent,
    Colors.tealAccent,
  ];

  Color getEventColor(Event event) {
    if (event.isMeeting && event.backgroundColor != null) {
      return event.backgroundColor!;
    }
    return colors[event.hashCode % colors.length];
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
          Column(
            children: [
              _buildCalendarHeader(isDarkMode),
              _buildFilters(),
              _buildSearchBar(),
              _buildCalendar(isDarkMode),
              _buildSectionSeparator(),
              Expanded(
                child: _buildCalendarView(context, _eventsForDay),
              ),
            ],
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
            selectedColor: Colors.blueAccent,
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
      height: 300,
      margin: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TableCalendar<Event>(
        rowHeight: 38,
        firstDay: DateTime.utc(2010, 10, 16),
        lastDay: DateTime.utc(2030, 3, 14),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        availableCalendarFormats: const {
          CalendarFormat.month: 'Month',
        },
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },
        onDaySelected: (selectedDay, focusedDay) {
          if (_singleTapSelectedDay != null &&
              isSameDay(_singleTapSelectedDay, selectedDay)) {
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
          // Ensure that the calendar format remains within available formats
          if (format != CalendarFormat.month) {
            setState(() {
              _calendarFormat = CalendarFormat.month;
            });
          }
        },
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
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
          weekendTextStyle:
          TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54),
          defaultTextStyle:
          TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          markerDecoration: const BoxDecoration(
            color: Colors.transparent,
          ),
        ),
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left,
            size: 16,
            color: isDarkMode ? Colors.white : Colors.black,
            semanticLabel: 'Previous Month',
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            size: 16,
            color: isDarkMode ? Colors.white : Colors.black,
            semanticLabel: 'Next Month',
          ),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isNotEmpty) {
              final sortedEvents = events
                ..sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
              final latestEvents = sortedEvents.take(3).toList();
              final eventSpans = latestEvents.where((event) {
                return date.isAfter(event.startDateTime.subtract(const Duration(days: 1))) &&
                    date.isBefore(event.endDateTime.add(const Duration(days: 1)));
              }).toList();

              return Align(
                alignment: Alignment.bottomCenter,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: eventSpans.map((event) {
                    return Container(
                      width: 6,
                      height: 6,
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
          height: 5,
        ),
      ],
    );
  }

  Widget _buildCalendarView(BuildContext context, List<Event> events) {
    final List<String> timeSlots = List.generate(12, (index) {
      final hour = index + 7;
      final formattedHour = hour > 12 ? hour - 12 : hour;
      final period = hour >= 12 ? 'PM' : 'AM';
      return '${formattedHour.toString().padLeft(2, '0')} $period';
    });

    String selectedDateString = DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!);

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
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
          ),
          if (events.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text(
                  "There are no events this day",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          else
            Column(
              children: timeSlots.map((timeSlot) {
                int timeSlotHour = int.parse(timeSlot.split(" ")[0]);
                String period = timeSlot.split(" ")[1];
                if (period == "PM" && timeSlotHour != 12) {
                  timeSlotHour += 12;
                }

                final List<Event> eventsForThisHour = events.where((event) {
                  int eventStartHour = event.startDateTime.hour;
                  int eventEndHour = event.endDateTime.hour;
                  return timeSlotHour == eventStartHour ||
                      (timeSlotHour > eventStartHour && timeSlotHour < eventEndHour);
                }).toList();

                return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width > 800 ? 24.0 : 18.0,
                      vertical: MediaQuery.of(context).size.width > 800 ? 6.0 : 2.0,
                    ),
                    child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: SizedBox(
                                  width: MediaQuery.of(context).size.width > 800
                                      ? MediaQuery.of(context).size.width * 0.12
                                      : MediaQuery.of(context).size.width * 0.10,
                                  height: 24,
                                  child: Text(
                                    timeSlot,
                                    style: TextStyle(
                                      fontSize: MediaQuery.of(context).size.width > 800
                                          ? MediaQuery.of(context).size.width * 0.025
                                          : MediaQuery.of(context).size.width * 0.03,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: eventsForThisHour.map((event) {
                                    final eventColor = getEventColor(event);

                                    return InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EventDetailView(
                                              event: {
                                                'title': event.title,
                                                'time':
                                                '${DateFormat.jm().format(event.startDateTime)} - ${DateFormat.jm().format(event.endDateTime)}',
                                                'location': event.location ?? '',
                                                'status': event.status,
                                                'description': event.description,
                                                'createdBy': event.createdBy ?? '',
                                                'isRepeat': event.isRepeat ?? '',
                                                'videoConference': event.videoConference ?? '',
                                                'uid': event.uid ?? '',
                                                'img_name': event.imgName ?? '',
                                                'created_at': event.createdAt ?? '',
                                                'isMeeting': event.isMeeting,
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        padding: const EdgeInsets.all(16.0),
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(15),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 8,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                          border: Border(
                                            right: BorderSide(
                                              color: eventColor,
                                              width: 6,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              event.title,
                                              style: TextStyle(
                                                fontSize: MediaQuery.of(context).size.width * 0.04,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.access_time,
                                                    size: 16, color: Colors.green, semanticLabel: 'Time'),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${DateFormat.jm().format(event.startDateTime)} - ${DateFormat.jm().format(event.endDateTime)}',
                                                  style: const TextStyle(color: Colors.black54),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (event.location != null && event.location!.isNotEmpty) ...[
                                              Row(
                                                children: [
                                                  const Icon(Icons.location_on,
                                                      size: 16, color: Colors.red, semanticLabel: 'Location'),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    event.location!,
                                                    style: const TextStyle(color: Colors.black54),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                            ],
                                            if (event.createdBy != null && event.createdBy!.isNotEmpty) ...[
                                              Row(
                                                children: [
                                                  const Icon(Icons.person,
                                                      size: 16, color: Colors.blue, semanticLabel: 'Created By'),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Created by: ${event.createdBy}',
                                                    style: const TextStyle(color: Colors.black54),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                            ],
                                            if (event.description.isNotEmpty) ...[
                                              Row(
                                                children: [
                                                  const Icon(Icons.description,
                                                      size: 16, color: Colors.grey, semanticLabel: 'Description'),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      event.description,
                                                      style: const TextStyle(color: Colors.black54),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                            ],
                                            Row(
                                              children: [
                                                const Icon(Icons.check_circle,
                                                    size: 16, color: Colors.green, semanticLabel: 'Status'),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Status: ${event.status}',
                                                  style: const TextStyle(color: Colors.black54),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.event,
                                                    size: 16, color: Colors.orange, semanticLabel: 'Category'),
                                                const SizedBox(width: 8),
                                                Text(
                                                  event.category,
                                                  style: const TextStyle(color: Colors.black54),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ]));
              }).toList(),
            ),
        ],
      ),
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
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation1;
  late Animation<Color?> _colorAnimation2;

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
  bool isAllDay(int index) {
    return false;
  }
}
