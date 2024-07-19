import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/popups/EventDetailsPopup.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';

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

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _events = ValueNotifier(_initializeEvents());

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
        Event(
            'Sale Presentation: HI App production',
            DateTime.now().add(const Duration(hours: 1)),
            DateTime.now().add(const Duration(hours: 2)),
            'Meeting Onsite',
            8),
        Event('Pick up from Hotel to Bank', DateTime.now().add(const Duration(hours: 2)),
            DateTime.now().add(const Duration(hours: 3)), 'Travel', 4),
        Event('Japan Vendor', DateTime.now().add(const Duration(hours: 3)),
            DateTime.now().add(const Duration(hours: 4)), 'Meeting Online', 6),
        Event('Deadline for HIAPP product', DateTime.now().add(const Duration(hours: 4)),
            DateTime.now().add(const Duration(hours: 5)), 'Deadline', 2),
      ],
      DateTime.now().add(const Duration(days: 1)): [
        Event('Team Meeting', DateTime.now().add(const Duration(days: 1, hours: 1)),
            DateTime.now().add(const Duration(days: 1, hours: 2)), 'Meeting Onsite', 5),
        Event('Client Call', DateTime.now().add(const Duration(days: 1, hours: 2)),
            DateTime.now().add(const Duration(days: 1, hours: 3)), 'Call', 3),
      ],
      DateTime.now().add(const Duration(days: 2)): [
        Event('Project Deadline', DateTime.now().add(const Duration(days: 2, hours: 3)),
            DateTime.now().add(const Duration(days: 2, hours: 4)), 'Deadline', 1),
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

  void _addEvent(String title, DateTime startDateTime, DateTime endDateTime, String description, int attendees) {
    final newEvent = Event(title, startDateTime, endDateTime, description, attendees);
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

  void _showAddEventOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Personal'),
              onTap: () {
                Navigator.pop(context);
                _navigateToAddEvent('Personal');
              },
            ),
            ListTile(
              leading: const Icon(Icons.work),
              title: const Text('Office'),
              onTap: () {
                Navigator.pop(context);
                _navigateToAddEvent('Office');
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToAddEvent(String eventType) async {
    final newEvent = await Navigator.push<Event?>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEventScreen(eventType: eventType),
      ),
    );
    if (newEvent != null) {
      _addEvent(newEvent.title, newEvent.startDateTime, newEvent.endDateTime, newEvent.description, newEvent.attendees);
    }
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
                    bottomLeft: Radius.circular(50),
                    bottomRight: Radius.circular(50),
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
                        onPressed: _showAddEventOptions,
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
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    markerDecoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    selectedDecoration: BoxDecoration(
                      color: isDarkMode ? Colors.orange : Colors.yellow,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    defaultTextStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                    weekendTextStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                    todayTextStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                    selectedTextStyle: TextStyle(color: isDarkMode ? Colors.black : Colors.white),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    leftChevronIcon: Icon(
                      Icons.chevron_left,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isNotEmpty) {
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            height: 4.0,
                            color: Colors.green,
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
                          return CustomEventBox(event: event, isDarkMode: isDarkMode);
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
}

class Event {
  final String title;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String description;
  final int attendees;

  Event(this.title, this.startDateTime, this.endDateTime, this.description, this.attendees);

  String get formattedTime => DateFormat.jm().format(startDateTime);

  @override
  String toString() => title;
}

class AddEventScreen extends StatefulWidget {
  final String eventType;
  const AddEventScreen({required this.eventType, super.key});

  @override
  _AddEventScreenState createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _startDateTime = DateTime.now();
  DateTime _endDateTime = DateTime.now();
  int _attendeesCount = 1;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Center(child: Text('Add ${widget.eventType} Event')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: brightness == Brightness.dark ? Colors.white : Colors.black),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/background.png',
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: kToolbarHeight + 20),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Event Title',
                      labelStyle: TextStyle(color: brightness == Brightness.dark ? Colors.white : Colors.black),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: brightness == Brightness.dark ? Colors.black45 : Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Event Description',
                      labelStyle: TextStyle(color: brightness == Brightness.dark ? Colors.white : Colors.black),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: brightness == Brightness.dark ? Colors.black45 : Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    title: Text(
                      'Start: ${DateFormat.yMd().add_jm().format(_startDateTime)}',
                      style: TextStyle(color: brightness == Brightness.dark ? Colors.white : Colors.black),
                    ),
                    trailing: const Icon(Icons.calendar_today, color: Colors.black),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDateTime,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_startDateTime),
                        );
                        if (time != null) {
                          setState(() {
                            _startDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                          });
                        }
                      }
                    },
                  ),
                  ListTile(
                    title: Text(
                      'End: ${DateFormat.yMd().add_jm().format(_endDateTime)}',
                      style: TextStyle(color: brightness == Brightness.dark ? Colors.white : Colors.black),
                    ),
                    trailing: const Icon(Icons.calendar_today, color: Colors.black),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDateTime,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_endDateTime),
                        );
                        if (time != null) {
                          setState(() {
                            _endDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Duration: ${_endDateTime.difference(_startDateTime).inDays} days',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: brightness == Brightness.dark ? Colors.white : Colors.black),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text('Attendees:', style: TextStyle(color: brightness == Brightness.dark ? Colors.white : Colors.black)),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: Icon(Icons.remove, color: brightness == Brightness.dark ? Colors.white : Colors.black),
                        onPressed: () {
                          setState(() {
                            if (_attendeesCount > 1) {
                              _attendeesCount--;
                            }
                          });
                        },
                      ),
                      Text(_attendeesCount.toString(), style: TextStyle(color: brightness == Brightness.dark ? Colors.white : Colors.black)),
                      IconButton(
                        icon: Icon(Icons.add, color: brightness == Brightness.dark ? Colors.white : Colors.black),
                        onPressed: () {
                          setState(() {
                            _attendeesCount++;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final event = Event(
                          _titleController.text,
                          _startDateTime,
                          _endDateTime,
                          _descriptionController.text,
                          _attendeesCount,
                        );
                        Navigator.pop(context, event);
                      },
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.yellow, Colors.orange],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: double.infinity, minHeight: 50.0),
                          alignment: Alignment.center,
                          child: const Text(
                            'Add Event',
                            style: TextStyle(fontSize: 16, color: Colors.black),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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
          color: event.attendees > 5 ? Colors.red : Colors.green,
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
                event.attendees > 10 ? 10 : event.attendees,
                    (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2.0),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.green,
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
            if (event.attendees > 10)
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Text(
                  '+${event.attendees - 10}',
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                ),
              ),
          ],
        ),
        trailing: event.attendees > 10
            ? CircleAvatar(
          backgroundColor: Colors.grey,
          child: Text('+${event.attendees - 10}', style: const TextStyle(color: Colors.black)),
        )
            : null,
      ),
    );
  }
}
