import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';

class TestNotificationWidget extends StatefulWidget {
  const TestNotificationWidget({super.key});

  @override
  TestNotificationWidgetState createState() => TestNotificationWidgetState();
}

class TestNotificationWidgetState extends State<TestNotificationWidget> {
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  String _permissionStatus = 'Unknown';
  String _lastNotificationResult = '';

  @override
  void initState() {
    super.initState();
    _initializeNotificationPlugin();
    _checkPermissions();
  }

  void _initializeNotificationPlugin() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      onDidReceiveLocalNotification:
          (int id, String? title, String? body, String? payload) async {
        debugPrint('iOS local notification received: $title - $body');
      },
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _checkPermissions() async {
    try {
      final status = await Permission.notification.status;
      setState(() {
        _permissionStatus = status.toString();
      });

      if (Platform.isIOS) {
        // Check iOS-specific notification settings
        final iosPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();

        if (iosPlugin != null) {
          final settings = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true,
          );
          debugPrint('iOS notification permission result: $settings');
        }

        // Check Firebase messaging permission
        final firebaseSettings =
            await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        debugPrint(
            'Firebase permission status: ${firebaseSettings.authorizationStatus}');
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      setState(() {
        _permissionStatus = 'Error: $e';
      });
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final status = await Permission.notification.request();
      setState(() {
        _permissionStatus = status.toString();
      });

      if (status.isGranted) {
        debugPrint('✅ Notification permission granted');
      } else if (status.isDenied || status.isPermanentlyDenied) {
        debugPrint('❌ Notification permission denied');
      }
    } catch (e) {
      debugPrint('Error requesting permission: $e');
      setState(() {
        _permissionStatus = 'Error: $e';
      });
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'test_channel',
        'Test Notifications',
        channelDescription: 'Channel for test notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await flutterLocalNotificationsPlugin.show(
        0,
        'Test Notification',
        'This is a test notification from the app',
        platformChannelSpecifics,
        payload: 'test_payload',
      );

      setState(() {
        _lastNotificationResult = 'Test notification sent successfully!';
      });
    } catch (e) {
      debugPrint('Error sending test notification: $e');
      setState(() {
        _lastNotificationResult = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Notifications'),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Permission Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current Status: $_permissionStatus',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _requestPermissions,
                        child: const Text('Request Permission'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Notification',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Platform: ${Platform.isIOS ? 'iOS' : 'Android'}',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _sendTestNotification,
                        child: const Text('Send Test Notification'),
                      ),
                      if (_lastNotificationResult.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _lastNotificationResult,
                          style: TextStyle(
                            color: _lastNotificationResult.contains('Error')
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Debug Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'iOS Version: ${Platform.operatingSystemVersion}',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Device: ${Platform.isIOS ? 'iPhone/iPad' : 'Android'}',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
