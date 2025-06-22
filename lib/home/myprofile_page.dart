// myprofile_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/core/utils/auth_utils.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  MyProfilePageState createState() => MyProfilePageState();
}

class MyProfilePageState extends State<MyProfilePage>
    with SingleTickerProviderStateMixin {
  late Future<UserProfile> futureUserProfile;
  late AnimationController _loadingController;
  late Animation<double> _loadingAnimation;

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  @override
  void initState() {
    super.initState();
    futureUserProfile = fetchUserProfile();

    // Initialize loading animation controller
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Create loading animation with custom curve
    _loadingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.easeInOutCubic,
    ));
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  Future<UserProfile> fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    // Use centralized auth validation with redirect
    if (!await AuthUtils.validateTokenAndRedirect(token)) {
      throw Exception(AppLocalizations.of(context)!.noTokenFound);
    }

    // Fetch user profile details from new API endpoint
    final response = await http.get(
      Uri.parse('$baseUrl/api/profile/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      if (responseBody['results'] == null) {
        throw Exception(AppLocalizations.of(context)!.noUserProfileData);
      }
      final userProfile = UserProfile.fromJson(responseBody['results']);

      // Fetch roles from the separate API
      final rolesResponse = await http.get(
        Uri.parse('$baseUrl/api/display/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (rolesResponse.statusCode == 200) {
        final rolesBody = jsonDecode(rolesResponse.body);
        if (rolesBody['results'] != null && rolesBody['results'].isNotEmpty) {
          userProfile.roles = rolesBody['results'][0]['roles'];
        }
      } else {
        throw Exception(AppLocalizations.of(context)!.failedToLoadRoles);
      }

      return userProfile;
    } else {
      throw Exception(AppLocalizations.of(context)!
          .failedToLoadUserProfile(response.reasonPhrase as Object));
    }
  }

  String formatDate(String dateStr) {
    // Handle invalid date formats like 'N/A'
    if (dateStr == 'N/A' || dateStr.isEmpty) {
      return 'N/A';
    }

    try {
      DateTime dateTime = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(dateTime);
    } catch (e) {
      // Return the original string if parsing fails
      return dateStr;
    }
  }

  Widget buildRolesSection(String roles) {
    // If roles string is empty, show a localized message
    if (roles.trim().isEmpty) {
      roles = AppLocalizations.of(context)!.noRolesAvailable;
    }

    // Split the roles string into a list
    List<String> roleList = roles.split(',');

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.rolesLabel,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDarkMode
                  ? Colors.white
                  : Colors.black, // Color based on theme
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: roleList.map((role) {
              return Chip(
                label: Text(
                  role.trim(),
                  style: TextStyle(
                    color: isDarkMode
                        ? Colors.white
                        : Colors.black, // Text color based on theme
                  ),
                ),
                backgroundColor: isDarkMode
                    ? Colors.deepPurple
                    : Colors.green[200], // Background color based on theme
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer(BuildContext context, bool isDarkMode) {
    final size = MediaQuery.of(context).size;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Info Card Loading
            Card(
              elevation: 2.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              color: isDarkMode ? Colors.grey[850] : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    8,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _loadingAnimation,
                            builder: (context, child) {
                              return Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      isDarkMode
                                          ? Colors.grey[800]!
                                          : Colors.grey[300]!,
                                      isDarkMode
                                          ? Colors.grey[700]!
                                          : Colors.grey[200]!,
                                      isDarkMode
                                          ? Colors.grey[800]!
                                          : Colors.grey[300]!,
                                    ],
                                    stops: [
                                      0.0,
                                      _loadingAnimation.value,
                                      1.0,
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedBuilder(
                                  animation: _loadingAnimation,
                                  builder: (context, child) {
                                    return Container(
                                      height: 14,
                                      width: size.width * 0.3,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(7),
                                        gradient: LinearGradient(
                                          colors: [
                                            isDarkMode
                                                ? Colors.grey[800]!
                                                : Colors.grey[300]!,
                                            isDarkMode
                                                ? Colors.grey[700]!
                                                : Colors.grey[200]!,
                                            isDarkMode
                                                ? Colors.grey[800]!
                                                : Colors.grey[300]!,
                                          ],
                                          stops: [
                                            0.0,
                                            _loadingAnimation.value,
                                            1.0,
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 4),
                                AnimatedBuilder(
                                  animation: _loadingAnimation,
                                  builder: (context, child) {
                                    return Container(
                                      height: 12,
                                      width: size.width * 0.5,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        gradient: LinearGradient(
                                          colors: [
                                            isDarkMode
                                                ? Colors.grey[800]!
                                                : Colors.grey[300]!,
                                            isDarkMode
                                                ? Colors.grey[700]!
                                                : Colors.grey[200]!,
                                            isDarkMode
                                                ? Colors.grey[800]!
                                                : Colors.grey[300]!,
                                          ],
                                          stops: [
                                            0.0,
                                            _loadingAnimation.value,
                                            1.0,
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20.0),
            // Roles Info Card Loading
            Card(
              elevation: 2.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              color: isDarkMode ? Colors.grey[850] : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedBuilder(
                      animation: _loadingAnimation,
                      builder: (context, child) {
                        return Container(
                          height: 16,
                          width: size.width * 0.3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: LinearGradient(
                              colors: [
                                isDarkMode
                                    ? Colors.grey[800]!
                                    : Colors.grey[300]!,
                                isDarkMode
                                    ? Colors.grey[700]!
                                    : Colors.grey[200]!,
                                isDarkMode
                                    ? Colors.grey[800]!
                                    : Colors.grey[300]!,
                              ],
                              stops: [
                                0.0,
                                _loadingAnimation.value,
                                1.0,
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: List.generate(
                        4,
                        (index) => AnimatedBuilder(
                          animation: _loadingAnimation,
                          builder: (context, child) {
                            return Container(
                              height: 32,
                              width: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [
                                    isDarkMode
                                        ? Colors.grey[800]!
                                        : Colors.grey[300]!,
                                    isDarkMode
                                        ? Colors.grey[700]!
                                        : Colors.grey[200]!,
                                    isDarkMode
                                        ? Colors.grey[800]!
                                        : Colors.grey[300]!,
                                  ],
                                  stops: [
                                    0.0,
                                    _loadingAnimation.value,
                                    1.0,
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                  isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        title: Text(
          AppLocalizations.of(context)!.myProfile,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        toolbarHeight: 90,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<UserProfile>(
        future: futureUserProfile,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingShimmer(context, isDarkMode);
          } else if (snapshot.hasError) {
            return Center(
                child: Text(AppLocalizations.of(context)!
                    .errorWithDetails(snapshot.error.toString())));
          } else if (snapshot.hasData) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Info Card
                    Card(
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      color: isDarkMode ? Colors.grey[850] : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProfileInfoRow(
                              icon: Icons.person,
                              label: AppLocalizations.of(context)!.gender,
                              value: snapshot.data!.gender.isNotEmpty
                                  ? snapshot.data!.gender
                                  : AppLocalizations.of(context)!.notAvailable,
                              textColor:
                                  isDarkMode ? Colors.white : Colors.black,
                            ),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(
                              icon: Icons.badge,
                              label:
                                  AppLocalizations.of(context)!.nameAndSurname,
                              value:
                                  '${snapshot.data!.name} ${snapshot.data!.surname}',
                              textColor:
                                  isDarkMode ? Colors.white : Colors.black,
                            ),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(
                              icon: Icons.date_range,
                              label:
                                  AppLocalizations.of(context)!.dateStartWork,
                              value: formatDate(snapshot.data!.createAt),
                              textColor:
                                  isDarkMode ? Colors.white : Colors.black,
                            ),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(
                              icon: Icons.date_range,
                              label: AppLocalizations.of(context)!
                                  .probationEndDate,
                              value: formatDate(snapshot.data!.updateAt),
                              textColor:
                                  isDarkMode ? Colors.white : Colors.black,
                            ),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(
                              icon: Icons.account_balance,
                              label: AppLocalizations.of(context)!.department,
                              value: snapshot.data!.departmentName.isNotEmpty
                                  ? snapshot.data!.departmentName
                                  : AppLocalizations.of(context)!.notAvailable,
                              textColor:
                                  isDarkMode ? Colors.white : Colors.black,
                            ),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(
                              icon: Icons.location_on,
                              label: AppLocalizations.of(context)!.branch,
                              value: snapshot.data!.branchName.isNotEmpty
                                  ? snapshot.data!.branchName
                                  : AppLocalizations.of(context)!.notAvailable,
                              textColor:
                                  isDarkMode ? Colors.white : Colors.black,
                            ),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(
                              icon: Icons.phone,
                              label: AppLocalizations.of(context)!.telephone,
                              value: snapshot.data!.tel.isNotEmpty
                                  ? snapshot.data!.tel
                                  : AppLocalizations.of(context)!.notAvailable,
                              textColor:
                                  isDarkMode ? Colors.white : Colors.black,
                            ),
                            const SizedBox(height: 10.0),
                            ProfileInfoRow(
                              icon: Icons.email,
                              label: AppLocalizations.of(context)!.emails,
                              value: snapshot.data!.email.isNotEmpty
                                  ? snapshot.data!.email
                                  : AppLocalizations.of(context)!.notAvailable,
                              textColor:
                                  isDarkMode ? Colors.white : Colors.black,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    // Roles Info Card
                    Card(
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      color: isDarkMode ? Colors.grey[850] : Colors.white,
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
            return Center(
                child: Text(AppLocalizations.of(context)!.noDataAvailable));
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
      id: 0, // As per new API response there is no id field
      employeeId: json['employee_id'] ?? 'N/A',
      name: json['employee_name'] ?? 'N/A',
      surname: json['employee_surname'] ?? 'N/A',
      branchId: json['branch_id'] ?? 0,
      branchName: json['branch_name'] ?? 'N/A',
      departmentId:
          0, // As per new API response there is no department_id field
      departmentName: json['department_name'] ?? 'N/A',
      tel: json['employee_tel'] ?? 'N/A',
      email: json['email'] ?? 'N/A',
      employeeStatus:
          'N/A', // As per new API response there is no employee_status field
      gender: json['employee_gender'] ?? 'N/A',
      createAt: json['datestartwork'] ?? 'N/A',
      updateAt: json['passed_probation_date'] ?? 'N/A',
      imgName: json['img_name'] ?? 'avatar_placeholder.png',
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textColor;

  const ProfileInfoRow(
      {super.key,
      required this.icon,
      required this.label,
      required this.value,
      required this.textColor});

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
                Text(value, style: TextStyle(color: textColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
