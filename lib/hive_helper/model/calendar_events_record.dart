// models/calendar_events_record.dart

import 'package:hive/hive.dart';

part 'calendar_events_record.g.dart';

@HiveType(typeId: 5)
class CalendarEventsRecord extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  DateTime startDateTime;

  @HiveField(2)
  DateTime endDateTime;

  @HiveField(3)
  String description;

  @HiveField(4)
  String status;

  @HiveField(5)
  bool isMeeting;

  @HiveField(6)
  String? location;

  @HiveField(7)
  String? createdBy;

  @HiveField(8)
  String? imgName;

  @HiveField(9)
  String? createdAt;

  @HiveField(10)
  String uid;

  @HiveField(11)
  String? isRepeat;

  @HiveField(12)
  String? videoConference;

  @HiveField(13)
  int? backgroundColor;

  @HiveField(14)
  String? outmeetingUid;

  @HiveField(15)
  String? leaveType;

  @HiveField(16)
  String category;

  @HiveField(17)
  double? days;

  @HiveField(18)
  List<String>? memberIds;

  @HiveField(19)
  List<String>? reminders;

  @HiveField(20)
  bool isAllDay;

  CalendarEventsRecord({
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
    this.memberIds,
    this.reminders,
    this.isAllDay = false,
  });
}
