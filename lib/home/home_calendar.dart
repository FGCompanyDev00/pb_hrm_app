
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
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

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
    // _fetchMeetingData();

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    _fetchLeaveRequests(_selectedDay ?? _focusedDay);
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
        final leaveRequests = List<Map<String, dynamic>>.from(results);

        final Map<DateTime, List<Event>> approvalEvents = {};
        for (var item in leaveRequests) {
          final DateTime startDate = item['take_leave_from'] != null
              ? DateTime.parse(item['take_leave_from'])
              : DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 8); // Default to 8 AM

          DateTime endDate = item['take_leave_to'] != null
              ? DateTime.parse(item['take_leave_to'])
              : DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 17); // Default to 5 PM

          // Ensure start is before end
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
          _eventsForDay = _getEventsForDay(selectedDate);  // Update the events for the selected day
        });
      } else {
        _showErrorDialog(
            'Failed to Load Leave Requests', 'Server returned status code: ${response.statusCode}. Message: ${response.reasonPhrase}');
      }
    } catch (e) {
      _showErrorDialog('Error Fetching Leave Requests', 'An unexpected error occurred: $e');
    }
  }

  // Future<void> _fetchMeetingData() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final token = prefs.getString('token');
  //
  //   if (token == null) {
  //     _showErrorDialog('Authentication Error', 'Token is null. Please log in again.');
  //     return;
  //   }
  //
  //   try {
  //     final response = await http.get(
  //       Uri.parse('https://demo-application-api.flexiflows.co/api/work-tracking/out-meeting/outmeeting/my-members'),
  //       headers: {'Authorization': 'Bearer $token'},
  //     );
  //
  //     if (response.statusCode == 200) {
  //       final List<dynamic> results = json.decode(response.body)['results'];
  //       final Map<DateTime, List<Event>> meetingEvents = {};
  //
  //       for (var item in results) {
  //         final DateTime startDate = DateTime.parse(item['fromdate']);
  //         final DateTime endDate = DateTime.parse(item['todate']);
  //         final Color eventColor = _parseColor(item['backgroundColor']);
  //         final event = Event(
  //           item['title'],
  //           startDate,
  //           endDate,
  //           item['description'] ?? '',
  //           'Meeting',
  //           true,
  //         );
  //
  //         for (var day = startDate;
  //         day.isBefore(endDate.add(const Duration(days: 1)));
  //         day = day.add(const Duration(days: 1))) {
  //           final normalizedDay = _normalizeDate(day);
  //           if (meetingEvents.containsKey(normalizedDay)) {
  //             meetingEvents[normalizedDay]!.add(event);
  //           } else {
  //             meetingEvents[normalizedDay] = [event];
  //           }
  //         }
  //       }
  //
  //       setState(() {
  //         _events.value.addAll(meetingEvents);
  //         _eventsForDay = _getEventsForDay(_focusedDay);
  //       });
  //     } else {
  //       _showErrorDialog('Failed to Load Meetings', 'Server returned status code: ${response.statusCode}. Message: ${response.reasonPhrase}');
  //     }
  //   } catch (e) {
  //     _showErrorDialog('Error Fetching Meetings', 'An unexpected error occurred: $e');
  //   }
  // }

  Color _parseColor(String colorString) {
    return Color(int.parse(colorString.replaceFirst('#', '0xff')));
  }

  List<Event> _getEventsForDay(DateTime day) {
    final normalizedDay = _normalizeDate(day);
    return _events.value[normalizedDay] ?? [];
  }

  _showDayView(DateTime selectedDay) {
    final List<Event> dayEvents = _getEventsForDay(selectedDay);

    final List<TimetableItem<String>> timetableItems = dayEvents.map((event) {
      DateTime start = event.startDateTime;
      DateTime end = event.endDateTime;

      // Default time if only the date is provided
      if (start == null) {
        start = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 9); // Default to 9 AM
      }
      if (end == null) {
        end = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 17); // Default to 5 PM
      }

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

  Widget _buildCalendar(bool isDarkMode) {
    return Container(
      height: 280,
      margin: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black : Colors.white,
        boxShadow: const [],
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
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
          outsideDaysVisible: false,
          weekendTextStyle: TextStyle(color: Colors.black),
          defaultTextStyle: TextStyle(color: Colors.black),
        ),
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: const TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          leftChevronIcon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.chevron_left,
              size: 16,
              color: Colors.black,
            ),
          ),
          rightChevronIcon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.chevron_right,
              size: 16,
              color: Colors.black,
            ),
          ),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isNotEmpty) {
              List<Widget> markers = [];
              for (var i = 0; i < (events.length > 3 ? 3 : events.length); i++) {
                final event = events[i];
                final isMeeting = event.isMeeting;
                final isMultiDayEvent = event.startDateTime.isBefore(date) && event.endDateTime.isAfter(date);

                // Green line for leave requests, orange line for meetings
                final eventColor = isMeeting ? Colors.orange : Colors.green;

                markers.add(
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 0.8),
                      height: 3,
                      width: isMultiDayEvent ? double.infinity : 16,
                      color: eventColor,
                    ),
                  ),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: markers,
              );
            }
            return null;
          },
        ),

      ),
    );

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
    return Column(
      children: [
        // Date Navigation Row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (index) {
              final day = _selectedDay!.add(Duration(days: index - 3)); // Adjust days for week navigation
              final hasEvent = _eventsForDay.any((event) =>
              event.startDateTime.day == day.day &&
                  event.startDateTime.month == day.month &&
                  event.startDateTime.year == day.year);
              return _buildDateItem(
                DateFormat.E().format(day), // Display the weekday name (e.g., Mon, Tue)
                day.day, // Display the day number
                isSelected: day.day == _selectedDay!.day, // Highlight selected day
                hasEvent: hasEvent, // Indicate if the day has events
                onTap: () {
                  setState(() {
                    _selectedDay = day;
                    _eventsForDay = _getEventsForDay(_selectedDay!); // Fetch events for the selected day
                  });
                },
              );
            }),
          ),
        ),

        // Time slots and event blocks for the selected day
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _buildEventSlotsForDay(_selectedDay!), // Show hourly slots with events
          ),
        ),
      ],
    );
  }

  Widget _buildDateItem(String day, int date, {required bool isSelected, required bool hasEvent, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            day.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? Colors.green : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.green.withOpacity(0.8)
                  : hasEvent ? Colors.greenAccent.withOpacity(0.7) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: isSelected || hasEvent
                  ? Border.all(color: Colors.green, width: 1.5)
                  : Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
            ),
            child: Text(
              "$date",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected || hasEvent ? Colors.white : Colors.black.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTimeSlot(String time, {String? event}) {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              time, // Display the hour (e.g., 08:00)
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: event != null && event.isNotEmpty
                ? Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green, // Color the slot green if it has an event
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                event, // Display the event title
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            )
                : Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1), // Underline for empty time slots
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEventSlotsForDay(DateTime date) {
    final List<Widget> slots = [];
    final eventsForDay = _eventsForDay.where((event) =>
    event.startDateTime.day == date.day &&
        event.startDateTime.month == date.month &&
        event.startDateTime.year == date.year).toList();

    for (var i = 0; i < 24; i++) {
      final String timeLabel = "${i.toString().padLeft(2, '0')}:00"; // Format time as HH:00
      final matchingEvent = eventsForDay.firstWhere(
            (event) => event.startDateTime.hour == i, // Match the event's start time to the slot
        orElse: () => Event('', DateTime(date.year, date.month, date.day, i), DateTime(date.year, date.month, date.day, i + 1), '', '', false),
      );

      String eventTitle = matchingEvent.title;

      if (eventTitle.isNotEmpty) {
        slots.add(_buildTimeSlot(timeLabel, event: eventTitle)); // Add event title to time slot if available
      } else {
        slots.add(_buildTimeSlot(timeLabel)); // Empty time slot if no event
      }
    }

    return slots;
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