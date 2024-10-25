import 'dart:collection';

import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/event_detail_view.dart';

class TimeTableDayWidget extends StatelessWidget {
  const TimeTableDayWidget({
    super.key,
    required this.eventsTimeTable,
    this.selectedDay,
  });

  final List<TimetableItem> eventsTimeTable;
  final DateTime? selectedDay;

  @override
  Widget build(BuildContext context) {
    final currentTime = DateTime.now();
    int currentHour = currentTime.hour > 9 ? 11 : 7;
    int untilEnd = currentTime.hour > 9 ? 19 : 10;

    List<TimetableItem> currentEvents = [];
    List<OverTimeEventsRow<String>> currentOverflowEventsRow = [];

    eventsTimeTable.removeWhere((e) => e.start.hour == 0 || e.end.hour == 0);

    for (var e in eventsTimeTable) {
      DateTime endTime = DateTime.utc(e.start.year, e.start.month, e.start.day, e.end.hour, e.end.minute);
      Duration storeHours = e.start.difference(endTime);

      if (currentTime.hour > 9) {
        if (storeHours.inHours > 4) {
          // int splitHoursStart = e.startDateTime.hour - storeHours.inHours;
          int splitHours = endTime.hour - storeHours.inHours;
          endTime = endTime.subtract(Duration(hours: splitHours));

          // startTime = startTime.add(const Duration(hours: 0));
          currentEvents.add(e);
        } else {
          currentEvents.add(e);
        }
      } else {
        currentEvents.add(e);
      }
    }

    for (var i in currentEvents) {
      currentOverflowEventsRow.add(
        OverTimeEventsRow(
          events: currentEvents,
          start: i.start,
          end: i.end,
        ),
      );
    }
    return Expanded(
      child: TimeTableDayView(
        onTimeTap: (s) {},
        overflowEvents: currentOverflowEventsRow,
        events: UnmodifiableListView(currentEvents),
        dividerColor: Colors.black,
        currentDate: selectedDay ?? DateTime.now(),
        heightPerMin: 2,
        startOfDay: TimeOfDay(hour: currentHour, minute: 0),
        endOfDay: TimeOfDay(hour: untilEnd, minute: 0),
        renderRowAsListView: true,
        showCurrentTimeLine: true,
        cropBottomEvents: true,
        showMoreOnRowButton: true,
        timeTitleColumnWidth: 40,
        time12: true,
        timeViewItemBuilder: (context, constraints, itemIndex, event) {
          Color statusColor = Colors.orange;
          String category = '';

          if (event.category == 'AL') {
            category = 'Leave';
            statusColor = Colors.green;
          }

          if (event.category == 'MC') category = 'Sick';

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
                      'created_at': eventsTimeTable[itemIndex].updatedOn ?? '',
                      'is_repeat': '',
                      'video_conference': '',
                      'uid': eventsTimeTable[itemIndex].id,
                      'members': const [],
                      'category': category,
                    },
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 3, left: 3),
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 10,
              ),
              height: constraints.maxHeight,
              width: 50,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.8),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: Text(
                category,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
