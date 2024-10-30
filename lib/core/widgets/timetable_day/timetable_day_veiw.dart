import 'dart:collection';

import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
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

    autoEventsSlot() {
      currentEvents.value.clear();
      currentOverflowEventsRow.value.clear();
      for (var e in eventsTimeTable) {
        DateTime slotStartTime = DateTime.utc(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          currentHour,
          0,
        );
        DateTime slotEndTime = DateTime.utc(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          untilEnd,
          0,
        );
        DateTime startTime = DateTime.utc(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          currentHour + 1,
          0,
        );
        DateTime endTime = DateTime.utc(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          untilEnd - 1,
          0,
        );

        if (slotEndTime.isBefore(startTime)) {
        } else if (startTime.isBefore(slotStartTime)) {
        } else if (startTime.isAfter(endTime)) {
        } else {
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
        padding: const EdgeInsets.only(top: 10),
        child: ValueListenableBuilder(
            valueListenable: currentOverflowEventsRow,
            builder: (context, data, child) {
              return TimeTableDayView(
                onTimeTap: (s) {},
                overflowEvents: data,
                events: UnmodifiableListView(eventsTimeTable),
                dividerColor: Colors.black,
                currentDate: selectedDay ?? DateTime.now(),
                heightPerMin: 0.8,
                startOfDay: TimeOfDay(hour: currentHour, minute: 30),
                endOfDay: TimeOfDay(hour: untilEnd, minute: 0),
                renderRowAsListView: true,
                showCurrentTimeLine: true,
                cropBottomEvents: true,
                showMoreOnRowButton: true,
                timeTitleColumnWidth: 40,
                time12: true,
                timeViewItemBuilder: (context, constraints, itemIndex, event) {
                  Color statusColor;

                  debugPrint(event.category);

                  statusColor = categoryColors[event.category] ?? Colors.orange;

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
                    child: Container(
                      margin: const EdgeInsets.only(right: 3, left: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 10,
                      ),
                      height: constraints.maxHeight,
                      width: 60,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.8),
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        event.category ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
      ),
    );
  }
}
