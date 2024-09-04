import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  _MyProfilePageState createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  late Future<UserProfile> futureUserProfile;

  @override
  void initState() {
    super.initState();
    futureUserProfile = fetchUserProfile();
  }

  Future<UserProfile> fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    if (token == null) {
      throw Exception('No token found');
    }

    // Fetch user profile details (without roles)
    final response = await http.get(
      Uri.parse('https://demo-application-api.flexiflows.co/api/work-tracking/project-member/get-all-employees'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      if (responseBody['results'] == null || responseBody['results'].isEmpty) {
        throw Exception('No user profile data found');
      }
      final userProfile = UserProfile.fromJson(responseBody['results'][0]);

      // Fetch roles from the separate API
      final rolesResponse = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/display/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (rolesResponse.statusCode == 200) {
        final rolesBody = jsonDecode(rolesResponse.body);
        if (rolesBody['results'] != null && rolesBody['results'].isNotEmpty) {
          userProfile.roles = rolesBody['results'][0]['roles']; // Set the roles from the second API
        }
      } else {
        throw Exception('Failed to load roles');
      }

      return userProfile;
    } else {
      throw Exception('Failed to load user profile: ${response.reasonPhrase}');
    }
  }

  String formatDate(String dateStr) {
    DateTime dateTime = DateTime.parse(dateStr);
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }

  Widget buildRolesSection(String roles) {
    List<String> roleList = roles.split(',');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Roles:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: roleList.map((role) {
              return Chip(
                label: Text(role),
                backgroundColor: Colors.green[100],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
      ),
      body: FutureBuilder<UserProfile>(
        future: futureUserProfile,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProfileInfoRow(icon: Icons.person, label: 'Gender', value: snapshot.data!.gender),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(icon: Icons.badge, label: 'Name & Surname', value: '${snapshot.data!.name} ${snapshot.data!.surname}'),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(icon: Icons.date_range, label: 'Date Start Work', value: formatDate(snapshot.data!.createAt)),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(icon: Icons.date_range, label: 'Passes Probation Date', value: formatDate(snapshot.data!.updateAt)),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(icon: Icons.account_balance, label: 'Department', value: snapshot.data!.departmentName),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(icon: Icons.location_on, label: 'Branch', value: snapshot.data!.branchName),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(icon: Icons.phone, label: 'Tel.', value: snapshot.data!.tel),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(icon: Icons.email, label: 'Emails', value: snapshot.data!.email),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    Card(
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: buildRolesSection(snapshot.data!.roles),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return const Center(child: Text('No data available'));
          }
        },
      ),
    );
  }

}

class UserProfile {
  final int id;
  final String employeeId;
  final String name;
  final String surname;
  final int branchId;
  final String branchName;
  final int departmentId;
  final String departmentName;
  final String tel;
  final String email;
  final String employeeStatus;
  final String gender;
  final String createAt;
  final String updateAt;
  final String imgName;
  String roles;

  UserProfile({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.surname,
    required this.branchId,
    required this.branchName,
    required this.departmentId,
    required this.departmentName,
    required this.tel,
    required this.email,
    required this.employeeStatus,
    required this.gender,
    required this.createAt,
    required this.updateAt,
    required this.imgName,
    this.roles = 'No roles available',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? 0,
      employeeId: json['employee_id'] ?? 'N/A',
      name: json['name'] ?? 'N/A',
      surname: json['surname'] ?? 'N/A',
      branchId: json['branch_id'] ?? 0,
      branchName: json['b_name'] ?? 'N/A',
      departmentId: json['department_id'] ?? 0,
      departmentName: json['d_name'] ?? 'N/A',
      tel: json['tel'] ?? 'N/A',
      email: json['email'] ?? 'N/A',
      employeeStatus: json['employee_status'] ?? 'N/A',
      gender: json['gender'] ?? 'N/A',
      createAt: json['create_at'] ?? 'N/A',
      updateAt: json['update_at'] ?? 'N/A',
      imgName: json['img_name'] ?? 'default_avatar.jpg',
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const ProfileInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
