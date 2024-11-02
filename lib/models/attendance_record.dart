// models/attendance_record.dart

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
  String section; // 'Home', 'Office', 'Offsite'

  @HiveField(4)
  String type; // 'checkIn' or 'checkOut'

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

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
