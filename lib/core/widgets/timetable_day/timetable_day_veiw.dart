import 'dart:collection';
import 'package:flutter_datetime_format/flutter_datetime_format.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/core/widgets/avatar.dart';
import 'package:pb_hrsystem/core/widgets/calendar_day/events_utils.dart';
import 'package:pb_hrsystem/home/event_detail_view.dart';

class TimeTableDayWidget extends HookWidget {
  const TimeTableDayWidget({
    super.key,
    required this.eventsTimeTable,
    this.selectedDay,
  });

  final List<TimetableItem> eventsTimeTable;
  final DateTime? selectedDay;

  @override
  Widget build(BuildContext context) {
    final ValueNotifier<List<TimetableItem<String>>> currentEvents = useState([]);
    final ValueNotifier<List<OverTimeEventsRow<String>>> currentOverflowEventsRow = useState([]);
    int currentHour = 7;
    int untilEnd = 19;
    late String _eventType;

    final listSections = [
      [7, 10],
      [10, 13],
      [13, 17],
    ];

    autoEventsSlot() {
      currentEvents.value.clear();
      currentOverflowEventsRow.value.clear();
      for (var e in eventsTimeTable) {
        DateTime startTime;
        DateTime endTime;

        if (e.start.hour == 0 && e.end.hour == 0) {
          for (var section in listSections) {
            startTime = DateTime.utc(
              selectedDay!.year,
              selectedDay!.month,
              selectedDay!.day,
              section[0],
              5,
            );
            endTime = DateTime.utc(
              selectedDay!.year,
              selectedDay!.month,
              selectedDay!.day,
              section[1] - 1,
              55,
            );
            currentEvents.value.add(TimetableItem(
              uid: e.uid,
              title: e.title ?? '',
              desc: e.desc ?? '',
              start: startTime,
              end: endTime,
              category: e.category ?? '',
              members: e.members,
              status: e.status,
              leaveType: e.leaveType,
            ));
          }
        } else if (e.start.hour > 7 && e.end.hour > 11) {
          startTime = DateTime.utc(
            selectedDay!.year,
            selectedDay!.month,
            selectedDay!.day,
            7,
            5,
          );
          endTime = DateTime.utc(
            selectedDay!.year,
            selectedDay!.month,
            selectedDay!.day,
            9,
            55,
          );
          currentEvents.value.add(TimetableItem(
            uid: e.uid,
            title: e.title ?? '',
            desc: e.desc ?? '',
            start: startTime,
            end: endTime,
            category: e.category ?? '',
            members: e.members,
            status: e.status,
            leaveType: e.leaveType,
          ));
        } else if (e.start.hour > 10 && e.end.hour > 14) {
          startTime = DateTime.utc(
            selectedDay!.year,
            selectedDay!.month,
            selectedDay!.day,
            10,
            5,
          );
          endTime = DateTime.utc(
            selectedDay!.year,
            selectedDay!.month,
            selectedDay!.day,
            13,
            55,
          );
          currentEvents.value.add(TimetableItem(
            uid: e.uid,
            title: e.title ?? '',
            desc: e.desc ?? '',
            start: startTime,
            end: endTime,
            category: e.category ?? '',
            members: e.members,
            status: e.status,
            leaveType: e.leaveType,
          ));
        } else if (e.start.hour > 14 && e.end.hour > 18) {
          startTime = DateTime.utc(
            selectedDay!.year,
            selectedDay!.month,
            selectedDay!.day,
            13,
            5,
          );
          endTime = DateTime.utc(
            selectedDay!.year,
            selectedDay!.month,
            selectedDay!.day,
            17,
            55,
          );
          currentEvents.value.add(TimetableItem(
            uid: e.uid,
            title: e.title ?? '',
            desc: e.desc ?? '',
            start: startTime,
            end: endTime,
            category: e.category ?? '',
            members: e.members,
            status: e.status,
            leaveType: e.leaveType,
          ));
        } else {}
      }

      currentOverflowEventsRow.value = processOverTimeEvents(
        [...currentEvents.value]..sort((a, b) => a.compare(b)),
        startOfDay: selectedDay!.copyTimeAndMinClean(TimeOfDay(hour: currentHour, minute: 0)),
        endOfDay: selectedDay!.copyTimeAndMinClean(TimeOfDay(hour: untilEnd, minute: 0)),
        cropBottomEvents: true,
      );
    }

    useEffect(() => autoEventsSlot());

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 30),
        child: ValueListenableBuilder(
          valueListenable: currentOverflowEventsRow,
          builder: (context, data, child) {
            return TimeTableDayView(
              onTimeTap: (s) {},
              overflowEvents: data,
              events: UnmodifiableListView(eventsTimeTable),
              dividerColor: Colors.black,
              currentDate: selectedDay ?? DateTime.now(),
              heightPerMin: 1.5,
              startOfDay: TimeOfDay(hour: currentHour, minute: 0),
              endOfDay: TimeOfDay(hour: untilEnd, minute: 0),
              renderRowAsListView: true,
              cropBottomEvents: true,
              showMoreOnRowButton: true,
              timeTitleColumnWidth: 40,
              time12: true,
              timeViewItemBuilder: (context, constraints, itemIndex, event) {
                Color statusColor;
                Widget statusChild = const SizedBox.shrink();
                IconData? iconCategory = categoryIcon[event.category];

                debugPrint(event.category);

                statusColor = categoryColors[event.category] ?? Colors.orange;

                switch (event.category) {
                  case 'Add Meeting':
                    _eventType = AppLocalizations.of(context)!.meetingTitle;
                  case 'Leave':
                    _eventType = AppLocalizations.of(context)!.leave;
                  case 'Meeting Room Bookings':
                    _eventType = AppLocalizations.of(context)!.meetingRoomBookings;
                  case 'Booking Car':
                    _eventType = AppLocalizations.of(context)!.bookingCar;
                  case 'Minutes Of Meeting':
                    _eventType = AppLocalizations.of(context)!.minutesOfMeeting;
                  default:
                    _eventType = AppLocalizations.of(context)!.other;
                }

                switch (event.status) {
                  case 'Approved':
                    statusChild = Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 10,
                      ),
                      height: constraints.maxHeight,
                      width: 60,
                      decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: const BorderRadius.all(Radius.circular(10)),
                          border: Border.all(
                            color: statusColor,
                            width: 3,
                          )),
                      child: Text(
                        _eventType,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  case 'Pending':
                    statusChild = Container(
                      margin: const EdgeInsets.only(right: 10),
                      height: constraints.maxHeight,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                      ),
                      width: 60,
                      child: DottedBorder(
                        color: statusColor,
                        strokeWidth: 3,
                        dashPattern: const <double>[5, 5],
                        borderType: BorderType.RRect,
                        radius: const Radius.circular(12),
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
                        child: Text(
                          _eventType,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  default:
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  key: ValueKey(event.hashCode),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventDetailView(
                          event: {
                            'title': event.title,
                            'description': eventsTimeTable[itemIndex].reason,
                            'startDateTime': eventsTimeTable[itemIndex].start.toString(),
                            'endDateTime': eventsTimeTable[itemIndex].end.toString(),
                            'isMeeting': true,
                            'createdBy': eventsTimeTable[itemIndex].requestorID,
                            'location': '',
                            'status': event.status,
                            'img_name': eventsTimeTable[itemIndex].imgName ?? '',
                            'created_at': eventsTimeTable[itemIndex].createdAt ?? '',
                            'is_repeat': '',
                            'video_conference': '',
                            'uid': eventsTimeTable[itemIndex].uid,
                            'members': const [],
                            'category': event.category,
                            'leave_type': event.leaveType,
                          },
                        ),
                      ),
                    );
                  },
                  // child: statusChild,
                  child: Container(
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
                                const Icon(Icons.window_rounded, size: 15),
                                const SizedBox(width: 5),
                                Text(_eventType),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: buildMembersAvatarsTimeTable(event, context)),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        iconCategory != null ? Icon(iconCategory, size: 15) : const SizedBox.shrink(),
                                        const SizedBox(width: 5),
                                        Text(event.desc ?? '', style: const TextStyle(fontSize: 10)),
                                      ],
                                    ),
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
                );
              },
            );
          },
        ),
      ),
    );
  }
}
