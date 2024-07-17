import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/popups/EventDetailsPopup.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

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

  // Notification initialization
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();

    _selectedDay = _focusedDay;
    _events = ValueNotifier(_initializeEvents());

    // Initialize notification plugin
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Map<DateTime, List<Event>> _initializeEvents() {
    return {
      DateTime.now(): [
        Event('Sale Presentation: HI App production', DateTime.now().add(const Duration(hours: 1)), 'Meeting Onsite', 8),
        Event('Pick up from Hotel to Bank', DateTime.now().add(const Duration(hours: 2)), 'Travel', 4),
        Event('Japan Vendor', DateTime.now().add(const Duration(hours: 3)), 'Meeting Online', 6),
        Event('Deadline for HIAPP product', DateTime.now().add(const Duration(hours: 4)), 'Deadline', 2),
      ],
      DateTime.now().add(const Duration(days: 1)): [
        Event('Team Meeting', DateTime.now().add(const Duration(days: 1, hours: 1)), 'Meeting Onsite', 5),
        Event('Client Call', DateTime.now().add(const Duration(days: 1, hours: 2)), 'Call', 3),
      ],
      DateTime.now().add(const Duration(days: 2)): [
        Event('Project Deadline', DateTime.now().add(const Duration(days: 2, hours: 3)), 'Deadline', 1),
      ],
    };
  }

  List<Event> _getEventsForDay(DateTime day) {
    return _events.value[day] ?? [];
  }

  @override
  void dispose() {
    _events.dispose();
    super.dispose();
  }

  void _addEvent(String title, DateTime dateTime, String description, int attendees) {
    final newEvent = Event(title, dateTime, description, attendees);
    final eventsForDay = _getEventsForDay(_selectedDay!);
    setState(() {
      _events.value = {
        ..._events.value,
        _selectedDay!: [...eventsForDay, newEvent],
      };
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
      body: Stack(
        children: [
          // Positioned.fill(
          //   child: Image.asset(
          //     'assets/background.png',
          //     fit: BoxFit.cover,
          //   ),
          // ),
          Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
                child: Container(
                  width: double.infinity, // Make the AppBar take full width
                  height: MediaQuery.of(context).size.height * 0.1, // Make the ClipRRect larger
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/background.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: AppBar(
                    centerTitle: true, // Center the title
                    title: const Text('Calendar'),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    actions: [
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          size: 40, // Make the plus button bigger
                          color: Colors.green, // Color the plus button green
                        ),
                        onPressed: () async {
                          final newEvent = await Navigator.push<Event?>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddEventScreen(),
                            ),
                          );
                          if (newEvent != null) {
                            _addEvent(newEvent.title, newEvent.dateTime, newEvent.description, newEvent.attendees);
                          }
                        },
                      ),
                    ],
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
                calendarStyle: const CalendarStyle(
                  outsideDaysVisible: false,
                  markerDecoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.yellow,
                    shape: BoxShape.rectangle,
                  ),
                  defaultTextStyle: TextStyle(color: Colors.black),
                  weekendTextStyle: TextStyle(color: Colors.black),
                  todayTextStyle: TextStyle(color: Colors.black),
                  selectedTextStyle: TextStyle(color: Colors.black),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
              ),
              // Add the yellow line
              Container(
                height: 2.0,
                color: Colors.amber,
                margin: const EdgeInsets.symmetric(vertical: 4.0),
              ),
              Expanded(
                child: ValueListenableBuilder<Map<DateTime, List<Event>>>(
                  valueListenable: _events,
                  builder: (context, value, _) {
                    final events = _getEventsForDay(_selectedDay!);
                    return ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: _getEventColor(event.title),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16.0),
                              bottomRight: Radius.circular(16.0),
                              bottomLeft: Radius.circular(4.0),
                              topRight: Radius.circular(4.0),
                            ),
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
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: List.generate(event.attendees, (index) {
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 2.0),
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.primaries[index % Colors.primaries.length],
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: 16, color: Colors.grey[700]),
                                    const SizedBox(width: 4),
                                    Text(event.description, style: TextStyle(color: Colors.grey[700])),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 16, color: Colors.grey[700]),
                                    const SizedBox(width: 4),
                                    Text(event.formattedTime, style: TextStyle(color: Colors.grey[700])),
                                  ],
                                ),
                              ],
                            ),
                            trailing: event.attendees > 5
                                ? CircleAvatar(
                                    backgroundColor: Colors.grey,
                                    child: Text('+${event.attendees - 5}', style: TextStyle(color: Colors.white)),
                                  )
                                : null,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
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
  final String description;
  final int attendees;

  Event(this.title, this.dateTime, this.description, this.attendees);

  String get formattedTime => DateFormat.jm().format(dateTime);

  @override
  String toString() => title;
}

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  _AddEventScreenState createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedTime = DateTime.now();
  int _attendeesCount = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Event'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Event Title'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Event Description'),
            ),
            const SizedBox(height: 20),
            ListTile(
              title: Text('Time: ${DateFormat.jm().format(_selectedTime)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectTime,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Attendees:'),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    setState(() {
                      if (_attendeesCount > 1) {
                        _attendeesCount--;
                      }
                    });
                  },
                ),
                Text(_attendeesCount.toString()),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      _attendeesCount++;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final event = Event(_titleController.text, _selectedTime, _descriptionController.text, _attendeesCount);
                Navigator.pop(context, event);
              },
              child: const Text('Add Event'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime() async {
    final TimeOfDay? timeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedTime),
    );
    if (timeOfDay != null) {
      setState(() {
        _selectedTime = DateTime(
          _selectedTime.year,
          _selectedTime.month,
          _selectedTime.day,
          timeOfDay.hour,
          timeOfDay.minute,
        );
      });
    }
  }
}
