// lib/settings/settings_page.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:pb_hrsystem/home/notification_settings_page.dart';
import 'package:pb_hrsystem/settings/change_password.dart';
import 'package:pb_hrsystem/settings/edit_profile.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  final LocalAuthentication auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();
  bool _biometricEnabled = false;
  late Future<UserProfile> futureUserProfile;
  String _appVersion = 'PSBV Next Demo v1.0.46(46)';

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
    _loadNotificationSetting();
    futureUserProfile = fetchUserProfile();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    setState(() {
      _appVersion = 'PSBV Next Demo v1.0.46(46)';
      // _appVersion = 'PSBV Next v${packageInfo.version}';
    });
  }

  Future<void> _loadBiometricSetting() async {
    bool isEnabled = (await _storage.read(key: 'biometricEnabled') ?? 'false') == 'true';
    setState(() {
      _biometricEnabled = isEnabled;
    });
  }

  Future<void> _loadNotificationSetting() async {
    setState(() {});
  }

  Future<void> _saveBiometricSetting(bool enabled) async {
    await _storage.write(key: 'biometricEnabled', value: enabled.toString());
    debugPrint('Saved biometric, Enabled as: $enabled'); // Debugging
  }

  Future<void> _showBiometricModal() async {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/fingerprint.png',
                  height: 60,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Setup biometric login',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF9C640C),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Do you want to use Fingerprint as a preferred login method for the next time?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F1E0),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _enableBiometrics(true); // Call the function to enable biometrics
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDBB342),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('OK'),
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

  Future<void> _enableBiometrics(bool enable) async {
    if (enable) {
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.biometricNotAvailable),
            ),
          );
        }
        return;
      }
      try {
        bool authenticated = await auth.authenticate(
          localizedReason: AppLocalizations.of(context)!.authenticateToEnableBiometrics,
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.errorEnablingBiometrics(e.toString())),
            ),
          );
        }
      }
    } else {
      setState(() {
        _biometricEnabled = false;
      });
      await _storage.delete(key: 'biometricEnabled');
      await _saveBiometricSetting(false);
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

    return WillPopScope(
      onWillPop: () async {
        // Schedule the navigation to occur after the current frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const Dashboard()),
            (route) => false,
          );
        });
        // Prevent the default pop action
        return false;
      },
      child: Scaffold(
        backgroundColor: themeNotifier.isDarkMode ? Colors.black : Colors.white,
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  themeNotifier.isDarkMode ? 'assets/darkbg.png' : 'assets/background.png',
                ),
                fit: BoxFit.cover,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
          centerTitle: true,
          title: Text(
            AppLocalizations.of(context)!.settings,
            style: TextStyle(
              color: themeNotifier.isDarkMode ? Colors.white : Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: themeNotifier.isDarkMode ? Colors.white : Colors.black,
              size: 20,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          toolbarHeight: 100,
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
                            color: themeNotifier.isDarkMode ? Colors.grey[300] : Colors.grey,
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
                          MaterialPageRoute(builder: (context) => const ChangePasswordPage()),
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
                          MaterialPageRoute(builder: (context) => const EditProfilePage()),
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
                          if (value) {
                            _showBiometricModal();
                          } else {
                            _enableBiometrics(false); // Disable biometrics
                          }
                        },
                        activeColor: const Color(0xFFDBB342),
                        inactiveTrackColor: themeNotifier.isDarkMode ? Colors.grey[700] : Colors.grey[300],
                      ),
                    ),
                    // Enable Dark Mode Switch
                    _buildSettingsTile(
                      context,
                      title: 'Dark Mode',
                      trailing: Switch(
                        value: themeNotifier.isDarkMode,
                        onChanged: (bool value) {
                          themeNotifier.toggleTheme();
                        },
                        activeColor: const Color(0xFFDBB342),
                        inactiveThumbColor: themeNotifier.isDarkMode ? Colors.grey[600] : Colors.grey,
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
                          MaterialPageRoute(builder: (context) => const NotificationSettingsPage()),
                        );
                      },
                    ),
                    // PIN Fallback Page Test Tile
                    // _buildSettingsTile(
                    //   context,
                    //   title: AppLocalizations.of(context)!.password,
                    //   icon: Icons.arrow_forward_ios,
                    //   onTap: () {
                    //     Navigator.push(
                    //       context,
                    //       MaterialPageRoute(builder: (context) => const PinEntryPage()),
                    //     );
                    //   },
                    // ),
                    // Display App Version
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        _appVersion,
                        style: themeNotifier.textStyle.copyWith(
                          fontSize: 14,
                          color: themeNotifier.isDarkMode ? Colors.grey[400] : Colors.grey,
                        ),
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

  Widget _buildSettingsTile(
    BuildContext context, {
    required String title,
    Widget? trailing,
    IconData? icon,
    void Function()? onTap,
  }) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        tileColor: isDarkMode ? Colors.grey[800] : Colors.white,
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
