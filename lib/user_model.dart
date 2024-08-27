// import 'package:flutter/material.dart';

// import 'roles.dart';

// class User {
//   String id;
//   String name;
//   String role;

//   User({required this.id, required this.name, required this.role});

//   bool hasPermission(String permission) {
//     return UserRole.permissions[role]?.contains(permission) ?? false;
//   }
// }

// class UserProvider extends ChangeNotifier {
//   User _currentUser = User(id: '1', name: 'Default User', role: UserRole.john);

//   User get currentUser => _currentUser;

//   void updateUser(User user) {
//     _currentUser = user;
//     notifyListeners();
//   }
// }

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class User {
  String id;
  String name;
  List<String> roles;

  User({required this.id, required this.name, required this.roles});

  bool hasRole(String role) {
    return roles.contains(role);
  }
}

class UserProvider extends ChangeNotifier {
  User _currentUser = User(id: '1', name: 'Default User', roles: ['User']);

  User get currentUser => _currentUser;

  void updateUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> fetchAndUpdateUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    try {
      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/display/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> userJson = jsonDecode(response.body)['results'][0];

        // Log the fetched user data
        print('Fetched user data: $userJson');

        // Split roles by comma and convert them to a list
        List<String> roles = (userJson['roles'] as String).split(',');

        // Log the parsed roles
        print('Parsed roles: $roles');

        User loggedInUser = User(
          id: userJson['id'],
          name: userJson['employee_name'],
          roles: roles,
        );

        // Log the current user being updated
        print('Updating current user to: ${loggedInUser.name} with roles: ${loggedInUser.roles}');

        updateUser(loggedInUser);
      } else {
        // Log the error response
        print('Failed to fetch user data. Status code: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      // Log any exceptions
      print('Error occurred while fetching user data: $e');
    }
  }
}

