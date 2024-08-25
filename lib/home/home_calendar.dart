// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:pb_hrsystem/home/office_events/office_add_event.dart';
// import 'package:pb_hrsystem/home/popups/event_details_popups.dart';
// import 'package:pb_hrsystem/home/timetable_page.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:table_calendar/table_calendar.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:pb_hrsystem/theme/theme.dart';
// import 'package:pb_hrsystem/home/leave_request_page.dart';
// import 'package:http/http.dart' as http;

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
//   List<Map<String, dynamic>> _leaveRequests = [];
//   late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

//   @override
//   void initState() {
//     super.initState();
//     _selectedDay = _focusedDay;
//     _events = ValueNotifier({});

//     flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
//     const AndroidInitializationSettings initializationSettingsAndroid =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
//     const InitializationSettings initializationSettings =
//         InitializationSettings(android: initializationSettingsAndroid);
//     flutterLocalNotificationsPlugin.initialize(initializationSettings);

//     _fetchLeaveRequests(); // Fetch approvals and initialize events in the calendar
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
//         _leaveRequests = List<Map<String, dynamic>>.from(results);

//         final Map<DateTime, List<Event>> approvalEvents = {};
//         for (var item in _leaveRequests) {
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

//   List<Event> _getEventsForMonth(DateTime month) {
//     final startOfMonth = DateTime(month.year, month.month, 1);
//     final endOfMonth = DateTime(month.year, month.month + 1, 0);

//     return _events.value.entries
//         .where((entry) => entry.key.isAfter(startOfMonth.subtract(const Duration(days: 1))) && entry.key.isBefore(endOfMonth.add(const Duration(days: 1))))
//         .expand((entry) => entry.value)
//         .toList();
//   }

//   void _showDayView(DateTime date) {
//     final events = _getEventsForDay(date);
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => DayViewScreen(date: date, events: events),
//       ),
//     );
//   }

//   bool _hasPendingApprovals(DateTime day) {
//     return _getEventsForDay(day).any((event) => event.status == 'Waiting');
//   }

//   @override
//   void dispose() {
//     _events.dispose();
//     super.dispose();
//   }

//   void _addEvent(String title, DateTime startDateTime, DateTime endDateTime, String description, String status, bool isMeeting) {
//     final newEvent = Event(title, startDateTime, endDateTime, description, status, isMeeting);
//     final eventsForDay = _getEventsForDay(_selectedDay!);
//     setState(() {
//       _events.value = {
//         ..._events.value,
//         _selectedDay!: [...eventsForDay, newEvent],
//       };
//     });
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
//           'Pending', // Default to pending status for new events
//           true, // isMeeting set to true for office events
//         );
//       }
//     }
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
//               Container(
//                 width: double.infinity,
//                 height: MediaQuery.of(context).size.height * 0.1,
//                 decoration: BoxDecoration(
//                   image: DecorationImage(
//                     image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
//                     fit: BoxFit.cover,
//                   ),
//                   borderRadius: const BorderRadius.only(
//                     bottomLeft: Radius.circular(20),
//                     bottomRight: Radius.circular(20),
//                   ),
//                 ),
//                 child: Stack(
//                   children: [
//                     Center(
//                       child: Text(
//                         'Calendar',
//                         style: TextStyle(
//                           color: isDarkMode ? Colors.white : Colors.black,
//                           fontSize: 24,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                     Positioned(
//                       top: 25,
//                       right: 20,
//                       child: IconButton(
//                         icon: const Icon(
//                           Icons.add_circle,
//                           size: 40,
//                           color: Colors.green,
//                         ),
//                         onPressed: _showAddEventOptionsPopup,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Container(
//                 margin: const EdgeInsets.all(16.0),
//                 decoration: BoxDecoration(
//                   color: isDarkMode ? Colors.black54 : Colors.white,
//                   boxShadow: const [
//                     BoxShadow(
//                       color: Colors.black26,
//                       blurRadius: 10,
//                       offset: Offset(0, 4),
//                     ),
//                   ],
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: TableCalendar<Event>(
//                   firstDay: DateTime.utc(2010, 10, 16),
//                   lastDay: DateTime.utc(2030, 3, 14),
//                   focusedDay: _focusedDay,
//                   calendarFormat: CalendarFormat.month,
//                   availableCalendarFormats: const {
//                     CalendarFormat.month: 'Month',
//                   },

//                   selectedDayPredicate: (day) {
//                     return isSameDay(_selectedDay, day);
//                   },
//                   // onDaySelected: (selectedDay, focusedDay) {
//                   //   if (_singleTapSelectedDay != null && isSameDay(_singleTapSelectedDay, selectedDay)) {
//                   //     _showDayView(selectedDay);
//                   //     _singleTapSelectedDay = null;
//                   //   } else {
//                   //     setState(() {
//                   //       _singleTapSelectedDay = selectedDay;
//                   //       _selectedDay = selectedDay;
//                   //       _focusedDay = focusedDay;
//                   //     });
//                   //   }
//                   // },
//                   onDaySelected: (selectedDay, focusedDay) {
//                     if (_singleTapSelectedDay != null && isSameDay(_singleTapSelectedDay, selectedDay)) {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => TimetablePage(date: selectedDay, events: _getEventsForDay(selectedDay)),
//                         ),
//                       );
//                       _singleTapSelectedDay = null;
//                     } else {
//                       setState(() {
//                         _singleTapSelectedDay = selectedDay;
//                         _selectedDay = selectedDay;
//                         _focusedDay = focusedDay;
//                       });
//                     }
//                   },

//                   onFormatChanged: (format) {
//                     if (_calendarFormat != format) {
//                       setState(() {
//                         _calendarFormat = format;
//                       });
//                     }
//                   },
//                   onPageChanged: (focusedDay) {
//                     setState(() {
//                       _focusedDay = focusedDay;
//                     });
//                   },
//                   eventLoader: _getEventsForDay,
//                   calendarStyle: const CalendarStyle(
//                     todayDecoration: BoxDecoration(
//                       color: Colors.orangeAccent,
//                       shape: BoxShape.circle,
//                     ),
//                     selectedDecoration: BoxDecoration(
//                       color: Colors.deepPurple,
//                       shape: BoxShape.circle,
//                     ),
//                     markerDecoration: BoxDecoration(
//                       color: Colors.orange,
//                       shape: BoxShape.circle,
//                     ),
//                   ),
//                   headerStyle: const HeaderStyle(
//                     titleCentered: true,
//                     formatButtonVisible: false,
//                     titleTextStyle: TextStyle(
//                       fontSize: 20.0,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black,
//                     ),
//                     leftChevronIcon: Icon(
//                       Icons.chevron_left,
//                       color: Colors.black,
//                     ),
//                     rightChevronIcon: Icon(
//                       Icons.chevron_right,
//                       color: Colors.black,
//                     ),
//                   ),
//                   calendarBuilders: CalendarBuilders(
//                     defaultBuilder: (context, date, _) {
//                       final hasPendingApproval = _hasPendingApprovals(date);
//                       return CustomPaint(
//                         painter: hasPendingApproval ? DottedBorderPainter() : null,
//                         child: Container(
//                           decoration: BoxDecoration(
//                             image: isSameDay(_singleTapSelectedDay, date)
//                                 ? const DecorationImage(
//                                     image: AssetImage('assets/background.png'),
//                                     fit: BoxFit.cover,
//                                   )
//                                 : null,
//                             color: isSameDay(_singleTapSelectedDay, date) ? null : Colors.transparent,
//                           ),
//                           child: Center(
//                             child: Text(
//                               '${date.day}',
//                               style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
//                             ),
//                           ),
//                         ),
//                       );
//                     },
//                     markerBuilder: (context, date, events) {
//                       if (events.isNotEmpty) {
//                         final isFirstEvent = _isFirstEvent(events, date);
//                         final isLastEvent = _isLastEvent(events, date);

//                         return Align(
//                           alignment: Alignment.bottomCenter,
//                           child: Container(
//                             width: isFirstEvent || isLastEvent ? 20 : double.infinity,
//                             height: 4.0,
//                             color: Colors.green,
//                           ),
//                         );
//                       }
//                       return const SizedBox();
//                     },
//                   ),
//                   daysOfWeekHeight: 0,
//                 ),
//               ),

//               Container(
//                 height: 6.0,
//                 color: Colors.orange,
//                 margin: const EdgeInsets.symmetric(horizontal: 20.0),
//               ),

//               Expanded(
//                 child: Container(
//                   padding: const EdgeInsets.only(top: 10),
//                   decoration: const BoxDecoration(
//                   ),
//                   child: _buildTimeTable(_focusedDay), // Filtered timetable by month
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   bool _isFirstEvent(List<Event> events, DateTime date) {
//     final event = events.firstWhere((e) => e.startDateTime.isAtSameMomentAs(date), orElse: () => events.first);
//     return event.startDateTime.isAtSameMomentAs(date);
//   }

//   bool _isLastEvent(List<Event> events, DateTime date) {
//     final event = events.firstWhere((e) => e.endDateTime.isAtSameMomentAs(date), orElse: () => events.first);
//     return event.endDateTime.isAtSameMomentAs(date);
//   }

//   void _showEventDetails(BuildContext context, Event event) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return EventDetailsPopup(event: event);
//       },
//     );
//   }

//   Widget _buildTimeTable(DateTime month) {
//     final eventsForMonth = _getEventsForMonth(month);
//     final groupedByDay = <DateTime, List<Event>>{};

//     for (var event in eventsForMonth) {
//       final normalizedDay = _normalizeDate(event.startDateTime);
//       if (groupedByDay.containsKey(normalizedDay)) {
//         groupedByDay[normalizedDay]!.add(event);
//       } else {
//         groupedByDay[normalizedDay] = [event];
//       }
//     }

//     return ListView(
//       children: [
//         for (var day in groupedByDay.keys)
//           if (groupedByDay[day]!.isNotEmpty) _buildDayEvents(day, groupedByDay[day]!),
//       ],
//     );
//   }

//   Widget _buildDayEvents(DateTime day, List<Event> events) {
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             DateFormat.yMMMMEEEEd().format(day),
//             style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 8.0),
//           SizedBox(
//             height: 100,
//             child: ListView.builder(
//               scrollDirection: Axis.horizontal,
//               itemCount: events.length,
//               itemBuilder: (context, index) {
//                 return _buildEventCard(events[index]);
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildEventCard(Event event) {
//     return InkWell(
//         onTap: () {
//           showDialog(
//             context: context,
//             builder: (context) => EventDetailsPopup(event: event),
//           );
//     },
//     child: Container(
//       width: 300,
//       height: 300,
//       margin: const EdgeInsets.only(right: 30.0),
//       padding: const EdgeInsets.all(12.0),
//       decoration: BoxDecoration(
//         color: event.status == 'Approved' ? Colors.green[200] : event.status == 'Rejected' ? Colors.red[200] : Colors.orange[200],
//         borderRadius: BorderRadius.circular(12.0),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(event.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
//           Text(event.description),
//           const Spacer(),
//           Text('${DateFormat.jm().format(event.startDateTime)} - ${DateFormat.jm().format(event.endDateTime)}'),
//           Text(event.status, style: TextStyle(color: event.status == 'Approved' ? Colors.green : Colors.red)),
//         ],
//       ),
//     ));
//   }
// }

// class Event {
//   final String title;
//   final DateTime startDateTime;
//   final DateTime endDateTime;
//   final String description;
//   final String status;
//   final bool isMeeting;

//   Event(this.title, this.startDateTime, this.endDateTime, this.description, this.status, this.isMeeting);

//   String get formattedTime => DateFormat.jm().format(startDateTime);

//   @override
//   String toString() => '$title ($status) from ${DateFormat.yMMMd().format(startDateTime)} to ${DateFormat.yMMMd().format(endDateTime)}';
// }

// class DottedBorderPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     const double dashWidth = 4.0;
//     const double dashSpace = 4.0;
//     final Paint paint = Paint()
//       ..color = Colors.white
//       ..strokeWidth = 2.0
//       ..style = PaintingStyle.stroke;

//     double startX = 0;
//     final Path path = Path();

//     while (startX < size.width) {
//       path.moveTo(startX, 0);
//       path.lineTo(startX + dashWidth, 0);
//       startX += dashWidth + dashSpace;
//     }

//     double startY = 0;
//     while (startY < size.height) {
//       path.moveTo(0, startY);
//       path.lineTo(0, startY + dashWidth);
//       startY += dashWidth + dashSpace;
//     }

//     canvas.drawPath(path, paint);
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) {
//     return false;
//   }
// }

// class DayViewScreen extends StatelessWidget {
//   final DateTime date;
//   final List<Event> events;

//   const DayViewScreen({required this.date, required this.events, super.key});

//   @override
//   Widget build(BuildContext context) {
//     final themeNotifier = Provider.of<ThemeNotifier>(context);
//     final bool isDarkMode = themeNotifier.isDarkMode;

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(DateFormat('EEEE, MMM d, yyyy').format(date)),
//         backgroundColor: isDarkMode ? Colors.black : Colors.yellow,
//       ),
//       body: events.isEmpty
//           ? Center(
//               child: Text(
//                 'No events for this day',
//                 style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
//               ),
//             )
//           : ListView.builder(
//               padding: const EdgeInsets.all(16.0),
//               itemCount: events.length,
//               itemBuilder: (context, index) {
//                 final event = events[index];
//                 Color statusColor;

//                 switch (event.status) {
//                   case 'Approved':
//                     statusColor = Colors.green;
//                     break;
//                   case 'Rejected':
//                     statusColor = Colors.red;
//                     break;
//                   default:
//                     statusColor = Colors.orange;
//                 }

//                 return Card(
//                   color: isDarkMode ? Colors.black54 : Colors.white,
//                   elevation: 4,
//                   margin: const EdgeInsets.only(bottom: 16.0),
//                   child: ListTile(
//                     leading: CircleAvatar(
//                       backgroundColor: statusColor,
//                       child: const Icon(
//                         Icons.event,
//                         color: Colors.white,
//                       ),
//                     ),
//                     title: Text(
//                       event.title,
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         color: isDarkMode ? Colors.white : Colors.black,
//                       ),
//                     ),
//                     subtitle: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           '${DateFormat('hh:mm a').format(event.startDateTime)} - ${DateFormat('hh:mm a').format(event.endDateTime)}',
//                           style: TextStyle(color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           event.description,
//                           style: TextStyle(color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           event.status,
//                           style: TextStyle(
//                             color: statusColor,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//     );
//   }
// }

// class EventDetailsPopup extends StatelessWidget {
//   final Event event;

//   const EventDetailsPopup({required this.event, super.key});

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(20.0),
//       ),
//       backgroundColor: Colors.grey[50],
//       title: Text(
//         event.title,
//         style: const TextStyle(
//           fontSize: 20,
//           fontWeight: FontWeight.bold,
//           color: Colors.black87,
//         ),
//       ),
//       content: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 10.0),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 const Icon(Icons.access_time, color: Colors.blueAccent),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     'Time: ${event.formattedTime}',
//                     style: const TextStyle(
//                       fontSize: 16,
//                       color: Colors.black54,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             Row(
//               children: [
//                 const Icon(Icons.stairs, color: Colors.greenAccent),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     'Status: ${event.status}',
//                     style: const TextStyle(
//                       fontSize: 16,
//                       color: Colors.black54,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             Text(
//               'Description: ${event.description}',
//               style: const TextStyle(
//                 fontSize: 14,
//                 color: Colors.black87,
//               ),
//             ),
//           ],
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () {
//             Navigator.of(context).pop();
//           },
//           child: const Text(
//             'Close',
//             style: TextStyle(
//               fontSize: 16,
//               color: Colors.blueAccent,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/office_events/office_add_event.dart';
import 'package:pb_hrsystem/home/popups/event_details_popups.dart';
import 'package:pb_hrsystem/home/timetable_page.dart';
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

  List<Event> _getEventsForMonth(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    return _events.value.entries
        .where((entry) => entry.key.isAfter(startOfMonth.subtract(const Duration(days: 1))) && entry.key.isBefore(endOfMonth.add(const Duration(days: 1))))
        .expand((entry) => entry.value)
        .toList();
  }

  void _showDayView(DateTime date) {
    final events = _getEventsForDay(date);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TimetablePage(date: date, events: events),
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
                    if (_singleTapSelectedDay != null && isSameDay(_singleTapSelectedDay, selectedDay)) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TimetablePage(date: selectedDay, events: _getEventsForDay(selectedDay)),
                        ),
                      );
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
                      color: Colors.deepPurple,
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
                      color: Colors.black,
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right,
                      color: Colors.black,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, date, _) {
                      final hasPendingApproval = _hasPendingApprovals(date);
                      return CustomPaint(
                        painter: hasPendingApproval ? StraightLineBorderPainter() : null,
                        child: Container(
                          decoration: BoxDecoration(
                            image: isSameDay(_singleTapSelectedDay, date)
                                ? const DecorationImage(
                                    image: AssetImage('assets/background.png'),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: isSameDay(_singleTapSelectedDay, date) ? null : Colors.transparent,
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
                        final isFirstEvent = _isFirstEvent(events, date);
                        final isLastEvent = _isLastEvent(events, date);

                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: isFirstEvent || isLastEvent ? 20 : double.infinity,
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

              Container(
                height: 6.0,
                color: Colors.orange,
                margin: const EdgeInsets.symmetric(horizontal: 20.0),
              ),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                  ),
                  child: _buildTimeTable(_focusedDay), // Filtered timetable by month
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isFirstEvent(List<Event> events, DateTime date) {
    final event = events.firstWhere((e) => e.startDateTime.isAtSameMomentAs(date), orElse: () => events.first);
    return event.startDateTime.isAtSameMomentAs(date);
  }

  bool _isLastEvent(List<Event> events, DateTime date) {
    final event = events.firstWhere((e) => e.endDateTime.isAtSameMomentAs(date), orElse: () => events.first);
    return event.endDateTime.isAtSameMomentAs(date);
  }

  void _showEventDetails(BuildContext context, Event event) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EventDetailsPopup(event: event);
      },
    );
  }

  Widget _buildTimeTable(DateTime month) {
    final eventsForMonth = _getEventsForMonth(month);
    final groupedByDay = <DateTime, List<Event>>{};

    for (var event in eventsForMonth) {
      final normalizedDay = _normalizeDate(event.startDateTime);
      if (groupedByDay.containsKey(normalizedDay)) {
        groupedByDay[normalizedDay]!.add(event);
      } else {
        groupedByDay[normalizedDay] = [event];
      }
    }

    return ListView(
      children: [
        for (var day in groupedByDay.keys)
          if (groupedByDay[day]!.isNotEmpty) _buildDayEvents(day, groupedByDay[day]!),
      ],
    );
  }

  Widget _buildDayEvents(DateTime day, List<Event> events) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.yMMMMEEEEd().format(day),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8.0),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: events.length,
              itemBuilder: (context, index) {
                return _buildEventCard(events[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    return InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => EventDetailsPopup(event: event),
          );
    },
    child: Container(
      width: 300,
      height: 300,
      margin: const EdgeInsets.only(right: 30.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: event.status == 'Approved' ? Colors.green[200] : event.status == 'Rejected' ? Colors.red[200] : Colors.orange[200],
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Text(event.description),
          const Spacer(),
          Text('${DateFormat.jm().format(event.startDateTime)} - ${DateFormat.jm().format(event.endDateTime)}'),
          Text(event.status, style: TextStyle(color: event.status == 'Approved' ? Colors.green : Colors.red)),
        ],
      ),
    ));
  }
}

class Event {
  final String title;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String description;
  final String status;
  final bool isMeeting;

  Event(this.title, this.startDateTime, this.endDateTime, this.description, this.status, this.isMeeting);

  String get formattedTime => DateFormat.jm().format(startDateTime);

  @override
  String toString() => '$title ($status) from ${DateFormat.yMMMd().format(startDateTime)} to ${DateFormat.yMMMd().format(endDateTime)}';
}

class StraightLineBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Drawing the straight border
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), paint); // Top border
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), paint); // Left border
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), paint); // Bottom border
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), paint); // Right border
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
      body: events.isEmpty
          ? Center(
              child: Text(
                'No events for this day',
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                Color statusColor;

                switch (event.status) {
                  case 'Approved':
                    statusColor = Colors.green;
                    break;
                  case 'Rejected':
                    statusColor = Colors.red;
                    break;
                  default:
                    statusColor = Colors.orange;
                }

                return Card(
                  color: isDarkMode ? Colors.black54 : Colors.white,
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor,
                      child: const Icon(
                        Icons.event,
                        color: Colors.white,
                      ),
                    ),
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
                        Text(
                          '${DateFormat('hh:mm a').format(event.startDateTime)} - ${DateFormat('hh:mm a').format(event.endDateTime)}',
                          style: TextStyle(color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          event.description,
                          style: TextStyle(color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          event.status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      backgroundColor: Colors.grey[50],
      title: Text(
        event.title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Time: ${event.formattedTime}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.stairs, color: Colors.greenAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Status: ${event.status}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Description: ${event.description}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'Close',
            style: TextStyle(
              fontSize: 16,
              color: Colors.blueAccent,
            ),
          ),
        ),
      ],
    );
  }
}
