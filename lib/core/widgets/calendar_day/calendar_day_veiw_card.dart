// calendar_day_veiw_card.dart

// ignore_for_file: deprecated_member_use

import 'dart:collection';
import 'package:pb_hrsystem/l10n/app_localizations.dart';
import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_format/flutter_datetime_format.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:pb_hrsystem/core/standard/color.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/core/widgets/avatar.dart';
import 'package:pb_hrsystem/core/widgets/calendar_day/events_utils.dart';
import 'package:pb_hrsystem/home/event_detail_view.dart';
import 'package:pb_hrsystem/home/timetable_page.dart';

class CalendarDayWidgetCard extends HookWidget {
  const CalendarDayWidgetCard({
    super.key,
    required this.eventsCalendar,
    this.selectedDay,
    this.selectedSlotTime,
    this.heightTime,
  });

  final List<Events> eventsCalendar;
  final DateTime? selectedDay;
  final int? selectedSlotTime;
  final double? heightTime;

  @override
  Widget build(BuildContext context) {
    final currentHour = useState(7);
    final untilEnd = useState(11);
    final displayTime = useState('7AM-10AM');
    final switchTime = useState(selectedSlotTime);
    final statusList = useState(<Widget>[]);
    final ValueNotifier<List<AdvancedDayEvent<String>>> currentEvents = useState([]);
    final ValueNotifier<List<OverflowEventsRow<String>>> currentOverflowEventsRow = useState([]);

    autoEventsSlot() {
      statusList.value.clear();
      switch (switchTime.value) {
        case 1:
          currentHour.value = 7;
          untilEnd.value = 10;
          displayTime.value = '7AM-10AM';
          break;
        case 2:
          currentHour.value = 10;
          untilEnd.value = 13;
          displayTime.value = '10AM-1PM';
          break;
        case 3:
          currentHour.value = 13;
          untilEnd.value = 16;
          displayTime.value = '1PM-4PM';
          break;
      }

      currentEvents.value.clear();
      currentOverflowEventsRow.value.clear();
      for (var e in eventsCalendar) {
        DateTime slotStartTime = DateTime.utc(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          e.start.hour,
          e.start.minute,
        );
        DateTime slotEndTime = DateTime.utc(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          e.end.hour,
          e.end.minute,
        );

        if ((e.start.hour > 0 && e.start.hour < 7) && e.end.hour < 19) {
          debugPrint('invalid between 12AM and 6PM');
        } else if (e.start.hour != 0 && e.end.hour != 0 && slotStartTime.isAtSameMomentAs(slotEndTime)) {
          debugPrint('invalid same time');
        } else if (e.end.hour < e.start.hour) {
          debugPrint('wrong time');
        } else {
          DateTime startTime = DateTime.utc(
            selectedDay!.year,
            selectedDay!.month,
            selectedDay!.day,
            e.start.hour == 0 ? currentHour.value : e.start.hour,
            e.start.minute,
          );
          DateTime endTime = DateTime.utc(
            selectedDay!.year,
            selectedDay!.month,
            selectedDay!.day,
            e.end.hour == 0 ? untilEnd.value : e.end.hour,
            e.end.minute,
          );

          // if (slotEndTime.isBefore(startTime)) {
          // } else if (endTime.isBefore(slotStartTime)) {
          // } else if (startTime.isAfter(endTime)) {
          // } else if (startTime.isBefore(slotStartTime)) {
          statusList.value.add(Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: getEventColor(e),
              shape: BoxShape.circle,
            ),
          ));

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
          ));
        }

        // } else {
        //   statusList.value.add(Container(
        //     width: 5,
        //     height: 5,
        //     margin: const EdgeInsets.symmetric(horizontal: 1),
        //     decoration: BoxDecoration(
        //       color: getEventColor(e),
        //       shape: BoxShape.circle,
        //     ),
        //   ));
        //   startTime = DateTime.utc(
        //     selectedDay!.year,
        //     selectedDay!.month,
        //     selectedDay!.day,
        //     currentHour.value,
        //     0,
        //   );
        //   endTime = DateTime.utc(
        //     selectedDay!.year,
        //     selectedDay!.month,
        //     selectedDay!.day,
        //     untilEnd.value - 1,
        //     0,
        //   );

        //   currentEvents.value.add(AdvancedDayEvent(
        //     value: e.uid,
        //     title: e.title,
        //     desc: e.description,
        //     start: startTime,
        //     end: endTime,
        //     category: e.category,
        //     members: e.members,
        //     status: e.status,
        //   ));
        // }
      }
      // }

      currentOverflowEventsRow.value = processOverflowEvents(
        [...currentEvents.value]..sort((a, b) => a.compare(b)),
        startOfDay: selectedDay!.copyTimeAndMinClean(TimeOfDay(hour: currentHour.value, minute: 0)),
        endOfDay: selectedDay!.copyTimeAndMinClean(TimeOfDay(hour: untilEnd.value, minute: 0)),
        cropBottomEvents: true,
      );
    }

    useEffect(() => autoEventsSlot());

    return ValueListenableBuilder(
      valueListenable: currentOverflowEventsRow,
      builder: (context, flowEvent, child) {
        return OverFlowCalendarDayView(
          onTimeTap: (s) {},
          overflowEvents: flowEvent,
          events: UnmodifiableListView(currentEvents.value),
          dividerColor: Colors.black,
          currentDate: selectedDay ?? DateTime.now(),
          heightPerMin: heightTime ?? 1,
          startOfDay: TimeOfDay(hour: currentHour.value, minute: 0),
          endOfDay: TimeOfDay(hour: untilEnd.value + 1, minute: 0),
          renderRowAsListView: true,
          cropBottomEvents: true,
          showMoreOnRowButton: true,
          timeTitleColumnWidth: 40,
          physics: const NeverScrollableScrollPhysics(),
          time12: true,
          overflowItemBuilder: (context, constraints, itemIndex, event) {
            Color statusColor = categoryColors[event.category] ?? Colors.grey;
            String? iconCategory = categoryIcon[event.category];
            Widget child;

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
                            alignment: Alignment.center,
                            margin: const EdgeInsets.only(right: 3, left: 3),
                            padding: const EdgeInsets.all(8.0),
                            height: constraints.maxHeight,
                            width: 80,
                            decoration: BoxDecoration(
                              color: ColorStandardization().colorDarkGold,
                              borderRadius: const BorderRadius.all(Radius.circular(10)),
                            ),
                            child: Text(
                              eventCategory,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
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
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Image.asset('assets/icons/element_4.png', width: 20),
                                            const SizedBox(width: 5),
                                            Text(eventCategory),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(children: buildMembersAvatars(event, context)),
                                            const SizedBox(height: 20),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    iconCategory != null
                                                        ? Padding(
                                                            padding: const EdgeInsets.only(right: 5),
                                                            child: Image.asset(iconCategory, width: 15),
                                                          )
                                                        : const SizedBox.shrink(),
                                                    ConstrainedBox(
                                                      constraints: const BoxConstraints(maxWidth: 100),
                                                      child: ListTileTheme(
                                                        dense: true,
                                                        contentPadding: EdgeInsets.zero,
                                                        minVerticalPadding: 0,
                                                        minLeadingWidth: 0,
                                                        horizontalTitleGap: 0,
                                                        child: Text(
                                                          event.desc,
                                                          style: const TextStyle(fontSize: 10),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(width: 20),
                                                Row(
                                                  children: [
                                                    Image.asset(
                                                      'assets/icons/time_circle.png',
                                                      width: 15,
                                                      color: Theme.of(context).brightness == Brightness.dark
                                                          ? Colors.white // White icon in dark mode
                                                          : Colors.black, // Black icon in light mode
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      '${FLDateTime.formatWithNames(event.start, 'hh:mm a')}-${FLDateTime.formatWithNames(event.end, 'hh:mm a')}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Theme.of(context).brightness == Brightness.dark
                                                            ? Colors.white // White text in dark mode
                                                            : Colors.black, // Black text in light mode
                                                      ),
                                                    ),
                                                  ],
                                                )
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
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Image.asset('assets/icons/element_4.png', width: 20),
                                                const SizedBox(width: 5),
                                                Text(eventCategory),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(children: buildMembersAvatars(event, context)),
                                                const SizedBox(height: 20),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        iconCategory != null
                                                            ? Padding(
                                                                padding: const EdgeInsets.only(right: 10),
                                                                child: Image.asset(iconCategory, width: 15),
                                                              )
                                                            : const SizedBox.shrink(),
                                                        ConstrainedBox(
                                                          constraints: const BoxConstraints(maxWidth: 100),
                                                          child: ListTileTheme(
                                                            dense: true,
                                                            contentPadding: EdgeInsets.zero,
                                                            minVerticalPadding: 0,
                                                            minLeadingWidth: 0,
                                                            horizontalTitleGap: 0,
                                                            child: Text(
                                                              event.desc,
                                                              style: const TextStyle(fontSize: 10),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                      children: [
                                                        const Icon(Icons.access_time, size: 15),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          '${FLDateTime.formatWithNames(event.start, 'hh:mm a')}-${FLDateTime.formatWithNames(event.end, 'hh:mm a')}',
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
        );
      },
    );
  }
}
