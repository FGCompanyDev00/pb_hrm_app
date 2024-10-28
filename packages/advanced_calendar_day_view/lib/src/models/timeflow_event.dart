import 'package:flutter/foundation.dart';

class TimetableItem<T> {
  TimetableItem({
    required this.id,
    required this.value,
    required this.start,
    required this.end,
    required this.leaveTypeID,
    required this.days,
    this.data,
    this.requestorID,
    this.imgName,
    this.imgPath,
    this.name,
    this.title,
    this.reason,
    this.denyReason,
    this.category,
    this.status,
    this.updatedOn,
  });
  final int id;
  final DateTime start;
  final DateTime end;
  final T? data;
  final String? requestorID;
  final String? imgName;
  final String? imgPath;
  final int leaveTypeID;
  final String? name;
  final String? title;
  final String? reason;
  final double days;
  final String? denyReason;
  final String? category;
  final T value;
  final String? status;
  final DateTime? updatedOn;
}

class OverTimeEventsRow<T extends Object> {
  final List<TimetableItem> events;
  final DateTime start;
  final DateTime end;
  OverTimeEventsRow({
    required this.events,
    required this.start,
    required this.end,
  });

  OverTimeEventsRow<T> copyWith({
    List<TimetableItem>? events,
    DateTime? start,
    DateTime? end,
  }) {
    return OverTimeEventsRow<T>(
      events: events ?? this.events,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  String toString() => 'OverTimeEventsRow(events: $events, start: $start, end: $end)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is OverTimeEventsRow<T> && listEquals(other.events, events) && other.start == start && other.end == end;
  }

  @override
  int get hashCode => events.hashCode ^ start.hashCode ^ end.hashCode;
}

extension TimetableExtension on TimetableItem {
  int get durationInMins => end.difference(start).inMinutes;

  int get timeGapFromZero => start.hour * 60 + start.minute;

  int minutesFrom(DateTime timePoint) => start.difference(timePoint).inMinutes;

  bool isInThisGap(DateTime timePoint, int gap) {
    final dif = start.copyWith(second: 00).difference(timePoint.copyWith(second: 00)).inSeconds;
    return dif <= gap && dif >= 0;
    // return start.hour == timePoint.hour &&
    //     (start.minute >= timePoint.minute &&
    //         start.minute < (timePoint.minute + gap));
  }

  bool startInThisGap(DateTime timePoint, int gap) {
    return start.isAfter(timePoint) && start.isBefore(timePoint.add(Duration(minutes: gap)));
  }

  bool startAt(DateTime timePoint) => start.hour == timePoint.hour && timePoint.minute == start.minute;
  bool startAtHour(DateTime timePoint) => start.hour == timePoint.hour;

  int compare(TimetableItem other) {
    return start.isBefore(other.start) ? -1 : 1;
  }
}
