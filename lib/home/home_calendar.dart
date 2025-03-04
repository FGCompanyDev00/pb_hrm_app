import 'dart:convert';
import 'dart:async';
import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart';
import 'package:pb_hrsystem/core/standard/color.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/core/standard/extension.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/core/widgets/calendar_day/calendar_day_switch_view.dart';
import 'package:pb_hrsystem/core/widgets/snackbar/snackbar.dart';
import 'package:pb_hrsystem/home/office_events/office_add_event.dart';
import 'package:pb_hrsystem/home/timetable_page.dart';
import 'package:pb_hrsystem/login/date.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:pb_hrsystem/services/http_service.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:pb_hrsystem/home/leave_request_page.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

abstract class Refreshable {
  void refresh();
}

class HomeCalendar extends StatefulWidget {
  const HomeCalendar({super.key});

  @override
  HomeCalendarState createState() => HomeCalendarState();
}

class HomeCalendarState extends State<HomeCalendar>
    with TickerProviderStateMixin
    implements Refreshable {
  late Box eventsBox;

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  // ValueNotifier to hold events mapped by date
  final selectedSlot = ValueNotifier(1);
  final switchTime = ValueNotifier(false);

  // Calendar properties
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now().toLocal();
  DateTime? _selectedDay;
  DateTime? _singleTapSelectedDay;

  // Notifications
  late final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  // Filters and Search
  final String _selectedCategory = 'All';
  final String _searchQuery = '';

  // Animation Controller
  late final AnimationController _animationController;

  // Double Tap Timer
  Timer? _doubleTapTimer;
  static const int doubleTapDelay = 300;

  // Loading State
  bool _isLoading = false;

  // Add at the top of the class after other variables
  final _eventCountsCache = <DateTime, Map<String, int>>{};
  final _processedEventsCache = <DateTime, List<Events>>{};

  @override
  void initState() {
    super.initState();
    fetchData();
    _selectedDay = _focusedDay;
    switchTime.value =
        (_focusedDay.hour < 18 && _focusedDay.hour > 6) ? false : true;

    eventsForDay = [];
    eventsForAll = [];

    // Initialize Animation Controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Clear cache when connectivity changes
    connectivityResult.onConnectivityChanged.listen((source) async {
      _eventCountsCache.clear();
      _processedEventsCache.clear();
      if (source.contains(ConnectivityResult.none)) {
        eventsForDay = await offlineProvider.getCalendar();
        if (events.value.isEmpty) addEventOffline(eventsForDay);
      } else {
        fetchData();
      }
    });
  }

  @override
  void dispose() {
    _eventCountsCache.clear();
    _processedEventsCache.clear();
    events.dispose();
    _animationController.dispose();
    _doubleTapTimer?.cancel();
    super.dispose();
  }

  void addEvent(DateTime date, Events event) {
    if (date.year == _selectedDay?.year) {
      eventsForAll.add(event);
    }

    final detectDate = normalizeDate(date);
    if (events.value.containsKey(detectDate)) {
      // If the date already has events, add to the list
      if (events.value[detectDate]!
          .where((desc) => desc.desc == event.desc)
          .isEmpty) {
        events.value[detectDate]!.add(event);
      } else {
        event.members?.forEach(
          (e) => events.value[detectDate]!
              .where((desc) => desc.desc == event.desc)
              .first
              .members
              ?.add(e),
        );
      }
    } else {
      // Otherwise, create a new list with this event
      events.value[detectDate] = [event];
    }
  }

  void addEventOffline(List<Events> eventOffline) {
    for (var i in eventOffline) {
      final normalizedStartDay = normalizeDate(i.start);
      final normalizedEndDay = normalizeDate(i.end);

      for (var day = normalizedStartDay;
          !day.isAfter(normalizedEndDay);
          day = day.add(const Duration(days: 1))) {
        final detectDate = normalizeDate(day);

        if (events.value.containsKey(detectDate)) {
          // If the date already has events, add to the list
          if (events.value[detectDate]!
              .where((desc) => desc.desc == i.desc)
              .isEmpty) {
            events.value[detectDate]!.add(i);
          } else {
            i.members?.forEach(
              (e) => events.value[detectDate]!
                  .where((desc) => desc.desc == i.desc)
                  .first
                  .members
                  ?.add(e),
            );
          }
        } else {
          // Otherwise, create a new list with this event
          events.value[detectDate] = [i];
        }
      }
    }
    _eventsOffline();
  }

  /// Fetches all required data concurrently
  Future<void> fetchData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await Future.wait([
        _fetchMeetingData(),
        _fetchLeaveRequests(),
        _fetchMeetingRoomBookings(),
        _fetchMeetingRoomInvite(),
        _fetchCarBookings(),
        _fetchCarBookingsInvite(),
        _fetchMinutesOfMeeting(),
        _fetchMeetingMembers(),
      ]);
    } catch (e) {
      showSnackBar('Network Error');
    } finally {
      setState(() {
        _isLoading = false;
      });
      _filterAndSearchEvents();
    }
  }

  /// Fetches all required data concurrently
  Future<void> fetchDataPass() async {
    try {
      await Future.wait([
        _fetchMeetingData(),
        _fetchLeaveRequests(),
        _fetchMeetingRoomBookings(),
        _fetchMeetingRoomInvite(),
        _fetchCarBookings(),
        _fetchCarBookingsInvite(),
        _fetchMinutesOfMeeting(),
        _fetchMeetingMembers(),
      ]);
    } catch (e) {
      showSnackBar('Network Error');
    } finally {}
  }

  @override
  void refresh() async {
    await fetchDataPass(); // Refresh data when triggered from the bottom navigation bar
  }

  /// Fetches leave requests from the API
  Future<void> _fetchLeaveRequests() async {
    final response = await getRequest('/api/leave_requests');
    if (response == null) return;

    try {
      final List<dynamic> results = json.decode(response.body)['results'];
      final leaveRequests = List<Map<String, dynamic>>.from(results);
      // List<dynamic> resultType;
      String? leaveType;
      for (var item in leaveRequests) {
        // final responseType = await getRequest(context, '/api/leave-type/${item['leave_type_id']}');
        // if (responseType != null) {
        //   resultType = json.decode(responseType.body)['results'];
        //   leaveType = resultType.firstOrNull['name'];
        // }

        final DateTime startDate = item['take_leave_from'] != null
            ? normalizeDate(DateTime.parse(item['take_leave_from']))
            : normalizeDate(DateTime.now());
        final DateTime endDate = item['take_leave_to'] != null
            ? normalizeDate(DateTime.parse(item['take_leave_to']))
            : normalizeDate(DateTime.now());
        final String uid = 'leave_${item['id']}';
        double days;

        if (item['days'].runtimeType == int) {
          days = double.parse(item['days'].toString());
        } else {
          days = item['days'];
        }

        String status = item['is_approve'] != null
            ? _mapLeaveStatus(item['is_approve'].toString())
            : 'Pending';

        if (status == 'Cancelled') continue;

        final event = Events(
          title: item['name'] ?? 'Leave',
          start: startDate,
          end: endDate,
          desc: item['take_leave_reason'] ?? 'Approval Pending',
          status: status,
          isMeeting: false,
          category: 'Leave',
          uid: uid,
          imgName: item['img_name'],
          createdAt: item['updated_at'],
          createdBy: item['requestor_id'],
          days: days,
          leaveType: leaveType,
        );

        for (var day = startDate;
            day.isBefore(endDate.add(const Duration(days: 1)));
            day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {}
  }

  /// Maps API leave status to human-readable status
  String _mapLeaveStatus(String apiStatus) {
    switch (apiStatus.toLowerCase()) {
      case 'approved':
        return 'Approved';
      case 'waiting':
      case 'processing':
        return 'Pending';
      case 'cancel':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  /// Fetches meeting data from the API
  Future<void> _fetchMinutesOfMeeting() async {
    final response =
        await getRequest('/api/work-tracking/meeting/get-all-meeting');
    if (response == null) return;

    try {
      final data = json.decode(response.body);

      if (data == null || data['results'] == null || data['results'] is! List) {
        return;
      }

      final List<dynamic> results = data['results'];

      for (var item in results) {
        // Ensure necessary fields are present
        if (item['from_date'] == null ||
            item['to_date'] == null ||
            item['start_time'] == null ||
            item['end_time'] == null) {
          showSnackBar('Missing date or time fields in meeting data.');
          continue;
        }

        final responseMember = await getRequest(
            '/api/work-tracking/meeting/Meetig-Member/${item['id']}');

        dynamic dataMember;
        List<dynamic> resultsMember = [];
        if (responseMember != null) {
          dataMember = json.decode(responseMember.body);
          resultsMember = dataMember['results'] ?? [];
        }

        // Filter duplicates by employee_id for meeting members
        final seenEmployeeIds = <dynamic>{};
        final uniqueMembers = <Map<String, dynamic>>[];

        for (var member in resultsMember) {
          if (member['employee_id'] != null &&
              !seenEmployeeIds.contains(member['employee_id'])) {
            seenEmployeeIds.add(member['employee_id']);
            uniqueMembers.add(Map<String, dynamic>.from(member));
          }
        }

        // Combine 'from_date' with 'start_time' and 'to_date' with 'end_time'
        DateTime startDateTime;
        DateTime endDateTime;
        try {
          // Parse 'from_date' and 'start_time' separately and combine
          DateTime fromDate = DateTime.parse(item['from_date']);
          List<String> startTimeParts = item['start_time'] != ""
              ? item['start_time'].split(':')
              : ["00", "00"];
          if (startTimeParts.length == 3) startTimeParts.removeLast();
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
          List<String> endTimeParts = item['end_time'] != ""
              ? item['end_time'].split(':')
              : ["00", "00"];
          if (endTimeParts.length == 3) endTimeParts.removeLast();
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

        final String uid =
            item['meeting_id']?.toString() ?? UniqueKey().toString();
        String status = item['s_name'] != null
            ? mapEventStatus(item['s_name'].toString())
            : 'Pending';
        if (status == 'Cancelled') continue;

        final event = Events(
          title: item['title'] ?? 'Minutes Of Meeting',
          start: startDateTime,
          end: endDateTime,
          desc: item['description'] ?? '',
          status: status,
          isMeeting: true,
          location: item['location'] ?? '',
          createdBy: item['create_by'] ?? '',
          createdAt: item['created_at'] ?? '',
          uid: uid,
          isRepeat: item['is_repeat']?.toString(),
          videoConference: item['video_conference']?.toString(),
          backgroundColor: item['backgroundColor'] != null
              ? parseColor(item['backgroundColor'])
              : Colors.blue,
          outmeetingUid: item['meeting_id']?.toString(),
          category: 'Minutes Of Meeting',
          fileName: item['file_name'],
          members: uniqueMembers, // Use filtered unique members list
        );

        // Normalize the start and end dates for event mapping
        final normalizedStartDay = normalizeDate(startDateTime);
        final normalizedEndDay = normalizeDate(endDateTime);

        for (var day = normalizedStartDay;
            !day.isAfter(normalizedEndDay);
            day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar('Data Error');
    }
  }

  /// Fetches meeting out data from the API
  Future<void> _fetchMeetingData() async {
    final response =
        await getRequest('/api/work-tracking/out-meeting/out-meeting');
    if (response == null) return;

    try {
      final data = json.decode(response.body);

      if (data == null || data['results'] == null || data['results'] is! List) {
        return;
      }

      final List<dynamic> results = data['results'];

      for (var item in results) {
        // Ensure necessary fields are present
        if (item['fromdate'] == null || item['todate'] == null) {
          showSnackBar('Missing date or time fields in meeting data.');
          continue;
        }

        // Combine 'from_date' with 'start_time' and 'to_date' with 'end_time'
        DateTime startDateTime;
        DateTime endDateTime;
        try {
          // Parse 'from_date' and 'start_time' separately and combine
          DateTime fromDate = DateTime.parse(item['fromdate']);

          startDateTime = DateTime(
            fromDate.year,
            fromDate.month,
            fromDate.day,
            fromDate.hour,
            fromDate.minute,
          );

          // Parse 'to_date' and 'end_time' separately and combine
          DateTime toDate = DateTime.parse(item['todate']);
          endDateTime = DateTime(
            toDate.year,
            toDate.month,
            toDate.day,
            toDate.hour,
            toDate.minute,
          );
        } catch (e) {
          showSnackBar('Error parsing meeting dates or times: $e');
          continue;
        }

        // Handle possible nulls with default values
        final String uid =
            item['meeting_id']?.toString() ?? UniqueKey().toString();

        String status = item['s_name'] != null
            ? mapEventStatus(item['s_name'].toString())
            : 'Pending';

        if (status == 'Cancelled') continue;

        final event = Events(
          // title: item['title'] ?? 'Minutes Of Meeting',
          title: item['title'] ?? 'Add Meeting',
          start: startDateTime,
          end: endDateTime,
          desc: item['description'] ?? '',
          status: status,
          isMeeting: true,
          location: item['location'] ?? '', // Assuming 'location' field exists
          createdBy: item['create_by'] ?? '',
          imgName: item['file_name'] ?? '',
          createdAt: item['created_at'] ?? '',
          uid: uid,
          isRepeat: item['is_repeat']?.toString(),
          videoConference: item['video_conference']?.toString(),
          backgroundColor: item['backgroundColor'] != null
              ? parseColor(item['backgroundColor'])
              : Colors.blue,
          outmeetingUid: item['meeting_id']?.toString(),
          category: 'Add Meeting',
          members: item['guests'] != null
              ? List<Map<String, dynamic>>.from(item['guests'])
              : [],
        );

        // Normalize the start and end dates for event mapping
        final normalizedStartDay = normalizeDate(startDateTime);
        final normalizedEndDay = normalizeDate(endDateTime);

        for (var day = normalizedStartDay;
            !day.isAfter(normalizedEndDay);
            day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar('Data Error');
    }

    return;
  }

  /// Fetches meeting out data from the API
  Future<void> _fetchMeetingMembers() async {
    final response = await getRequest(
        '/api/work-tracking/out-meeting/outmeeting/my-members');
    if (response == null) return;

    try {
      final data = json.decode(response.body);

      if (data == null || data['results'] == null || data['results'] is! List) {
        return;
      }

      final List<dynamic> results = data['results'];

      for (var item in results) {
        if (item['fromdate'] == null || item['todate'] == null) {
          showSnackBar('Missing date fields in meeting data.');
          continue;
        }

        DateTime startDateTime;
        DateTime endDateTime;
        try {
          DateTime fromDate = DateTime.parse(item['fromdate']);
          startDateTime = DateTime(
            fromDate.year,
            fromDate.month,
            fromDate.day,
            fromDate.hour,
            fromDate.minute,
          );

          DateTime toDate = DateTime.parse(item['todate']);
          endDateTime = DateTime(
            toDate.year,
            toDate.month,
            toDate.day,
            toDate.hour,
            toDate.minute,
          );
        } catch (e) {
          showSnackBar('Error parsing meeting dates or times: $e');
          continue;
        }

        final String uid =
            item['meeting_id']?.toString() ?? UniqueKey().toString();
        String status = item['status'] != null
            ? mapEventStatus(item['status'].toString())
            : 'Pending';
        if (status == 'Cancelled') continue;

        // Filter duplicates by employee_id for minutes of meeting members
        List<Map<String, dynamic>> membersList = item['members'] != null
            ? List<Map<String, dynamic>>.from(item['members'])
            : [];
        final seenEmployeeIds = <dynamic>{};
        final uniqueMembers = <Map<String, dynamic>>[];
        for (var member in membersList) {
          if (member['employee_id'] != null &&
              !seenEmployeeIds.contains(member['employee_id'])) {
            seenEmployeeIds.add(member['employee_id']);
            uniqueMembers.add(member);
          }
        }

        final event = Events(
          title: item['title'] ?? 'Minutes Of Meeting',
          start: startDateTime,
          end: endDateTime,
          desc: item['description'] ?? '',
          status: status,
          isMeeting: true,
          location: item['location'] ?? '',
          createdBy: item['create_by'] ?? '',
          imgName: item['file_name'] ?? '',
          createdAt: item['created_at'] ?? '',
          uid: uid,
          isRepeat: item['is_repeat']?.toString(),
          videoConference: item['video_conference']?.toString(),
          backgroundColor: item['backgroundColor'] != null
              ? parseColor(item['backgroundColor'])
              : Colors.blue,
          outmeetingUid: item['meeting_id']?.toString(),
          category: 'Minutes Of Meeting',
          members: uniqueMembers, // Use filtered unique members list
        );

        final normalizedStartDay = normalizeDate(startDateTime);
        final normalizedEndDay = normalizeDate(endDateTime);

        for (var day = normalizedStartDay;
            !day.isAfter(normalizedEndDay);
            day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar('Data Error');
    }
  }

  /// Fetches meeting room bookings from the API
  Future<void> _fetchMeetingRoomInvite() async {
    final response = await getRequest(
        '/api/office-administration/book_meeting_room/invites-meeting');
    if (response == null) return;

    try {
      final List<dynamic> results = json.decode(response.body)['results'] ?? [];
      final minutesMeeting = List<Map<String, dynamic>>.from(results);

      for (var item in minutesMeeting) {
        // final DateTime? startDateTime = item['from_date'] != null ? DateTime.parse(item['from_date']) : null;
        // final DateTime? endDateTime = item['to_date'] != null ? DateTime.parse(item['to_date']) : null;

        String dateFrom = formatDateString(item['from_date_time'].toString());
        String dateTo = formatDateString(item['to_date_time'].toString());
        // String startTime = item['start_time'] != "" ? item['start_time'].toString() : '00:00';
        // String endTime = item['end_time'] != "" ? item['end_time'].toString() : '23:59';

        if (dateFrom.isEmpty || dateTo.isEmpty) {
          showSnackBar('Missing from_date or to_date in minutes of meeting.');
          continue;
        }

        DateTime? startDateTime;
        DateTime? endDateTime;

        try {
          // Combine date and time properly
          DateTime fromDate = DateTime.parse(dateFrom);
          // List<String> timeOutParts = startTime.split(':');
          // if (timeOutParts.length == 3) timeOutParts.removeLast();
          // if (timeOutParts.length != 2) {
          //   throw const FormatException('Invalid time_out format');
          // }
          startDateTime = DateTime(
            fromDate.year,
            fromDate.month,
            fromDate.day,
            fromDate.hour,
            fromDate.minute,
          );

          DateTime inDate = DateTime.parse(dateTo);

          endDateTime = DateTime(
            inDate.year,
            inDate.month,
            inDate.day,
            inDate.hour,
            inDate.minute,
          );
        } catch (e) {
          showSnackBar('Error parsing car booking dates: $e');
          continue;
        }

        final String uid =
            item['project_id']?.toString() ?? UniqueKey().toString();

        String status = item['statuss'] != null
            ? item['statuss'] == 1
                ? 'Success'
                : 'Pending'
            : 'Pending';

        if (status == 'Cancelled') continue;

        Events? event;
        event = Events(
          title: item['project_name'] ?? 'Minutes  Of Meeting',
          start: startDateTime,
          end: endDateTime,
          desc: item['descriptions'] ?? 'Minutes Of Meeting Pending',
          status: status,
          isMeeting: true,
          category: 'Minutes Of Meeting',
          uid: uid,
          imgName: item['img_name'],
          createdBy: item['member_name'],
          createdAt: item['updated_at'],
          // members: List<Map<String, dynamic>>.from(resultMembers),
        );

        for (var day = normalizeDate(startDateTime);
            !day.isAfter(normalizeDate(endDateTime));
            day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar('Data Error');
    }
    return;
  }

  /// Fetches meeting room bookings from the API
  Future<void> _fetchMeetingRoomBookings() async {
    final response = await getRequest(
        '/api/office-administration/book_meeting_room/my-requests');
    if (response == null) return;

    try {
      final List<dynamic> results = json.decode(response.body)['results'] ?? [];
      final meetingRoomBookings = List<Map<String, dynamic>>.from(results);

      for (var item in meetingRoomBookings) {
        final DateTime? startDateTime = item['from_date_time'] != null
            ? DateTime.parse(item['from_date_time'])
            : null;
        final DateTime? endDateTime = item['to_date_time'] != null
            ? DateTime.parse(item['to_date_time'])
            : null;

        if (startDateTime == null || endDateTime == null) {
          showSnackBar(
              'Missing from_date_time or to_date_time in meeting room booking.');
          continue;
        }

        final String uid = item['uid']?.toString() ?? UniqueKey().toString();
        String status = item['status'] != null
            ? mapEventStatus(item['status'].toString())
            : 'Pending';
        if (status == 'Cancelled') continue;

        // Filter duplicates by employee_id for meeting room members
        List<Map<String, dynamic>> membersList = item['members'] != null
            ? List<Map<String, dynamic>>.from(item['members'])
            : [];
        final seenEmployeeIds = <dynamic>{};
        final uniqueMembers = <Map<String, dynamic>>[];
        for (var member in membersList) {
          if (member['employee_id'] != null &&
              !seenEmployeeIds.contains(member['employee_id'])) {
            seenEmployeeIds.add(member['employee_id']);
            uniqueMembers.add(member);
          }
        }

        final event = Events(
          title: item['title'] ??
              AppLocalizations.of(context)!.meetingRoomBookings,
          start: startDateTime,
          end: endDateTime,
          desc: item['remark'] ?? 'Booking Pending',
          status: status,
          isMeeting: true,
          category: 'Meeting Room Bookings',
          uid: uid,
          imgName: item['img_name'],
          createdBy: item['employee_name'],
          createdAt: item['date_create'],
          location: item['room_name'] ?? 'Meeting Room',
          members: uniqueMembers, // Use filtered unique members list
        );

        for (var day = normalizeDate(startDateTime);
            !day.isAfter(normalizeDate(endDateTime));
            day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar('Data Error');
    }
  }

  /// Fetches car bookings from the API
  Future<void> _fetchCarBookings() async {
    final response =
        await getRequest('/api/office-administration/car_permits/me');
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
          if (timeOutParts.length == 3) timeOutParts.removeLast();
          if (timeOutParts.length != 2) {
            throw const FormatException('Invalid time_out format');
          }

          endDateTime = DateTime(
            outDate.year,
            outDate.month,
            outDate.day,
            int.parse(timeOutParts[0]),
            int.parse(timeOutParts[1]),
          );

          DateTime inDate = DateTime.parse(dateInStr);
          List<String> timeInParts = timeInStr.split(':');
          if (timeInParts.length == 3) timeInParts.removeLast();
          if (timeInParts.length != 2) {
            throw const FormatException('Invalid time_in format');
          }
          startDateTime = DateTime(
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

        final String uid =
            'car_${item['uid']?.toString() ?? UniqueKey().toString()}';

        String status = item['status'] != null
            ? mapEventStatus(item['status'].toString())
            : 'Pending';

        if (status == 'Cancelled') continue;

        Events? event;

        event = Events(
          title: item['purpose'] ?? AppLocalizations.of(context)!.noTitle,
          start: startDateTime,
          end: endDateTime,
          desc: item['desc'] ?? 'Car Booking Pending',
          status: status,
          isMeeting: false,
          category: 'Booking Car',
          uid: uid,
          location: item['place'] ?? '',
          imgName: item['img_name'],
          createdBy: item['requestor_name'],
          createdAt: item['updated_at'],
        );

        for (var day = normalizeDate(startDateTime);
            !day.isAfter(normalizeDate(endDateTime));
            day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar('Data Error');
    }
    return;
  }

  /// Fetches car bookings from the API
  Future<void> _fetchCarBookingsInvite() async {
    final response = await getRequest(
        '/api/office-administration/car_permits/invites-car-member');
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
          DateTime outDate = DateTime.parse(dateOutStr);
          List<String> timeOutParts = timeOutStr.split(':');
          if (timeOutParts.length == 3) timeOutParts.removeLast();
          if (timeOutParts.length != 2) {
            throw const FormatException('Invalid time_out format');
          }

          endDateTime = DateTime(
            outDate.year,
            outDate.month,
            outDate.day,
            int.parse(timeOutParts[0]),
            int.parse(timeOutParts[1]),
          );

          DateTime inDate = DateTime.parse(dateInStr);
          List<String> timeInParts = timeInStr.split(':');
          if (timeInParts.length == 3) timeInParts.removeLast();
          if (timeInParts.length != 2) {
            throw const FormatException('Invalid time_in format');
          }
          startDateTime = DateTime(
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

        final String uid =
            'car_${item['uid']?.toString() ?? UniqueKey().toString()}';
        String status = item['status'] != null
            ? mapEventStatus(item['status'].toString())
            : 'Pending';
        if (status == 'Cancelled') continue;

        // Filter duplicates by employee_id for car booking members
        List<Map<String, dynamic>> membersList = item['members'] != null
            ? List<Map<String, dynamic>>.from(item['members'])
            : [];
        final seenEmployeeIds = <dynamic>{};
        final uniqueMembers = <Map<String, dynamic>>[];
        for (var member in membersList) {
          if (member['employee_id'] != null &&
              !seenEmployeeIds.contains(member['employee_id'])) {
            seenEmployeeIds.add(member['employee_id']);
            uniqueMembers.add(member);
          }
        }

        final event = Events(
          title: item['purpose'] ?? AppLocalizations.of(context)!.noTitle,
          start: startDateTime,
          end: endDateTime,
          desc: item['place'] ?? 'Car Booking Pending',
          status: status,
          isMeeting: false,
          category: 'Booking Car',
          uid: uid,
          location: item['place'] ?? '',
          imgName: item['img_name'],
          createdBy: item['requestor_name'],
          createdAt: item['updated_at'],
          members: uniqueMembers, // Use filtered unique members list
        );

        for (var day = normalizeDate(startDateTime);
            !day.isAfter(normalizeDate(endDateTime));
            day = day.add(const Duration(days: 1))) {
          addEvent(day, event);
        }
      }
    } catch (e) {
      showSnackBar('Data Error');
    }
  }

  /// Handles pull-to-refresh action
  Key _refreshKey = UniqueKey();

  Future<void> _onRefresh() async {
    _clearCaches(); // Clear caches on refresh

    connectivityResult.checkConnectivity().then((e) async {
      if (e.contains(ConnectivityResult.none)) {
        eventsForDay = await offlineProvider.getCalendar();
        setState(() {
          addEventOffline(eventsForDay);
          _refreshKey = UniqueKey();
        });
      } else {
        await fetchData();
        setState(() {
          _refreshKey = UniqueKey();
        });
      }
    });
  }

  int liveHour() {
    int hour = DateTime.now().toLocal().hour;
    return hour;
  }

  /// Optimized event retrieval with caching
  List<Events> _getEventsForDay(DateTime day) {
    final normalizedDay = normalizeDate(day);
    if (_processedEventsCache.containsKey(normalizedDay)) {
      return _processedEventsCache[normalizedDay]!;
    }
    final result = events.value[normalizedDay] ?? [];
    _processedEventsCache[normalizedDay] = result;
    return result;
  }

  /// Optimized event counts with caching
  Map<String, int> _getEventCountsByCategory(DateTime day) {
    final normalizedDay = normalizeDate(day);
    if (_eventCountsCache.containsKey(normalizedDay)) {
      return _eventCountsCache[normalizedDay]!;
    }

    final events = _getEventsForDay(day);
    final counts = <String, int>{};

    for (var event in events) {
      counts[event.category] = (counts[event.category] ?? 0) + 1;
    }

    _eventCountsCache[normalizedDay] = counts;
    return counts;
  }

  /// Clear caches when data is updated
  void _clearCaches() {
    _eventCountsCache.clear();
    _processedEventsCache.clear();
  }

  /// Optimized filter and search
  void _filterAndSearchEvents() {
    if (_selectedDay == null) return;

    _clearCaches(); // Clear caches when events are filtered
    offlineProvider.insertCalendar(eventsForAll);

    final dayEvents = _getEventsForDay(_selectedDay!);
    List<Events> filteredEvents = dayEvents;

    if (_selectedCategory != 'All') {
      filteredEvents = filteredEvents
          .where((event) => event.category == _selectedCategory)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredEvents = filteredEvents.where((event) {
        final title = event.title.toLowerCase();
        final description = event.desc.toLowerCase();
        return title.contains(query) || description.contains(query);
      }).toList();
    }

    setState(() {
      eventsForDay = filteredEvents;
    });
  }

  void _eventsOffline() async {
    if (_selectedDay == null) return;

    List<Events> dayEvents = _getEventsForDay(_selectedDay!);
    if (_selectedCategory != 'All') {
      dayEvents = dayEvents
          .where((event) => event.category == _selectedCategory)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      dayEvents = dayEvents.where((event) {
        final eventTitle = event.title.toLowerCase();
        final eventDescription = event.desc.toLowerCase();
        return eventTitle.contains(_searchQuery.toLowerCase()) ||
            eventDescription.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    setState(() {
      eventsForDay = dayEvents;
      events.value;
    });
  }

  /// Navigates to day view when a day is double-tapped
  void _showDayView(DateTime selectedDay) {
    // final List<Events> dayEvents = _getEventsForDay(selectedDay);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TimetablePage(date: selectedDay),
      ),
    );
  }

  /// Displays a popup to choose between adding personal or office events
  void showAddEventOptionsPopup() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                    color: isDarkMode
                        ? Colors.grey[850]
                        : Colors.white, // Dark mode background
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withOpacity(0.6)
                            : Colors.black.withOpacity(
                                0.2), // Darker shadow for dark mode
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
                        label: '1. ${AppLocalizations.of(context)!.personal}',
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToAddEvent('Personal');
                        },
                        isDarkMode: isDarkMode, // Passing dark mode flag
                      ),
                      const Divider(height: 1),
                      _buildPopupOption(
                        icon: Icons.work,
                        label: '2. ${AppLocalizations.of(context)!.office}',
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToAddEvent('Office');
                        },
                        isDarkMode: isDarkMode, // Passing dark mode flag
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

  /// Builds individual popup options
  Widget _buildPopupOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDarkMode, // Added the 'isDarkMode' parameter here
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon color changes based on dark mode
            Icon(
              icon,
              size: 20,
              color: isDarkMode
                  ? Colors.white70
                  : Colors.black54, // Dark mode: white, Light mode: black
              semanticLabel: label,
            ),
            const SizedBox(width: 12),
            // Text color changes based on dark mode
            Text(
              label,
              style: TextStyle(
                color: isDarkMode
                    ? Colors.white
                    : Colors.black87, // Dark mode: white, Light mode: black
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Navigates to the appropriate event addition page
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
          title: newEvent['title'] ?? 'New Event',
          startDateTime: DateTime.parse(newEvent['startDateTime']),
          endDateTime: DateTime.parse(newEvent['endDateTime']),
          description: newEvent['description'] ?? '',
          status: 'Pending',
          isMeeting: true,
          category: 'Meetings',
          uid: newEvent['uid'] ?? UniqueKey().toString(),
        );
        Fluttertoast.showToast(
          msg: "Event Created Successfully",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green[600],
          textColor: Colors.white,
        );
      }
    }
  }

  /// Adds a new event to the calendar
  void _addEvent({
    required String title,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required String description,
    required String status,
    required bool isMeeting,
    required String category,
    required String uid,
  }) {
    final newEvent = Events(
      title: title,
      start: startDateTime,
      end: endDateTime,
      desc: description,
      status: status,
      isMeeting: isMeeting,
      category: category,
      uid: uid,
    );
    final normalizedDay = normalizeDate(startDateTime);
    setState(() {
      if (events.value.containsKey(normalizedDay)) {
        if (!events.value[normalizedDay]!.any((e) => e.uid == uid)) {
          events.value[normalizedDay]!.add(newEvent);
        }
      } else {
        events.value[normalizedDay] = [newEvent];
      }
      _filterAndSearchEvents();
      _animationController.forward(from: 0.0);
    });
  }

  /// Shows a modern snackbar with event counts
  void _showEventCountsSnackbar(DateTime day, bool isDarkMode) {
    final counts = _getEventCountsByCategory(day);
    if (counts.isEmpty) return;

    final formattedDate = DateFormat('EEE, dd MMM').format(day);

    const categoryOrder = {
      'Add Meeting': 1,
      'Meeting Room Bookings': 2,
      'Booking Car': 3,
      'Minutes Of Meeting': 4,
      'Leave': 5,
    };

    final sortedCounts = counts.entries.toList()
      ..sort((a, b) =>
          (categoryOrder[a.key] ?? 99).compareTo(categoryOrder[b.key] ?? 99));

    final snackBar = SnackBar(
      content: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ColorStandardization().colorDarkGold,
                    ColorStandardization().colorDarkGreen,
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sortedCounts.map((entry) {
                      final category = entry.key;
                      final count = entry.value;
                      final color = categoryColors[category] ?? Colors.grey;
                      String displayCategory = '';

                      switch (category) {
                        case 'Add Meeting':
                          displayCategory =
                              AppLocalizations.of(context)!.meetingTitle;
                        case 'Leave':
                          displayCategory = AppLocalizations.of(context)!.leave;
                        case 'Meeting Room Bookings':
                          displayCategory =
                              AppLocalizations.of(context)!.meetingRoomBookings;
                        case 'Booking Car':
                          displayCategory =
                              AppLocalizations.of(context)!.bookingCar;
                        case 'Minutes Of Meeting':
                          displayCategory =
                              AppLocalizations.of(context)!.minutesOfMeeting;
                        default:
                          displayCategory = category;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          border: Border.all(
                              color: color.withOpacity(0.3), width: 1),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              categoryIcon[category] != null
                                  ? Icons.circle
                                  : Icons.event,
                              size: 8,
                              color: color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              displayCategory,
                              style: TextStyle(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.9)
                                    : Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                count.toString(),
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),

      margin: const EdgeInsets.fromLTRB(12, 50, 12, 30), // Top: 50, Bottom: 12
      duration: const Duration(seconds: 4),
      animation: CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
        reverseCurve: Curves.easeOut,
      ),
      elevation: isDarkMode ? 8 : 4,
      action: SnackBarAction(
        label: 'OK',
        textColor: ColorStandardization().colorDarkGold,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
    _animationController.forward(from: 0.0);
  }

  /// Retrieves events for a specific day with duplicates filtered
  List<Events> _getDubplicateEventsForDay(DateTime day) {
    final normalizedDay = normalizeDate(day);
    final listEvent = events.value[normalizedDay] ?? [];
    List<Events> updateEvents = [];
    if (listEvent.length > 4) {
      for (var i in listEvent) {
        if (updateEvents.isEmpty) {
          updateEvents.add(i);
        } else if (updateEvents.any((u) => u.category.contains(i.category))) {
          // Skip duplicate categories
        } else {
          updateEvents.add(i);
        }
      }
    } else {
      updateEvents = listEvent;
    }

    return updateEvents;
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      key: _refreshKey,
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(160),
        child: _buildCalendarHeader(isDarkMode),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (DateTime.now().toLocal().hour > 19) {
            await _onRefresh();
          } else {
            await _onRefresh();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    "Your calendar data has been refreshed and updated successfully",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: isDarkMode ? Colors.orange : Colors.green,
                  margin: const EdgeInsets.all(20),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        },
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildCalendar(context, isDarkMode),
              _buildSectionSeparator(),
              Center(
                child: Transform.translate(
                  offset: const Offset(0, -14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('EEEE')
                            .format(_selectedDay ?? DateTime.now()),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        ', ${DateFormat('dd MMMM yyyy').format(_selectedDay ?? DateTime.now())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -32),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.50,
                  child: eventsForDay.isEmpty
                      ? Center(
                          child: Text(
                            AppLocalizations.of(context)!.noEventsForThisDay,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : CalendarDaySwitchView(
                          selectedDay: _selectedDay,
                          passDefaultCurrentHour: 0,
                          passDefaultEndHour: 25,
                          eventsCalendar: eventsForDay,
                        ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the calendar header with background and add button
  Widget _buildCalendarHeader(bool isDarkMode) {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
              isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
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
                const SizedBox(height: 60),
                Text(
                  AppLocalizations.of(context)!.calendar,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 60,
            right: 15,
            child: IconButton(
              icon: Icon(
                Icons.add_circle,
                size: 55,
                color: Colors.green,
                semanticLabel: AppLocalizations.of(context)!.addEvent,
              ),
              onPressed: showAddEventOptionsPopup,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the TableCalendar widget with customized navigation arrows
  Widget _buildCalendar(BuildContext context, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black38 : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCustomHeader(isDarkMode),
          Consumer2<DateProvider, LanguageNotifier>(
            builder: (context, dateProvider, languageNotifier, child) {
              return TableCalendar<Events>(
                rowHeight: 35,
                firstDay: DateTime.utc(2010, 10, 16),
                lastDay: DateTime.utc(2030, 3, 14),
                focusedDay: dateProvider.selectedDate,
                locale: languageNotifier.currentLocale.languageCode,
                calendarFormat: _calendarFormat,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                },
                headerVisible: false,
                selectedDayPredicate: (day) {
                  return isSameDay(dateProvider.selectedDate, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  if (_singleTapSelectedDay != null &&
                      isSameDay(_singleTapSelectedDay, selectedDay)) {
                    _showDayView(selectedDay);
                    _singleTapSelectedDay = null;
                  } else {
                    dateProvider.updateSelectedDate(selectedDay);
                    setState(() {
                      _singleTapSelectedDay = selectedDay;
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                      _filterAndSearchEvents();
                    });

                    // Show event counts snackbar
                    _showEventCountsSnackbar(selectedDay, isDarkMode);
                  }
                },
                onFormatChanged: (format) {
                  if (format != CalendarFormat.month) {
                    setState(() {
                      _calendarFormat = CalendarFormat.month;
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                    dateProvider.updateSelectedDate(focusedDay);
                  });
                },
                eventLoader: _getDubplicateEventsForDay,
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: ColorStandardization().colorDarkGold,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.green.withOpacity(1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  defaultDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  weekendDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  outsideDaysVisible: false,
                  weekendTextStyle: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                  defaultTextStyle: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isNotEmpty) {
                      final sortedEvents = events
                        ..sort((a, b) => b.start.compareTo(a.start));
                      final latestEvents = sortedEvents.take(3).toList();
                      final eventSpans = latestEvents.where((event) {
                        return date.isAfter(event.start
                                .subtract(const Duration(days: 1))) &&
                            date.isBefore(
                                event.end.add(const Duration(days: 1)));
                      }).toList();

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: eventSpans.map((event) {
                          final totalDays = event.end.difference(event.start);
                          return Container(
                            height: 2,
                            margin: EdgeInsets.symmetric(
                                vertical: 1,
                                horizontal: totalDays.inDays > 0 ? 0 : 20),
                            decoration: BoxDecoration(
                              color: ColorStandardization().colorDarkGreen,
                              shape: BoxShape.rectangle,
                            ),
                          );
                        }).toList(),
                      );
                    }
                    return child;
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Builds a custom header with bordered navigation arrows
  Widget _buildCustomHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Month Arrow with Border
          GestureDetector(
            onTap: () {
              final previousMonth = DateTime(
                  _focusedDay.year, _focusedDay.month - 1, _focusedDay.day);
              _focusedDay = previousMonth;
              Provider.of<DateProvider>(context, listen: false)
                  .updateSelectedDate(previousMonth);
              setState(() {
                _selectedDay = previousMonth;
                _filterAndSearchEvents();
              });
            },
            child: Container(
              decoration: BoxDecoration(
                border:
                    Border.all(color: isDarkMode ? Colors.white : Colors.grey),
                borderRadius: BorderRadius.circular(7.0),
              ),
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.chevron_left,
                size: 18,
                color: isDarkMode ? Colors.white : Colors.black,
                semanticLabel: AppLocalizations.of(context)!.previousMonth,
              ),
            ),
          ),
          // Current Month and Year
          Consumer<DateProvider>(
            builder: (context, dateProvider, child) {
              return Text(
                DateFormat.MMMM(
                        sl<UserPreferences>().getLocalizeSupport().languageCode)
                    .format(dateProvider.selectedDate),
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              );
            },
          ),
          // Next Month Arrow with Border
          GestureDetector(
            onTap: () {
              final nextMonth = DateTime(
                  _focusedDay.year, _focusedDay.month + 1, _focusedDay.day);
              _focusedDay = nextMonth;
              Provider.of<DateProvider>(context, listen: false)
                  .updateSelectedDate(nextMonth);
              setState(() {
                _selectedDay = nextMonth;
                _filterAndSearchEvents();
              });
            },
            child: Container(
              decoration: BoxDecoration(
                border:
                    Border.all(color: isDarkMode ? Colors.white : Colors.grey),
                borderRadius: BorderRadius.circular(7.0),
              ),
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: isDarkMode ? Colors.white : Colors.black,
                semanticLabel: AppLocalizations.of(context)!.nextMonth,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a gradient animated line as a section separator
  Widget _buildSectionSeparator() {
    return const GradientAnimationLine();
  }
}

/// Gradient animated line widget
class GradientAnimationLine extends StatefulWidget {
  const GradientAnimationLine({super.key});

  @override
  GradientAnimationLineState createState() => GradientAnimationLineState();
}

class GradientAnimationLineState extends State<GradientAnimationLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorAnimation1;
  late final Animation<Color?> _colorAnimation2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _colorAnimation1 = ColorTween(
      begin: Colors.deepOrange,
      end: Colors.orange,
    ).animate(_controller);
    _colorAnimation2 = ColorTween(
      begin: Colors.orange,
      end: const Color(0xFFDBB342),
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Builds the animated gradient line
  Widget _buildSectionSeparator() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: 5.0,
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
          margin: const EdgeInsets.only(
              bottom: 22.0, left: 15.0, right: 15.0, top: 20.0),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildSectionSeparator();
  }
}

/// Function to use the animated line as a separator
Widget buildSectionSeparator() {
  return const Column(
    children: [
      GradientAnimationLine(),
      SizedBox(height: 5),
    ],
  );
}
