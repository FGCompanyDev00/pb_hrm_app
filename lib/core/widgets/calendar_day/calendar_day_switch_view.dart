import 'dart:collection';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_format/flutter_datetime_format.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:pb_hrsystem/core/standard/color.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/core/widgets/calendar_day/events_utils.dart';
import 'package:pb_hrsystem/home/event_detail_view.dart';
import 'package:pb_hrsystem/home/timetable_page.dart';

class CalendarDaySwitchView extends HookWidget {
  const CalendarDaySwitchView({
    super.key,
    required this.eventsCalendar,
    this.selectedDay,
    required this.passDefaultCurrentHour,
    required this.passDefaultEndHour,
  });

  final List<Events> eventsCalendar;
  final DateTime? selectedDay;
  final int passDefaultCurrentHour;
  final int passDefaultEndHour;

  @override
  Widget build(BuildContext context) {
    final currentHour = useState(7);
    final untilEnd = useState(18);
    final currentHourDisplay = useState(7);
    final untilEndDisplay = useState(18);
    final currentHourDefault = useState(7);
    final untilEndDefault = useState(23);
    // final switchTime = useState(selectedSlotTime);
    final ValueNotifier<List<AdvancedDayEvent<String>>> currentEvents = useState([]);
    final ValueNotifier<List<AdvancedDayEvent<String>>> categoriesEvents = useState([]);
    final ValueNotifier<List<OverflowEventsRow<String>>> currentOverflowEventsRow = useState([]);

    // ScrollController to control the initial scroll position
    final scrollController = useScrollController();

    // Function to process and slot events
    autoEventsSlot() {
      // Set default start and end hours
      currentHourDefault.value = passDefaultCurrentHour; // 0
      untilEndDefault.value = passDefaultEndHour; // 24
      currentHour.value = 7; // Starting display at 7 AM

      // Clear previous events
      currentEvents.value.clear();
      categoriesEvents.value.clear();
      currentOverflowEventsRow.value.clear();

      for (var e in eventsCalendar) {
        DateTime startTimeDisplay = DateTime(
          e.start.year,
          e.start.month,
          e.start.day,
          e.start.hour == 0 ? currentHourDisplay.value : e.start.hour,
          e.start.hour == 0 ? 0 : e.start.minute,
        );
        DateTime endTimeDisplay = DateTime(
          e.end.year,
          e.end.month,
          e.end.day,
          e.end.hour == 0 ? untilEndDisplay.value : e.end.hour,
          e.end.hour == 0
              ? untilEndDisplay.value == 23
                  ? 59
                  : 0
              : e.end.minute,
        );
        DateTime slotStartTime = DateTime(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          passDefaultCurrentHour,
          0,
        );
        DateTime slotEndTime = DateTime(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          passDefaultEndHour,
          0,
        );
        DateTime startTime = DateTime(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          e.start.hour == 0 ? currentHour.value : e.start.hour,
          e.start.minute,
        );
        DateTime endTime = DateTime(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          e.end.hour == 0 ? untilEnd.value : e.end.hour,
          e.end.minute,
        );

        if (startTime.hour != 0 && endTime.hour != 0 && startTime.isAtSameMomentAs(endTime)) {
          startTime = DateTime(
            selectedDay!.year,
            selectedDay!.month,
            selectedDay!.day,
            currentHour.value,
            e.start.minute,
          );
          endTime = DateTime(
            selectedDay!.year,
            selectedDay!.month,
            selectedDay!.day,
            untilEnd.value,
            e.end.minute,
          );

          startTimeDisplay = DateTime(
            e.start.year,
            e.start.month,
            e.start.day,
            currentHourDisplay.value,
            0,
          );
          endTimeDisplay = DateTime(
            e.end.year,
            e.end.month,
            e.end.day,
            untilEndDisplay.value,
            0,
          );
        }

        if (slotEndTime.isBefore(startTime)) {
          // Event ends before the visible slot; ignore
        } else if (endTime.isBefore(slotStartTime)) {
          // Event starts after the visible slot; ignore
        } else if (startTime.isAfter(endTime)) {
          // Invalid event timing; ignore
        } else {
          currentEvents.value.add(AdvancedDayEvent(
            value: e.uid,
            title: e.title,
            desc: e.desc,
            start: startTime,
            end: endTime,
            startDisplay: startTimeDisplay,
            endDisplay: endTimeDisplay,
            category: e.category,
            members: e.members,
            status: e.status,
            duration: endTime.difference(startTime),
          ));
        }
      }

      List<AdvancedDayEvent<String>> addMeetingEvents = [];
      List<AdvancedDayEvent<String>> leaveEvents = [];
      List<AdvancedDayEvent<String>> meetingRoomBookingsEvents = [];
      List<AdvancedDayEvent<String>> bookingCarEvents = [];
      List<AdvancedDayEvent<String>> minutesOfMeetingEvents = [];

      for (var i in currentEvents.value) {
        if (i.category == 'Add Meeting') {
          addMeetingEvents.add(i);
        } else if (i.category == 'Leave') {
          leaveEvents.add(i);
        } else if (i.category == 'Meeting Room Bookings') {
          meetingRoomBookingsEvents.add(i);
        } else if (i.category == 'Booking Car') {
          bookingCarEvents.add(i);
        } else if (i.category == 'Minutes Of Meeting') {
          minutesOfMeetingEvents.add(i);
        }
      }

      categoriesEvents.value
        ..addAll(addMeetingEvents)
        ..addAll(meetingRoomBookingsEvents)
        ..addAll(bookingCarEvents)
        ..addAll(minutesOfMeetingEvents)
        ..addAll(leaveEvents);

      const categoryOrder = {
        'Add Meeting': 1,
        'Meeting Room Bookings': 2,
        'Booking Car': 3,
        'Minutes Of Meeting': 4,  // Lower priority
        'Leave': 5,
      };

      categoriesEvents.value.sort((a, b) {
        final timeCompare = a.start.compareTo(b.start);
        return timeCompare != 0
            ? timeCompare
            : categoryOrder[a.category]!.compareTo(categoryOrder[b.category]!);
      });

      // Process overflow events
      currentOverflowEventsRow.value = processOverflowEvents(
        [...categoriesEvents.value]..sort((a, b) => a.compare(b)),
        startOfDay: selectedDay!.copyTimeAndMinClean(const TimeOfDay(hour: 0, minute: 0)),
        endOfDay: selectedDay!.copyTimeAndMinClean(const TimeOfDay(hour: 24, minute: 0)),
        cropBottomEvents: true,
      );

      for (var row in currentOverflowEventsRow.value) {
        row.events.sort((a, b) => categoryOrder[a.category]!.compareTo(categoryOrder[b.category]!));
      }
    }

    // switchSlot() {
    //   switch (switchTime.value) {
    //     case false:
    //       currentHourDefault.value = 7;
    //       untilEndDefault.value = 18;
    //       displayTime.value = '7AM-6PM';
    //     case true:
    //       currentHourDefault.value = 0;
    //       untilEndDefault.value = 25;
    //       displayTime.value = '12AM-12AM';
    //     default:
    //       currentHourDefault.value = 7;
    //       untilEndDefault.value = 11;
    //   }
    // }

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        const double offset = 7 * 60.0;
        if (scrollController.hasClients) {
          scrollController.jumpTo(offset);
        }
      });
      return null;
    }, []);

    useEffect(() {
      autoEventsSlot();
      return null;
    }, [eventsCalendar, selectedDay, passDefaultCurrentHour, passDefaultEndHour]);

    return ValueListenableBuilder(
        valueListenable: currentOverflowEventsRow,
        builder: (context, flowEvent, child) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: OverFlowCalendarDayView(
              controller: scrollController,
              onTimeTap: (s) {},
              overflowEvents: flowEvent,
              events: UnmodifiableListView(currentEvents.value),
              dividerColor: Colors.black,
              currentDate: selectedDay ?? DateTime.now(),
              heightPerMin: 1,
              startOfDay: TimeOfDay(hour: currentHourDefault.value, minute: 0),
              endOfDay: TimeOfDay(hour: untilEndDefault.value, minute: 0),
              renderRowAsListView: true,
              showMoreOnRowButton: true,
              showCurrentTimeLine: true,
              cropBottomEvents: true,
              timeTitleColumnWidth: 40,
              time12: true,
              overflowItemBuilder: (context, constraints, itemIndex, event) {
                Color statusColor = categoryColors[event.category] ?? Colors.grey;
                String? iconCategory = categoryIcon[event.category];
                Widget child;
                Duration? time = event.end.difference(event.start);

                String eventCategory = '';

                switch (event.category) {
                  case 'Add Meeting':
                    eventCategory = AppLocalizations.of(context)!.meetingTitle;
                  case 'Leave':
                    eventCategory = AppLocalizations.of(context)!.leave;
                  case 'Meeting Room Bookings':
                    eventCategory = AppLocalizations.of(context)!.meetingRoomBookings;
                  case 'Booking Car':
                    eventCategory = AppLocalizations.of(context)!.bookingCar;
                  case 'Minutes Of Meeting':
                    eventCategory = AppLocalizations.of(context)!.minutesOfMeeting;
                  default:
                    eventCategory = AppLocalizations.of(context)!.other;
                }

                event.category == "Minutes Of Meeting"
                    ? child = GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        key: ValueKey(event.hashCode),
                        onDoubleTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TimetablePage(date: selectedDay!),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EventDetailView(
                                event: {
                                  'title': event.title,
                                  'description': eventsCalendar[itemIndex].desc,
                                  'startDateTime': event.startDisplay.toString(),
                                  'endDateTime': event.endDisplay.toString(),
                                  'isMeeting': eventsCalendar[itemIndex].isMeeting,
                                  'createdBy': eventsCalendar[itemIndex].createdBy ?? '',
                                  'location': eventsCalendar[itemIndex].location ?? '',
                                  'status': event.status,
                                  'img_name': eventsCalendar[itemIndex].imgName ?? '',
                                  'created_at': eventsCalendar[itemIndex].createdAt ?? '',
                                  'is_repeat': eventsCalendar[itemIndex].isRepeat ?? '',
                                  'video_conference': eventsCalendar[itemIndex].videoConference ?? '',
                                  'uid': eventsCalendar[itemIndex].uid,
                                  'members': event.members ?? [],
                                  'category': event.category,
                                  'leave_type': eventsCalendar[itemIndex].leaveType ?? '',
                                },
                              ),
                            ),
                          );
                        },
                        child: event.status == 'Cancelled'
                            ? const SizedBox.shrink()
                            : Container(
                                margin: const EdgeInsets.only(right: 3, left: 3),
                                padding: const EdgeInsets.all(8.0),
                                height: constraints.maxHeight,
                                width: 100,
                                decoration: BoxDecoration(
                                  color: ColorStandardization().colorDarkGold,
                                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                                ),
                                child: Text(eventCategory),
                              ),
                      )
                    : child = GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        key: ValueKey(event.hashCode),
                        onDoubleTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TimetablePage(date: selectedDay!),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EventDetailView(
                                event: {
                                  'title': event.title,
                                  'description': eventsCalendar[itemIndex].desc,
                                  'startDateTime': event.startDisplay.toString(),
                                  'endDateTime': event.endDisplay.toString(),
                                  'isMeeting': eventsCalendar[itemIndex].isMeeting,
                                  'createdBy': eventsCalendar[itemIndex].createdBy ?? '',
                                  'location': eventsCalendar[itemIndex].location ?? '',
                                  'status': event.status,
                                  'img_name': eventsCalendar[itemIndex].imgName ?? '',
                                  'created_at': eventsCalendar[itemIndex].createdAt ?? '',
                                  'is_repeat': eventsCalendar[itemIndex].isRepeat ?? '',
                                  'video_conference': eventsCalendar[itemIndex].videoConference ?? '',
                                  'uid': eventsCalendar[itemIndex].uid,
                                  'members': event.members ?? [],
                                  'category': event.category,
                                  'leave_type': eventsCalendar[itemIndex].leaveType,
                                },
                              ),
                            ),
                          );
                        },
                        child: event.status == 'Cancelled'
                            ? const SizedBox.shrink()
                            : event.status == 'Approved'
                                ? Container(
                                    margin: const EdgeInsets.only(right: 3, left: 3),
                                    padding: const EdgeInsets.all(8.0),
                                    height: constraints.maxHeight,
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.2),
                                      border: Border(
                                        left: BorderSide(color: statusColor, width: 4),
                                        right: BorderSide(color: statusColor),
                                        top: BorderSide(color: statusColor),
                                        bottom: BorderSide(color: statusColor),
                                      ),
                                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                                    ),
                                    child: Row(
                                      children: [
                                        (time.inHours) < 3
                                            ? Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  SingleChildScrollView(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            const Icon(Icons.window_rounded, size: 15),
                                                            const SizedBox(width: 5),
                                                            Text(eventCategory),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Row(
                                                          children: [
                                                            iconCategory != null ? Image.asset(iconCategory, width: 15) : const SizedBox.shrink(),
                                                            const SizedBox(width: 5),
                                                            Text(event.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                          ],
                                                        ),
                                                        // Text(event.desc, style: const TextStyle(fontSize: 10)),
                                                        Row(children: _buildMembersAvatars(event, context)),
                                                        Row(
                                                          children: [
                                                            const Icon(Icons.access_time, size: 15),
                                                            const SizedBox(width: 5),
                                                            Text(
                                                              '${FLDateTime.formatWithNames(event.start, 'hh:mm a')} - ${FLDateTime.formatWithNames(event.end, 'hh:mm a')}',
                                                              style: const TextStyle(fontSize: 10),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.window_rounded, size: 15),
                                                          const SizedBox(width: 5),
                                                          Text(eventCategory),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: [
                                                          iconCategory != null ? Image.asset(iconCategory, width: 15) : const SizedBox.shrink(),
                                                          const SizedBox(width: 5),
                                                          Text(event.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                        ],
                                                      ),
                                                      // Text(event.desc, style: const TextStyle(fontSize: 10)),
                                                    ],
                                                  ),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(children: _buildMembersAvatars(event, context)),
                                                      const SizedBox(height: 20),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.access_time, size: 15),
                                                          const SizedBox(width: 5),
                                                          Text(
                                                            '${FLDateTime.formatWithNames(event.start, 'hh:mm a')} - ${FLDateTime.formatWithNames(event.end, 'hh:mm a')}',
                                                            style: const TextStyle(fontSize: 10),
                                                          ),
                                                        ],
                                                      )
                                                    ],
                                                  ),
                                                ],
                                              ),
                                      ],
                                    ),
                                  )
                                : Container(
                                    margin: const EdgeInsets.only(right: 3, left: 3),
                                    height: constraints.maxHeight,
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.2),
                                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                                    ),
                                    child: DottedBorder(
                                      color: statusColor,
                                      strokeWidth: 3,
                                      dashPattern: const <double>[5, 5],
                                      borderType: BorderType.RRect,
                                      radius: const Radius.circular(12),
                                      padding: const EdgeInsets.symmetric(horizontal: 5),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Row(
                                          children: [
                                            time.inHours < 3
                                                ? Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      SingleChildScrollView(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                const Icon(Icons.window_rounded, size: 15),
                                                                const SizedBox(width: 5),
                                                                Text(eventCategory),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 8),
                                                            Row(
                                                              children: [
                                                                const Icon(Icons.title, size: 15),
                                                                const SizedBox(width: 5),
                                                                Text(event.desc, style: const TextStyle(fontSize: 10)),
                                                              ],
                                                            ),
                                                            Row(children: _buildMembersAvatars(event, context)),
                                                            const SizedBox(height: 20),
                                                            Row(
                                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                              children: [
                                                                const SizedBox(width: 20),
                                                                Row(
                                                                  children: [
                                                                    const Icon(Icons.access_time, size: 15),
                                                                    const SizedBox(width: 5),
                                                                    Text(
                                                                      '${FLDateTime.formatWithNames(event.start, 'hh:mm a')} - ${FLDateTime.formatWithNames(event.end, 'hh:mm a')}',
                                                                      style: const TextStyle(fontSize: 10),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                : Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              const Icon(Icons.window_rounded, size: 15),
                                                              const SizedBox(width: 5),
                                                              Text(eventCategory),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 8),
                                                          Row(
                                                            children: [
                                                              const Icon(Icons.title, size: 15),
                                                              const SizedBox(width: 5),
                                                              Text(event.desc, style: const TextStyle(fontSize: 10)),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                      Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(children: _buildMembersAvatars(event, context)),
                                                          const SizedBox(height: 20),
                                                          Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              const SizedBox(width: 20),
                                                              Row(
                                                                children: [
                                                                  const Icon(Icons.access_time, size: 15),
                                                                  const SizedBox(width: 5),
                                                                  Text(
                                                                    '${FLDateTime.formatWithNames(event.start, 'hh:mm a')} - ${FLDateTime.formatWithNames(event.end, 'hh:mm a')}',
                                                                    style: const TextStyle(fontSize: 10),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          )
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                      );
                return child;
              },
            ),
          );
        });
  }

  List<Widget> _buildMembersAvatars(
    AdvancedDayEvent<String> event,
    BuildContext context,
  ) {
    // Filter duplicate members based on employee_id
    List<dynamic> filteredMembers = [];
    final seenIds = <dynamic>{};
    if (event.members != null) {
      for (var member in event.members!) {
        if (member['employee_id'] != null && seenIds.contains(member['employee_id'])) {
          continue;
        }
        seenIds.add(member['employee_id']);
        filteredMembers.add(member);
      }
    }

    List<Widget> membersAvatar = [];
    List<Widget> membersList = [];
    int moreMembers = 0;
    int countMembers = 0;
    bool isEnoughCount = false;

    // Use filteredMembers instead of event.members
    for (var v in filteredMembers) {
      // Build a list of member details once
      membersList.add(_avatarUserList(v['img_name'], v['member_name']));
    }

    for (int i = 0; i < filteredMembers.length && i < 3; i++) {
      membersAvatar.add(_avatarUser(filteredMembers[i]['img_name']));
    }

    if (filteredMembers.length > 3) {
      int remaining = filteredMembers.length - 3;
      membersAvatar.add(
        _avatarMore(context, membersList, count: '+ $remaining'),
      );
    }

    return membersAvatar;
  }

  Widget _avatarUser(String link) {
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: CircleAvatar(
        radius: 15,
        backgroundImage: CachedNetworkImageProvider(link),
      ),
    );
  }

  Widget _avatarUserList(String? link, name) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage(link ?? ''),
          ),
          const SizedBox(
            width: 20,
          ),
          Text(name ?? ''),
        ],
      ),
    );
  }

  Widget _avatarMore(BuildContext context, List<Widget> avatarList, {String? count}) {
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: GestureDetector(
        onTap: () => showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  title: Text(AppLocalizations.of(context)!.attendant),
                  content: SingleChildScrollView(
                    child: Column(
                      children: avatarList,
                    ),
                  ),
                )),
        child: CircleAvatar(
          radius: 15,
          backgroundColor: Colors.black54,
          child: Text(
            count ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ),
    );
  }
}
