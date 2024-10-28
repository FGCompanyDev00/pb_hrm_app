// settings_page.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pb_hrsystem/home/notification_settings_page.dart';
import 'package:pb_hrsystem/settings/change_password.dart';
import 'package:pb_hrsystem/settings/edit_profile.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import localization

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
  String _appVersion = 'PSBV Next Demo v1.0.16'; // Updated version

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
    AndroidInitializationSettings('@mipmap/playstore');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    if (kDebugMode) {
      print('Notification system initialized');
    }
  }

  Future<void> _loadAppVersion() async {
    setState(() {
      _appVersion = 'PSBV Next Demo v1.0.16';
      // _appVersion = 'PSBV Next v${packageInfo.version}';
    });
  }

  Future<void> _loadBiometricSetting() async {
    bool? isEnabled = await _storage.read(key: 'biometricEnabled') == 'true';
    setState(() {
      _biometricEnabled = isEnabled;
    });
  }

  Future<void> _loadNotificationSetting() async {
    bool? isEnabled =
        await _storage.read(key: 'notificationEnabled') == 'true';
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
    Navigator.pop(context);
    return false;
  }

  Future<void> _enableBiometrics(bool enable) async {
    if (enable) {
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.biometricNotAvailable),
          ),
        );
        return;
      }
      try {
        bool authenticated = await auth.authenticate(
          localizedReason:
          AppLocalizations.of(context)!.authenticateToEnableBiometrics,
          options: const AuthenticationOptions(
            stickyAuth: true,
            useErrorDialogs: true,
          ),
        );
        if (authenticated) {
          setState(() {
            _biometricEnabled = true;
          });
          await _saveBiometricSetting(true); // Save the setting after successful authentication
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error enabling biometrics: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorEnablingBiometrics(e.toString())),
          ),
        );
      }
    } else {
      setState(() {
        _biometricEnabled = false;
      });
      await _storage.deleteAll(); // Clear stored biometric credentials
      await _saveBiometricSetting(false); // Save the setting
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
        'Notifications about assignments, project updates, and member changes in PSBV Next app.',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/playstore',
      );
      const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
      await flutterLocalNotificationsPlugin.show(
        0,
        AppLocalizations.of(context)!.exampleNotificationTitle,
        AppLocalizations.of(context)!.exampleNotificationBody,
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
      throw Exception(AppLocalizations.of(context)!.failedToLoadUserProfile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: false,
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
          centerTitle: true,
          title: Text(
            AppLocalizations.of(context)!.settings,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          toolbarHeight: 80,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Account Settings Header
                    Row(
                      children: [
                        Image.asset(
                          'assets/account_settings.png',
                          width: 24,
                          height: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          AppLocalizations.of(context)!.accountSettings,
                          style: themeNotifier.textStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Change Password Tile
                    _buildSettingsTile(
                      context,
                      title: AppLocalizations.of(context)!.changePassword,
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ChangePasswordPage()),
                        );
                      },
                    ),
                    // Edit Profile Tile
                    _buildSettingsTile(
                      context,
                      title: AppLocalizations.of(context)!.editProfile,
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const EditProfilePage()),
                        );
                      },
                    ),
                    // Enable Biometric Authentication Switch
                    _buildSettingsTile(
                      context,
                      title: AppLocalizations.of(context)!.enableBiometricAuth,
                      trailing: Switch(
                        value: _biometricEnabled,
                        onChanged: (bool value) {
                          _enableBiometrics(value);
                        },
                        activeColor: Colors.green,
                      ),
                    ),
                    // Notification Tile
                    _buildSettingsTile(
                      context,
                      title: AppLocalizations.of(context)!.notification,
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => NotificationSettingsPage()),
                        );
                      },
                    ),
                    // Display App Version
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
