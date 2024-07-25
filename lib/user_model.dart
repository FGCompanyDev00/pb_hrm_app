import 'package:flutter/material.dart';

import 'roles.dart';

class User {
  String id;
  String name;
  String role;

  User({required this.id, required this.name, required this.role});

  bool hasPermission(String permission) {
    return UserRole.permissions[role]?.contains(permission) ?? false;
  }
}

class UserProvider extends ChangeNotifier {
  User _currentUser = User(id: '1', name: 'Default User', role: UserRole.john);

  User get currentUser => _currentUser;

  void updateUser(User user) {
    _currentUser = user;
    notifyListeners();
  }
}
