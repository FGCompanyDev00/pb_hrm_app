import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:workmanager/workmanager.dart';

/// Service to handle session expiration checks in the background
class SessionService {
  static const String sessionCheckTaskName = 'sessionExpiryCheck';
  static const int sessionExpiryNotificationId = 9999;
  static const int sessionWarningNotificationId = 9998;
  static const Duration sessionDuration = Duration(hours: 8);
  static const Duration warningThreshold = Duration(minutes: 30);

  // Fallback timer-based check
  static Timer? _fallbackTimer;
  static bool _isInitialized = false;
  static bool _isWorkManagerInitialized = false;

  // Flag to completely disable notifications

  // Initialize the session service
  static Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('Session service already initialized');
      return;
    }

    try {
      if (!kIsWeb && Platform.isAndroid) {
        // For Android, try to initialize Workmanager first
        await _initializeAndroidBackgroundService();
      }

      // Always set up timer-based checks as a fallback
      _setupPeriodicCheck();
      _isInitialized = true;
      debugPrint('Session service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing session service: $e');
      // Ensure fallback timer is running even if initialization fails
      _setupPeriodicCheck();
    }
  }

  static Future<void> _initializeAndroidBackgroundService() async {
    if (_isWorkManagerInitialized) return;

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false, // Set to false to reduce debug logging
      );

      await Workmanager().registerPeriodicTask(
        'sessionCheck',
        sessionCheckTaskName,
        frequency: const Duration(minutes: 15),
        initialDelay: const Duration(minutes: 1),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.linear,
        tag: 'session_check',
      );

      _isWorkManagerInitialized = true;
      debugPrint('Android background service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Android background service: $e');
      rethrow; // Propagate error to trigger fallback
    }
  }

  static void _setupPeriodicCheck() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      debugPrint('Running periodic session check (Timer-based)');
      await checkSessionStatus();
    });

    // Also check immediately
    Future.delayed(const Duration(seconds: 1), () {
      checkSessionStatus();
    });
  }

  static Future<void> _checkSessionExpiry() async {
    try {
      // Check if UserPreferences is registered before accessing it
      if (!sl.isRegistered<UserPreferences>()) {
        debugPrint(
            'UserPreferences not registered yet, attempting to register it');
        try {
          // Attempt to initialize service locator if needed
          await setupServiceLocator();

          // Double-check if it's now registered
          if (!sl.isRegistered<UserPreferences>()) {
            debugPrint(
                'Failed to register UserPreferences, skipping session check');
            return;
          }
        } catch (e) {
          debugPrint('Error registering UserPreferences: $e');
          return;
        }
      }

      final prefs = sl<UserPreferences>();

      // Check if user is logged in
      final isLoggedIn = await prefs.getLoggedInAsync() ?? false;
      if (!isLoggedIn) {
        debugPrint('User not logged in, skipping session check');
        return;
      }

      // Get login time
      final loginTime = await prefs.getLoginSessionAsync();
      if (loginTime == null) {
        debugPrint('No login time found, skipping session check');
        return;
      }

      // Calculate time difference
      final now = DateTime.now();
      final difference = now.difference(loginTime);
      debugPrint('Session time elapsed: ${difference.inMinutes} minutes');

      if (difference >= sessionDuration) {
        debugPrint('Session expired, handling expiry');
        // Notifications are disabled as per user request
        // Force logout
        await prefs.setLoggedOff();
      } else if (sessionDuration - difference <= warningThreshold) {
        final minutesLeft = (sessionDuration - difference).inMinutes;
        debugPrint('Session expiring soon, $minutesLeft minutes left');
        // Notifications are disabled as per user request
      }
    } catch (e) {
      debugPrint('Error checking session expiry: $e');
    }
  }

  // Public method to check session status
  static Future<void> checkSessionStatus() async {
    await _checkSessionExpiry();
  }

  // Cleanup method
  static Future<void> dispose() async {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;

    if (_isWorkManagerInitialized && Platform.isAndroid) {
      try {
        await Workmanager().cancelAll();
        _isWorkManagerInitialized = false;
      } catch (e) {
        debugPrint('Error canceling Workmanager tasks: $e');
      }
    }

    _isInitialized = false;
    debugPrint('Session service disposed');
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      switch (task) {
        case SessionService.sessionCheckTaskName:
          debugPrint('Executing background session check via Workmanager');
          await SessionService.checkSessionStatus();
          return true;
        default:
          return false;
      }
    } catch (e) {
      debugPrint('Background task error: $e');
      return false;
    }
  });
}
