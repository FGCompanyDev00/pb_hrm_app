import 'package:flutter/material.dart';

class AdvancedTimeEvent<T extends Object> {
  final String title;
  final DateTime startDateTime;
  final DateTime? endDateTime;
  final String description;
  final String status;
  final bool isMeeting;
  final String? location;
  final String? createdBy;
  final String? imgName;
  final String? createdAt;
  final String uid;
  final String? isRepeat;
  final String? videoConference;
  final Color? backgroundColor;
  final String? outmeetingUid;
  final String category;
  final List<Map<String, dynamic>>? members;

  AdvancedTimeEvent({
    required this.title,
    required this.startDateTime,
    this.endDateTime,
    required this.description,
    required this.status,
    required this.isMeeting,
    this.location,
    this.createdBy,
    this.imgName,
    this.createdAt,
    required this.uid,
    this.isRepeat,
    this.videoConference,
    this.backgroundColor,
    this.outmeetingUid,
    required this.category,
    this.members,
  });

  AdvancedTimeEvent<T> copyWith({
    String? title,
    DateTime? startDateTime,
    DateTime? endDateTime,
    String? description,
    String? status,
    bool? isMeeting,
    String? location,
    String? createdBy,
    String? imgName,
    String? createdAt,
    String? uid,
    String? isRepeat,
    String? videoConference,
    Color? backgroundColor,
    String? outmeetingUid,
    String? category,
    List<Map<String, dynamic>>? members,
  }) {
    return AdvancedTimeEvent<T>(
      title: title ?? this.title,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      description: description ?? this.description,
      status: status ?? this.status,
      isMeeting: isMeeting ?? this.isMeeting,
      category: title ?? this.category,
      location: title ?? this.location,
      createdBy: createdBy ?? this.createdBy,
      imgName: imgName ?? this.imgName,
      uid: uid ?? this.uid,
      isRepeat: isRepeat ?? this.isRepeat,
      videoConference: videoConference ?? this.videoConference,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      outmeetingUid: outmeetingUid ?? this.outmeetingUid,
      members: members ?? this.members,
    );
  }

  @override
  String toString() {
    return 'AdvancedTimeEvent(title: $title, start: $startDateTime, end: $endDateTime, desc: $description)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AdvancedTimeEvent<T> && other.uid == uid && other.startDateTime == startDateTime && other.endDateTime == endDateTime && other.title == title;
  }

  @override
  int get hashCode {
    return uid.hashCode ^ startDateTime.hashCode ^ endDateTime.hashCode ^ title.hashCode;
  }
}

extension TimeEventExtension on AdvancedTimeEvent {
  int get durationInMins => endDateTime == null ? 30 : endDateTime!.difference(startDateTime).inMinutes;

  int get timeGapFromZero => startDateTime.hour * 60 + startDateTime.minute;

  int minutesFrom(DateTime timePoint) => startDateTime.difference(timePoint).inMinutes;
  // (start.hour - timePoint.hour) * 60 + (start.minute - timePoint.minute);

  bool isInThisGap(DateTime timePoint, int gap) {
    final dif = startDateTime.copyWith(second: 00).difference(timePoint.copyWith(second: 00)).inSeconds;
    return dif <= gap && dif >= 0;
    // return start.hour == timePoint.hour &&
    //     (start.minute >= timePoint.minute &&
    //         start.minute < (timePoint.minute + gap));
  }

  bool startInThisGap(DateTime timePoint, int gap) {
    return startDateTime.isAfter(timePoint) && startDateTime.isBefore(timePoint.add(Duration(minutes: gap)));
  }

  bool startAt(DateTime timePoint) => startDateTime.hour == timePoint.hour && timePoint.minute == startDateTime.minute;
  bool startAtHour(DateTime timePoint) => startDateTime.hour == timePoint.hour;

  int compare(AdvancedTimeEvent other) {
    return startDateTime.isBefore(other.startDateTime) ? -1 : 1;

    // if (start.hour > other.start.hour) return 1;
    // if (start.hour == other.start.hour && start.minute > other.start.minute) {
    //   return 1;
    // }
    // return -1;
  }
}
