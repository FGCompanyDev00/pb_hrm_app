// lib/models/attendance_record.dart

import 'package:hive/hive.dart';

part 'attendance_record.g.dart';

@HiveType(typeId: 0)
class AttendanceRecord extends HiveObject {
  @HiveField(0)
  String deviceId;

  @HiveField(1)
  String latitude;

  @HiveField(2)
  String longitude;

  @HiveField(3)
  String section;

  @HiveField(4)
  String type; // 'checkIn', 'checkOut', 'autoCheckOut'

  @HiveField(5)
  DateTime timestamp;

  AttendanceRecord({
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    required this.section,
    required this.type,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'latitude': latitude,
    'longitude': longitude,
    'section': section,
    'type': type,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      deviceId: json['deviceId'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      section: json['section'],
      type: json['type'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
