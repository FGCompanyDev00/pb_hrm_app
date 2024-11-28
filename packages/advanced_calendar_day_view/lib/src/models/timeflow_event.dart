import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Parses color from hex string
Color parseColorTime(String colorString) {
  try {
    return Color(int.parse(colorString.replaceFirst('#', '0xff')));
  } catch (_) {
    return Colors.blueAccent;
  }
}

class Events {
  Events({
    required this.uid,
    required this.start,
    required this.end,
    required this.category,
    required this.title,
    required this.desc,
    this.isMeeting = false,
    this.id,
    this.days,
    this.leaveTypeID,
    this.requestorID,
    this.imgName,
    this.imgPath,
    this.name,
    this.location,
    this.reason,
    this.denyReason,
    this.status,
    this.createdAt,
    this.createdBy,
    this.isRepeat,
    this.videoConference,
    this.backgroundColor,
    this.outmeetingUid,
    this.members,
    this.leaveType,
  });
  final int? id;
  final DateTime start;
  final DateTime end;
  final String? requestorID;
  final String? imgName;
  final String? imgPath;
  final int? leaveTypeID;
  final String? name;
  final String title;
  final String desc;
  final String? location;
  final String? reason;
  final double? days;
  final bool isMeeting;
  final String? denyReason;
  final String category;
  final String? status;
  final String? createdAt;
  final String? createdBy;
  final String uid;
  final String? isRepeat;
  final String? videoConference;
  final Color? backgroundColor;
  final String? outmeetingUid;
  final String? leaveType;
  final List<Map<String, dynamic>>? members;

  Map<String, dynamic> toJson() => {
        'title': title,
        'startDateTime': start.toIso8601String(),
        'endDateTime': end.toIso8601String(),
        'description': desc,
        'status': status,
        'isMeeting': isMeeting ? 1 : 0,
        'location': location,
        'createdBy': createdBy,
        'imgName': imgName,
        'createdAt': createdAt,
        'uid': uid,
        'isRepeat': isRepeat,
        'videoConference': videoConference,
        'backgroundColor': backgroundColor?.value,
        'outmeetingUid': outmeetingUid,
        'leaveType': leaveType,
        'category': category,
        'days': days,
        'members': jsonEncode(members),
      };

  factory Events.fromJson(Map<String, dynamic> json) {
    return Events(
      title: json['title'],
      start: DateTime.parse(json['startDateTime']),
      end: DateTime.parse(json['endDateTime']),
      desc: json['description'],
      status: json['status'],
      isMeeting: (json['isMeeting'] as num) == 1 ? true : false,
      location: json['location'],
      createdBy: json['createdBy'],
      imgName: json['imgName'],
      createdAt: json['createdAt'],
      uid: json['uid'],
      isRepeat: json['isRepeat'],
      videoConference: json['videoConference'],
      backgroundColor: json['backgroundColor'] != null ? parseColorTime(json['backgroundColor']) : null,
      outmeetingUid: json['outmeetingUid'],
      leaveType: json['leaveType'],
      category: json['category'],
      days: (json['days'] as num?)?.toDouble(),
      members: parseMembers(json['members']),
    );
  }

  /// Returns formatted time for display
  String get formattedTime => DateFormat.jm().format(start);

  @override
  String toString() => '$title ($status) from ${DateFormat.yMMMd().format(start)} to ${DateFormat.yMMMd().format(end)}';

  static List<Map<String, dynamic>>? parseMembers(dynamic members) {
    if (members == null || members == 'null') {
      return null;
    }
    if (members is String) {
      try {
        // Parse the JSON string into a list of maps
        final List<dynamic> decoded = jsonDecode(members);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (e) {
        // Handle invalid JSON strings gracefully
        print('Error decoding members: $e');
        return null;
      }
    } else if (members is List) {
      // Directly return if it's already a list
      return members.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return null;
  }
}

class OverTimeEventsRow<T extends Object> {
  final List<Events> events;
  final DateTime start;
  final DateTime end;
  OverTimeEventsRow({
    required this.events,
    required this.start,
    required this.end,
  });

  OverTimeEventsRow<T> copyWith({
    List<Events>? events,
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

extension TimetableExtension on Events {
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

  int compare(Events other) {
    return start.isBefore(other.start) ? -1 : 1;
  }
}
