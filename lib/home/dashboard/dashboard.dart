import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:pb_hrsystem/home/dashboard/Card/history_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approval/approvals_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/inventory_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/kpi_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking_page.dart';
import 'package:pb_hrsystem/home/profile_screen.dart';
import 'package:pb_hrsystem/roles.dart';
import 'package:pb_hrsystem/user_model.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:pb_hrsystem/home/myprofile_page.dart';
import 'package:pb_hrsystem/home/settings_page.dart';
import 'package:pb_hrsystem/login/login_page.dart';
import 'package:pb_hrsystem/home/notification/notification_page.dart';
import 'package:pb_hrsystem/management/management_pages.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool _hasUnreadNotifications = true;
  late Future<UserProfile> futureUserProfile;

  @override
  void initState() {
    super.initState();
    futureUserProfile = fetchUserProfile();
  }

  Future<UserProfile> fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('https://demo-application-api.flexiflows.co/api/work-tracking/project-member/get-all-employees'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> results = jsonDecode(response.body)['results'];
      final userProfile = UserProfile.fromJson(results[0]);
      return userProfile;
    } else {
      throw Exception('Failed to load user profile');
    }
  }

  Future<void> _refreshUserProfile() async {
    setState(() {
      futureUserProfile = fetchUserProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final currentUser = Provider.of<UserProvider>(context).currentUser;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Stack(
          children: [
            if (isDarkMode)
              Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/darkbg.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Column(
              children: [
                Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.1,
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: SafeArea(
                    child: Center(
                      child: FutureBuilder<UserProfile>(
                        future: futureUserProfile,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          } else if (snapshot.hasData) {
                            String title = snapshot.data!.gender == "Male" ? "Mr." : "Ms.";
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const MyProfilePage()),
                                    );
                                  },
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundImage: snapshot.data!.imgName != 'default_avatar.jpg'
                                        ? NetworkImage('https://demo-application-api.flexiflows.co/images/${snapshot.data!.imgName}')
                                        : null,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const MyProfilePage()),
                                      );
                                    },
                                    child: Text(
                                      '$title ${snapshot.data!.name} ${snapshot.data!.surname}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: isDarkMode ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.person, color: isDarkMode ? Colors.white : Colors.black),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                                        ).then((_) => _refreshUserProfile());
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.settings, color: isDarkMode ? Colors.white : Colors.black),
                                      onPressed: () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (context) => const SettingsPage()),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.power_settings_new, color: isDarkMode ? Colors.white : Colors.black),
                                      onPressed: () {
                                        _showLogoutDialog(context);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            );
                          } else {
                            return const Center(child: Text('No data available'));
                          }
                        },
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CarouselSlider(
                          options: CarouselOptions(
                            height: 150.0,
                            enlargeCenterPage: true,
                            autoPlay: true,
                            aspectRatio: 16 / 9,
                            autoPlayCurve: Curves.fastOutSlowIn,
                            enableInfiniteScroll: true,
                            autoPlayAnimationDuration: const Duration(milliseconds: 800),
                            viewportFraction: 0.8,
                          ),
                          items: [
                            'assets/banner1.png',
                            'assets/banner2.png',
                            'assets/banner3.png'
                          ].map((i) {
                            return Builder(
                              builder: (BuildContext context) {
                                return Container(
                                  width: MediaQuery.of(context).size.width,
                                  margin: const EdgeInsets.symmetric(horizontal: 5.0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(
                                      image: AssetImage(i),
                                      fit: BoxFit.cover,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 24,
                              color: Colors.green,
                              margin: const EdgeInsets.only(right: 8),
                            ),
                            Text(
                              'Action Menu',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            const Spacer(),
                            Stack(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.notifications, color: isDarkMode ? Colors.white : Colors.black),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const NotificationPage()),
                                    ).then((_) {
                                      setState(() {
                                        _hasUnreadNotifications = false;
                                      });
                                    });
                                  },
                                ),
                                if (_hasUnreadNotifications)
                                  Positioned(
                                    right: 11,
                                    top: 11,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 12,
                                        minHeight: 12,
                                      ),
                                      child: const Text(
                                        '',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            double width = constraints.maxWidth;
                            int crossAxisCount = width > 600 ? 3 : 2;
                            double childAspectRatio = width > 600 ? 1 : 1;

                            return GridView.count(
                              crossAxisCount: crossAxisCount,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: childAspectRatio,
                              mainAxisSpacing: 20,
                              crossAxisSpacing: 10,
                              children: [
                                _buildActionCard(context, 'assets/data-2.png', 'History', isDarkMode, () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const HistoryPage()),
                                  );
                                }),
                                _buildActionCard(context, 'assets/people.png', 'Approvals', isDarkMode, () {
                                  if ([
                                    UserRole.managersst,
                                    UserRole.managersbh,
                                    UserRole.managerkt
                                  ].contains(currentUser.role)) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const ManagementApprovalsPage()),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const StaffApprovalsPage()),
                                    );
                                  }
                                }),
                                _buildActionCard(context, 'assets/firstline.png', 'KPI', isDarkMode, () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const KpiPage()),
                                  );
                                }),
                                _buildActionCard(context, 'assets/status-up.png', 'Work Tracking', isDarkMode, () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const WorkTrackingPage()),
                                  );
                                }),
                                _buildActionCard(context, 'assets/shop-add.png', 'Inventory', isDarkMode, () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const InventoryPage()),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String imagePath, String title, bool isDarkMode, VoidCallback onTap) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDarkMode ? Colors.white : Colors.black, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(imagePath, height: 60, width: 60),
              const SizedBox(height: 10),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 60, color: Colors.green),
                const SizedBox(height: 16),
                const Text(
                  'LOGOUT',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Are you sure you want to log out?'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black, backgroundColor: Colors.grey.shade200,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Yes, Logout'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      employeeId: json['employee_id'],
      name: json['name'],
      surname: json['surname'],
      branchId: json['branch_id'],
      branchName: json['b_name'],
      departmentId: json['department_id'],
      departmentName: json['d_name'],
      tel: json['tel'],
      email: json['email'],
      employeeStatus: json['employee_status'],
      gender: json['gender'],
      createAt: json['create_at'],
      updateAt: json['update_at'],
      imgName: json['img_name'],
    );
  }
}
