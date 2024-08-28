import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_auth/local_auth.dart';
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
  String _appVersion = 'PSBV Next demo version v1.0';

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
    _loadNotificationSetting();
    futureUserProfile = fetchUserProfile();
    _initializeNotifications();
    _loadAppVersion();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/playstore'); // Use your app's logo here
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    if (kDebugMode) {
      print('Notification system initialized');
    }
  }

  Future<void> _loadAppVersion() async {
    setState(() {
      _appVersion = 'PSBV Next demo version v1.0';
      // _appVersion = 'PSBV Next v${packageInfo.version}';
    });
  }

  // Future<void> _loadBiometricSetting() async {
  //   bool? isEnabled = await _storage.read(key: 'biometricEnabled') == 'true';
  //   setState(() {
  //     _biometricEnabled = isEnabled;
  //   });
  // }

  Future<void> _loadBiometricSetting() async {
    String? biometricEnabled = await _storage.read(key: 'biometricEnabled');
    setState(() {
        _biometricEnabled = biometricEnabled == 'true';
    });
}



  Future<void> _loadNotificationSetting() async {
    bool? isEnabled = await _storage.read(key: 'notificationEnabled') == 'true';
    setState(() {
      _notificationEnabled = isEnabled;
    });
  }

  Future<void> _saveNotificationSetting(bool enabled) async {
    await _storage.write(key: 'notificationEnabled', value: enabled.toString());
  }

  Future<void> _saveBiometricSetting(bool enabled) async {
    await _storage.write(key: 'biometricEnabled', value: enabled.toString());
  }


  Future<bool> _onWillPop() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
    return false;
  }

  // Future<void> _enableBiometrics(bool enable) async {
  //   if (enable) {
  //     bool canCheckBiometrics = await auth.canCheckBiometrics;
  //     if (!canCheckBiometrics) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Biometric authentication is not available.'),
  //         ),
  //       );
  //       return;
  //     }
  //     try {
  //       bool authenticated = await auth.authenticate(
  //         localizedReason: 'Please authenticate to enable biometric login',
  //         options: const AuthenticationOptions(
  //           stickyAuth: true,
  //           useErrorDialogs: true,
  //         ),
  //       );
  //       if (authenticated) {
  //         setState(() {
  //           _biometricEnabled = true;
  //         });
  //         await _saveBiometricSetting(true);  // Save the setting after successful authentication
  //       }
  //     } catch (e) {
  //       if (kDebugMode) {
  //         print('Error enabling biometrics: $e');
  //       }
  //     }
  //   } else {
  //     setState(() {
  //       _biometricEnabled = false;
  //     });
  //     await _storage.deleteAll(); // Clear stored biometric credentials
  //     await _saveBiometricSetting(false); // Save the setting
  //   }
  // }

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
                await _saveBiometricSetting(true);
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
        await _saveBiometricSetting(false);
    }
}


  Future<void> _toggleNotification(bool enable) async {
    if (enable) {
      setState(() {
        _notificationEnabled = true;
      });
      _saveNotificationSetting(true);
      _showNotification();
    } else {
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
        'psbv_next_channel', // Updated channel ID for app
        'PSBV Next Notifications', // Updated channel name
        channelDescription:
        'Notifications about assignments, project updates, and member changes in PSBV Next app.', // Updated channel description
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/playstore', // Use your app's logo here
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
      if (kDebugMode) {
        print('Notification shown');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error showing notification: $e');
      }
    }
  }

  Future<UserProfile> fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('https://demo-application-api.flexiflows.co/api/display/me'),
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
                        return Center(
                            child: Text('Error: ${snapshot.error}'));
                      } else if (snapshot.hasData) {
                        return _buildProfileHeader(
                          isDarkMode,
                          profileImage: snapshot.data!.imgName !=
                              'default_avatar.jpg'
                              ? NetworkImage(
                              'https://demo-application-api.flexiflows.co/images/${snapshot.data!.imgName}')
                              : null,
                          name: '${snapshot.data!.name} ${snapshot.data!.surname}',
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
                        _buildSettingsSection(
                            'Account Settings', themeNotifier),
                        _buildSettingsTile(
                          context,
                          title: 'Change Password',
                          icon: Icons.arrow_forward_ios,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                  const ChangePasswordPage()),
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
                              MaterialPageRoute(
                                  builder: (context) =>
                                  const TestNotificationWidget()),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            _appVersion,
                            style: themeNotifier.textStyle
                                .copyWith(fontSize: 14, color: Colors.grey),
                          ),
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

  Widget _buildProfileHeader(bool isDarkMode,
      {ImageProvider<Object>? profileImage,
        required String name,
        required String email}) {
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
            child: profileImage == null
                ? const Icon(Icons.person, size: 35)
                : null,
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
                MaterialPageRoute(
                    builder: (context) => const EditProfilePage()),
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
        style: themeNotifier.textStyle
            .copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context,
      {required String title,
        Widget? trailing,
        IconData? icon,
        void Function()? onTap}) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
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
        trailing:
        trailing ?? Icon(icon, color: isDarkMode ? Colors.white70 : Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

class UserProfile {
  final String id;
  final String name;
  final String surname;
  final String email;
  final String imgName;
  final String roles;

  UserProfile({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    required this.imgName,
    required this.roles,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      name: json['employee_name'],
      surname: json['employee_surname'],
      email: json['employee_email'],
      imgName: json['images'],
      roles: json['roles'],
    );
  }
}
