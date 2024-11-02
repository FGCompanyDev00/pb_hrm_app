import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/core/standard/color.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/core/standard/extension.dart';
import 'package:pb_hrsystem/core/widgets/snackbar/snackbar.dart';
import 'package:pb_hrsystem/core/widgets/timetable_day/timetable_day_veiw.dart';
import 'package:pb_hrsystem/services/http_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TimetablePage extends StatefulWidget {
  final DateTime date;

  const TimetablePage({
    super.key,
    required this.date,
  });

  @override
  TimetablePageState createState() => TimetablePageState();
}

class TimetablePageState extends State<TimetablePage> {
  late final ValueNotifier<Map<DateTime, List<TimetableItem>>> _eventTime;

  late DateTime selectedDate = widget.date;
  List<TimetableItem> events = [];
  List<TimetableItem> currentEvents = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _eventTime = ValueNotifier({});
    fetchData();
  }

  void addEvent(DateTime date, TimetableItem event) {
    final detectDate = normalizeDate(date);
    if (_eventTime.value.containsKey(detectDate)) {
      // If the date already has events, add to the list
      _eventTime.value[detectDate]!.add(event);
    } else {
      // Otherwise, create a new list with this event
      _eventTime.value[detectDate] = [event];
    }
  }

  /// Filters and searches events based on selected category and search query
  void filterDate() {
    List<TimetableItem>? dayEvents = _getEventsForDay(selectedDate);

    setState(() {
      currentEvents = dayEvents;
    });
  }

  /// Retrieves events for a specific day
  List<TimetableItem> _getEventsForDay(DateTime day) {
    final normalizedDay = normalizeDate(day);
    return _eventTime.value[normalizedDay] ?? [];
  }

  /// Fetches all required data concurrently
  Future<void> fetchData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await Future.wait([
        fetchMeetingData(),
        fetchLeaveRequests(),
        fetchMeetingRoomBookings(),
        fetchCarBookings(),
        fetchMinutesOfMeeting(),
      ]).whenComplete(() => filterDate());
    } catch (e) {
      showSnackBar('Error fetching data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Fetches meeting data from the API
  Future<void> fetchMeetingData() async {
    final response = await getRequest('/api/work-tracking/meeting/get-all-meeting');
    if (response == null) return;

    try {
      final data = json.decode(response.body);

      if (data == null || data['results'] == null || data['results'] is! List) {
        showSnackBar('Invalid meeting data format.');
        return;
      }

      final List<dynamic> results = data['results'];

      for (var item in results) {
        // Ensure necessary fields are present
        if (item['from_date'] == null || item['to_date'] == null || item['start_time'] == null || item['end_time'] == null) {
          showSnackBar('Missing date or time fields in meeting data.');
          continue;
        }

        // Combine 'from_date' with 'start_time' and 'to_date' with 'end_time'
        DateTime startDateTime;
        DateTime endDateTime;

        try {
          // Parse 'from_date' and 'start_time' separately and combine
          DateTime fromDate = DateTime.parse(item['from_date']);
          List<String> startTimeParts = item['start_time'] != "" ? item['start_time'].split(':') : ["00", "00"];
          if (startTimeParts.length != 2) {
            throw const FormatException('Invalid start_time format');
          }
          startDateTime = DateTime(
            fromDate.year,
            fromDate.month,
            fromDate.day,
            int.parse(startTimeParts[0]),
            int.parse(startTimeParts[1]),
          );

          // Parse 'to_date' and 'end_time' separately and combine
          DateTime toDate = DateTime.parse(item['to_date']);
          List<String> endTimeParts = item['end_time'] != "" ? item['end_time'].split(':') : ["00", "00"];
          if (endTimeParts.length != 2) {
            throw const FormatException('Invalid end_time format');
          }
          endDateTime = DateTime(
            toDate.year,
            toDate.month,
            toDate.day,
            int.parse(endTimeParts[0]),
            int.parse(endTimeParts[1]),
          );
        } catch (e) {
          showSnackBar('Error parsing meeting dates or times: $e');
          continue;
        }

        // Handle possible nulls with default values
        final String uid = item['meeting_id']?.toString() ?? UniqueKey().toString();
        final DateTime createdOn = DateTime.parse(item['created_at']);

        String status = item['s_name'] != null ? mapEventStatus(item['s_name'].toString()) : 'Pending';

        if (status == 'Cancelled') continue;

        final event = TimetableItem(
          title: item['title'] ?? 'Add Meeting',
          start: startDateTime,
          end: endDateTime,
          desc: item['description'] ?? '',
          status: status,
          location: item['location'] ?? '', // Assuming 'location' field exists
          createdBy: item['create_by'] ?? '',
          imgName: item['file_name'] ?? '',
          createdAt: createdOn,
          uid: uid,
          isRepeat: item['is_repeat']?.toString(),
          videoConference: item['video_conference']?.toString(),
          backgroundColor: item['backgroundColor'] != null ? parseColor(item['backgroundColor']) : Colors.blue,
          outmeetingUid: item['meeting_id']?.toString(),
          category: 'Add Meeting',
          members: item['members'] != null ? List<Map<String, dynamic>>.from(item['members']) : [],
        );

        // Normalize the start and end dates for event mapping
        final normalizedStartDay = normalizeDate(startDateTime);
        final normalizedEndDay = normalizeDate(endDateTime);

        for (var day = normalizedStartDay; !day.isAfter(normalizedEndDay); day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar('Error parsing meeting data: $e');
    }

    return;
  }

  Future<void> fetchLeaveRequests() async {
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
        results = results.where((e) {
          DateTime dateData = DateTime.parse(e['take_leave_from']);
          return dateData.day == selectedDate.day;
        }).toList();
        for (var item in results) {
          final responseType = await getRequest('/api/leave-type/${item['leave_type_id']}');
          final List<dynamic> resultType = json.decode(responseType!.body)['results'];

          final DateTime updatedOn = item['updated_at'] != null ? DateTime.parse(item['updated_at']) : DateTime.parse(item['created_at']);
          final eventTitle = item['name'];
          final eventReason = item['take_leave_reason'] ?? 'Approval Pending';
          final String? leaveType = resultType.firstOrNull['name'];
          double eventDays = 0;

          if (item['days'].runtimeType == double) {
            eventDays = item['days'];
          }

          if (item['days'].runtimeType == int) {
            eventDays = double.parse(item['days'].toString());
          }

          // Create TimetableItems for each day of the event
          // if (startDate.hour > 0 && endDate.hour > 0) {

          final convertData = TimetableItem(
            id: item['take_leave_request_id'],
            uid: item['pID'],
            title: eventTitle,
            reason: eventReason,
            name: item['requestor_name'],
            createdAt: updatedOn,
            leaveTypeID: item['leave_type_id'],
            days: eventDays.toDouble(),
            start: DateTime.utc(selectedDate.year, selectedDate.month, selectedDate.day, 8, 0),
            end: DateTime.utc(selectedDate.year, selectedDate.month, selectedDate.day, 17, 0),
            category: 'Leave',
            status: item['is_approve'],
            leaveType: leaveType,
          );

          addEvent(
              DateTime.utc(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                8,
                0,
              ),
              convertData);
        }
      } else {
        _showErrorDialog('Failed to Load Leave Requests', 'Server returned status code: ${response.statusCode}. Message: ${response.reasonPhrase}');
      }
    } catch (e) {
      _showErrorDialog('Error Fetching Leave Requests', 'An unexpected error occurred: $e');
    }
  }

  /// Fetches meeting room bookings from the API
  Future<void> fetchMeetingRoomBookings() async {
    final response = await getRequest('/api/office-administration/book_meeting_room/my-requests');
    if (response == null) return;

    try {
      final List<dynamic> results = json.decode(response.body)['results'] ?? [];
      final meetingRoomBookings = List<Map<String, dynamic>>.from(results);

      for (var item in meetingRoomBookings) {
        final DateTime? startDateTime = item['from_date_time'] != null ? DateTime.parse(item['from_date_time']) : null;
        final DateTime? endDateTime = item['to_date_time'] != null ? DateTime.parse(item['to_date_time']) : null;

        if (startDateTime == null || endDateTime == null) {
          showSnackBar('Missing from_date_time or to_date_time in meeting room booking.');
          continue;
        }

        final String uid = item['uid']?.toString() ?? UniqueKey().toString();
        final DateTime? createdOn = DateTime.parse(item['date_create']);

        String status = item['status'] != null ? mapEventStatus(item['status'].toString()) : 'Pending';

        if (status == 'Cancelled') continue;

        final event = TimetableItem(
          title: item['title'] ?? 'Meeting Room Bookings',
          start: startDateTime,
          end: endDateTime,
          desc: item['remark'] ?? 'Booking Pending',
          status: status,
          category: 'Meeting Room Bookings',
          uid: uid,
          imgName: item['img_name'],
          createdBy: item['employee_name'],
          createdAt: createdOn,
          location: item['room_name'] ?? 'Meeting Room',
          members: item['members'] != null ? List<Map<String, dynamic>>.from(item['members']) : [],
        );

        for (var day = normalizeDate(startDateTime); !day.isAfter(normalizeDate(endDateTime)); day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar('Error parsing meeting room bookings: $e');
    }
    return;
  }

  /// Fetches car bookings from the API
  Future<void> fetchCarBookings() async {
    final response = await getRequest('/api/office-administration/car_permits/me');
    if (response == null) return;

    try {
      final List<dynamic> results = json.decode(response.body)['results'] ?? [];
      final carBookings = List<Map<String, dynamic>>.from(results);

      for (var item in carBookings) {
        if (item['date_out'] == null || item['date_in'] == null) {
          showSnackBar('Missing date_out or date_in in car booking.');
          continue;
        }

        String dateOutStr = formatDateString(item['date_out'].toString());
        String dateInStr = formatDateString(item['date_in'].toString());
        String timeOutStr = item['time_out']?.toString() ?? '00:00';
        String timeInStr = item['time_in']?.toString() ?? '23:59';

        DateTime? startDateTime;
        DateTime? endDateTime;

        try {
          // Combine date and time properly
          DateTime outDate = DateTime.parse(dateOutStr);
          List<String> timeOutParts = timeOutStr.split(':');
          if (timeOutParts.length != 2) {
            throw const FormatException('Invalid time_out format');
          }
          startDateTime = DateTime(
            outDate.year,
            outDate.month,
            outDate.day,
            int.parse(timeOutParts[0]),
            int.parse(timeOutParts[1]),
          );

          DateTime inDate = DateTime.parse(dateInStr);
          List<String> timeInParts = timeInStr.split(':');
          if (timeInParts.length != 2) {
            throw const FormatException('Invalid time_in format');
          }
          endDateTime = DateTime(
            inDate.year,
            inDate.month,
            inDate.day,
            int.parse(timeInParts[0]),
            int.parse(timeInParts[1]),
          );
        } catch (e) {
          showSnackBar('Error parsing car booking dates: $e');
          continue;
        }

        final String uid = 'car_${item['uid']?.toString() ?? UniqueKey().toString()}';

        String status = item['status'] != null ? mapEventStatus(item['status'].toString()) : 'Pending';

        if (status == 'Cancelled') continue;

        final DateTime createdOn = DateTime.parse(item['updated_at']);

        final event = TimetableItem(
          title: item['purpose'] ?? 'No Title',
          start: startDateTime,
          end: endDateTime,
          desc: item['place'] ?? 'Car Booking Pending',
          status: status,
          category: 'Booking Car',
          uid: uid,
          location: item['place'] ?? '',
          imgName: item['img_name'],
          createdBy: item['requestor_name'],
          createdAt: createdOn,
        );

        for (var day = normalizeDate(startDateTime); !day.isAfter(normalizeDate(endDateTime)); day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar('Error parsing booking car: $e');
    }
    return;
  }

  /// Fetches meeting room bookings from the API
  Future<void> fetchMinutesOfMeeting() async {
    final response = await getRequest('/api/work-tracking/meeting/assignment/my-metting');
    if (response == null) return;

    try {
      final List<dynamic> results = json.decode(response.body)['results'] ?? [];
      final minutesMeeting = List<Map<String, dynamic>>.from(results);

      for (var item in minutesMeeting) {
        // final DateTime? startDateTime = item['from_date'] != null ? DateTime.parse(item['from_date']) : null;
        // final DateTime? endDateTime = item['to_date'] != null ? DateTime.parse(item['to_date']) : null;
        final responseMembers = await getRequest('/api/work-tracking/meeting/get-meeting/${item['meeting_uid']}');
        final List<dynamic> resultMembers = json.decode(responseMembers!.body)['result'];
        String dateFrom = formatDateString(item['from_date'].toString());
        String dateTo = formatDateString(item['to_date'].toString());
        String startTime = item['start_time'] != "" ? item['start_time'].toString() : '00:00';
        String endTime = item['end_time'] != "" ? item['end_time'].toString() : '23:59';

        if (dateFrom.isEmpty || dateTo.isEmpty) {
          showSnackBar('Missing from_date or to_date in minutes of meeting.');
          continue;
        }

        DateTime? startDateTime;
        DateTime? endDateTime;

        try {
          // Combine date and time properly
          DateTime fromDate = DateTime.parse(dateFrom);
          List<String> timeOutParts = startTime.split(':');
          if (timeOutParts.length != 2) {
            throw const FormatException('Invalid time_out format');
          }
          startDateTime = DateTime(
            fromDate.year,
            fromDate.month,
            fromDate.day,
            int.parse(timeOutParts[0]),
            int.parse(timeOutParts[1]),
          );

          DateTime inDate = DateTime.parse(dateTo);
          List<String> timeInParts = endTime.split(':');
          if (timeInParts.length != 2) {
            throw const FormatException('Invalid time_in format');
          }
          endDateTime = DateTime(
            inDate.year,
            inDate.month,
            inDate.day,
            int.parse(timeInParts[0]),
            int.parse(timeInParts[1]),
          );
        } catch (e) {
          showSnackBar('Error parsing car booking dates: $e');
          continue;
        }

        final String uid = item['project_id']?.toString() ?? UniqueKey().toString();

        String status = item['statuss'] != null
            ? item['statuss'] == 1
            ? 'Success'
            : 'Pending'
            : 'Pending';

        if (status == 'Cancelled') continue;

        final DateTime createdOn = DateTime.parse(item['updated_at']);

        final event = TimetableItem(
          title: item['project_name'] ?? 'Minutes Of Meeting',
          start: startDateTime,
          end: endDateTime,
          desc: item['descriptions'] ?? 'Minutes Of Meeting Pending',
          status: status,
          category: 'Minutes Of Meeting',
          uid: uid,
          imgName: item['img_name'],
          // members:  List<Map<String, dynamic>>.from(resultMembers),
          createdAt: createdOn,
        );

        for (var day = normalizeDate(startDateTime); !day.isAfter(normalizeDate(endDateTime)); day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar('Error parsing meeting room bookings: $e');
    }
    return;
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
        flexibleSpace: Stack(
          children: [
            Container(
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
            if (_isLoading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: 10,
                  child: const LinearProgressIndicator(),
                ),
              ),
          ],
        ),

        // 'Detail Calendar Event'
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.detailCalendarEvent,
          style: const TextStyle(
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
                      fetchData();
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
}