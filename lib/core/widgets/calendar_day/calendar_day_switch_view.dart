import 'dart:collection';
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
    final currentHourDefault = useState(passDefaultCurrentHour);
    final untilEndDefault = useState(passDefaultEndHour);
    // final switchTime = useState(selectedSlotTime);
    final ValueNotifier<List<AdvancedDayEvent<String>>> currentEvents = useState([]);
    final ValueNotifier<List<OverflowEventsRow<String>>> currentOverflowEventsRow = useState([]);

    autoEventsSlot() {
      currentHourDefault.value = passDefaultCurrentHour;
      untilEndDefault.value = passDefaultEndHour;
      currentEvents.value.clear();
      currentOverflowEventsRow.value.clear();

      if (passDefaultCurrentHour != 0) {
        if (passDefaultCurrentHour > 18) {
          currentHourDefault.value = passDefaultCurrentHour;
          untilEndDefault.value = passDefaultEndHour;
          currentHour.value = 7;
          untilEnd.value = 18;
        } else if (passDefaultCurrentHour > 14) {
          currentHourDefault.value = 14;
          untilEndDefault.value = 18;
          currentHour.value = 14;
          untilEnd.value = 18;
        } else if (passDefaultCurrentHour > 10) {
          currentHourDefault.value = 11;
          untilEndDefault.value = 15;
          currentHour.value = 11;
          untilEnd.value = 15;
        } else if (passDefaultCurrentHour > 6) {
          currentHourDefault.value = 7;
          untilEndDefault.value = 11;
          currentHour.value = 7;
          untilEnd.value = 11;
        }
      } else {
        currentHourDefault.value = passDefaultCurrentHour;
        untilEndDefault.value = passDefaultEndHour;
        currentHour.value = 7;
        untilEnd.value = 18;
      }

      for (var e in eventsCalendar) {
        DateTime startTimeDisplay = DateTime.utc(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          e.start.hour == 0 ? currentHourDisplay.value : e.start.hour,
          e.start.hour == 0 ? 0 : e.start.minute,
        );
        DateTime endTimeDisplay = DateTime.utc(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          e.end.hour == 0 ? untilEndDisplay.value : e.end.hour,
          e.end.hour == 0
              ? untilEndDisplay.value == 23
                  ? 59
                  : 0
              : e.end.minute,
        );
        DateTime slotStartTime = DateTime.utc(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          passDefaultCurrentHour,
          0,
        );
        DateTime slotEndTime = DateTime.utc(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          passDefaultEndHour,
          0,
        );
        DateTime startTime = DateTime.utc(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          e.start.hour == 0 ? currentHour.value : (e.start.hour > currentHourDefault.value ? e.start.hour : currentHourDefault.value),
          e.start.minute,
        );
        DateTime endTime = DateTime.utc(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          e.end.hour == 0
              ? untilEnd.value
              : (e.end.hour == e.start.hour
                  ? e.end.hour
                  : e.end.hour > untilEnd.value
                      ? untilEnd.value
                      : e.end.hour),
          e.end.minute,
        );

        if (startTime.hour != 0 && endTime.hour != 0 && startTime.isAtSameMomentAs(endTime)) {
          startTime = DateTime.utc(
            selectedDay!.year,
            selectedDay!.month,
            selectedDay!.day,
            currentHour.value,
            e.start.minute,
          );
          endTime = DateTime.utc(
            selectedDay!.year,
            selectedDay!.month,
            selectedDay!.day,
            untilEnd.value,
            e.end.minute,
          );

          startTimeDisplay = DateTime.utc(
            selectedDay!.year,
            selectedDay!.month,
            selectedDay!.day,
            currentHourDisplay.value,
            0,
          );
          endTimeDisplay = DateTime.utc(
            selectedDay!.year,
            selectedDay!.month,
            selectedDay!.day,
            untilEndDisplay.value,
            0,
          );
        }

        if (slotEndTime.isBefore(startTime)) {
        } else if (endTime.isBefore(slotStartTime)) {
        } else if (startTime.isAfter(endTime)) {
        } else if (startTime.isBefore(slotStartTime)) {
          // int subHours = currentHour.value - startTime.hour;
          // startTime = startTime.add(Duration(hours: subHours));
          // if (startTime.minute > 0) {
          //   startTime = startTime.subtract(Duration(minutes: startTime.minute));
          // }

          // if (endTime.isAtSameMomentAs(slotEndTime.add(const Duration(hours: 1)))) {
          //   endTime = endTime.subtract(const Duration(hours: 1));
          // }

          // if (endTime.hour >= slotEndTime.hour) {
          //   int subHours = endTime.hour - (untilEnd.value - 1);
          // startTime = DateTime.utc(
          //   selectedDay!.year,
          //   selectedDay!.month,
          //   selectedDay!.day,
          //   currentHour.value,
          //   0,
          // );
          // endTime = DateTime.utc(
          //   selectedDay!.year,
          //   selectedDay!.month,
          //   selectedDay!.day,
          //   untilEnd.value - 1,
          //   0,
          // );

          // }

          currentEvents.value.add(AdvancedDayEvent(
            value: e.uid,
            title: e.title,
            desc: e.desc,
            start: startTime,
            end: endTime,
            category: e.category,
            members: e.members,
            status: e.status,
            startDisplay: startTimeDisplay,
            endDisplay: endTimeDisplay,
          ));
        } else {
          // final timeDuration = endTime.difference(startTime);
          // if (timeDuration.inMinutes < 30) {
          //   endTime = endTime.add(const Duration(hours: 1));
          // }
          // if (startTime.hour <= currentHour.value && startTime.minute > 0) {
          //   int addHours = currentHour.value - startTime.hour;
          //   startTime = startTime.add(Duration(hours: addHours)).subtract(Duration(minutes: startTime.minute));
          // }

          // if (endTime.isAtSameMomentAs(slotEndTime.add(const Duration(hours: 1)))) {
          //   endTime = endTime.subtract(const Duration(hours: 1));
          // }

          // if (endTime.hour >= slotEndTime.hour) {
          //   int subHours = endTime.hour - (untilEnd.value - 1);
          //   endTime = endTime.subtract(Duration(hours: subHours));
          //   if (endTime.minute > 0) {
          //     endTime = endTime.subtract(Duration(minutes: endTime.minute));
          //   }
          // }
          // startTime = DateTime.utc(
          //   selectedDay!.year,
          //   selectedDay!.month,
          //   selectedDay!.day,
          //   currentHour.value,
          //   0,
          // );
          // endTime = DateTime.utc(
          //   selectedDay!.year,
          //   selectedDay!.month,
          //   selectedDay!.day,
          //   untilEnd.value - 1,
          //   0,
          // );

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
          ));
        }
      }

      currentOverflowEventsRow.value = processOverflowEvents(
        [...currentEvents.value]..sort((a, b) => a.compare(b)),
        startOfDay: selectedDay!.copyTimeAndMinClean(TimeOfDay(hour: currentHour.value, minute: 0)),
        endOfDay: selectedDay!.copyTimeAndMinClean(TimeOfDay(hour: untilEnd.value, minute: 0)),
        cropBottomEvents: true,
      );
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

    useEffect(() => autoEventsSlot());

    return ValueListenableBuilder(
        valueListenable: currentOverflowEventsRow,
        builder: (context, flowEvent, child) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: OverFlowCalendarDayView(
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
              timeTitleColumnWidth: 40,
              time12: true,
              overflowItemBuilder: (context, constraints, itemIndex, event) {
                Color statusColor = categoryColors[event.category] ?? Colors.grey;
                String? iconCategory = categoryIcon[event.category];
                Widget child;
                Duration? time = event.end?.difference(event.start);

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
                                  'startDateTime': event.start.toString(),
                                  'endDateTime': event.end.toString(),
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
                                  'startDateTime': event.start.toString(),
                                  'endDateTime': event.end.toString(),
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
                                        (time?.inHours ?? 0) < 2
                                            ? Row(
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
                                                            '${FLDateTime.formatWithNames(event.start, 'hh:mm a')} - ${event.end != null ? FLDateTime.formatWithNames(event.end!, 'hh:mm a') : ''}',
                                                            style: const TextStyle(fontSize: 10),
                                                          ),
                                                        ],
                                                      )
                                                    ],
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
                                                            '${FLDateTime.formatWithNames(event.start, 'hh:mm a')} - ${event.end != null ? FLDateTime.formatWithNames(event.end!, 'hh:mm a') : ''}',
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
                                            (time?.inHours ?? 0) < 2
                                                ? Row(
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
                                                                    '${FLDateTime.formatWithNames(event.start, 'hh:mm a')} - ${event.end != null ? FLDateTime.formatWithNames(event.end!, 'hh:mm a') : ''}',
                                                                    style: const TextStyle(fontSize: 10),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          )
                                                        ],
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
                                                                    '${FLDateTime.formatWithNames(event.start, 'hh:mm a')} - ${event.end != null ? FLDateTime.formatWithNames(event.end!, 'hh:mm a') : ''}',
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
    List<Widget> membersAvatar = [];
    List<Widget> membersList = [];
    int moreMembers = 0;
    int countMembers = 0;
    bool isEnoughCount = false;

    if (event.members != null) {
      event.members?.forEach((v) {
        countMembers += 1;
        membersList.add(_avatarUserList(v['img_name'], v['member_name']));
        if (isEnoughCount) return;
        if (countMembers < 4) {
          membersAvatar.add(_avatarUser(v['img_name']));
        } else {
          moreMembers = (event.members?.length ?? 0) - (countMembers - 1);
          membersAvatar.add(
            _avatarMore(context, membersList, count: '+ $moreMembers'),
          );
          isEnoughCount = true;
        }
      });
    }
    return membersAvatar;
  }

  Widget _avatarUser(String link) {
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: CircleAvatar(
        radius: 15,
        backgroundImage: NetworkImage(link),
      ),
    );
  }

  Widget _avatarUserList(String link, name) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage(link),
          ),
          const SizedBox(
            width: 20,
          ),
          Text(name),
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
