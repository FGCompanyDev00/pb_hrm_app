// notification_permission_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../settings/theme_notifier.dart';
import 'location_information_page.dart';
import 'dart:io';

class NotificationPermissionPage extends StatefulWidget {
  const NotificationPermissionPage({super.key});

  @override
  NotificationPermissionPageState createState() =>
      NotificationPermissionPageState();
}

class NotificationPermissionPageState
    extends State<NotificationPermissionPage> {
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  bool _isRequestingPermission = false;

  @override
  void initState() {
    super.initState();
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false, // Don't request on initialization
      requestBadgePermission: false,
      requestSoundPermission: false,
      onDidReceiveLocalNotification:
          (int id, String? title, String? body, String? payload) async {
        // Handle notification received on iOS
        debugPrint('iOS local notification received: $title - $body');
      },
    );

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _requestNotificationPermission() async {
    if (_isRequestingPermission) return;

    setState(() {
      _isRequestingPermission = true;
    });

    try {
      if (Platform.isIOS) {
        // iOS-specific notification permission request
        await _requestIOSNotificationPermission();
      } else {
        // Android permission flow
        await _requestAndroidNotificationPermission();
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      _showErrorDialog(
          'Failed to request notification permission. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingPermission = false;
        });
      }
    }
  }

  Future<void> _requestIOSNotificationPermission() async {
    try {
      // Step 1: Request local notification permissions
      final bool? localResult = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true, // For important notifications
          );

      debugPrint('iOS Local Notification Permission Result: $localResult');

      // Step 2: Request Firebase messaging permissions
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('Firebase Permission Status: ${settings.authorizationStatus}');

      // Check if either permission was granted
      final bool isLocalGranted = localResult == true;
      final bool isFirebaseGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized;

      if (isLocalGranted || isFirebaseGranted) {
        debugPrint('✅ iOS notification permission granted');
        _proceedToNextScreen();
      } else {
        debugPrint('❌ iOS notification permission denied');
        _showPermissionDeniedDialog();
      }
    } catch (e) {
      debugPrint('Error requesting iOS notification permission: $e');
      // Proceed anyway to avoid blocking the user
      _proceedToNextScreen();
    }
  }

  Future<void> _requestAndroidNotificationPermission() async {
    final status = await Permission.notification.status;

    if (status.isGranted) {
      debugPrint('✅ Android notification permission already granted');
      _proceedToNextScreen();
    } else {
      // Request permission
      final result = await Permission.notification.request();

      if (mounted) {
        if (result.isGranted) {
          debugPrint('✅ Android notification permission granted');
          _proceedToNextScreen();
        } else if (result.isDenied || result.isPermanentlyDenied) {
          debugPrint('❌ Android notification permission denied');
          _showPermissionDeniedDialog();
        }
      }
    }
  }

  void _proceedToNextScreen() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => const LocationInformationPage()),
      );
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Notification Permission'),
        content: const Text(
            'Notification permission is required for important updates. Please enable notifications in Settings to continue.'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _proceedToNextScreen(); // Allow user to continue anyway
            },
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _proceedToNextScreen(); // Allow user to continue anyway
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Spacer(),
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
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  AppLocalizations.of(context)!.weWantToSendYou,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white70 : Colors.black,
                  ),
                ),
              ),
              const Spacer(),
              Center(
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _isRequestingPermission
                          ? null
                          : () => _requestNotificationPermission(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 100, vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: _isRequestingPermission
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(AppLocalizations.of(context)!.next,
                              style: const TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPageIndicator(context, isActive: true),
                    _buildPageIndicator(context, isActive: false),
                    _buildPageIndicator(context, isActive: false),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  AppLocalizations.of(context)!
                      .pageIndicator1of3, // Ensure this key exists
                  style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white70 : Colors.black),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(BuildContext context, {required bool isActive}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      width: isActive ? 12.0 : 8.0,
      height: isActive ? 12.0 : 8.0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.green : Colors.grey,
      ),
    );
  }
}
