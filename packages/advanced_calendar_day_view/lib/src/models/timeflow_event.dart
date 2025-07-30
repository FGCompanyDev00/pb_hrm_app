// ignore_for_file: deprecated_member_use

import 'dart:convert';

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
    this.fileName,
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
  final String? fileName;
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
        'fileName': fileName,
        'category': category,
        'days': days,
        'members': jsonEncode(members),
      };

  factory Events.fromJson(Map<String, dynamic> json) {
    return Events(
      title: _parseString(json['title']) ?? '',
      start: DateTime.parse(json['startDateTime']),
      end: DateTime.parse(json['endDateTime']),
      desc: _parseString(json['description']) ?? '',
      status: _parseString(json['status']) ?? '',
      isMeeting: _parseIsMeeting(json['isMeeting']),
      location: _parseString(json['location']),
      createdBy: _parseString(json['createdBy']),
      imgName: _parseString(json['imgName']),
      createdAt: _parseString(json['createdAt']),
      uid: _parseString(json['uid']) ?? '',
      isRepeat: _parseString(json['isRepeat']),
      videoConference: _parseString(json['videoConference']),
      backgroundColor: json['backgroundColor'] != null
          ? parseColorTime(json['backgroundColor'].toString())
          : null,
      outmeetingUid: _parseString(json['outmeetingUid']),
      leaveType: _parseString(json['leaveType']),
      fileName: _parseString(json['fileName']),
      category: _parseString(json['category']) ?? '',
      days: _parseDays(json['days']),
      members: parseMembers(json['members']),
    );
  }

  /// Helper method to safely parse string fields
  static String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  /// Helper method to safely parse isMeeting field
  static bool _parseIsMeeting(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }

  /// Helper method to safely parse days field
  static double? _parseDays(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Returns formatted time for display
  String get formattedTime => DateFormat.jm().format(start);

  @override
  String toString() =>
      '$title ($status) from ${DateFormat.yMMMd().format(start)} to ${DateFormat.yMMMd().format(end)}';

  static List<Map<String, dynamic>>? parseMembers(dynamic members) {
    if (members == null || members == 'null') {
      return null;
    }

    try {
      if (members is String) {
        try {
          // Parse the JSON string into a list of maps
          if (members.isEmpty) {
            return [];
          }
          final List<dynamic> decoded = jsonDecode(members);
          return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (e) {
          // Handle invalid JSON strings gracefully
          debugPrint('Error decoding members string: $e');
          return [];
        }
      } else if (members is List) {
        try {
          // Create a new list to avoid modifying a read-only list
          return members.map((e) {
            if (e is Map) {
              return Map<String, dynamic>.from(e);
            } else {
              debugPrint('Invalid member format: $e');
              return <String, dynamic>{};
            }
          }).toList();
        } catch (e) {
          debugPrint('Error processing members list: $e');
          return [];
        }
      } else if (members is Map) {
        // Handle case where members is a single map
        try {
          return [Map<String, dynamic>.from(members)];
        } catch (e) {
          debugPrint('Error processing members map: $e');
          return [];
        }
      }
    } catch (e) {
      debugPrint('Unexpected error in parseMembers: $e');
    }

    return [];
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
  String toString() =>
      'OverTimeEventsRow(events: $events, start: $start, end: $end)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is OverTimeEventsRow<T> &&
        listEquals(other.events, events) &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => events.hashCode ^ start.hashCode ^ end.hashCode;
}

extension TimetableExtension on Events {
  int get durationInMins => end.difference(start).inMinutes;

  int get timeGapFromZero => start.hour * 60 + start.minute;

  int minutesFrom(DateTime timePoint) => start.difference(timePoint).inMinutes;

  bool isInThisGap(DateTime timePoint, int gap) {
    final dif = start
        .copyWith(second: 00)
        .difference(timePoint.copyWith(second: 00))
        .inSeconds;
    return dif <= gap && dif >= 0;
    // return start.hour == timePoint.hour &&
    //     (start.minute >= timePoint.minute &&
    //         start.minute < (timePoint.minute + gap));
  }

  bool startInThisGap(DateTime timePoint, int gap) {
    return start.isAfter(timePoint) &&
        start.isBefore(timePoint.add(Duration(minutes: gap)));
  }

  bool startAt(DateTime timePoint) =>
      start.hour == timePoint.hour && timePoint.minute == start.minute;
  bool startAtHour(DateTime timePoint) => start.hour == timePoint.hour;

  int compare(Events other) {
    return start.isBefore(other.start) ? -1 : 1;
  }
}
