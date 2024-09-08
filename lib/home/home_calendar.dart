import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_timetable/flutter_timetable.dart';
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

class HomeCalendar extends StatefulWidget {
  const HomeCalendar({super.key});

  @override
  _HomeCalendarState createState() => _HomeCalendarState();
}

class _HomeCalendarState extends State<HomeCalendar> {
  late final ValueNotifier<Map<DateTime, List<Event>>> _events;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _singleTapSelectedDay;
  DateTime _syncfusionSelectedDate = DateTime.now();
  List<Event> _eventsForDay = [];
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _events = ValueNotifier({});
    _eventsForDay = [];
    _fetchMeetingData();

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    _fetchLeaveRequests();
    _fetchMeetingData();
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
          final event = Event(
            item['name'],
            startDate,
            endDate,
            item['take_leave_reason'] ?? 'Approval Pending',
            item['is_approve'] ?? 'Waiting',
            false,
          );

          for (var day = startDate;
          day.isBefore(endDate.add(const Duration(days: 1)));
          day = day.add(const Duration(days: 1))) {
            final normalizedDay = _normalizeDate(day);
            if (approvalEvents.containsKey(normalizedDay)) {
              approvalEvents[normalizedDay]!.add(event);
            } else {
              approvalEvents[normalizedDay] = [event];
            }
          }
        }

        setState(() {
          _events.value = approvalEvents;
          _eventsForDay = _getEventsForDay(_focusedDay);
        });
      } else {
        _showErrorDialog(
            'Failed to Load Leave Requests', 'Server returned status code: ${response.statusCode}. Message: ${response.reasonPhrase}');
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
        Uri.parse('https://demo-application-api.flexiflows.co/api/work-tracking/out-meeting/outmeeting/my-members'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body)['results'];
        final Map<DateTime, List<Event>> meetingEvents = {};

        for (var item in results) {
          final DateTime startDate = DateTime.parse(item['fromdate']);
          final DateTime endDate = DateTime.parse(item['todate']);
          final Color eventColor = _parseColor(item['backgroundColor']);
          final event = Event(
            item['title'],
            startDate,
            endDate,
            item['description'] ?? '',
            'Meeting',
            true,
          );

          for (var day = startDate;
          day.isBefore(endDate.add(const Duration(days: 1)));
          day = day.add(const Duration(days: 1))) {
            final normalizedDay = _normalizeDate(day);
            if (meetingEvents.containsKey(normalizedDay)) {
              meetingEvents[normalizedDay]!.add(event);
            } else {
              meetingEvents[normalizedDay] = [event];
            }
          }
        }

        setState(() {
          _events.value.addAll(meetingEvents);
          _eventsForDay = _getEventsForDay(_focusedDay);
        });
      } else {
        _showErrorDialog('Failed to Load Meetings', 'Server returned status code: ${response.statusCode}. Message: ${response.reasonPhrase}');
      }
    } catch (e) {
      _showErrorDialog('Error Fetching Meetings', 'An unexpected error occurred: $e');
    }
  }

  Color _parseColor(String colorString) {

    return Color(int.parse(colorString.replaceFirst('#', '0xff')));
  }


  List<Event> _getEventsForDay(DateTime day) {
    final normalizedDay = _normalizeDate(day);
    return _events.value[normalizedDay] ?? [];
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

  TimetableItem<String> convertEventToTimetableItem(Event event) {
    return TimetableItem<String>(
      event.startDateTime,
      event.endDateTime,
      data: event.title,
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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
              _buildCalendar(isDarkMode),
              _buildSectionSeparator(),
              Expanded(
                child: _buildCalendarView(),
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
                const SizedBox(height: 50),
                Text(
                  'Calendar',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 55,
            right: 20,
            child: IconButton(
              icon: const Icon(
                Icons.add_circle,
                size: 40,
                color: Colors.green,
              ),
              onPressed: _showAddEventOptionsPopup,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(bool isDarkMode) {
    return Container(
      height: 270,
      margin: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black : Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        borderRadius: BorderRadius.circular(8),
      ),
      child: TableCalendar<Event>(
        rowHeight: 38,
        firstDay: DateTime.utc(2010, 10, 16),
        lastDay: DateTime.utc(2030, 3, 14),
        focusedDay: _focusedDay,
        calendarFormat: CalendarFormat.month,
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
              _syncfusionSelectedDate = selectedDay;
              _eventsForDay = _getEventsForDay(selectedDay);
            });
          }
        },
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() {
              _calendarFormat = format;
            });
          }
        },
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
        },
        eventLoader: _getEventsForDay,
        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Colors.orangeAccent,
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
          outsideDaysVisible: false,
          weekendTextStyle: TextStyle(color: Colors.black),
          defaultTextStyle: TextStyle(color: Colors.black),
        ),
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left,
            size: 16,
            color: Colors.black,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            size: 16,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionSeparator() {
    return const Column(
      children: [
        GradientAnimationLine(),
        SizedBox(
          height: 15,
        ),
      ],
    );
  }

  Widget _buildCalendarView() {
    // Time slots from 7 AM to 6 PM
    final List<String> timeSlots = List.generate(12, (index) {
      final hour = index + 7;
      final formattedHour = hour > 12 ? hour - 12 : hour;
      final period = hour >= 12 ? 'PM' : 'AM';
      return '${formattedHour.toString().padLeft(2, '0')} $period';
    });

    // Example events
    final List<Map<String, dynamic>> dummyEvents = [
      {
        'title': 'Sale Presentation: HI App production',
        'time': '07:00 AM - 12:00 PM',
        'location': 'Meeting Onsite',
        'attendees': [
          'assets/avatar1.png',
          'assets/avatar2.png',
          'assets/avatar3.png',
          'assets/avatar4.png',
          'assets/avatar5.png'
        ],
        'color': Colors.green.shade100,
        'isMinutesOfMeeting': true,
        'startHour': 7,
        'duration': 5, // 5-hour duration
      },
      {
        'title': 'Pick up from Hotel to Bank',
        'time': '08:00 AM - 10:00 AM',
        'location': '',
        'attendees': [
          'assets/avatar1.png',
          'assets/avatar2.png',
        ],
        'color': Colors.blue.shade100,
        'isMinutesOfMeeting': false,
        'startHour': 8,
        'duration': 2,
      },
      {
        'title': 'Japan Vendor',
        'time': '08:00 AM - 09:00 AM',
        'location': 'Tokyo, Japan',
        'attendees': [
          'assets/avatar_placeholder.png',
          'assets/avatar_placeholder.png',
          'assets/avatar_placeholder.png',
          'assets/avatar_placeholder.png',
        ],
        'color': Colors.red.shade100,
        'isMinutesOfMeeting': false,
        'startHour': 8,
        'duration': 1,
      },
      {
        'title': 'Deadline for HIAPP product',
        'time': '09:00 AM - 10:00 AM',
        'location': 'Meeting Onsite',
        'attendees': [
          'assets/avatar_placeholder.png',
          'assets/avatar_placeholder.png',
          'assets/avatar_placeholder.png',
          'assets/avatar_placeholder.png',
        ],
        'color': Colors.orange.shade100,
        'isMinutesOfMeeting': false,
        'startHour': 9,
        'duration': 2,
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        children: timeSlots.map((timeSlot) {
          int timeSlotHour = int.parse(timeSlot.split(" ")[0]);
          String period = timeSlot.split(" ")[1];
          if (period == "PM" && timeSlotHour != 12) {
            timeSlotHour += 12;
          }

          final List<Map<String, dynamic>> eventsForThisHour = dummyEvents.where((event) {
            int eventStartHour = event['startHour'];
            int eventEndHour = eventStartHour + (event['duration'] as int);

            return timeSlotHour == eventStartHour ||
                (timeSlotHour > eventStartHour && timeSlotHour < eventEndHour);
          }).toList();


          final Set<String> eventTitlesDisplayed = {};

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: SizedBox(
                        width: 60,
                        height: 20,
                        child: Text(
                          timeSlot,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 140.0,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: eventsForThisHour.where((event) {
                            if (eventTitlesDisplayed.contains(event['title'])) {
                              return false;
                            }
                            eventTitlesDisplayed.add(event['title']);
                            return true;
                          }).map((event) {
                            int eventStart = event['startHour'];
                            int eventEnd = eventStart + (event['duration'] as int);

                            double eventHeight = (eventEnd - eventStart) * 140.0;

                            return Container(
                              width: MediaQuery.of(context).size.width * 0.8 / eventsForThisHour.length,
                              margin: const EdgeInsets.only(right: 8.0, bottom: 12.0),
                              padding: const EdgeInsets.all(8.0),
                              height: eventHeight,
                              decoration: BoxDecoration(
                                color: event['color'],
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event['title'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (event['location'] != '')
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          event['location'],
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    event['time'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: (event['attendees'] as List<String>).map((avatar) {
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 4.0),
                                        child: CircleAvatar(
                                          radius: 14,
                                          backgroundImage: AssetImage(avatar),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        }).toList(),
      ),
    );
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
            Icon(icon, size: 20, color: Colors.black54),
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
          newEvent['startDateTime'],
          newEvent['endDateTime'],
          newEvent['description'] ?? '',
          'Pending', // Default to pending status for new events
          true, // isMeeting set to true for office events
        );
      }
    }
  }

  void _addEvent(String title, DateTime startDateTime, DateTime endDateTime,
      String description, String status, bool isMeeting) {
    final newEvent = Event(
        title, startDateTime, endDateTime, description, status, isMeeting);
    final eventsForDay = _getEventsForDay(_selectedDay!);
    setState(() {
      _events.value = {
        ..._events.value,
        _selectedDay!: [...eventsForDay, newEvent],
      };
      _eventsForDay = _getEventsForDay(_selectedDay!);
    });
  }
}

// Animation and Event classes
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

  Event(this.title, this.startDateTime, this.endDateTime, this.description,
      this.status, this.isMeeting);

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
