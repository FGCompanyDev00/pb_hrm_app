import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard.dart';
import 'package:pb_hrsystem/home/myprofile_page.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:pb_hrsystem/settings/edit_profile.dart';
import 'package:pb_hrsystem/settings/change_password.dart';
import 'package:provider/provider.dart';

import '../theme/theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _biometricEnabled = false;

  Future<bool> _onWillPop() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
    return false;
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
                MaterialPageRoute(builder: (context) => const Dashboard()),
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
                  _buildProfileHeader(isDarkMode),
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
                              MaterialPageRoute(builder: (context) => const MyProfilePage()),
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
                              _showBiometricDialog(context);
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
                            value: false,
                            onChanged: (bool value) {
                              // Handle Notification Toggle
                            },
                            activeColor: Colors.green,
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

  Widget _buildProfileHeader(bool isDarkMode) {
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
          const CircleAvatar(
            radius: 35,
            backgroundImage: AssetImage('assets/profile_picture.png'),
          ),
          const SizedBox(width: 20),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mr. Alex John',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black, // Always black
                ),
              ),
              SizedBox(height: 5),
              Text(
                'alex.john@example.com',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey, // Always grey
                ),
              ),
            ],
          ),
          const Spacer(),
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

  void _showBiometricDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Column(
            children: [
              Icon(
                Icons.fingerprint,
                size: 40,
                color: Colors.green,
              ),
              SizedBox(height: 10),
              Text(
                'Setup biometric login',
                style: TextStyle(
                  color: Colors.green,
                ),
              ),
            ],
          ),
          content: const Text(
            'Do you want to use Fingerprint as a preferred login method for the next time?',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white, backgroundColor: Colors.green, // foreground
              ),
              child: const Text('OK'),
              onPressed: () {
                setState(() {
                  _biometricEnabled = true;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
