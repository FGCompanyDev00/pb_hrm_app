import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:permission_handler/permission_handler.dart';
import 'login_page.dart'; // Ensure this import is correct
import 'location_information_page.dart'; // Ensure this import is correct
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _initializeNotifications();
    _checkPermissionAndNavigate();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _checkPermissionAndNavigate() async {
    final status = await Permission.notification.status;

    if (status.isGranted) {
      // If permission is already granted, navigate to LocationInformationPage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } else {
      // Request permission
      final newStatus = await Permission.notification.request();
      if (newStatus.isGranted) {
        // If permission granted after request, navigate to LocationInformationPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LocationInformationPage()),
        );
      } else if (newStatus.isDenied) {
        // Show dialog if permission is denied
        _showPermissionDeniedDialog();
      } else if (newStatus.isPermanentlyDenied) {
        // Open app settings if permission is permanently denied
        openAppSettings();
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Notification Permission'),
          content: const Text('Please allow notifications to stay updated with important information.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      // Handle skip
                    },
                    child:  Text(
                      AppLocalizations.of(context)!.skip,
                      style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Column(
                    children: [
                      SizedBox(height: 4),
                      Text("Lao", style: TextStyle(fontSize: 18, color: Colors.white)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Image.asset(
                  'assets/notification_image.png',
                  width: 200,
                  height: 200,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                   AppLocalizations.of(context)!.notification,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                 AppLocalizations.of(context)!.weWantToSendYou,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
              const Spacer(),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const LocationInformationPage()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child:  Text(AppLocalizations.of(context)!.next, style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  "2 of 8",
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
