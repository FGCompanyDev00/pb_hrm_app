// dashboard.dart

import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approvals_page/approvals_main_page.dart';
import 'package:pb_hrsystem/home/dashboard/history/history_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking_page.dart';
import 'package:pb_hrsystem/home/qr_profile_page.dart';
import 'package:pb_hrsystem/notifications/notification_page.dart';
import 'package:pb_hrsystem/roles.dart';
import 'package:pb_hrsystem/user_model.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:pb_hrsystem/home/settings_page.dart';
import 'package:pb_hrsystem/login/login_page.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool _hasUnreadNotifications = true;
  late Future<UserProfile> futureUserProfile;
  late Future<List<String>> futureBanners;
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    Provider.of<UserProvider>(context, listen: false).fetchAndUpdateUser();
    futureUserProfile = fetchUserProfile();
    futureBanners = fetchBanners();
    _pageController = PageController(initialPage: _currentPage);

    // Auto-swiping the carousel every 5 seconds
    Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_pageController.hasClients) {
        int nextPage = _currentPage + 1;
        if (nextPage >= (_pageController.position.maxScrollExtent / _pageController.position.viewportDimension).ceil()) {
          nextPage = 0;
        }
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
        );
      }
    });
  }

  Future<UserProfile> fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');
    final userProfileBox = Hive.box<String>('userProfileBox'); // Access the already opened box as a String box

    try {
      // Fetch profile data online
      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/display/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseJson = jsonDecode(response.body);
        final List<dynamic> results = responseJson['results'];
        if (results.isNotEmpty) {
          final Map<String, dynamic> userJson = results[0];
          final userProfile = UserProfile.fromJson(userJson);

          // Save the profile as a JSON string to Hive
          await userProfileBox.put('userProfile', jsonEncode(userProfile.toJson()));

          print("Fetched and saved user profile to Hive successfully.");
          return userProfile;
        } else {
          print("Error: No data available in the response.");
          throw Exception(AppLocalizations.of(context)!.noDataAvailable);
        }
      } else {
        print("Error: Failed to fetch data. Status Code: ${response.statusCode}");
        throw Exception(AppLocalizations.of(context)!.errorWithDetails('Status Code: ${response.statusCode}'));
      }
    } catch (e) {
      print("Network error: $e. Attempting to retrieve profile from Hive.");

      // Retrieve profile from Hive if network request fails
      final cachedProfileJson = userProfileBox.get('userProfile');
      if (cachedProfileJson != null) {
        final userProfile = UserProfile.fromJson(jsonDecode(cachedProfileJson));
        print("Retrieved user profile from Hive successfully.");
        return userProfile;
      } else {
        print("Error: No cached profile data available in Hive.");
        throw Exception(AppLocalizations.of(context)!.noDataAvailable);
      }
    }
  }

  Future<List<String>> fetchBanners() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    try {
      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/app/promotions/files/active'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final results = jsonDecode(response.body)['results'];
        final banners = results.map<String>((file) => file['files'] as String).toList();

        final bannersBox = await Hive.openBox<List<String>>('bannersBox');
        await bannersBox.put('banners', banners); // Save to Hive

        return banners;
      } else {
        throw Exception("Failed to load banners");
      }
    } catch (e) {
      // Retrieve from Hive if network request fails
      final bannersBox = await Hive.openBox<List<String>>('bannersBox');
      return bannersBox.get('banners') ?? [];
    }
  }

  Future<void> _refreshUserProfile() async {
    setState(() {
      futureUserProfile = fetchUserProfile();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Removed the _hasManagementRole method as it's no longer needed

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(140.0),
          child: FutureBuilder<UserProfile>(
            future: futureUserProfile,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return AppBar();
              } else if (snapshot.hasError) {
                return AppBar(
                  title: Text(
                    AppLocalizations.of(context)!.errorWithDetails(snapshot.error.toString()),
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              } else if (snapshot.hasData) {
                final userProfile = snapshot.data!;
                return AppBar(
                  automaticallyImplyLeading: false,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  flexibleSpace: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/background.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 40.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SettingsPage()),
                                  );
                                },
                                child: const Icon(Icons.settings, color: Colors.black, size: 40),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                                    );
                                  },
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 25,
                                        backgroundImage: userProfile.imgName != 'default_avatar.jpg'
                                            ? NetworkImage(userProfile.imgName)
                                            : const AssetImage('assets/default_avatar.jpg') as ImageProvider,
                                        backgroundColor: Colors.white,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        AppLocalizations.of(context)!.greeting(userProfile.name),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  _showLogoutDialog(context);
                                },
                                child: const Icon(Icons.power_settings_new, color: Colors.black, size: 40),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                return AppBar(
                  title: Text(AppLocalizations.of(context)!.noDataAvailable),
                );
              }
            },
          ),
        ),
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 130.0,
                          child: FutureBuilder<List<String>>(
                            future: futureBanners,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return Center(child: Text(AppLocalizations.of(context)!.errorWithDetails(snapshot.error.toString())));
                              } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                return PageView.builder(
                                  controller: _pageController,
                                  itemCount: snapshot.data!.length,
                                  onPageChanged: (int index) {
                                    setState(() {
                                      _currentPage = index;
                                    });
                                  },
                                  itemBuilder: (context, index) {
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 5.0),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        image: DecorationImage(
                                          image: NetworkImage(snapshot.data![index]),
                                          fit: BoxFit.cover,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.orange,
                                            blurRadius: 10,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              } else {
                                return Center(child: Text(AppLocalizations.of(context)!.noBannersAvailable));
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 60,
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 24,
                                color: Colors.green,
                                margin: const EdgeInsets.only(right: 8),
                              ),
                              Text(
                                AppLocalizations.of(context)!.actionMenu,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                AppLocalizations.of(context)!.notification,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(width: 1),
                              Stack(
                                children: [
                                  IconButton(
                                    icon: Image.asset(
                                      'assets/notification-status.png',
                                      width: 24,
                                      height: 24,
                                      color: isDarkMode ? Colors.white : Colors.black,
                                    ),
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
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 0),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Transform.translate(
                                offset: const Offset(0, 12),
                                child: GridView.count(
                                  crossAxisCount: 3,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: 0.7,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  children: [
                                    _buildActionCard(
                                      context,
                                      'assets/data-2.png',
                                      AppLocalizations.of(context)!.history,
                                      isDarkMode,
                                          () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const HistoryPage()),
                                        );
                                      },
                                    ),
                                    _buildActionCard(
                                      context,
                                      'assets/people.png',
                                      AppLocalizations.of(context)!.approvals,
                                      isDarkMode,
                                          () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const ApprovalsMainPage()),
                                        );
                                      },
                                    ),
                                    _buildActionCard(
                                      context,
                                      'assets/status-up.png',
                                      AppLocalizations.of(context)!.workTracking,
                                      isDarkMode,
                                          () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const WorkTrackingPage()),
                                        );
                                      },
                                    ),
                                  ],
                                ));
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
    return LayoutBuilder(
      builder: (context, constraints) {

        double iconSize = constraints.maxWidth * 0.5;
        double fontSize = constraints.maxWidth * 0.1;

        fontSize = fontSize.clamp(12.0, 18.0); // Minimum 12, maximum 18

        return Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.yellow, width: 1.5),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(imagePath, height: iconSize, width: iconSize),
                  const SizedBox(height: 10),
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: fontSize,
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
      },
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 60, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.logoutTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.logoutConfirmation,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: Colors.grey.shade200,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(AppLocalizations.of(context)!.cancel),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Call logout method in UserProvider to clear session data
                          Provider.of<UserProvider>(context, listen: false).logout();

                          // Redirect to LoginPage and remove all other pages from the stack
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                                (Route<dynamic> route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(AppLocalizations.of(context)!.yesLogout),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class UserProfile {
  final String id;
  final String name;
  final String surname;
  final String email;
  final String imgName;
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
    List<String> rolesList = [];
    if (json['roles'] is List) {
      rolesList = List<String>.from(json['roles']);
    } else if (json['roles'] is String) {
      rolesList = (json['roles'] as String).split(',').map((role) => role.trim()).toList();
    }

    return UserProfile(
      id: json['id'].toString(),
      name: json['employee_name'],
      surname: json['employee_surname'],
      email: json['employee_email'],
      imgName: json['images'],
      roles: rolesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_name': name,
      'employee_surname': surname,
      'employee_email': email,
      'images': imgName,
      'roles': roles,
    };
  }
}

