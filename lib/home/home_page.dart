import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/popups/EventDetailsPopup.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ValueNotifier<List<Event>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Notification initialization
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();

    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));

    // Initialize notification plugin
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  List<Event> _getEventsForDay(DateTime day) {
    return [
      Event('Sale Presentation: HI App production', DateTime.now().add(const Duration(hours: 1))),
      Event('Pick up from Hotel to Bank', DateTime.now().add(const Duration(hours: 2))),
      Event('Japan Vendor', DateTime.now().add(const Duration(hours: 3))),
      Event('Deadline for HIAPP product', DateTime.now().add(const Duration(hours: 4))),
    ];
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  void _addEvent(String title, String type) {
    final newEvent = Event('$type: $title', _selectedDay!);
    setState(() {
      _selectedEvents.value.add(newEvent);
    });
  }

  void _showEventDetails(Event event) {
    showDialog(
      context: context,
      builder: (context) => EventDetailsPopup(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            child: SizedBox(
              width: double.infinity, // Make the AppBar take full width
              child: Container(
                color: Colors.amber,
                child: AppBar(
                  title: const Text('Calendar'),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  actions: [
                    PopupMenuButton<String>(
                      icon: Container(
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                        ),
                      ),
                      onSelected: (String result) async {
                        final String? title = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddEventScreen(),
                          ),
                        );
                        if (title != null) {
                          _addEvent(title, result);
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'Personal',
                          child: Text('Personal'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'Office',
                          child: Text('Office'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          TableCalendar<Event>(
            firstDay: DateTime.utc(2010, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _selectedEvents.value = _getEventsForDay(selectedDay);
              });
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
          ),
          // Add the yellow line
          Container(
            height: 4.0,
            color: Colors.amber,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
          ),
          Expanded(
            child: Row(
              children: [
                Column(
                  children: List.generate(4, (index) {
                    final hour = index + 7; // Start from 7 AM
                    final time = hour < 12 ? '$hour AM' : (hour == 12 ? '12 PM' : '${hour - 12} PM');
                    return Expanded(
                      child: Container(
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(
                          time,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: _selectedEvents.value.map((event) {
                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: _getEventColor(event.title),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: _getEventBorderColor(event.title)),
                          ),
                          child: ListTile(
                            onTap: () => _showEventDetails(event),
                            title: Text(
                              event.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.grey[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Meeting Onsite',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.grey[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  event.formattedTime,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                            trailing: SizedBox(
                              width: 50, // Adjusted width to fit 2 avatars plus text
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: List.generate(1, (index) {
                                  return const Padding(
                                    padding: EdgeInsets.only(left: 4.0),
                                    child: CircleAvatar(
                                      radius: 10,
                                      backgroundImage: AssetImage('assets/avatar_placeholder.png'),
                                    ),
                                  );
                                })..add(
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4.0),
                                      child: CircleAvatar(
                                        radius: 10,
                                        child: Text('+3', style: TextStyle(fontSize: 10)),
                                      ),
                                    ),
                                  ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getEventColor(String title) {
    if (title.contains('Sale Presentation')) {
      return Colors.green.withOpacity(0.3);
    } else if (title.contains('Pick up')) {
      return Colors.blue.withOpacity(0.3);
    } else if (title.contains('Japan Vendor')) {
      return Colors.orange.withOpacity(0.3);
    } else if (title.contains('Deadline')) {
      return Colors.red.withOpacity(0.3);
    } else {
      return Colors.grey.withOpacity(0.3);
    }
  }

  Color _getEventBorderColor(String title) {
    if (title.contains('Sale Presentation')) {
      return Colors.green;
    } else if (title.contains('Pick up')) {
      return Colors.blue;
    } else if (title.contains('Japan Vendor')) {
      return Colors.orange;
    } else if (title.contains('Deadline')) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }
}

class Event {
  final String title;
  final DateTime dateTime;

  Event(this.title, this.dateTime);

  String get formattedTime => DateFormat.jm().format(dateTime);

  @override
  String toString() => title;
}

class AddEventScreen extends StatelessWidget {
  const AddEventScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController _controller = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Event'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'Event Title'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, _controller.text);
              },
              child: const Text('Add Event'),
            ),
          ],
        ),
      ),
    );
  }
}
