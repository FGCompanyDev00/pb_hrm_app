// ignore_for_file: unused_import, unnecessary_import, library_private_types_in_public_api

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../login/location_information_page.dart';

class NotificationPermissionPage extends StatefulWidget {
  const NotificationPermissionPage({super.key});

  @override
  _NotificationPermissionPageState createState() =>
      _NotificationPermissionPageState();
}

class _NotificationPermissionPageState
    extends State<NotificationPermissionPage> {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    if (Platform.isIOS) {
      try {
        final bool? result = await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
              critical: true, // For important notifications
            );

        debugPrint('iOS Notification Permission Result: $result');

        if (result == true) {
          // Also request Firebase messaging permission for complete coverage
          final settings = await FirebaseMessaging.instance.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );

          debugPrint(
              'Firebase Permission Status: ${settings.authorizationStatus}');

          if (settings.authorizationStatus == AuthorizationStatus.authorized) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const LocationInformationPage()),
              );
            }
          } else {
            _showPermissionDeniedDialog();
          }
        } else {
          _showPermissionDeniedDialog();
        }
      } catch (e) {
        debugPrint('Error requesting iOS notification permission: $e');
        _showPermissionDeniedDialog();
      }
    } else {
      // Existing Android permission flow
      // ... rest of the Android code ...
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Denied'),
        content: const Text(
            'Notification permission denied. Please enable notifications in settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Permission'),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
