// ignore_for_file: unnecessary_null_comparison

import 'package:flutter/material.dart';

class AdvancedDayEvent<T extends Object> {
  final T value;
  final String title;
  final String category;
  final String desc;
  final DateTime start;
  final DateTime end;
  final DateTime? startDisplay;
  final DateTime? endDisplay;
  final Duration? duration;
  final Color? color;
  final String? status;
  final List<Map<String, dynamic>>? members;

  AdvancedDayEvent({
    required this.value,
    required this.title,
    required this.category,
    required this.desc,
    required this.start,
    required this.end,
    this.startDisplay,
    this.endDisplay,
    this.duration,
    this.color,
    this.members,
    this.status,
  });

  AdvancedDayEvent<T> copyWith({
    T? value,
    String? title,
    String? category,
    String? desc,
    DateTime? start,
    DateTime? end,
    DateTime? startDisplay,
    DateTime? endDisplay,
    Duration? duration,
    Color? color,
    String? status,
    List<Map<String, dynamic>>? members,
  }) {
    return AdvancedDayEvent<T>(
      value: value ?? this.value,
      title: title ?? this.title,
      category: title ?? this.category,
      desc: desc ?? this.desc,
      start: start ?? this.start,
      end: end ?? this.end,
      startDisplay: startDisplay ?? this.startDisplay,
      endDisplay: endDisplay ?? this.endDisplay,
      duration: duration ?? this.duration,
      color: color ?? this.color,
      status: status ?? this.status,
      members: members ?? this.members,
    );
  }

  @override
  String toString() {
    return 'AdvancedDayEvent(title: $title, start: $start, end: $end, desc: $desc)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AdvancedDayEvent<T> && other.value == value && other.start == start && other.end == end && other.title == title;
  }

  @override
  int get hashCode {
    return value.hashCode ^ start.hashCode ^ end.hashCode ^ title.hashCode;
  }
}

extension DayEventExtension on AdvancedDayEvent {
  int get durationInMins => end == null ? 30 : end.difference(start).inMinutes;

  int get timeGapFromZero => start.hour * 60 + start.minute;

  int minutesFrom(DateTime timePoint) => start.difference(timePoint).inMinutes;
  // (start.hour - timePoint.hour) * 60 + (start.minute - timePoint.minute);

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

  int compare(AdvancedDayEvent other) {
    return start.isBefore(other.start) ? -1 : 1;

    // if (start.hour > other.start.hour) return 1;
    // if (start.hour == other.start.hour && start.minute > other.start.minute) {
    //   return 1;
    // }
    // return -1;
  }
}
