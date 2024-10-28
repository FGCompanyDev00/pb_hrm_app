import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/core/standard/color.dart';
import 'package:pb_hrsystem/core/widgets/timetable_day/timetable_day_veiw.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TimetablePage extends StatefulWidget {
  final DateTime date;
  // final List<TimetableItem> events;

  const TimetablePage({required this.date, super.key});

  @override
  TimetablePageState createState() => TimetablePageState();
}

class TimetablePageState extends State<TimetablePage> {
  late DateTime selectedDate = widget.date;
  List<TimetableItem> events = [];
  List<TimetableItem<String>> currentEvents = [];

  @override
  void initState() {
    super.initState();
    // events = widget.events;
    _fetchLeaveRequests(selectedDate);
  }

  Future<void> _fetchLeaveRequests(DateTime date) async {
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
        List<dynamic> results = json.decode(response.body)['results'];
        final List<TimetableItem<String>> fetchedEvents = [];
        results = results.where((e) {
          DateTime dateData = DateTime.parse(e['take_leave_from']);
          return dateData.day == selectedDate.day;
        }).toList();
        for (var item in results) {
          final DateTime startDate = item['take_leave_from'] != null ? DateTime.parse(item['take_leave_from']) : DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 8);
          final DateTime endDate = item['take_leave_to'] != null ? DateTime.parse(item['take_leave_to']) : DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 17);
          final DateTime updatedOn = item['updated_at'] != null ? DateTime.parse(item['updated_at']) : DateTime.parse(item['created_at']);
          final eventTitle = item['name'];
          final eventReason = item['take_leave_reason'] ?? 'Approval Pending';
          double eventDays = 0;

          if (item['days'].runtimeType == double) {
            eventDays = item['days'];
          }

          if (item['days'].runtimeType == int) {
            eventDays = double.parse(item['days'].toString());
          }

          // Create TimetableItems for each day of the event
          // if (startDate.hour > 0 && endDate.hour > 0) {
          for (var day = startDate; day.isBefore(endDate.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
            fetchedEvents.add(
              TimetableItem(
                id: item['take_leave_request_id'],
                value: item['pID'],
                title: eventTitle,
                reason: eventReason,
                name: item['requestor_name'],
                updatedOn: updatedOn,
                leaveTypeID: item['leave_type_id'],
                days: eventDays.toDouble(),
                start: DateTime(day.year, day.month, day.day, 12, 0),
                end: DateTime(day.year, day.month, day.day, 15, 0),
                category: 'AL',
                status: item['is_approve'],
              ),
            );
          }
          // }
        }

        setState(() {
          currentEvents = fetchedEvents;
        });
      } else {
        _showErrorDialog('Failed to Load Leave Requests', 'Server returned status code: ${response.statusCode}. Message: ${response.reasonPhrase}');
      }
    } catch (e) {
      _showErrorDialog('Error Fetching Leave Requests', 'An unexpected error occurred: $e');
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
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Detail Calendar Event',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        toolbarHeight: 80,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 10.0,
              horizontal: 25,
            ),
            child: Text(
              DateFormat('y MMMM').format(selectedDate),
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (index) {
                final day = selectedDate.add(Duration(days: index - 3));
                final hasEvent = events.any((event) => event.start.day == day.day && event.start.month == day.month && event.start.year == day.year);
                return _buildDateItem(
                  DateFormat.E().format(day),
                  day.day,
                  isSelected: day.day == selectedDate.day,
                  hasEvent: hasEvent,
                  onTap: () {
                    setState(() {
                      selectedDate = day;
                      _fetchLeaveRequests(selectedDate);
                    });
                  },
                );
              }),
            ),
          ),
          Container(
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: ColorStandardization().colorDarkGold,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Colors.grey,
                  spreadRadius: 1.0,
                  blurRadius: 5.0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          TimeTableDayWidget(
            eventsTimeTable: currentEvents,
            selectedDay: selectedDate,
          ),
          // Expanded(
          //   child: ListView(
          //     padding: const EdgeInsets.symmetric(horizontal: 16),
          //     children: _buildEventSlotsForDay(selectedDate),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildDateItem(String day, int date, {bool isSelected = false, bool hasEvent = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 12,
        ),
        width: 45,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD4A017)
              : hasEvent
                  ? Colors.green.withOpacity(0.5)
                  : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              day.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "$date",
              style: TextStyle(
                fontSize: 16,
                color: isSelected || hasEvent ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
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
              time,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: event != null && event.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // List<Widget> _buildEventSlotsForDay(DateTime date) {
  //   final List<Widget> slots = [];
  //   final eventsForDay = events.where((event) => event.start.day == date.day && event.start.month == date.month && event.start.year == date.year).toList();

  //   for (var i = 7; i < 16; i++) {
  //     final String timeLabel = "${i.toString().padLeft(2, '0')}:00";
  //     final matchingEvent = eventsForDay.firstWhere(
  //       (event) => event.start.hour == i,
  //       orElse: () => TimetableItem<String>(
  //         DateTime(date.year, date.month, date.day, i),
  //         DateTime(date.year, date.month, date.day, i + 1),
  //         data: "",
  //       ),
  //     );

  //     String eventTitle = matchingEvent.data ?? "";

  //     if (eventTitle.isNotEmpty) {
  //       slots.add(_buildTimeSlot(timeLabel, event: eventTitle));
  //     } else {
  //       slots.add(_buildTimeSlot(timeLabel));
  //     }
  //   }

  //   return slots;
  // }
}
