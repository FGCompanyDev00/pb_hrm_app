// // import 'dart:convert';
// // import 'package:flutter/material.dart';
// // import 'package:flutter_timetable/flutter_timetable.dart';
// // import 'package:pb_hrsystem/home/office_events/office_add_event.dart';
// // import 'package:pb_hrsystem/home/timetable_page.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import 'package:table_calendar/table_calendar.dart';
// // import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// // import 'package:intl/intl.dart';
// // import 'package:provider/provider.dart';
// // import 'package:pb_hrsystem/theme/theme.dart';
// // import 'package:pb_hrsystem/home/leave_request_page.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:syncfusion_flutter_calendar/calendar.dart';

// // class HomeCalendar extends StatefulWidget {
// //   const HomeCalendar({super.key});

// //   @override
// //   _HomeCalendarState createState() => _HomeCalendarState();
// // }

// // class _HomeCalendarState extends State<HomeCalendar> {
// //   late final ValueNotifier<Map<DateTime, List<Event>>> _events;
// //   CalendarFormat _calendarFormat = CalendarFormat.month;
// //   DateTime _focusedDay = DateTime.now();
// //   DateTime? _selectedDay;
// //   List<Event> _eventsForDay = []; // Initialize as an empty list
// //   late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _selectedDay = _focusedDay;
// //     _events = ValueNotifier({});
// //     _eventsForDay = [];

// //     flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
// //     const AndroidInitializationSettings initializationSettingsAndroid =
// //     AndroidInitializationSettings('@mipmap/ic_launcher');
// //     const InitializationSettings initializationSettings =
// //     InitializationSettings(android: initializationSettingsAndroid);
// //     flutterLocalNotificationsPlugin.initialize(initializationSettings);

// //     _fetchLeaveRequests();
// //   }

// //   DateTime _normalizeDate(DateTime date) {
// //     return DateTime(date.year, date.month, date.day);
// //   }

// //   Future<void> _fetchLeaveRequests() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     final token = prefs.getString('token');

// //     if (token == null) {
// //       _showErrorDialog(
// //           'Authentication Error', 'Token is null. Please log in again.');
// //       return;
// //     }

// //     try {
// //       final response = await http.get(
// //         Uri.parse(
// //             'https://demo-application-api.flexiflows.co/api/leave_requests'),
// //         headers: {'Authorization': 'Bearer $token'},
// //       );

// //       if (response.statusCode == 200) {
// //         final List<dynamic> results = json.decode(response.body)['results'];
// //         final leaveRequests = List<Map<String, dynamic>>.from(results);

// //         final Map<DateTime, List<Event>> approvalEvents = {};
// //         for (var item in leaveRequests) {
// //           final DateTime startDate =
// //           _normalizeDate(DateTime.parse(item['take_leave_from']));
// //           final DateTime endDate =
// //           _normalizeDate(DateTime.parse(item['take_leave_to']));
// //           final event = Event(
// //             item['name'],
// //             startDate,
// //             endDate,
// //             item['take_leave_reason'] ?? 'Approval Pending',
// //             item['is_approve'] ?? 'Waiting',
// //             false,
// //           );

// //           for (var day = startDate;
// //           day.isBefore(endDate.add(const Duration(days: 1)));
// //           day = day.add(const Duration(days: 1))) {
// //             final normalizedDay = _normalizeDate(day);
// //             if (approvalEvents.containsKey(normalizedDay)) {
// //               approvalEvents[normalizedDay]!.add(event);
// //             } else {
// //               approvalEvents[normalizedDay] = [event];
// //             }
// //           }
// //         }

// //         setState(() {
// //           _events.value = approvalEvents;
// //           _eventsForDay = _getEventsForDay(_focusedDay);
// //         });
// //       } else {
// //         _showErrorDialog('Failed to Load Leave Requests',
// //             'Server returned status code: ${response.statusCode}. Message: ${response.reasonPhrase}');
// //       }
// //     } catch (e) {
// //       _showErrorDialog('Error Fetching Leave Requests',
// //           'An unexpected error occurred: $e');
// //     }
// //   }

// //   List<Event> _getEventsForDay(DateTime day) {
// //     final normalizedDay = _normalizeDate(day);
// //     return _events.value[normalizedDay] ?? [];
// //   }

// //   void _showDayView(DateTime selectedDay) {
// //     final List<Event> dayEvents = _getEventsForDay(selectedDay);

// //     // Convert Event objects to TimetableItem<String>
// //     final List<TimetableItem<String>> timetableItems = dayEvents.map((event) {
// //       return TimetableItem<String>(
// //         event.startDateTime,
// //         event.endDateTime,
// //         data: event.title,
// //       );
// //     }).toList();

// //     Navigator.push(
// //       context,
// //       MaterialPageRoute(
// //         builder: (context) => TimetablePage(
// //           date: selectedDay,
// //           events: timetableItems,
// //         ),
// //       ),
// //     );
// //   }

// //   TimetableItem<String> convertEventToTimetableItem(Event event) {
// //     return TimetableItem<String>(
// //       event.startDateTime,
// //       event.endDateTime,
// //       data: event.title,
// //     );
// //   }

// //   void _showErrorDialog(String title, String message) {
// //     showDialog(
// //       context: context,
// //       builder: (context) {
// //         return AlertDialog(
// //           title: Text(title),
// //           content: Text(message),
// //           actions: [
// //             TextButton(
// //               onPressed: () {
// //                 Navigator.of(context).pop();
// //               },
// //               child: const Text('OK'),
// //             ),
// //           ],
// //         );
// //       },
// //     );
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     final themeNotifier = Provider.of<ThemeNotifier>(context);
// //     final bool isDarkMode = themeNotifier.isDarkMode;

// //     return Scaffold(
// //       body: Stack(
// //         children: [
// //           Column(
// //             children: [
// //               _buildCalendarHeader(isDarkMode),
// //               _buildCalendar(isDarkMode),
// //               _buildSectionSeparator(), // The separator line
// //               Expanded(
// //                 child: _buildSyncfusionCalendarView(),
// //               ),
// //             ],
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildCalendarHeader(bool isDarkMode) {
// //     return Container(
// //       width: double.infinity,
// //       height: 120,
// //       decoration: BoxDecoration(
// //         image: DecorationImage(
// //           image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
// //           fit: BoxFit.cover,
// //         ),
// //         borderRadius: const BorderRadius.only(
// //           bottomLeft: Radius.circular(20),
// //           bottomRight: Radius.circular(20),
// //         ),
// //       ),
// //       child: Stack(
// //         children: [
// //           Center(
// //             child: Column(
// //               mainAxisSize: MainAxisSize.min,
// //               children: [
// //                 const SizedBox(height: 50),
// //                 Text(
// //                   'Calendar',
// //                   style: TextStyle(
// //                     color: isDarkMode ? Colors.white : Colors.black,
// //                     fontSize: 20,  // Smaller font size
// //                     fontWeight: FontWeight.bold,
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //           Positioned(
// //             top: 55,
// //             right: 20,
// //             child: IconButton(
// //               icon: const Icon(
// //                 Icons.add_circle,
// //                 size: 40,
// //                 color: Colors.green,
// //               ),
// //               onPressed: _showAddEventOptionsPopup,
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildCalendar(bool isDarkMode) {
// //     return Container(
// //       height: 300,
// //       margin: const EdgeInsets.all(18.0),
// //       decoration: BoxDecoration(
// //         color: isDarkMode ? Colors.black : Colors.white,
// //         boxShadow: const [
// //           BoxShadow(
// //             color: Colors.black26,
// //             blurRadius: 4,
// //             offset: Offset(0, 2),
// //           ),
// //         ],
// //         borderRadius: BorderRadius.circular(8),
// //       ),
// //       child: TableCalendar<Event>(
// //         rowHeight: 44,
// //         firstDay: DateTime.utc(2010, 10, 16),
// //         lastDay: DateTime.utc(2030, 3, 14),
// //         focusedDay: _focusedDay,
// //         calendarFormat: CalendarFormat.month,
// //         availableCalendarFormats: const {
// //           CalendarFormat.month: 'Month',
// //         },
// //         selectedDayPredicate: (day) {
// //           return isSameDay(_selectedDay, day);
// //         },
// //         onDaySelected: (selectedDay, focusedDay) {
// //           setState(() {
// //             _selectedDay = selectedDay;
// //             _focusedDay = focusedDay;
// //             _eventsForDay = _getEventsForDay(selectedDay);
// //           });
// //         },
// //         onFormatChanged: (format) {
// //           if (_calendarFormat != format) {
// //             setState(() {
// //               _calendarFormat = format;
// //             });
// //           }
// //         },
// //         onPageChanged: (focusedDay) {
// //           setState(() {
// //             _focusedDay = focusedDay;
// //           });
// //         },
// //         eventLoader: _getEventsForDay,
// //         calendarStyle: const CalendarStyle(
// //           todayDecoration: BoxDecoration(
// //             color: Colors.orangeAccent,
// //             shape: BoxShape.circle,
// //           ),
// //           selectedDecoration: BoxDecoration(
// //             color: Colors.green,
// //             shape: BoxShape.circle,
// //           ),
// //           markerDecoration: BoxDecoration(
// //             color: Colors.orange,
// //             shape: BoxShape.circle,
// //           ),
// //         ),
// //         headerStyle: const HeaderStyle(
// //           titleCentered: true,
// //           formatButtonVisible: false,
// //           titleTextStyle: TextStyle(
// //             fontSize: 20.0,
// //             fontWeight: FontWeight.bold,
// //             color: Colors.black,
// //           ),
// //           leftChevronIcon: Icon(
// //             Icons.chevron_left,
// //             size: 16,
// //             color: Colors.black,
// //           ),
// //           rightChevronIcon: Icon(
// //             Icons.chevron_right,
// //             size: 16,
// //             color: Colors.black,
// //           ),
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _buildSectionSeparator() {
// //     // return Container(
// //     //   height: 8.0,
// //     //   decoration: const BoxDecoration(
// //     //     gradient: LinearGradient(
// //     //       begin: Alignment.topRight,
// //     //       end: Alignment.bottomLeft,
// //     //       colors: [
// //     //         Colors.green,
// //     //         Colors.orange,
// //     //       ],
// //     //     ),
// //     //   ),
// //     //   margin: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 2.0),
// //     // );
// //     return const GradientAnimationLine();
// //   }

// //   Widget _buildSyncfusionCalendarView() {
// //     return SfCalendar(
// //       view: CalendarView.day,
// //       dataSource: MeetingDataSource(_eventsForDay),
// //       initialSelectedDate: _selectedDay,
// //       headerHeight: 50,
// //       headerStyle: const CalendarHeaderStyle(
// //         textAlign: TextAlign.center,
// //         textStyle: TextStyle(
// //           fontSize: 17,
// //           color: Colors.black,
// //         ),
// //       ),
// //       timeSlotViewSettings: const TimeSlotViewSettings(
// //         timeIntervalHeight: 40,
// //         startHour: 0,
// //         endHour: 24,
// //       ),
// //       appointmentBuilder: (context, details) {
// //         final Event meeting = details.appointments.first;
// //         return Container(
// //           padding: const EdgeInsets.all(8.0),
// //           decoration: BoxDecoration(
// //             color: meeting.isMeeting ? Colors.blue : Colors.orange,
// //             borderRadius: BorderRadius.circular(8),
// //           ),
// //           child: Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               Text(
// //                 meeting.title,
// //                 style: const TextStyle(
// //                   color: Colors.white,
// //                   fontWeight: FontWeight.bold,
// //                 ),
// //               ),
// //               const SizedBox(height: 8),
// //               Text(
// //                 '${DateFormat.jm().format(meeting.startDateTime)} - ${DateFormat.jm().format(meeting.endDateTime)}',
// //                 style: const TextStyle(
// //                   color: Colors.white70,
// //                   fontSize: 12,
// //                 ),
// //               ),
// //             ],
// //           ),
// //         );
// //       },
// //     );
// //   }

// //   void _showAddEventOptionsPopup() {
// //     showDialog(
// //       context: context,
// //       barrierColor: Colors.transparent,
// //       builder: (BuildContext context) {
// //         return Stack(
// //           children: [
// //             Positioned(
// //               top: 75,
// //               right: 40,
// //               child: Material(
// //                 color: Colors.transparent,
// //                 child: Container(
// //                   padding: const EdgeInsets.symmetric(vertical: 10),
// //                   width: 160,
// //                   decoration: BoxDecoration(
// //                     color: Colors.white,
// //                     borderRadius: BorderRadius.circular(16),
// //                     boxShadow: [
// //                       BoxShadow(
// //                         color: Colors.black.withOpacity(0.2),
// //                         blurRadius: 10,
// //                         offset: const Offset(0, 4),
// //                       ),
// //                     ],
// //                   ),
// //                   child: Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       _buildPopupOption(
// //                         icon: Icons.person,
// //                         label: '1. Personal',
// //                         onTap: () {
// //                           Navigator.pop(context);
// //                           _navigateToAddEvent('Personal');
// //                         },
// //                       ),
// //                       const Divider(height: 1),
// //                       _buildPopupOption(
// //                         icon: Icons.work,
// //                         label: '2. Office',
// //                         onTap: () {
// //                           Navigator.pop(context);
// //                           _navigateToAddEvent('Office');
// //                         },
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //               ),
// //             ),
// //           ],
// //         );
// //       },
// //     );
// //   }

// //   Widget _buildPopupOption({
// //     required IconData icon,
// //     required String label,
// //     required VoidCallback onTap,
// //   }) {
// //     return InkWell(
// //       onTap: onTap,
// //       child: Padding(
// //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// //         child: Row(
// //           children: [
// //             Icon(icon, size: 20, color: Colors.black54),
// //             const SizedBox(width: 12),
// //             Text(label, style: const TextStyle(color: Colors.black87)),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   void _navigateToAddEvent(String eventType) async {
// //     if (eventType == 'Personal') {
// //       Navigator.push(
// //         context,
// //         MaterialPageRoute(
// //           builder: (context) => const LeaveManagementPage(),
// //         ),
// //       );
// //     } else {
// //       final newEvent = await Navigator.push<Map<String, dynamic>>(
// //         context,
// //         MaterialPageRoute(
// //           builder: (context) => const OfficeAddEventPage(),
// //         ),
// //       );
// //       if (newEvent != null) {
// //         _addEvent(
// //           newEvent['title'],
// //           newEvent['startDateTime'],
// //           newEvent['endDateTime'],
// //           newEvent['description'] ?? '',
// //           'Pending', // Default to pending status for new events
// //           true, // isMeeting set to true for office events
// //         );
// //       }
// //     }
// //   }

// //   void _addEvent(String title, DateTime startDateTime, DateTime endDateTime,
// //       String description, String status, bool isMeeting) {
// //     final newEvent = Event(title, startDateTime, endDateTime, description,
// //         status, isMeeting);
// //     final eventsForDay = _getEventsForDay(_selectedDay!);
// //     setState(() {
// //       _events.value = {
// //         ..._events.value,
// //         _selectedDay!: [...eventsForDay, newEvent],
// //       };
// //       _eventsForDay = _getEventsForDay(_selectedDay!);
// //     });
// //   }
// // }

// // class AnimatedSectionSeparator extends StatefulWidget {
// //   const AnimatedSectionSeparator({super.key});

// //   @override
// //   _AnimatedSectionSeparatorState createState() => _AnimatedSectionSeparatorState();
// // }

// // class _AnimatedSectionSeparatorState extends State<AnimatedSectionSeparator>
// //     with SingleTickerProviderStateMixin {
// //   late AnimationController _controller;
// //   late Animation<LinearGradient> _animation;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _controller = AnimationController(
// //       duration: const Duration(seconds: 3), // Duration of the full animation cycle
// //       vsync: this,
// //     )..repeat(reverse: true); // Repeats the animation in reverse after each cycle

// //     _animation = Tween<LinearGradient>(
// //       begin: const LinearGradient(
// //         colors: [Colors.green, Colors.yellow],
// //         begin: Alignment.topRight,
// //         end: Alignment.bottomLeft,
// //       ),
// //       end: const LinearGradient(
// //         colors: [Colors.yellow, Colors.orange],
// //         begin: Alignment.topRight,
// //         end: Alignment.bottomLeft,
// //       ),
// //     ).animate(_controller);
// //   }

// //   @override
// //   void dispose() {
// //     _controller.dispose();
// //     super.dispose();
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return AnimatedBuilder(
// //       animation: _animation,
// //       builder: (context, child) {
// //         return Container(
// //           height: 8.0,
// //           decoration: BoxDecoration(
// //             gradient: _animation.value,
// //           ),
// //           margin: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 2.0),
// //         );
// //       },
// //     );
// //   }
// // }

// // class GradientAnimationLine extends StatefulWidget {
// //   const GradientAnimationLine({super.key});

// //   @override
// //   _GradientAnimationLineState createState() {
// //     return _GradientAnimationLineState();
// //   }
// // }

// // class _GradientAnimationLineState extends State<GradientAnimationLine> with SingleTickerProviderStateMixin {
// //   late AnimationController _controller;
// //   late Animation<Color?> _colorAnimation1;
// //   late Animation<Color?> _colorAnimation2;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _controller = AnimationController(
// //       duration: const Duration(seconds: 3),
// //       vsync: this,
// //     )..repeat(reverse: true);

// //     _colorAnimation1 = ColorTween(
// //       begin: Colors.yellow,
// //       end: Colors.orange,
// //     ).animate(_controller);

// //     _colorAnimation2 = ColorTween(
// //       begin: Colors.orange,
// //       end: Colors.yellow,
// //     ).animate(_controller);
// //   }

// //   @override
// //   void dispose() {
// //     _controller.dispose();
// //     super.dispose();
// //   }

// //   Widget _buildSectionSeparator() {
// //     return AnimatedBuilder(
// //       animation: _controller,
// //       builder: (context, child) {
// //         return Container(
// //           height: 8.0,
// //           decoration: BoxDecoration(
// //             gradient: LinearGradient(
// //               begin: Alignment.topRight,
// //               end: Alignment.bottomLeft,
// //               colors: [
// //                 _colorAnimation1.value!,
// //                 _colorAnimation2.value!,
// //               ],
// //             ),
// //           ),
// //           margin: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 2.0),
// //         );
// //       },
// //     );
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return _buildSectionSeparator();
// //   }
// // }


// // class Event {
// //   final String title;
// //   final DateTime startDateTime;
// //   final DateTime endDateTime;
// //   final String description;
// //   final String status;
// //   final bool isMeeting;

// //   Event(this.title, this.startDateTime, this.endDateTime, this.description,
// //       this.status, this.isMeeting);

// //   String get formattedTime => DateFormat.jm().format(startDateTime);

// //   @override
// //   String toString() =>
// //       '$title ($status) from ${DateFormat.yMMMd().format(startDateTime)} to ${DateFormat.yMMMd().format(endDateTime)}';
// // }

// // class MeetingDataSource extends CalendarDataSource {
// //   MeetingDataSource(List<Event> source) {
// //     appointments = source;
// //   }

// //   @override
// //   DateTime getStartTime(int index) {
// //     return appointments![index].startDateTime;
// //   }

// //   @override
// //   DateTime getEndTime(int index) {
// //     return appointments![index].endDateTime;
// //   }

// //   @override
// //   String getSubject(int index) {
// //     return appointments![index].title;
// //   }

// //   @override
// //   bool isAllDay(int index) {
// //     return false;
// //   }
// // }

// // import 'dart:convert';
// // import 'package:flutter/material.dart';
// // import 'package:flutter_timetable/flutter_timetable.dart';
// // import 'package:pb_hrsystem/home/office_events/office_add_event.dart';
// // import 'package:pb_hrsystem/home/timetable_page.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import 'package:table_calendar/table_calendar.dart';
// // import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// // import 'package:intl/intl.dart';
// // import 'package:provider/provider.dart';
// // import 'package:pb_hrsystem/theme/theme.dart';
// // import 'package:pb_hrsystem/home/leave_request_page.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:syncfusion_flutter_calendar/calendar.dart';

// // class HomeCalendar extends StatefulWidget {
// //   const HomeCalendar({super.key});

// //   @override
// //   _HomeCalendarState createState() => _HomeCalendarState();
// // }

// // class _HomeCalendarState extends State<HomeCalendar> {
// //   late final ValueNotifier<Map<DateTime, List<Event>>> _events;
// //   CalendarFormat _calendarFormat = CalendarFormat.month;
// //   DateTime _focusedDay = DateTime.now();
// //   DateTime? _selectedDay;
// //   DateTime? _singleTapSelectedDay; // Added to handle double-tap functionality
// //   List<Event> _eventsForDay = [];
// //   late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _selectedDay = _focusedDay;
// //     _events = ValueNotifier({});
// //     _eventsForDay = [];

// //     flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
// //     const AndroidInitializationSettings initializationSettingsAndroid =
// //         AndroidInitializationSettings('@mipmap/ic_launcher');
// //     const InitializationSettings initializationSettings =
// //         InitializationSettings(android: initializationSettingsAndroid);
// //     flutterLocalNotificationsPlugin.initialize(initializationSettings);

// //     _fetchLeaveRequests();
// //   }

// //   DateTime _normalizeDate(DateTime date) {
// //     return DateTime(date.year, date.month, date.day);
// //   }

// //   Future<void> _fetchLeaveRequests() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     final token = prefs.getString('token');

// //     if (token == null) {
// //       _showErrorDialog('Authentication Error', 'Token is null. Please log in again.');
// //       return;
// //     }

// //     try {
// //       final response = await http.get(
// //         Uri.parse('https://demo-application-api.flexiflows.co/api/leave_requests'),
// //         headers: {'Authorization': 'Bearer $token'},
// //       );

// //       if (response.statusCode == 200) {
// //         final List<dynamic> results = json.decode(response.body)['results'];
// //         final leaveRequests = List<Map<String, dynamic>>.from(results);

// //         final Map<DateTime, List<Event>> approvalEvents = {};
// //         for (var item in leaveRequests) {
// //           final DateTime startDate = _normalizeDate(DateTime.parse(item['take_leave_from']));
// //           final DateTime endDate = _normalizeDate(DateTime.parse(item['take_leave_to']));
// //           final event = Event(
// //             item['name'],
// //             startDate,
// //             endDate,
// //             item['take_leave_reason'] ?? 'Approval Pending',
// //             item['is_approve'] ?? 'Waiting',
// //             false,
// //           );

// //           for (var day = startDate;
// //               day.isBefore(endDate.add(const Duration(days: 1)));
// //               day = day.add(const Duration(days: 1))) {
// //             final normalizedDay = _normalizeDate(day);
// //             if (approvalEvents.containsKey(normalizedDay)) {
// //               approvalEvents[normalizedDay]!.add(event);
// //             } else {
// //               approvalEvents[normalizedDay] = [event];
// //             }
// //           }
// //         }

// //         setState(() {
// //           _events.value = approvalEvents;
// //           _eventsForDay = _getEventsForDay(_focusedDay);
// //         });
// //       } else {
// //         _showErrorDialog(
// //             'Failed to Load Leave Requests', 'Server returned status code: ${response.statusCode}. Message: ${response.reasonPhrase}');
// //       }
// //     } catch (e) {
// //       _showErrorDialog('Error Fetching Leave Requests', 'An unexpected error occurred: $e');
// //     }
// //   }

// //   List<Event> _getEventsForDay(DateTime day) {
// //     final normalizedDay = _normalizeDate(day);
// //     return _events.value[normalizedDay] ?? [];
// //   }

// //   void _showDayView(DateTime selectedDay) {
// //     final List<Event> dayEvents = _getEventsForDay(selectedDay);

// //     final List<TimetableItem<String>> timetableItems = dayEvents.map((event) {
// //       return TimetableItem<String>(
// //         event.startDateTime,
// //         event.endDateTime,
// //         data: event.title,
// //       );
// //     }).toList();

// //     Navigator.push(
// //       context,
// //       MaterialPageRoute(
// //         builder: (context) => TimetablePage(
// //           date: selectedDay,
// //           events: timetableItems,
// //         ),
// //       ),
// //     );
// //   }

// //   TimetableItem<String> convertEventToTimetableItem(Event event) {
// //     return TimetableItem<String>(
// //       event.startDateTime,
// //       event.endDateTime,
// //       data: event.title,
// //     );
// //   }

// //   void _showErrorDialog(String title, String message) {
// //     showDialog(
// //       context: context,
// //       builder: (context) {
// //         return AlertDialog(
// //           title: Text(title),
// //           content: Text(message),
// //           actions: [
// //             TextButton(
// //               onPressed: () {
// //                 Navigator.of(context).pop();
// //               },
// //               child: const Text('OK'),
// //             ),
// //           ],
// //         );
// //       },
// //     );
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     final themeNotifier = Provider.of<ThemeNotifier>(context);
// //     final bool isDarkMode = themeNotifier.isDarkMode;

// //     return Scaffold(
// //       body: Stack(
// //         children: [
// //           Column(
// //             children: [
// //               _buildCalendarHeader(isDarkMode),
// //               _buildCalendar(isDarkMode),
// //               _buildSectionSeparator(), // The separator line
// //               Expanded(
// //                 child: _buildSyncfusionCalendarView(),
// //               ),
// //             ],
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildCalendarHeader(bool isDarkMode) {
// //     return Container(
// //       width: double.infinity,
// //       height: 120,
// //       decoration: BoxDecoration(
// //         image: DecorationImage(
// //           image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
// //           fit: BoxFit.cover,
// //         ),
// //         borderRadius: const BorderRadius.only(
// //           bottomLeft: Radius.circular(20),
// //           bottomRight: Radius.circular(20),
// //         ),
// //       ),
// //       child: Stack(
// //         children: [
// //           Center(
// //             child: Column(
// //               mainAxisSize: MainAxisSize.min,
// //               children: [
// //                 const SizedBox(height: 50),
// //                 Text(
// //                   'Calendar',
// //                   style: TextStyle(
// //                     color: isDarkMode ? Colors.white : Colors.black,
// //                     fontSize: 20, // Smaller font size
// //                     fontWeight: FontWeight.bold,
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //           Positioned(
// //             top: 55,
// //             right: 20,
// //             child: IconButton(
// //               icon: const Icon(
// //                 Icons.add_circle,
// //                 size: 40,
// //                 color: Colors.green,
// //               ),
// //               onPressed: _showAddEventOptionsPopup,
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildCalendar(bool isDarkMode) {
// //     return Container(
// //       height: 300,
// //       margin: const EdgeInsets.all(18.0),
// //       decoration: BoxDecoration(
// //         color: isDarkMode ? Colors.black : Colors.white,
// //         boxShadow: const [
// //           BoxShadow(
// //             color: Colors.black26,
// //             blurRadius: 4,
// //             offset: Offset(0, 2),
// //           ),
// //         ],
// //         borderRadius: BorderRadius.circular(8),
// //       ),
// //       child: TableCalendar<Event>(
// //         rowHeight: 44,
// //         firstDay: DateTime.utc(2010, 10, 16),
// //         lastDay: DateTime.utc(2030, 3, 14),
// //         focusedDay: _focusedDay,
// //         calendarFormat: CalendarFormat.month,
// //         availableCalendarFormats: const {
// //           CalendarFormat.month: 'Month',
// //         },
// //         selectedDayPredicate: (day) {
// //           return isSameDay(_selectedDay, day);
// //         },
// //         onDaySelected: (selectedDay, focusedDay) {
// //           if (_singleTapSelectedDay != null &&
// //               isSameDay(_singleTapSelectedDay, selectedDay)) {
// //             // Double-tap detected, navigate to Timetable view
// //             _showDayView(selectedDay);
// //             _singleTapSelectedDay = null;
// //           } else {
// //             // Single tap
// //             setState(() {
// //               _singleTapSelectedDay = selectedDay;
// //               _selectedDay = selectedDay;
// //               _focusedDay = focusedDay;
// //               _eventsForDay = _getEventsForDay(selectedDay);
// //             });
// //           }
// //         },
// //         onFormatChanged: (format) {
// //           if (_calendarFormat != format) {
// //             setState(() {
// //               _calendarFormat = format;
// //             });
// //           }
// //         },
// //         onPageChanged: (focusedDay) {
// //           setState(() {
// //             _focusedDay = focusedDay;
// //           });
// //         },
// //         eventLoader: _getEventsForDay,
// //         calendarStyle: const CalendarStyle(
// //           todayDecoration: BoxDecoration(
// //             color: Colors.orangeAccent,
// //             shape: BoxShape.circle,
// //           ),
// //           selectedDecoration: BoxDecoration(
// //             color: Colors.green,
// //             shape: BoxShape.circle,
// //           ),
// //           markerDecoration: BoxDecoration(
// //             color: Colors.orange,
// //             shape: BoxShape.circle,
// //           ),
// //         ),
// //         headerStyle: const HeaderStyle(
// //           titleCentered: true,
// //           formatButtonVisible: false,
// //           titleTextStyle: TextStyle(
// //             fontSize: 20.0,
// //             fontWeight: FontWeight.bold,
// //             color: Colors.black,
// //           ),
// //           leftChevronIcon: Icon(
// //             Icons.chevron_left,
// //             size: 16,
// //             color: Colors.black,
// //           ),
// //           rightChevronIcon: Icon(
// //             Icons.chevron_right,
// //             size: 16,
// //             color: Colors.black,
// //           ),
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _buildSectionSeparator() {
// //     return const GradientAnimationLine();
// //   }

// //   Widget _buildSyncfusionCalendarView() {
// //     return SfCalendar(
// //       view: CalendarView.day,
// //       dataSource: MeetingDataSource(_eventsForDay),
// //       initialSelectedDate: _selectedDay,
// //       headerHeight: 50,
// //       headerStyle: const CalendarHeaderStyle(
// //         textAlign: TextAlign.center,
// //         textStyle: TextStyle(
// //           fontSize: 17,
// //           color: Colors.black,
// //         ),
// //       ),
// //       timeSlotViewSettings: const TimeSlotViewSettings(
// //         timeIntervalHeight: 40,
// //         startHour: 0,
// //         endHour: 24,
// //       ),
// //       appointmentBuilder: (context, details) {
// //         final Event meeting = details.appointments.first;
// //         return Container(
// //           padding: const EdgeInsets.all(8.0),
// //           decoration: BoxDecoration(
// //             color: meeting.isMeeting ? Colors.blue : Colors.orange,
// //             borderRadius: BorderRadius.circular(8),
// //           ),
// //           child: Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               Text(
// //                 meeting.title,
// //                 style: const TextStyle(
// //                   color: Colors.white,
// //                   fontWeight: FontWeight.bold,
// //                 ),
// //               ),
// //               const SizedBox(height: 8),
// //               Text(
// //                 '${DateFormat.jm().format(meeting.startDateTime)} - ${DateFormat.jm().format(meeting.endDateTime)}',
// //                 style: const TextStyle(
// //                   color: Colors.white70,
// //                   fontSize: 12,
// //                 ),
// //               ),
// //             ],
// //           ),
// //         );
// //       },
// //     );
// //   }

// //   void _showAddEventOptionsPopup() {
// //     showDialog(
// //       context: context,
// //       barrierColor: Colors.transparent,
// //       builder: (BuildContext context) {
// //         return Stack(
// //           children: [
// //             Positioned(
// //               top: 75,
// //               right: 40,
// //               child: Material(
// //                 color: Colors.transparent,
// //                 child: Container(
// //                   padding: const EdgeInsets.symmetric(vertical: 10),
// //                   width: 160,
// //                   decoration: BoxDecoration(
// //                     color: Colors.white,
// //                     borderRadius: BorderRadius.circular(16),
// //                     boxShadow: [
// //                       BoxShadow(
// //                         color: Colors.black.withOpacity(0.2),
// //                         blurRadius: 10,
// //                         offset: const Offset(0, 4),
// //                       ),
// //                     ],
// //                   ),
// //                   child: Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       _buildPopupOption(
// //                         icon: Icons.person,
// //                         label: '1. Personal',
// //                         onTap: () {
// //                           Navigator.pop(context);
// //                           _navigateToAddEvent('Personal');
// //                         },
// //                       ),
// //                       const Divider(height: 1),
// //                       _buildPopupOption(
// //                         icon: Icons.work,
// //                         label: '2. Office',
// //                         onTap: () {
// //                           Navigator.pop(context);
// //                           _navigateToAddEvent('Office');
// //                         },
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //               ),
// //             ),
// //           ],
// //         );
// //       },
// //     );
// //   }

// //   Widget _buildPopupOption({
// //     required IconData icon,
// //     required String label,
// //     required VoidCallback onTap,
// //   }) {
// //     return InkWell(
// //       onTap: onTap,
// //       child: Padding(
// //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// //         child: Row(
// //           children: [
// //             Icon(icon, size: 20, color: Colors.black54),
// //             const SizedBox(width: 12),
// //             Text(label, style: const TextStyle(color: Colors.black87)),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   void _navigateToAddEvent(String eventType) async {
// //     if (eventType == 'Personal') {
// //       Navigator.push(
// //         context,
// //         MaterialPageRoute(
// //           builder: (context) => const LeaveManagementPage(),
// //         ),
// //       );
// //     } else {
// //       final newEvent = await Navigator.push<Map<String, dynamic>>(
// //         context,
// //         MaterialPageRoute(
// //           builder: (context) => const OfficeAddEventPage(),
// //         ),
// //       );
// //       if (newEvent != null) {
// //         _addEvent(
// //           newEvent['title'],
// //           newEvent['startDateTime'],
// //           newEvent['endDateTime'],
// //           newEvent['description'] ?? '',
// //           'Pending', // Default to pending status for new events
// //           true, // isMeeting set to true for office events
// //         );
// //       }
// //     }
// //   }

// //   void _addEvent(String title, DateTime startDateTime, DateTime endDateTime,
// //       String description, String status, bool isMeeting) {
// //     final newEvent = Event(
// //         title, startDateTime, endDateTime, description, status, isMeeting);
// //     final eventsForDay = _getEventsForDay(_selectedDay!);
// //     setState(() {
// //       _events.value = {
// //         ..._events.value,
// //         _selectedDay!: [...eventsForDay, newEvent],
// //       };
// //       _eventsForDay = _getEventsForDay(_selectedDay!);
// //     });
// //   }
// // }

// // // Animation and Event classes
// // class GradientAnimationLine extends StatefulWidget {
// //   const GradientAnimationLine({super.key});

// //   @override
// //   _GradientAnimationLineState createState() => _GradientAnimationLineState();
// // }

// // class _GradientAnimationLineState extends State<GradientAnimationLine>
// //     with SingleTickerProviderStateMixin {
// //   late AnimationController _controller;
// //   late Animation<Color?> _colorAnimation1;
// //   late Animation<Color?> _colorAnimation2;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _controller = AnimationController(
// //       duration: const Duration(seconds: 3),
// //       vsync: this,
// //     )..repeat(reverse: true);

// //     _colorAnimation1 = ColorTween(
// //       begin: Colors.yellow,
// //       end: Colors.orange,
// //     ).animate(_controller);

// //     _colorAnimation2 = ColorTween(
// //       begin: Colors.orange,
// //       end: Colors.yellow,
// //     ).animate(_controller);
// //   }

// //   @override
// //   void dispose() {
// //     _controller.dispose();
// //     super.dispose();
// //   }

// //   Widget _buildSectionSeparator() {
// //     return AnimatedBuilder(
// //       animation: _controller,
// //       builder: (context, child) {
// //         return Container(
// //           height: 8.0,
// //           decoration: BoxDecoration(
// //             gradient: LinearGradient(
// //               begin: Alignment.topRight,
// //               end: Alignment.bottomLeft,
// //               colors: [
// //                 _colorAnimation1.value!,
// //                 _colorAnimation2.value!,
// //               ],
// //             ),
// //           ),
// //           margin: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 2.0),
// //         );
// //       },
// //     );
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return _buildSectionSeparator();
// //   }
// // }

// // class Event {
// //   final String title;
// //   final DateTime startDateTime;
// //   final DateTime endDateTime;
// //   final String description;
// //   final String status;
// //   final bool isMeeting;

// //   Event(this.title, this.startDateTime, this.endDateTime, this.description,
// //       this.status, this.isMeeting);

// //   String get formattedTime => DateFormat.jm().format(startDateTime);

// //   @override
// //   String toString() =>
// //       '$title ($status) from ${DateFormat.yMMMd().format(startDateTime)} to ${DateFormat.yMMMd().format(endDateTime)}';
// // }

// // class MeetingDataSource extends CalendarDataSource {
// //   MeetingDataSource(List<Event> source) {
// //     appointments = source;
// //   }

// //   @override
// //   DateTime getStartTime(int index) {
// //     return appointments![index].startDateTime;
// //   }

// //   @override
// //   DateTime getEndTime(int index) {
// //     return appointments![index].endDateTime;
// //   }

// //   @override
// //   String getSubject(int index) {
// //     return appointments![index].title;
// //   }

// //   @override
// //   bool isAllDay(int index) {
// //     return false;
// //   }
// // }

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter_timetable/flutter_timetable.dart';
// import 'package:pb_hrsystem/home/office_events/office_add_event.dart';
// import 'package:pb_hrsystem/home/timetable_page.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:table_calendar/table_calendar.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:pb_hrsystem/theme/theme.dart';
// import 'package:pb_hrsystem/home/leave_request_page.dart';
// import 'package:http/http.dart' as http;
// import 'package:syncfusion_flutter_calendar/calendar.dart';

// class HomeCalendar extends StatefulWidget {
//   const HomeCalendar({super.key});

//   @override
//   _HomeCalendarState createState() => _HomeCalendarState();
// }

// class _HomeCalendarState extends State<HomeCalendar> {
//   late final ValueNotifier<Map<DateTime, List<Event>>> _events;
//   CalendarFormat _calendarFormat = CalendarFormat.month;
//   DateTime _focusedDay = DateTime.now();
//   DateTime? _selectedDay;
//   DateTime? _singleTapSelectedDay;
//   List<Event> _eventsForDay = [];
//   late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

//   @override
//   void initState() {
//     super.initState();
//     _selectedDay = _focusedDay;
//     _events = ValueNotifier({});
//     _eventsForDay = [];

//     flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
//     const AndroidInitializationSettings initializationSettingsAndroid =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
//     const InitializationSettings initializationSettings =
//         InitializationSettings(android: initializationSettingsAndroid);
//     flutterLocalNotificationsPlugin.initialize(initializationSettings);

//     _fetchLeaveRequests();
//   }

//   DateTime _normalizeDate(DateTime date) {
//     return DateTime(date.year, date.month, date.day);
//   }

//   Future<void> _fetchLeaveRequests() async {
//     final prefs = await SharedPreferences.getInstance();
//     final token = prefs.getString('token');

//     if (token == null) {
//       _showErrorDialog('Authentication Error', 'Token is null. Please log in again.');
//       return;
//     }

//     try {
//       final response = await http.get(
//         Uri.parse('https://demo-application-api.flexiflows.co/api/leave_requests'),
//         headers: {'Authorization': 'Bearer $token'},
//       );

//       if (response.statusCode == 200) {
//         final List<dynamic> results = json.decode(response.body)['results'];
//         final leaveRequests = List<Map<String, dynamic>>.from(results);

//         final Map<DateTime, List<Event>> approvalEvents = {};
//         for (var item in leaveRequests) {
//           final DateTime startDate = _normalizeDate(DateTime.parse(item['take_leave_from']));
//           final DateTime endDate = _normalizeDate(DateTime.parse(item['take_leave_to']));
//           final event = Event(
//             item['name'],
//             startDate,
//             endDate,
//             item['take_leave_reason'] ?? 'Approval Pending',
//             item['is_approve'] ?? 'Waiting',
//             false,
//           );

//           for (var day = startDate;
//               day.isBefore(endDate.add(const Duration(days: 1)));
//               day = day.add(const Duration(days: 1))) {
//             final normalizedDay = _normalizeDate(day);
//             if (approvalEvents.containsKey(normalizedDay)) {
//               approvalEvents[normalizedDay]!.add(event);
//             } else {
//               approvalEvents[normalizedDay] = [event];
//             }
//           }
//         }

//         setState(() {
//           _events.value = approvalEvents;
//           _eventsForDay = _getEventsForDay(_focusedDay);
//         });
//       } else {
//         _showErrorDialog(
//             'Failed to Load Leave Requests', 'Server returned status code: ${response.statusCode}. Message: ${response.reasonPhrase}');
//       }
//     } catch (e) {
//       _showErrorDialog('Error Fetching Leave Requests', 'An unexpected error occurred: $e');
//     }
//   }

//   List<Event> _getEventsForDay(DateTime day) {
//     final normalizedDay = _normalizeDate(day);
//     return _events.value[normalizedDay] ?? [];
//   }

//   void _showDayView(DateTime selectedDay) {
//     final List<Event> dayEvents = _getEventsForDay(selectedDay);

//     final List<TimetableItem<String>> timetableItems = dayEvents.map((event) {
//       return TimetableItem<String>(
//         event.startDateTime,
//         event.endDateTime,
//         data: event.title,
//       );
//     }).toList();

//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => TimetablePage(
//           date: selectedDay,
//           events: timetableItems,
//         ),
//       ),
//     );
//   }

//   void _showEventPopup(Event event) {
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text(event.title),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('From: ${DateFormat.yMMMd().format(event.startDateTime)} ${DateFormat.jm().format(event.startDateTime)}'),
//               Text('To: ${DateFormat.yMMMd().format(event.endDateTime)} ${DateFormat.jm().format(event.endDateTime)}'),
//               Text('Description: ${event.description}'),
//               Text('Status: ${event.status}'),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('Close'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _showErrorDialog(String title, String message) {
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text(title),
//           content: Text(message),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//               child: const Text('OK'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final themeNotifier = Provider.of<ThemeNotifier>(context);
//     final bool isDarkMode = themeNotifier.isDarkMode;

//     return Scaffold(
//       body: Stack(
//         children: [
//           Column(
//             children: [
//               _buildCalendarHeader(isDarkMode),
//               _buildCalendar(isDarkMode),
//               _buildSectionSeparator(),
//               Expanded(child: _buildEventListView()), // Show event list below calendar
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildEventListView() {
//     return ListView.builder(
//       itemCount: _eventsForDay.length,
//       itemBuilder: (context, index) {
//         final event = _eventsForDay[index];
//         return ListTile(
//           title: Text(event.title),
//           subtitle: Text('Status: ${event.status}'),
//           onTap: () => _showEventPopup(event),
//         );
//       },
//     );
//   }

//   Widget _buildCalendarHeader(bool isDarkMode) {
//     return Container(
//       width: double.infinity,
//       height: 120,
//       decoration: BoxDecoration(
//         image: DecorationImage(
//           image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
//           fit: BoxFit.cover,
//         ),
//         borderRadius: const BorderRadius.only(
//           bottomLeft: Radius.circular(20),
//           bottomRight: Radius.circular(20),
//         ),
//       ),
//       child: Stack(
//         children: [
//           Center(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const SizedBox(height: 50),
//                 Text(
//                   'Calendar',
//                   style: TextStyle(
//                     color: isDarkMode ? Colors.white : Colors.black,
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Positioned(
//             top: 55,
//             right: 20,
//             child: IconButton(
//               icon: const Icon(
//                 Icons.add_circle,
//                 size: 40,
//                 color: Colors.green,
//               ),
//               onPressed: _showAddEventOptionsPopup,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildCalendar(bool isDarkMode) {
//     return Container(
//       height: 300,
//       margin: const EdgeInsets.all(18.0),
//       decoration: BoxDecoration(
//         color: isDarkMode ? Colors.black : Colors.white,
//         boxShadow: const [
//           BoxShadow(
//             color: Colors.black26,
//             blurRadius: 4,
//             offset: Offset(0, 2),
//           ),
//         ],
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: TableCalendar<Event>(
//         rowHeight: 44,
//         firstDay: DateTime.utc(2010, 10, 16),
//         lastDay: DateTime.utc(2030, 3, 14),
//         focusedDay: _focusedDay,
//         calendarFormat: CalendarFormat.month,
//         availableCalendarFormats: const {
//           CalendarFormat.month: 'Month',
//         },
//         selectedDayPredicate: (day) {
//           return isSameDay(_selectedDay, day);
//         },
//         onDaySelected: (selectedDay, focusedDay) {
//           if (_singleTapSelectedDay != null &&
//               isSameDay(_singleTapSelectedDay, selectedDay)) {
//             _showDayView(selectedDay);
//             _singleTapSelectedDay = null;
//           } else {
//             setState(() {
//               _singleTapSelectedDay = selectedDay;
//               _selectedDay = selectedDay;
//               _focusedDay = focusedDay;
//               _eventsForDay = _getEventsForDay(selectedDay);
//             });
//           }
//         },
//         onFormatChanged: (format) {
//           if (_calendarFormat != format) {
//             setState(() {
//               _calendarFormat = format;
//             });
//           }
//         },
//         onPageChanged: (focusedDay) {
//           setState(() {
//             _focusedDay = focusedDay;
//           });
//         },
//         eventLoader: _getEventsForDay,
//         calendarStyle: const CalendarStyle(
//           todayDecoration: BoxDecoration(
//             color: Colors.orangeAccent,
//             shape: BoxShape.circle,
//           ),
//           selectedDecoration: BoxDecoration(
//             color: Colors.green,
//             shape: BoxShape.circle,
//           ),
//           markerDecoration: BoxDecoration(
//             color: Colors.orange,
//             shape: BoxShape.circle,
//           ),
//         ),
//         headerStyle: const HeaderStyle(
//           titleCentered: true,
//           formatButtonVisible: false,
//           titleTextStyle: TextStyle(
//             fontSize: 20.0,
//             fontWeight: FontWeight.bold,
//             color: Colors.black,
//           ),
//           leftChevronIcon: Icon(
//             Icons.chevron_left,
//             size: 16,
//             color: Colors.black,
//           ),
//           rightChevronIcon: Icon(
//             Icons.chevron_right,
//             size: 16,
//             color: Colors.black,
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSectionSeparator() {
//     return const GradientAnimationLine();
//   }

//   void _showAddEventOptionsPopup() {
//     showDialog(
//       context: context,
//       barrierColor: Colors.transparent,
//       builder: (BuildContext context) {
//         return Stack(
//           children: [
//             Positioned(
//               top: 75,
//               right: 40,
//               child: Material(
//                 color: Colors.transparent,
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(vertical: 10),
//                   width: 160,
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(16),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.2),
//                         blurRadius: 10,
//                         offset: const Offset(0, 4),
//                       ),
//                     ],
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       _buildPopupOption(
//                         icon: Icons.person,
//                         label: '1. Personal',
//                         onTap: () {
//                           Navigator.pop(context);
//                           _navigateToAddEvent('Personal');
//                         },
//                       ),
//                       const Divider(height: 1),
//                       _buildPopupOption(
//                         icon: Icons.work,
//                         label: '2. Office',
//                         onTap: () {
//                           Navigator.pop(context);
//                           _navigateToAddEvent('Office');
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildPopupOption({
//     required IconData icon,
//     required String label,
//     required VoidCallback onTap,
//   }) {
//     return InkWell(
//       onTap: onTap,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         child: Row(
//           children: [
//             Icon(icon, size: 20, color: Colors.black54),
//             const SizedBox(width: 12),
//             Text(label, style: const TextStyle(color: Colors.black87)),
//           ],
//         ),
//       ),
//     );
//   }

//   void _navigateToAddEvent(String eventType) async {
//     if (eventType == 'Personal') {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => const LeaveManagementPage(),
//         ),
//       );
//     } else {
//       final newEvent = await Navigator.push<Map<String, dynamic>>(
//         context,
//         MaterialPageRoute(
//           builder: (context) => const OfficeAddEventPage(),
//         ),
//       );
//       if (newEvent != null) {
//         _addEvent(
//           newEvent['title'],
//           newEvent['startDateTime'],
//           newEvent['endDateTime'],
//           newEvent['description'] ?? '',
//           'Pending',
//           true,
//         );
//       }
//     }
//   }

//   void _addEvent(String title, DateTime startDateTime, DateTime endDateTime,
//       String description, String status, bool isMeeting) {
//     final newEvent = Event(
//         title, startDateTime, endDateTime, description, status, isMeeting);
//     final eventsForDay = _getEventsForDay(_selectedDay!);
//     setState(() {
//       _events.value = {
//         ..._events.value,
//         _selectedDay!: [...eventsForDay, newEvent],
//       };
//       _eventsForDay = _getEventsForDay(_selectedDay!);
//     });
//   }
// }

// class GradientAnimationLine extends StatefulWidget {
//   const GradientAnimationLine({super.key});

//   @override
//   _GradientAnimationLineState createState() => _GradientAnimationLineState();
// }

// class _GradientAnimationLineState extends State<GradientAnimationLine>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<Color?> _colorAnimation1;
//   late Animation<Color?> _colorAnimation2;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       duration: const Duration(seconds: 3),
//       vsync: this,
//     )..repeat(reverse: true);

//     _colorAnimation1 = ColorTween(
//       begin: Colors.yellow,
//       end: Colors.orange,
//     ).animate(_controller);

//     _colorAnimation2 = ColorTween(
//       begin: Colors.orange,
//       end: Colors.yellow,
//     ).animate(_controller);
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   Widget _buildSectionSeparator() {
//     return AnimatedBuilder(
//       animation: _controller,
//       builder: (context, child) {
//         return Container(
//           height: 8.0,
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topRight,
//               end: Alignment.bottomLeft,
//               colors: [
//                 _colorAnimation1.value!,
//                 _colorAnimation2.value!,
//               ],
//             ),
//           ),
//           margin: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 2.0),
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return _buildSectionSeparator();
//   }
// }

// class Event {
//   final String title;
//   final DateTime startDateTime;
//   final DateTime endDateTime;
//   final String description;
//   final String status;
//   final bool isMeeting;

//   Event(this.title, this.startDateTime, this.endDateTime, this.description,
//       this.status, this.isMeeting);

//   String get formattedTime => DateFormat.jm().format(startDateTime);

//   @override
//   String toString() =>
//       '$title ($status) from ${DateFormat.yMMMd().format(startDateTime)} to ${DateFormat.yMMMd().format(endDateTime)}';
// }

// class MeetingDataSource extends CalendarDataSource {
//   MeetingDataSource(List<Event> source) {
//     appointments = source;
//   }

//   @override
//   DateTime getStartTime(int index) {
//     return appointments![index].startDateTime;
//   }

//   @override
//   DateTime getEndTime(int index) {
//     return appointments![index].endDateTime;
//   }

//   @override
//   String getSubject(int index) {
//     return appointments![index].title;
//   }

//   @override
//   bool isAllDay(int index) {
//     return false;
//   }
// }

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

    _fetchLeaveRequests();
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

  void _showEventPopup(Event event) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(event.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('From: ${DateFormat.yMMMd().format(event.startDateTime)} ${DateFormat.jm().format(event.startDateTime)}'),
              Text('To: ${DateFormat.yMMMd().format(event.endDateTime)} ${DateFormat.jm().format(event.endDateTime)}'),
              Text('Description: ${event.description}'),
              Text('Status: ${event.status}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
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
              Expanded(child: _buildEventListView()), // Show event list below calendar in card format
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventListView() {
    return ListView.builder(
      itemCount: _eventsForDay.length,
      itemBuilder: (context, index) {
        final event = _eventsForDay[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          elevation: 3,
          child: ListTile(
            title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Status: ${event.status}\nFrom: ${DateFormat.jm().format(event.startDateTime)}\nTo: ${DateFormat.jm().format(event.endDateTime)}'),
            onTap: () => _showEventPopup(event),
          ),
        );
      },
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
                    fontSize: 20,
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
      height: 300,
      margin: const EdgeInsets.all(18.0),
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
        rowHeight: 44,
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
    return const GradientAnimationLine();
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
