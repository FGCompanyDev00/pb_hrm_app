import 'dart:ui';

import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

part 'event_record.g.dart';

@HiveType(typeId: 3)
class EventRecord {
  @HiveField(0)
  final String title;
  @HiveField(1)
  final DateTime startDateTime;
  @HiveField(2)
  final DateTime endDateTime;
  @HiveField(3)
  final String description;
  @HiveField(4)
  final String status;
  @HiveField(5)
  final bool isMeeting;
  @HiveField(6)
  final String? location;
  @HiveField(7)
  final String? createdBy;
  @HiveField(8)
  final String? imgName;
  @HiveField(9)
  final String? createdAt;
  @HiveField(10)
  final String uid;
  @HiveField(11)
  final String? isRepeat;
  @HiveField(12)
  final String? videoConference;
  @HiveField(13)
  final Color? backgroundColor;
  @HiveField(14)
  final String? outmeetingUid;
  @HiveField(15)
  final String? leaveType;
  @HiveField(16)
  final String category;
  @HiveField(17)
  final double? days;
  @HiveField(18)
  final List<Map<String, dynamic>>? members;

  EventRecord({
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
        'startDateTime': startDateTime,
        'endDateTime': endDateTime,
        'description': description,
        'status': status,
        'isMeeting': isMeeting,
        'location': location,
        'createdBy': createdBy,
        'imgName': imgName,
        'createdAt': createdAt,
        'uid': uid,
        'isRepeat': isRepeat,
        'videoConference': videoConference,
        'backgroundColor': backgroundColor,
        'outmeetingUid': outmeetingUid,
        'leaveType': leaveType,
        'category': category,
        'days': days,
        'members': members,
      };

  factory EventRecord.fromJson(Map<String, dynamic> json) {
    return EventRecord(
      title: json['title'],
      startDateTime: DateTime.parse(json['startDateTime']),
      endDateTime: DateTime.parse(json['endDateTime']),
      description: json['description'],
      status: json['status'],
      isMeeting: json['isMeeting'],
      location: json['location'],
      createdBy: json['createdBy'],
      imgName: json['imgName'],
      createdAt: json['createdAt'],
      uid: json['uid'],
      isRepeat: json['isRepeat'],
      videoConference: json['videoConference'],
      backgroundColor: json['backgroundColor'],
      outmeetingUid: json['outmeetingUid'],
      leaveType: json['leaveType'],
      category: json['category'],
      days: json['days'],
      members: json['members'],
    );
  }

  /// Returns formatted time for display
  String get formattedTime => DateFormat.jm().format(startDateTime);

  @override
  String toString() => '$title ($status) from ${DateFormat.yMMMd().format(startDateTime)} to ${DateFormat.yMMMd().format(endDateTime)}';
}
