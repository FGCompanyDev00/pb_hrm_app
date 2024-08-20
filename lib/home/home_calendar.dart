import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/office_events/office_add_event.dart';
import 'package:pb_hrsystem/home/popups/event_details_popups.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:pb_hrsystem/home/leave_request_page.dart';
import 'package:http/http.dart' as http;

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
  List<Map<String, dynamic>> _leaveRequests = [];

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _events = ValueNotifier({});

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    _fetchLeaveRequests(); // Fetch approvals and initialize events in the calendar
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
        _leaveRequests = List<Map<String, dynamic>>.from(results);

        // Map API data to calendar events
        final Map<DateTime, List<Event>> approvalEvents = {};
        for (var item in _leaveRequests) {
          final DateTime startDate = DateTime.parse(item['take_leave_from']);
          final DateTime endDate = DateTime.parse(item['take_leave_to']);
          final event = Event(
            item['name'],
            startDate,
            endDate,
            item['take_leave_reason'] ?? 'Approval Pending',
            item['is_approve'] ?? 'Waiting', // Status: Approved, Rejected, Waiting
            false, // isMeeting set to false for leave requests
          );

          // Add event to each day between startDate and endDate
          for (var day = startDate;
              day.isBefore(endDate.add(const Duration(days: 1)));
              day = day.add(const Duration(days: 1))) {
            if (approvalEvents.containsKey(day)) {
              approvalEvents[day]!.add(event);
            } else {
              approvalEvents[day] = [event];
            }
          }
        }

        setState(() {
          _events.value = approvalEvents;
        });
      } else {
        _showErrorDialog(
            'Failed to Load Leave Requests', 'Server returned status code: ${response.statusCode}. Message: ${response.reasonPhrase}');
      }
    } catch (e) {
      _showErrorDialog('Error Fetching Leave Requests', 'An unexpected error occurred: $e');
    }
  }

  List<Event> _getEventsForDay(DateTime day) {
    return _events.value[day] ?? [];
  }

  bool _hasPendingApprovals(DateTime day) {
    return _getEventsForDay(day).any((event) => event.status == 'Waiting');
  }

  @override
  void dispose() {
    _events.dispose();
    super.dispose();
  }

  void _addEvent(String title, DateTime startDateTime, DateTime endDateTime, String description, String status, bool isMeeting) {
    final newEvent = Event(title, startDateTime, endDateTime, description, status, isMeeting);
    final eventsForDay = _getEventsForDay(_selectedDay!);
    setState(() {
      _events.value = {
        ..._events.value,
        _selectedDay!: [...eventsForDay, newEvent],
      };
    });
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

  void _showDayView(DateTime date) {
    final events = _getEventsForDay(date);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DayViewScreen(date: date, events: events),
      ),
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
              Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.1,
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
                      child: Text(
                        'Calendar',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 25,
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
              ),
              Container(
                margin: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black54 : Colors.white,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TableCalendar<Event>(
                  firstDay: DateTime.utc(2010, 10, 16),
                  lastDay: DateTime.utc(2030, 3, 14),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    if (_singleTapSelectedDay != null && isSameDay(_singleTapSelectedDay, selectedDay)) {
                      _showDayView(selectedDay);
                      _singleTapSelectedDay = null; // reset the single tap state
                    } else {
                      setState(() {
                        _singleTapSelectedDay = selectedDay;
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
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
                    _focusedDay = focusedDay;
                  },
                  eventLoader: _getEventsForDay,
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, date, _) {
                      final hasPendingApproval = _hasPendingApprovals(date);
                      return CustomPaint(
                        painter: hasPendingApproval ? DottedBorderPainter() : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSameDay(_singleTapSelectedDay, date) ? Colors.yellow : Colors.transparent,
                          ),
                          child: Center(
                            child: Text(
                              '${date.day}',
                              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                            ),
                          ),
                        ),
                      );
                    },
                    markerBuilder: (context, date, events) {
                      if (events.isNotEmpty) {
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            height: 4.0,
                            color: Colors.green,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _getEventsForDay(date).any((event) => event.status == 'Waiting')
                                      ? Colors.orange
                                      : Colors.green,
                                  style: BorderStyle.solid,
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: ValueListenableBuilder<Map<DateTime, List<Event>>>(
                    valueListenable: _events,
                    builder: (context, value, _) {
                      final events = _getEventsForDay(_selectedDay!);
                      return ListView.builder(
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return GestureDetector(
                            onTap: () => _showEventDetails(context, event),
                            child: CustomEventBox(event: event, isDarkMode: isDarkMode),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEventDetails(BuildContext context, Event event) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EventDetailsPopup(event: event);
      },
    );
  }
}

class DottedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double dashWidth = 4.0;
    const double dashSpace = 4.0;
    final Paint paint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    double startX = 0;
    final Path path = Path();

    while (startX < size.width) {
      path.moveTo(startX, 0);
      path.lineTo(startX + dashWidth, 0);
      startX += dashWidth + dashSpace;
    }

    double startY = 0;
    while (startY < size.height) {
      path.moveTo(0, startY);
      path.lineTo(0, startY + dashWidth);
      startY += dashWidth + dashSpace;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class DayViewScreen extends StatelessWidget {
  final DateTime date;
  final List<Event> events;

  const DayViewScreen({required this.date, required this.events, super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEEE, MMM d, yyyy').format(date)),
        backgroundColor: isDarkMode ? Colors.black : Colors.yellow,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: isDarkMode ? Colors.black54 : Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final day = date.subtract(Duration(days: date.weekday - index - 1));
                return GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DayViewScreen(
                          date: day,
                          events: events,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Text(DateFormat('E').format(day),
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSameDay(day, date) ? (isDarkMode ? Colors.orange : Colors.yellow) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${day.day}',
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return CustomEventBox(event: event, isDarkMode: isDarkMode);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class Event {
  final String title;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String description;
  final String status; // New property to hold the status of the leave request
  final bool isMeeting; // New property to indicate if the event is a meeting

  Event(this.title, this.startDateTime, this.endDateTime, this.description, this.status, this.isMeeting);

  String get formattedTime => DateFormat.jm().format(startDateTime);

  @override
  String toString() => title;
}

class CustomEventBox extends StatelessWidget {
  final Event event;
  final bool isDarkMode;

  const CustomEventBox({required this.event, required this.isDarkMode, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 4.0,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black54 : Colors.white,
        border: Border.all(
          color: event.status == 'Rejected' ? Colors.red :
          event.status == 'Approved' ? Colors.green :
          Colors.orange,
        ),
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => EventDetailsPopup(event: event),
          );
        },
        title: Text(
          event.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                const SizedBox(width: 4),
                Text(event.description, style: TextStyle(color: isDarkMode ? Colors.grey[300] : Colors.grey[700])),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                const SizedBox(width: 4),
                Text(
                  '${DateFormat('hh:mm a').format(event.startDateTime)} - ${DateFormat('hh:mm a').format(event.endDateTime)}',
                  style: TextStyle(color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: List.generate(
                event.status == 'Approved' ? 10 : event.status == 'Rejected' ? 5 : 0,
                    (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2.0),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: event.status == 'Approved' ? Colors.green : Colors.red,
                        width: 2,
                      ),
                      image: const DecorationImage(
                        image: AssetImage('assets/profile_picture.png'), // Example placeholder for attendees' avatars
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (event.status == 'Approved' || event.status == 'Rejected')
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Text(
                  event.status,
                  style: TextStyle(color: event.status == 'Approved' ? Colors.green : Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EventDetailsPopup extends StatelessWidget {
  final Event event;

  const EventDetailsPopup({required this.event, super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(event.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Time: ${event.formattedTime}'),
          Text('Status: ${event.status}'),
          const SizedBox(height: 10),
          Text(event.description),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
      ],
    );
  }
}
