import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:flutter/material.dart';

// List<OverflowEventsRow<T>> processOverflowEvents<T extends Object>(
//   List<AdvancedDayEvent<T>> sortedEvents, {
//   required DateTime startOfDay,
//   required DateTime endOfDay,
//   bool cropBottomEvents = false,
// }) {
//   if (sortedEvents.isEmpty) return [];

//   List<Map<int, List<AdvancedDayEvent<T>>>> arrangeTime = [];
//   Map<int, OverflowEventsRow<T>> oM = {};
//   int numbersOfDayViews = 0;
//   List<AdvancedDayEvent<T>> toDuplicate = [];

//   for (var event in sortedEvents) {
//     List<Map<int, List<AdvancedDayEvent<T>>>> toAdd = [];
//     bool isAdded = false;

//     // Iterate over arrangeTime without modifying it
//     for (var j in arrangeTime) {
//       j.forEach((key, value) {
//         bool canAdd = true;

//         for (var k in value) {
//           debugPrint('${event.start} : ${event.end} . ${k.start} : ${k.end}}');
//           debugPrint('${event.end} earlier than ${k.start} = ${event.end!.earlierThan(k.start)}. ${event.end} earlier than ${k.end}} ${event.end!.earlierThan(k.end!)}');
//           debugPrint('${event.end} later than ${k.start} = ${event.end!.laterThan(k.start)}. ${event.start} later than ${k.start}} ${event.start.laterThan(k.start)}');
//           if ((event.end!.earlierThan(k.start) && event.start.earlierThan(k.start)) || (event.end!.laterThan(k.start) && event.start.laterThan(k.start))) {
//             // Can add to this time slot
//             canAdd = true;
//           } else {
//             // Cannot add to this time slot
//             canAdd = false;
//             break;
//           }
//         }

//         if (canAdd) {
//           // if (toDuplicate.contains(event)) {
//           //   return;
//           // }
//           // Mark as added and add the event
//           value.add(event);
//           // toDuplicate.add(event);
//           isAdded = true;
//           return;
//         }
//       });
//     }

//     // If not added to any existing slot, prepare to add a new slot
//     if (!isAdded) {
//       numbersOfDayViews += 1;
//       toAdd.add({
//         numbersOfDayViews: [event]
//       });
//     }

//     // Add new time slots to arrangeTime after iteration
//     arrangeTime.addAll(toAdd);

//     // arrangeTime = arrangeTime.toSet().toList();
//   }

//   // Populate the OverflowEventsRow map (oM)
//   // for (var eventSort in arrangeTime) {
//   //   eventSort.forEach((key, val) {
//   //     for (var ko in val) {
//   //       oM.update(
//   //         key,
//   //         (value) => value.copyWith(events: [...value.events, ko]),
//   //         ifAbsent: () => OverflowEventsRow(events: [ko], start: startOfDay, end: endOfDay),
//   //       );
//   //     }
//   //   });
//   // }

//   // Populate the OverflowEventsRow map (oM)
//   for (var eventSort in arrangeTime) {
//     eventSort.forEach((key, val) {
//       for (var ko in val) {
//         toDuplicate.add(ko);
//       }
//     });
//     toDuplicate.toSet().toList();
//   }

//   for (var update in toDuplicate) {
//     oM.update(
//       1,
//       (value) => value.copyWith(events: [...value.events, update]),
//       ifAbsent: () => OverflowEventsRow(events: [update], start: startOfDay, end: endOfDay),
//     );
//   }

//   return oM.values.toList();
// }

List<OverflowEventsRow<T>> processOverflowEvents<T extends Object>(
  List<AdvancedDayEvent<T>> sortedEvents, {
  required DateTime startOfDay,
  required DateTime endOfDay,
  bool cropBottomEvents = false,
}) {
  sortedEvents.sort((a, b) => b.duration!.inHours.compareTo(a.duration!.inHours));

  if (sortedEvents.isEmpty) return [];

  var start = sortedEvents.first.start.cleanSec();
  var end = sortedEvents.first.end!;

  final Map<DateTime, OverflowEventsRow<T>> oM = {};

  for (var event in sortedEvents) {
    if (event.start.earlierThan(end)) {
      oM.update(
        start,
        (value) => value.copyWith(events: [...value.events, event]),
        ifAbsent: () => OverflowEventsRow(events: [event], start: event.start, end: event.end!),
      );

      if (event.end!.laterThan(end)) {
        if (cropBottomEvents) {
          end = event.end!.isBefore(endOfDay) ? event.end! : endOfDay;
        } else {
          end = event.end!;
        }
        oM[start] = oM[start]!.copyWith(end: end);
      }
    } else {
      start = event.start.cleanSec();
      end = event.end!;
      oM[start] = OverflowEventsRow(events: [event], start: event.start, end: event.end!);
    }
  }

  return oM.values.toList();
}

// List<OverflowEventsRow<T>> processOverflowEvents<T extends Object>(
//   List<AdvancedDayEvent<T>> sortedEvents, {
//   required DateTime startOfDay,
//   required DateTime endOfDay,
//   bool cropBottomEvents = false,
// }) {
//   if (sortedEvents.isEmpty) return [];

//   // var start = sortedEvents.first.start.cleanSec();
//   // var end = sortedEvents.first.end!;

//   final Map<DateTime, OverflowEventsRow<T>> oM = {};

//   for (var event in sortedEvents) {
//     if (oM.isEmpty) {
//       oM.update(
//         startOfDay,
//         (value) => value.copyWith(events: [...value.events, event]),
//         ifAbsent: () => OverflowEventsRow(events: [event], start: event.start, end: event.end!),
//       );
//     } else {
//       bool isAvaliableSlot = false;
//       int countMo = 0;
//       for (var i in oM.values) {
//         for (var j in i.events) {
//           countMo += 1;
//           final eventStart = j.start;
//           final eventEnd = j.end;
//           if (event.end!.earlierThan(eventStart) && event.start.earlierThan(eventEnd!)) {
//             isAvaliableSlot = true;

//             // if (event.end!.laterThan(end)) {
//             //   if (cropBottomEvents) {
//             //     end = event.end!.isBefore(endOfDay) ? event.end! : endOfDay;
//             //   } else {
//             //     end = event.end!;
//             //   }
//             //   oM[start] = oM[start]!.copyWith(end: end);
//             // }
//           }

//           if (event.start.laterThan(eventEnd!) && event.end!.laterThan(eventStart)) {
//             isAvaliableSlot = true;
//           }
//           if (isAvaliableSlot && countMo == oM.values.length) {
//             final start = event.start.cleanSec();
//             final end = event.end!;
//             oM[startOfDay] = OverflowEventsRow(events: [event], start: start, end: end);
//           }

//           if (isAvaliableSlot == false && countMo == oM.values.length) {
//             // start = event.start.cleanSec();
//             // end = event.end!;
//             // oM[startOfDay] = OverflowEventsRow(events: [event], start: startOfDay, end: endOfDay);
//             oM.update(
//               startOfDay,
//               (value) => value.copyWith(events: [...value.events, event]),
//               ifAbsent: () => OverflowEventsRow(events: [event], start: event.start, end: event.end!),
//             );
//           }
//         }
//       }
//     }
//   }

//   return oM.values.toList();
// }

List<OverflowEventsRow<T>> processOverflowEventsyy<T extends Object>(
  List<AdvancedDayEvent<T>> sortedEvents, {
  required DateTime startOfDay,
  required DateTime endOfDay,
  bool cropBottomEvents = false,
  int maxEventsPerRow = 3, // Define max events per row
}) {
  if (sortedEvents.isEmpty) return [];

  // Sort events by start time if not already sorted
  sortedEvents.sort((a, b) => a.start.compareTo(b.start));

  // Map to store rows of overflow events
  Map<DateTime, List<OverflowEventsRow<T>>> overflowRows = {};

  // Helper to find available slots
  bool isSlotAvailable(DateTime start, DateTime end, List<OverflowEventsRow<T>> rows) {
    for (final row in rows) {
      for (final event in row.events) {
        if (!(end.isBefore(event.start) || start.isAfter(event.end!))) {
          // Overlapping slot found
          return false;
        }
      }
    }
    return true;
  }

  for (var event in sortedEvents) {
    final start = event.start.cleanSec();
    final end = cropBottomEvents && event.end!.isAfter(endOfDay) ? endOfDay : event.end!;

    // Check if any row is available
    bool added = false;

    // Iterate over existing rows for the event's start time
    if (overflowRows.containsKey(start)) {
      for (final row in overflowRows[start]!) {
        if (row.events.length < maxEventsPerRow && isSlotAvailable(event.start, end, [row])) {
          row.events.add(event);
          if (event.end!.laterThan(row.end)) {
            row.copyWith(end: event.end);
          }
          added = true;
          break;
        }
      }
    }

    // If not added, create a new row
    if (!added) {
      final newRow = OverflowEventsRow(
        events: [event],
        start: start,
        end: end,
      );

      overflowRows.update(
        start,
        (rows) => [...rows, newRow],
        ifAbsent: () => [newRow],
      );
    }
  }

  // Flatten rows and return as a list
  return overflowRows.values.expand((rows) => rows).toList();
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
    if (event.start.isBefore(startOfDay) || event.start.isAfter(endOfDay)) {
      continue;
    }
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

  bool isAfterOrEqual(DateTime other) {
    return isAfter(other) || isAtSameMomentAs(other);
  }

  bool isBeforeOrEqual(DateTime other) {
    return isBefore(other) || isAtSameMomentAs(other);
  }
}

List<DateTimeRange> findAvailableSlots({
  required DateTime startOfDay,
  required DateTime endOfDay,
  required List<DateTimeRange> existingSlots,
}) {
  final List<DateTimeRange> availableSlots = [];
  DateTime currentStart = startOfDay;

  for (var slot in existingSlots) {
    if (slot.start.isAfter(currentStart)) {
      availableSlots.add(DateTimeRange(start: currentStart, end: slot.start));
    }
    currentStart = slot.end.isAfter(currentStart) ? slot.end : currentStart;
  }

  if (currentStart.isBefore(endOfDay)) {
    availableSlots.add(DateTimeRange(start: currentStart, end: endOfDay));
  }

  return availableSlots;
}

bool addEventToCalendar<T extends Object>({
  required AdvancedDayEvent<T> newEvent,
  required List<OverflowEventsRow<T>> rows,
  required DateTime startOfDay,
  required DateTime endOfDay,
}) {
  final List<DateTimeRange> existingSlots = rows.expand((row) => row.events.map((event) => DateTimeRange(start: event.start, end: event.end!))).toList();

  final availableSlots = findAvailableSlots(
    startOfDay: startOfDay,
    endOfDay: endOfDay,
    existingSlots: existingSlots,
  );

  // Check if the event fits in an available slot
  for (var slot in availableSlots) {
    if (newEvent.start.isAfterOrEqual(slot.start) && newEvent.end!.isBeforeOrEqual(slot.end)) {
      // Add to an existing row
      for (var row in rows) {
        if (row.start.isBeforeOrEqual(newEvent.start) && row.end.isAfterOrEqual(newEvent.end!)) {
          row.events.add(newEvent);
          return true; // Event added successfully
        }
      }
    }
  }

  // If no available slots, create a new row
  rows.add(
    OverflowEventsRow(
      events: [newEvent],
      start: newEvent.start,
      end: newEvent.end!,
    ),
  );
  return true;
}
