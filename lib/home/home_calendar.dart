
import 'dart:convert';
import 'package:flutter/material.dart';
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
  List<Event> _eventsForDay = [];
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _events = ValueNotifier({});
    _eventsForDay = [];

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    _fetchLeaveRequests(DateTime.now());
    _fetchMeetingData();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _fetchLeaveRequests(DateTime selectedDate) async {
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
        print("Leave Requests Fetched: $results"); // Log API response

        final leaveRequests = List<Map<String, dynamic>>.from(results);
        final Map<DateTime, List<Event>> approvalEvents = {};

        for (var item in leaveRequests) {
          final DateTime startDate = item['take_leave_from'] != null
              ? DateTime.parse(item['take_leave_from'])
              : DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 8); // Default to 8 AM

          DateTime endDate = item['take_leave_to'] != null
              ? DateTime.parse(item['take_leave_to'])
              : DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 17); // Default to 5 PM

          if (!startDate.isBefore(endDate)) {
            endDate = startDate.add(const Duration(hours: 1));
          }

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
          print("_events.value populated: ${_events.value}"); // Log populated events
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
        print("Meeting Data Fetched: $results"); // Log API response

        for (var item in results) {
          final DateTime startDate = DateTime.parse(item['fromdate']);
          final DateTime endDate = DateTime.parse(item['todate']);

          final event = Event(
            item['title'],
            startDate,
            endDate,
            item['description'] ?? '',
            'Meeting',
            true,
          );

          setState(() {
            _addEventToDay(event, startDate, endDate);
            print("_events.value after adding meeting: ${_events.value}"); // Log added meeting events
          });
        }
      } else {
        _showErrorDialog('Failed to Load Meetings', 'Server returned status code: ${response.statusCode}. Message: ${response.reasonPhrase}');
      }
    } catch (e) {
      _showErrorDialog('Error Fetching Meetings', 'An unexpected error occurred: $e');
    }
  }

  List<Event> _getEventsForDay(DateTime day) {
    final normalizedDay = _normalizeDate(day);
    final events = _events.value[normalizedDay] ?? [];
    print("Events for the day $normalizedDay: $events"); // Log events for specific day
    return events;
  }

  List<Event> _getOverlappingEvents(Event event) {
    return _eventsForDay.where((otherEvent) => _doEventsOverlap(event, otherEvent)).toList();
  }

  _showDayView(DateTime selectedDay) {
    final List<Event> dayEvents = _getEventsForDay(selectedDay);

    final List<TimetableItem<String>> timetableItems = dayEvents.map((event) {
      DateTime start = event.startDateTime;
      DateTime end = event.endDateTime;

      // Default time if only the date is provided

      return TimetableItem<String>(
        start,
        end,
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

  void _addEventToDay(Event event, DateTime startDate, DateTime endDate) {
    for (var day = startDate;
    day.isBefore(endDate.add(const Duration(days: 1)));
    day = day.add(const Duration(days: 1))) {
      final normalizedDay = DateTime(day.year, day.month, day.day);
      if (_events.value.containsKey(normalizedDay)) {
        _events.value[normalizedDay]!.add(event);
      } else {
        _events.value[normalizedDay] = [event];
      }
    }
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
                child: _buildCalendarView(context),
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

  bool _doEventsOverlap(Event event1, Event event2) {
    return event1.endDateTime.isAfter(event2.startDateTime) &&
        event1.startDateTime.isBefore(event2.endDateTime);
  }

  Widget _buildCalendar(bool isDarkMode) {
    return StreamBuilder<Map<DateTime, List<Event>>>(
      stream: _getEventStream(), // Using stream for real-time updates
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator()); // Loading spinner
        }

        final events = snapshot.data!;
        return Container(
          height: 280,
          margin: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: GestureDetector(
            onDoubleTap: () {
              // Navigate to the timetable page on double-tap
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TimetablePage(
                    date: _focusedDay,
                    events: _eventsForDay.map(convertEventToTimetableItem).toList(),
                  ),
                ),
              );
            },
            child: SfCalendar(
              view: CalendarView.month,
              initialSelectedDate: _selectedDay,
              dataSource: MeetingDataSource(_getAllEvents()), // Using stream data
              monthViewSettings: MonthViewSettings(
                appointmentDisplayMode: MonthAppointmentDisplayMode.indicator,
                showAgenda: false,
                showTrailingAndLeadingDates: false,
              ),
              todayHighlightColor: Colors.orangeAccent,
              selectionDecoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: Colors.orange, width: 2),
                shape: BoxShape.circle,
              ),
              onTap: (CalendarTapDetails details) {
                if (details.targetElement == CalendarElement.calendarCell) {
                  setState(() {
                    _selectedDay = details.date;
                    _eventsForDay = _getEventsForDay(details.date!); // Update events for the selected day
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Events updated for ${DateFormat.yMMMMd().format(details.date!)}')),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }

  List<Event> _getAllEvents() {
    // Combines all events in _events into a single list
    return _events.value.values.expand((eventList) => eventList).toList();
  }

// Stream method to simulate real-time data updates
  Stream<Map<DateTime, List<Event>>> _getEventStream() async* {
    while (true) {
      await Future.delayed(const Duration(seconds: 2)); // Simulate data fetching delay
      yield _events.value; // Emit current events map for real-time updates
    }
  }

  Widget _buildSectionSeparator() {
    return Column(
      children: [
        Container(
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 2.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 6,
                offset: const Offset(0, 4),
              ),
            ],
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Colors.yellow,
                Colors.orange,
              ],
            ),
          ),
        ),
        const SizedBox(
          height: 12,
        ),
      ],
    );
  }

  Widget _buildCalendarView(BuildContext context) {
    return StreamBuilder<List<Event>>(
      stream: _getDayEventStream(), // Stream for real-time updates
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator()); // Loading spinner
        }

        final dayEvents = snapshot.data!;
        if (dayEvents.isEmpty) {
          return const Center(child: Text('No events for the selected day.'));
        }

        return Container(
          height: 400,  // Adjust the height for day view display
          margin: const EdgeInsets.all(10.0),
          child: SfCalendar(
            view: CalendarView.day,
            dataSource: MeetingDataSource(dayEvents), // Display events for selected day
            initialDisplayDate: _selectedDay,
            timeSlotViewSettings: TimeSlotViewSettings(
              startHour: _getStartHour(dayEvents), // Start at the first event's time or a default value
              endHour: _getStartHour(dayEvents) + 4, // Limit to 4 hours after the start hour
              timeIntervalHeight: 60,
              timeFormat: 'h:mm a',
            ),
            appointmentBuilder: (BuildContext context, CalendarAppointmentDetails details) {
              final Event event = details.appointments.first;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green, width: 2), // Green border as before
                ),
                child: ListTile(
                  title: Text(
                    event.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${event.formattedTime} - ${DateFormat.jm().format(event.endDateTime)}'),
                  trailing: event.isMeeting
                      ? const Icon(Icons.videocam, color: Colors.orange)
                      : const Icon(Icons.work, color: Colors.green),
                ),
              );
            },
          ),
        );
      },
    );
  }

// Real-time stream for day-specific events
  Stream<List<Event>> _getDayEventStream() async* {
    while (true) {
      await Future.delayed(const Duration(seconds: 2)); // Simulate data fetching delay
      yield _getEventsForDay(_selectedDay!); // Emit events for the selected day
    }
  }

// Get start hour based on earliest event
  double _getStartHour(List<Event> events) {
    return events.isEmpty ? 8.0 : events.map((e) => e.startDateTime.hour).reduce((a, b) => a < b ? a : b).toDouble();
  }

  void _showAddEventOptionsPopup() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return Stack(
          children: [
            Positioned(
              top: 45,
              right: 38,
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