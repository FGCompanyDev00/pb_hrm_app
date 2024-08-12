import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pb_hrsystem/home/profile_screen.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:pb_hrsystem/notifications/test_notification_widget.dart';
import 'package:pb_hrsystem/settings/change_password.dart';
import 'package:pb_hrsystem/settings/edit_profile.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final LocalAuthentication auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();
  bool _biometricEnabled = false;
  bool _notificationEnabled = false;
  late Future<UserProfile> futureUserProfile;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin(); // Notification plugin instance

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
    _loadNotificationSetting();
    futureUserProfile = fetchUserProfile();

    // Initialize local notifications
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    print('Notification system initialized');
  }

  Future<void> _loadBiometricSetting() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedUserId = await _storage.read(key: 'biometricUserId');
    if (storedUserId != null) {
      setState(() {
        _biometricEnabled = true;
      });
    }
  }

  Future<void> _loadNotificationSetting() async {
    bool? isEnabled = await _storage.read(key: 'notificationEnabled') == 'true';
    setState(() {
      _notificationEnabled = isEnabled ?? false;
    });
  }

  Future<void> _saveNotificationSetting(bool enabled) async {
    await _storage.write(key: 'notificationEnabled', value: enabled.toString());
  }

  Future<void> _saveBiometricSetting(bool enabled, String userId) async {
    if (enabled) {
      await _storage.write(key: 'biometricUserId', value: userId);
    } else {
      await _storage.delete(key: 'biometricUserId');
    }
  }

  Future<bool> _onWillPop() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
    return false;
  }

  Future<void> _enableBiometrics(bool enable) async {
    if (enable) {
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication is not available.'),
          ),
        );
        return;
      }
      try {
        bool authenticated = await auth.authenticate(
          localizedReason: 'Please authenticate to enable biometric login',
          options: const AuthenticationOptions(
            stickyAuth: true,
            useErrorDialogs: true,
          ),
        );
        if (authenticated) {
          setState(() {
            _biometricEnabled = true;
          });

          final prefs = await SharedPreferences.getInstance();
          String? userId = prefs.getString('userId');

          if (userId != null) {
            _saveBiometricSetting(true, userId);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error enabling biometrics: $e');
        }
      }
    } else {
      setState(() {
        _biometricEnabled = false;
      });
      await _storage.deleteAll();
      _saveBiometricSetting(false, '');
    }
  }

  Future<void> _toggleNotification(bool enable) async {
    if (enable) {
      print('Notification enabled');
      setState(() {
        _notificationEnabled = true;
      });
      _saveNotificationSetting(true);
      _showNotification();
    } else {
      print('Notification disabled');
      setState(() {
        _notificationEnabled = false;
      });
      _saveNotificationSetting(false);
    }
  }

  Future<void> _showNotification() async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'your_channel_id',
        'your_channel_name',
        channelDescription: 'your_channel_description',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);
      await flutterLocalNotificationsPlugin.show(
        0,
        'Example Notification',
        'This is an example notification',
        platformChannelSpecifics,
        payload: 'item x',
      );
      print('Notification shown');
    } catch (e) {
      print('Error showing notification: $e');
    }
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

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Settings',
            style: themeNotifier.textStyle.copyWith(fontSize: 24),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: themeNotifier.textStyle.color),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MainScreen()),
              );
            },
          ),
        ),
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(themeNotifier.backgroundImage),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  FutureBuilder<UserProfile>(
                    future: futureUserProfile,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (snapshot.hasData) {
                        String title = snapshot.data!.gender == "Male" ? "Mr." : "Ms.";
                        return _buildProfileHeader(
                          isDarkMode,
                          profileImage: snapshot.data!.imgName != 'default_avatar.jpg'
                              ? NetworkImage('https://demo-application-api.flexiflows.co/images/${snapshot.data!.imgName}')
                              : null,
                          name: '$title ${snapshot.data!.name} ${snapshot.data!.surname}',
                          email: snapshot.data!.email,
                        );
                      } else {
                        return const Center(child: Text('No data available'));
                      }
                    },
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        _buildSettingsSection('Account Settings', themeNotifier),
                        _buildSettingsTile(
                          context,
                          title: 'Profile Details',
                          icon: Icons.arrow_forward_ios,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ProfileScreen()),
                            );
                          },
                        ),
                        _buildSettingsTile(
                          context,
                          title: 'Change Password',
                          icon: Icons.arrow_forward_ios,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ChangePasswordPage()),
                            );
                          },
                        ),
                        _buildSettingsTile(
                          context,
                          title: 'Enable Touch ID / Face ID',
                          trailing: Switch(
                            value: _biometricEnabled,
                            onChanged: (bool value) {
                              _enableBiometrics(value);
                            },
                            activeColor: Colors.green,
                          ),
                        ),
                        _buildSettingsTile(
                          context,
                          title: 'Dark Mode',
                          trailing: Switch(
                            value: themeNotifier.isDarkMode,
                            onChanged: (bool value) {
                              themeNotifier.toggleTheme();
                            },
                            activeColor: Colors.green,
                          ),
                        ),
                        _buildSettingsTile(
                          context,
                          title: 'Notification',
                          trailing: Switch(
                            value: _notificationEnabled,
                            onChanged: (bool value) {
                              _toggleNotification(value);
                            },
                            activeColor: Colors.green,
                          ),
                        ),
                        _buildSettingsTile(
                          context,
                          title: 'Test Notification',
                          icon: Icons.arrow_forward_ios,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const TestNotificationWidget()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isDarkMode, {ImageProvider<Object>? profileImage, required String name, required String email}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 5,
            blurRadius: 15,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundImage: profileImage,
            backgroundColor: Colors.white,
            child: profileImage == null ? const Icon(Icons.person, size: 35) : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfilePage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, ThemeNotifier themeNotifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Text(
        title,
        style: themeNotifier.textStyle.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context, {required String title, Widget? trailing, IconData? icon, void Function()? onTap}) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        tileColor: isDarkMode ? Colors.black45 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 16,
          ),
        ),
        trailing: trailing ?? Icon(icon, color: isDarkMode ? Colors.white70 : Colors.grey),
        onTap: onTap,
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
