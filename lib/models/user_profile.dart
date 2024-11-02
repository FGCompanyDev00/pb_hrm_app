//user_profile.dart

import 'package:hive/hive.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 0)
class UserProfile extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String surname;

  @HiveField(3)
  final String email;

  @HiveField(4)
  final String imgName;

  @HiveField(5)
  final List<String> roles;

  UserProfile({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    required this.imgName,
    required this.roles,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'].toString(),
      name: json['employee_name'],
      surname: json['employee_surname'],
      email: json['employee_email'],
      imgName: json['images'],
      roles: List<String>.from(json['roles']),
    );
  }
}
