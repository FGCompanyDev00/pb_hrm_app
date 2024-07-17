import 'roles.dart';

class User {
  final String id;
  final String name;
  final String role;

  User({required this.id, required this.name, required this.role});

  // Getter to fetch permissions based on the user's role...
  List<String> get permissions => UserRole.permissions[role] ?? [];
}
