import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:flutter/material.dart';

// List<OverflowEventsRow<T>> processOverflowEvents<T extends Object>(
//   List<AdvancedDayEvent<T>> sortedEvents, {
//   required DateTime startOfDay,
//   required DateTime endOfDay,
//   bool cropBottomEvents = false,
// }) {
//   if (sortedEvents.isEmpty) return [];

//   final List<OverflowEventsRow<T>> eventsDay = [];

//   for (var event in sortedEvents) {
//     bool eventAdded = false;

//     // Try to fit the event into an existing slot
//     for (var slotDay in eventsDay) {
//       bool canFit = true;

//       for (var existingEvent in slotDay.events) {
//         // Check for overlap with existing events in the slot
//         if (!(event.end.isBefore(existingEvent.start) || event.start.isAfter(existingEvent.end))) {
//           canFit = false;
//           break;
//         }
//       }

//       if (canFit) {
//         slotDay.events.add(event); // Add event to this slot
//         slotDay.copyWith(
//             start: DateTime.fromMillisecondsSinceEpoch(
//           [slotDay.start.millisecondsSinceEpoch, event.start.millisecondsSinceEpoch].reduce((a, b) => a < b ? a : b),
//         ));
//         slotDay.copyWith(
//             end: DateTime.fromMillisecondsSinceEpoch(
//           [slotDay.end.millisecondsSinceEpoch, event.end.millisecondsSinceEpoch].reduce((a, b) => a > b ? a : b),
//         ));
//         eventAdded = true;
//         break;
//       }
//     }

//     // If the event doesn't fit in any existing slot, create a new slot
//     if (!eventAdded) {
//       eventsDay.add(OverflowEventsRow(events: [event], start: event.start, end: event.end));
//     }
//   }

//   return eventsDay;
// }

List<OverflowEventsRow<T>> processOverflowEvents<T extends Object>(
  List<AdvancedDayEvent<T>> sortedEvents, {
  required DateTime startOfDay,
  required DateTime endOfDay,
  bool cropBottomEvents = false,
}) {
  if (sortedEvents.isEmpty) return [];
  // sortedEvents.sort((a, b) => b.duration!.inHours.compareTo(a.duration!.inHours));

  var start = sortedEvents.first.start.cleanSec();
  var end = sortedEvents.first.end;

  final Map<DateTime, OverflowEventsRow<T>> oM = {};

  for (var event in sortedEvents) {
    if (event.start.isBefore(startOfDay) || event.start.isAfter(endOfDay)) {
      continue;
    }
    if (event.start.earlierThan(end)) {
      oM.update(
        start,
        (value) => value.copyWith(events: [...value.events, event]),
        ifAbsent: () => OverflowEventsRow(events: [event], start: event.start, end: event.end),
      );

      if (event.end.laterThan(end)) {
        if (cropBottomEvents) {
          end = event.end.isBefore(endOfDay) ? event.end : endOfDay;
        } else {
          end = event.end;
        }
        oM[start] = oM[start]!.copyWith(end: end);
      }
    } else {
      start = event.start.cleanSec();
      end = event.end;
      oM[start] = OverflowEventsRow(events: [event], start: event.start, end: event.end);
    }
  }

  return oM.values.toList();
}

List<OverTimeEventsRow<T>> processOverTimeEvents<T extends Object>(
  List<Events> sortedEvents, {
  required DateTime startOfDay,
  required DateTime endOfDay,
  bool cropBottomEvents = false,
}) {
  if (sortedEvents.isEmpty) return [];

  var start = sortedEvents.first.start.cleanSec();
  var end = sortedEvents.first.end;

  final Map<DateTime, OverTimeEventsRow<T>> oM = {};

  for (var event in sortedEvents) {
    // if (event.start.isBefore(startOfDay) || event.start.isAfter(endOfDay)) {
    //   continue;
    // }
    if (event.start.earlierThan(end)) {
      oM.update(
        start,
        (value) => value.copyWith(events: [...value.events, event]),
        ifAbsent: () => OverTimeEventsRow(events: [event], start: event.start, end: event.end),
      );

      if (event.end.laterThan(end)) {
        if (cropBottomEvents) {
          end = event.end.isBefore(endOfDay) ? event.end : endOfDay;
        } else {
          end = event.end;
        }
        oM[start] = oM[start]!.copyWith(end: end);
      }
    } else {
      start = event.start.cleanSec();
      end = event.end;
      oM[start] = OverTimeEventsRow(events: [event], start: event.start, end: event.end);
    }
  }

  return oM.values.toList();
}

extension DateTimeExtension on DateTime {
  bool earlierThan(DateTime other) {
    return isBefore(other);
    // return hour < other.hour || ((hour == other.hour) && minute < other.minute);
  }

  bool laterThan(DateTime other) {
    return isAfter(other);
    // return hour > other.hour || ((hour == other.hour) && minute > other.minute);
  }

  bool same(DateTime other) => hour == other.hour && minute == other.minute;

  int minuteFrom(DateTime timePoint) {
    return (hour - timePoint.hour) * 60 + (minute - timePoint.minute);
  }

  int minuteUntil(DateTime timePoint) {
    return timePoint.cleanSec().difference(cleanSec()).inMinutes;
    // return (timePoint.hour - hour) * 60 + (timePoint.minute - minute);
  }

  bool inTheGap(DateTime timePoint, int gap) {
    return hour == timePoint.hour && (minute >= timePoint.minute && minute < (timePoint.minute + gap));
  }

  DateTime copyTimeAndMinClean(TimeOfDay tod) => copyWith(
        hour: tod.hour,
        minute: tod.minute,
        second: 00,
        millisecond: 0,
        microsecond: 0,
      );

  DateTime cleanSec() => copyWith(second: 00, millisecond: 0, microsecond: 0);
  DateTime hourOnly() => copyWith(minute: 00, second: 00, millisecond: 0, microsecond: 0);
  String get hourDisplay24 => "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, "0")}";
  String get hourDisplay12 => "${(hour % 12 == 0 ? 12 : hour % 12).toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} ${hour >= 12 ? 'PM' : 'AM'}";
  String get hourDisplayZero12 => (hour % 12 == 0 ? 12 : hour % 12).toString();
  String get displayAMPM => hour >= 12 ? 'PM' : 'AM';
}
