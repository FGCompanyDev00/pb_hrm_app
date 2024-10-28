// myprofile_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import localization

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
      throw Exception(AppLocalizations.of(context)!.noTokenFound);
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
        throw Exception(AppLocalizations.of(context)!.noUserProfileData);
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
        throw Exception(AppLocalizations.of(context)!.failedToLoadRoles);
      }

      return userProfile;
    } else {
      throw Exception(AppLocalizations.of(context)!.failedToLoadUserProfile(response.reasonPhrase as Object));
    }
  }

  String formatDate(String dateStr) {
    DateTime dateTime = DateTime.parse(dateStr);
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }

  Widget buildRolesSection(String roles) {
    if (roles.trim().isEmpty) {
      roles = AppLocalizations.of(context)!.noRolesAvailable;
    }

    List<String> roleList = roles.split(',');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.rolesLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: roleList.map((role) {
              return Chip(
                label: Text(role.trim()),
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
        title: Text(
          AppLocalizations.of(context)!.myProfile,
          style: const TextStyle(
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
        toolbarHeight: 70,
      ),
      body: FutureBuilder<UserProfile>(
        future: futureUserProfile,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text(AppLocalizations.of(context)!.errorWithDetails(snapshot.error.toString())));
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
                            ProfileInfoRow(
                              icon: Icons.person,
                              label: AppLocalizations.of(context)!.gender,
                              value: snapshot.data!.gender.isNotEmpty ? snapshot.data!.gender : AppLocalizations.of(context)!.notAvailable,
                            ),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(
                              icon: Icons.badge,
                              label: AppLocalizations.of(context)!.nameAndSurname,
                              value: '${snapshot.data!.name} ${snapshot.data!.surname}',
                            ),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(
                              icon: Icons.date_range,
                              label: AppLocalizations.of(context)!.dateStartWork,
                              value: formatDate(snapshot.data!.createAt),
                            ),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(
                              icon: Icons.date_range,
                              label: AppLocalizations.of(context)!.probationEndDate,
                              value: formatDate(snapshot.data!.updateAt),
                            ),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(
                              icon: Icons.account_balance,
                              label: AppLocalizations.of(context)!.department,
                              value: snapshot.data!.departmentName.isNotEmpty ? snapshot.data!.departmentName : AppLocalizations.of(context)!.notAvailable,
                            ),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(
                              icon: Icons.location_on,
                              label: AppLocalizations.of(context)!.branch,
                              value: snapshot.data!.branchName.isNotEmpty ? snapshot.data!.branchName : AppLocalizations.of(context)!.notAvailable,
                            ),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(
                              icon: Icons.phone,
                              label: AppLocalizations.of(context)!.telephone,
                              value: snapshot.data!.tel.isNotEmpty ? snapshot.data!.tel : AppLocalizations.of(context)!.notAvailable,
                            ),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(
                              icon: Icons.email,
                              label: AppLocalizations.of(context)!.emails,
                              value: snapshot.data!.email.isNotEmpty ? snapshot.data!.email : AppLocalizations.of(context)!.notAvailable,
                            ),
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
            return Center(child: Text(AppLocalizations.of(context)!.noDataAvailable));
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
