import 'roles.dart';

class User {
  final String id;
  final String name;
  final String surname;
  final String role;
  final String email;

  User({
    required this.id,
    required this.name,
    required this.surname,
    required this.role,
    required this.email,
  });

  List<String> get permissions => UserRole.permissions[role] ?? [];

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      name: json['name'],
      surname: json['surname'],
      role: json['role'],
      email: json['email'],
    );
  }
}
