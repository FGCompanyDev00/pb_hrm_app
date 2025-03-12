// models/user_profile_record.dart

import 'package:hive/hive.dart';

part 'qr_profile_page.g.dart';

@HiveType(typeId: 1)
class UserProfileRecord extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String employeeId;

  @HiveField(2)
  String name;

  @HiveField(3)
  String surname;

  @HiveField(4)
  String images;

  @HiveField(5)
  String employeeTel;

  @HiveField(6)
  String employeeEmail;

  @HiveField(7)
  String gender;

  @HiveField(8)
  String roles;

  UserProfileRecord({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.surname,
    required this.images,
    required this.employeeTel,
    required this.employeeEmail,
    this.gender = 'N/A',
    this.roles = 'No roles available',
  });

  factory UserProfileRecord.fromJson(Map<String, dynamic> json) {
    return UserProfileRecord(
      id: json['id'] ?? '',
      employeeId: json['employee_id'] ?? 'N/A',
      name: json['employee_name'] ?? 'N/A',
      surname: json['employee_surname'] ?? 'N/A',
      images: json['images'] ?? 'avatar_placeholder.png',
      employeeTel: json['employee_tel'] ?? 'N/A',
      employeeEmail: json['employee_email'] ?? 'N/A',
      gender: json['gender'] ?? 'N/A',
      roles: json['roles'] ?? 'No roles available',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': name,
      'employee_surname': surname,
      'images': images,
      'employee_tel': employeeTel,
      'employee_email': employeeEmail,
      'roles': roles,
      'gender': gender,
    };
  }

  Map<String, dynamic> userProfileRecordToJson(UserProfileRecord? instance) => <String, dynamic>{};
}

@HiveType(typeId: 2)
class QRRecord extends HiveObject {
  @HiveField(0)
  String data;

  QRRecord({
    required this.data,
  });

  factory QRRecord.fromJson(Map<String, dynamic> json) {
    return QRRecord(
      data: json['data'] ?? '',
    );
  }
}
