import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';

class Events {
  final String title;
  final DateTime startDateTime;
  final DateTime endDateTime;
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
  final String? leaveType;
  final String category;
  final double? days;
  final List<Map<String, dynamic>>? members;

  Events({
    required this.title,
    required this.startDateTime,
    required this.endDateTime,
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
    this.leaveType,
    required this.category,
    this.days,
    this.members,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'startDateTime': startDateTime.toIso8601String(),
        'endDateTime': endDateTime.toIso8601String(),
        'description': description,
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
      startDateTime: DateTime.parse(json['startDateTime']),
      endDateTime: DateTime.parse(json['endDateTime']),
      description: json['description'],
      status: json['status'],
      isMeeting: (json['isMeeting'] as num) == 1 ? true : false,
      location: json['location'],
      createdBy: json['createdBy'],
      imgName: json['imgName'],
      createdAt: json['createdAt'],
      uid: json['uid'],
      isRepeat: json['isRepeat'],
      videoConference: json['videoConference'],
      backgroundColor: json['backgroundColor'] != null
          ? parseColor(json['backgroundColor'])
          : null,
      outmeetingUid: json['outmeetingUid'],
      leaveType: json['leaveType'],
      category: json['category'],
      days: (json['days'] as num?)?.toDouble(),
      members: parseMembers(json['members']),
    );
  }

  /// Returns formatted time for display
  String get formattedTime => DateFormat.jm().format(startDateTime);

  @override
  String toString() =>
      '$title ($status) from ${DateFormat.yMMMd().format(startDateTime)} to ${DateFormat.yMMMd().format(endDateTime)}';

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
