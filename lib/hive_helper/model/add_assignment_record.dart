// lib/models/attendance_record.dart

import 'package:hive/hive.dart';

part 'add_assignment_record.g.dart';

@HiveType(typeId: 2)
class AddAssignmentRecord extends HiveObject {
  @HiveField(0)
  String projectId;

  @HiveField(1)
  String title;

  @HiveField(2)
  String descriptions;

  @HiveField(3)
  String statusId;

  @HiveField(4)
  List<Map<String, String>> members; // 'checkIn', 'checkOut', 'autoCheckOut'

  @HiveField(5)
  String? imagePath;

  AddAssignmentRecord({
    required this.projectId,
    required this.title,
    required this.descriptions,
    required this.statusId,
    required this.members,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'title': title,
        'descriptions': descriptions,
        'statusId': statusId,
        'memberDetails': members,
        'imagePath': imagePath,
      };

  factory AddAssignmentRecord.fromJson(Map<String, dynamic> json) {
    return AddAssignmentRecord(
      projectId: json['projectId'],
      title: json['title'],
      descriptions: json['descriptions'],
      statusId: json['statusId'],
      members: json['memberDetails'],
      imagePath: json['imagePath'],
    );
  }
}
