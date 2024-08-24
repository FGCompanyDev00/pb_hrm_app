import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/office_events/office_add_event.dart';
import 'package:pb_hrsystem/home/popups/event_details_popups.dart' as popups;
import 'package:pb_hrsystem/notifications/notification_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:pb_hrsystem/home/leave_request_page.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';
import 'backup_home_calendar.dart';

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
    AndroidInitializationSettings('@mipmap/playstore'); // Updated to use your app's logo
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
    Workmanager().registerPeriodicTask(
      "1",
      "fetchNotifications",
      frequency: const Duration(minutes: 15), // Adjust as needed
    );

    _fetchLeaveRequests(); // Fetch approvals and initialize events in the calendar
  }

  Future<void> onDidReceiveNotificationResponse(
      NotificationResponse response) async {
    if (response.payload != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const NotificationPage()), // Replace with your Notification Page
      );
    }
  }

  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      await _fetchAndDisplayNotifications();
      return Future.value(true);
    });
  }

  static Future<void> _fetchAndDisplayNotifications() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String endpoint = '$baseUrl/api/work-tracking/proj/notifications';

    try {
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List notifications = data['results'];
        for (var notification in notifications) {
          if (notification['status'] == 0) {
            await _showNotification(notification);
          }
        }
      } else {
        if (kDebugMode) {
          print('Failed to fetch notifications');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching notifications: $e');
      }
    }
  }

  static Future<void> _showNotification(Map<String, dynamic> notification) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'psbv_next_channel', // Updated channel ID for app
      'PSBV Next Notifications', // Updated channel name
      channelDescription:
      'Notifications about assignments, project updates, and member changes in PSBV Next app.', // Updated channel description
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/playstore',
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);
    await FlutterLocalNotificationsPlugin().show(
      notification['id'],
      'New Notification',
      notification['message'],
      platformChannelSpecifics,
      payload: notification['id'].toString(),
    );
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
        _leaveRequests = List<Map<String, dynamic>>.from(results);

        final Map<DateTime, List<Event>> approvalEvents = {};
        for (var item in _leaveRequests) {
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
    final normalizedDay = _normalizeDate(day);
    return _events.value[normalizedDay] ?? [];
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

  bool _hasPendingApprovals(DateTime day) {
    return _getEventsForDay(day).any((event) => event.status == 'Waiting');
  }

  @override
  void dispose() {
    _events.dispose();
    super.dispose();
  }

  void _addEvent(String title, DateTime startDateTime, DateTime endDateTime,
      String description, String status, bool isMeeting) {
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
          'Pending',
          true,
        );
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
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontSize: 23.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, date, _) {
                      final hasPendingApproval = _hasPendingApprovals(date);
                      return CustomPaint(
                        painter:
                        hasPendingApproval ? DottedBorderPainter() : null,
                        child: Container(
                          decoration: BoxDecoration(
                            image: isSameDay(_singleTapSelectedDay, date)
                                ? const DecorationImage(
                              image: AssetImage('assets/background.png'),
                              fit: BoxFit.cover,
                            )
                                : null,
                            color: isSameDay(_singleTapSelectedDay, date)
                                ? null
                                : Colors.transparent,
                          ),
                          child: Center(
                            child: Text(
                              '${date.day}',
                              style: TextStyle(
                                  color:
                                  isDarkMode ? Colors.white : Colors.black),
                            ),
                          ),
                        ),
                      );
                    },
                    markerBuilder: (context, date, events) {
                      if (events.isNotEmpty) {
                        final isFirstEvent = _isFirstEvent(events, date);
                        final isLastEvent = _isLastEvent(events, date);

                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: isFirstEvent || isLastEvent
                                ? 20
                                : double.infinity,
                            height: 4.0,
                            color: Colors.green,
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                  daysOfWeekHeight: 0,
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/background.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: ListView.builder(
                    itemCount: _leaveRequests.length,
                    itemBuilder: (context, index) {
                      final leaveRequest = _leaveRequests[index];
                      final eventStatus = leaveRequest['is_approve'];
                      final eventColor = eventStatus == 'Approved'
                          ? Colors.green[200]
                          : eventStatus == 'Rejected'
                          ? Colors.red[200]
                          : Colors.orange[200];

                      return GestureDetector(
                          onDoubleTap: () {
                            if (leaveRequest['is_approve'] == 'Waiting') {
                              _showEventDetails(
                                context,
                                Event(
                                  leaveRequest['name'],
                                  DateTime.parse(
                                      leaveRequest['take_leave_from']),
                                  DateTime.parse(leaveRequest['take_leave_to']),
                                  leaveRequest['take_leave_reason'] ??
                                      'Approval Pending',
                                  leaveRequest['is_approve'] ?? 'Waiting',
                                  false,
                                ),
                              );
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: eventColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.white54,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundImage: NetworkImage(
                                    leaveRequest['img_path'] ??
                                        'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg',
                                  ),
                                  radius: 28,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        leaveRequest['name'],
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'From: ${DateFormat('dd MMM yyyy').format(DateTime.parse(leaveRequest['take_leave_from']))}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDarkMode
                                              ? Colors.grey[300]
                                              : Colors.grey[700],
                                        ),
                                      ),
                                      Text(
                                        'To: ${DateFormat('dd MMM yyyy').format(DateTime.parse(leaveRequest['take_leave_to']))}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDarkMode
                                              ? Colors.grey[300]
                                              : Colors.grey[700],
                                        ),
                                      ),
                                      Text(
                                        '${leaveRequest['days']} days',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDarkMode
                                              ? Colors.grey[300]
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.circle,
                                  color: eventStatus == 'Approved'
                                      ? Colors.green
                                      : eventStatus == 'Rejected'
                                      ? Colors.red
                                      : Colors.orange,
                                ),
                              ],
                            ),
                          ));
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

  bool _isFirstEvent(List<Event> events, DateTime date) {
    final event = events.firstWhere(
            (e) => e.startDateTime.isAtSameMomentAs(date),
        orElse: () => events.first);
    return event.startDateTime.isAtSameMomentAs(date);
  }

  bool _isLastEvent(List<Event> events, DateTime date) {
    final event = events.firstWhere(
            (e) => e.endDateTime.isAtSameMomentAs(date),
        orElse: () => events.first);
    return event.endDateTime.isAtSameMomentAs(date);
  }

  void _showEventDetails(BuildContext context, Event event) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return popups.EventDetailsPopup(event: event);
      },
    );
  }
}
