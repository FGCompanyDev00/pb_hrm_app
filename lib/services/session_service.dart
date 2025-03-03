import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:workmanager/workmanager.dart';

/// Service to handle session expiration checks in the background
class SessionService {
  static const String sessionCheckTaskName = 'sessionExpiryCheck';
  static const int sessionExpiryNotificationId = 9999;
  static const int sessionWarningNotificationId = 9998;

  // Flag to track if workmanager is available
  static bool _isWorkmanagerAvailable = false;

  // Initialize the session service
  static Future<void> initialize() async {
    try {
      // Only initialize on supported mobile platforms and not in web or desktop
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        // Check if we're running on a simulator/emulator
        bool isEmulator = false;
        try {
          // Simple check for emulator - can be enhanced with device_info_plus
          if (Platform.isAndroid) {
            isEmulator = await _isAndroidEmulator();
          } else if (Platform.isIOS) {
            isEmulator = await _isIosSimulator();
          }
        } catch (e) {
          debugPrint('Error detecting emulator: $e');
          // Assume it's not an emulator if detection fails
          isEmulator = false;
        }

        // Workmanager might not work properly on emulators
        if (isEmulator) {
          debugPrint(
              'Running on emulator - workmanager may not function properly');
        }

        // Try to initialize workmanager with error handling
        try {
          await Workmanager().initialize(
            callbackDispatcher,
            isInDebugMode: false,
          );
          _isWorkmanagerAvailable = true;

          // Only register task if initialization was successful
          await registerSessionExpiryCheck();
          debugPrint('SessionService initialized successfully');
        } catch (e) {
          _isWorkmanagerAvailable = false;
          // Handle specific MissingPluginException
          if (e.toString().contains('MissingPluginException')) {
            debugPrint(
                'Workmanager plugin not available on this platform or build');
          } else {
            debugPrint('Error initializing workmanager: $e');
          }
          // Continue app execution even if workmanager fails
        }
      } else {
        debugPrint(
            'SessionService: Workmanager not supported on this platform');
      }
    } catch (e) {
      // Catch any platform-related errors
      debugPrint('SessionService initialization error: $e');
    }
  }

  // Simple check for Android emulator
  static Future<bool> _isAndroidEmulator() async {
    try {
      // This is a simple check - for production, use device_info_plus
      return Platform.environment.containsKey('ANDROID_EMULATOR') ||
          Platform.environment.containsKey('ANDROID_SDK_ROOT');
    } catch (e) {
      return false;
    }
  }

  // Simple check for iOS simulator
  static Future<bool> _isIosSimulator() async {
    try {
      // This is a simple check - for production, use device_info_plus
      return !File('/dev/disk0').existsSync();
    } catch (e) {
      return false;
    }
  }

  // Register the background task for session expiry check
  static Future<void> registerSessionExpiryCheck() async {
    // Skip if workmanager is not available
    if (!_isWorkmanagerAvailable) {
      debugPrint(
          'Skipping session expiry check registration - workmanager not available');
      return;
    }

    try {
      await Workmanager().registerPeriodicTask(
        sessionCheckTaskName,
        sessionCheckTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 5),
      );
      debugPrint('Session expiry check registered successfully');
    } catch (e) {
      debugPrint('Error registering session expiry check: $e');
      // Continue app execution even if registration fails
    }
  }

  // Cancel the background task
  static Future<void> cancelSessionExpiryCheck() async {
    // Skip if workmanager is not available
    if (!_isWorkmanagerAvailable) {
      debugPrint(
          'Skipping session expiry check cancellation - workmanager not available');
      return;
    }

    try {
      await Workmanager().cancelByUniqueName(sessionCheckTaskName);
      debugPrint('Session expiry check cancelled successfully');
    } catch (e) {
      debugPrint('Error cancelling session expiry check: $e');
    }
  }

  // Check session status manually (can be used as fallback when workmanager is unavailable)
  static Future<void> checkSessionStatus() async {
    try {
      await _checkSessionExpiry();
    } catch (e) {
      debugPrint('Error checking session status manually: $e');
    }
  }
}

/// The callback function that will be called by Workmanager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      if (taskName == SessionService.sessionCheckTaskName) {
        await _checkSessionExpiry();
      }
      return Future.value(true);
    } catch (e) {
      debugPrint('Error in background task: $e');
      // Return true to prevent Workmanager from retrying the task
      return Future.value(true);
    }
  });
}

/// Check if the session has expired or is about to expire
Future<void> _checkSessionExpiry() async {
  try {
    final prefs = sl<UserPreferences>();

    // Check if user is logged in
    final isLoggedIn = await prefs.getLoggedInAsync() ?? false;
    if (!isLoggedIn) return;

    // Get login time
    final loginTime = await prefs.getLoginSessionAsync();
    if (loginTime == null) return;

    // Calculate time difference
    final now = DateTime.now();
    final difference = now.difference(loginTime);

    // Session validity is 8 hours
    const sessionDuration = Duration(hours: 8);

    if (difference >= sessionDuration) {
      // Session has expired - show notification
      await _showSessionExpiredNotification();
    } else if (sessionDuration - difference <= const Duration(minutes: 30)) {
      // Session will expire in less than 30 minutes - show warning
      final minutesLeft = (sessionDuration - difference).inMinutes;
      await _showSessionExpiryWarningNotification(minutesLeft);
    }
  } catch (e) {
    debugPrint('Error checking session expiry: $e');
  }
}

/// Show a notification that the session has expired
Future<void> _showSessionExpiredNotification() async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize notification settings
  await _initializeNotifications();

  // Android notification details
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'session_expiry_channel',
    'Session Expiry Notifications',
    channelDescription: 'Notifications about session expiry',
    importance: Importance.high,
    priority: Priority.high,
  );

  // iOS notification details
  const DarwinNotificationDetails iOSPlatformChannelSpecifics =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  // Combined platform-specific details
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
  );

  // Show the notification
  await flutterLocalNotificationsPlugin.show(
    SessionService.sessionExpiryNotificationId,
    'Session Expired',
    'Your session has expired. Please log in again.',
    platformChannelSpecifics,
    payload: 'session_expired',
  );
}

/// Show a notification warning that the session will expire soon
Future<void> _showSessionExpiryWarningNotification(int minutesLeft) async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize notification settings
  await _initializeNotifications();

  // Android notification details
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'session_expiry_channel',
    'Session Expiry Notifications',
    channelDescription: 'Notifications about session expiry',
    importance: Importance.high,
    priority: Priority.high,
  );

  // iOS notification details
  const DarwinNotificationDetails iOSPlatformChannelSpecifics =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  // Combined platform-specific details
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
  );

  // Show the notification
  await flutterLocalNotificationsPlugin.show(
    SessionService.sessionWarningNotificationId,
    'Session Expiring Soon',
    'Your session will expire in $minutesLeft minutes. Please save your work.',
    platformChannelSpecifics,
    payload: 'session_warning',
  );
}

/// Initialize the notifications plugin
Future<void> _initializeNotifications() async {
  try {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // For Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/playstore');

    // For iOS
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      onDidReceiveLocalNotification:
          (int id, String? title, String? body, String? payload) async {
        debugPrint(
            'Received iOS local notification: id=$id, title=$title, body=$body');
      },
    );

    // Combine settings
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize the plugin with error handling
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification response received: ${response.payload}');
      },
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('Notification initialization timed out');
        throw TimeoutException('Notification initialization timed out');
      },
    );

    // Create notification channel for Android
    if (!kIsWeb && Platform.isAndroid) {
      try {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'session_expiry_channel',
          'Session Expiry Notifications',
          description: 'Notifications about session expiry',
          importance: Importance.high,
        );

        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      } catch (e) {
        debugPrint('Error creating Android notification channel: $e');
        // Continue even if channel creation fails
      }
    }
  } catch (e) {
    debugPrint('Error initializing notifications: $e');
    // Continue even if notification initialization fails
  }
}
