//settings_page.dart

import 'package:flutter/material.dart';
import 'package:pb_hrsystem/main.dart';

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
    return false; // Prevent default back navigation behavior
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: Colors.green,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MainScreen()),
              );
            },
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const ListTile(
              title: Text(
                'Account Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Edit Profile'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Navigate to Edit Profile Page
              },
            ),
            ListTile(
              title: const Text('Change Password'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Navigate to Change Password Page
              },
            ),
            ListTile(
              title: const Text('Enable Touch ID / Face ID'),
              trailing: Switch(
                value: _biometricEnabled,
                onChanged: (bool value) {
                  _showBiometricDialog(context);
                },
              ),
              onTap: () {
                _showBiometricDialog(context);
              },
            ),
            ListTile(
              title: const Text('Dark Mode'),
              trailing: Switch(
                value: false,
                onChanged: (bool value) {
                  // Handle Dark Mode Toggle
                },
              ),
            ),
            ListTile(
              title: const Text('Notification'),
              trailing: Switch(
                value: false,
                onChanged: (bool value) {
                  // Handle Notification Toggle
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBiometricDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Column(
            children: const [
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