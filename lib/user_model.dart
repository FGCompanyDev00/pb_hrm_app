//user_model.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// User Model
class User {
  String id;
  String name;
  List<String> roles;

  User({required this.id, required this.name, required this.roles});

  bool hasRole(String role) {
    return roles.contains(role);
  }
}

// User Provider that includes token management and API interaction
class UserProvider extends ChangeNotifier {
  final prefs = sl<UserPreferences>();
  User _currentUser = User(id: '1', name: 'Default User', roles: ['User']);
  bool _isLoggedIn = false;
  String _token = '';
  DateTime? _loginTime;
  final _secureStorage = const FlutterSecureStorage();
  // Session expiry notification ID
  static const int sessionExpiryNotificationId = 9999;
  // Global navigator key to access context from anywhere
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  // Flag to prevent showing multiple expiry dialogs
  bool _isShowingExpiryDialog = false;

  User get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  String get token => _token;

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  UserProvider() {
    loadUser();
  }

  // Public method to load user login status and token from shared preferences
  Future<void> loadUser() async {
    // Try to load from secure storage first (especially for iOS)
    if (Platform.isIOS) {
      final secureToken = await _secureStorage.read(key: 'secure_token');
      final secureLoginTime =
          await _secureStorage.read(key: 'secure_login_time');
      final secureIsLoggedIn =
          await _secureStorage.read(key: 'secure_is_logged_in');

      if (secureToken != null && secureIsLoggedIn == 'true') {
        _token = secureToken;
        _isLoggedIn = true;
        _loginTime =
            secureLoginTime != null ? DateTime.tryParse(secureLoginTime) : null;

        // Sync with SharedPreferences for consistency
        if (_token.isNotEmpty) {
          await prefs.setToken(_token);
        }
        if (_isLoggedIn) {
          await prefs.setLoggedIn(true);
        }
        if (_loginTime != null) {
          await prefs.setLoginSession(_loginTime.toString());
        }

        debugPrint(
            'iOS: Loaded session from secure storage: token=$_token, isLoggedIn=$_isLoggedIn, loginTime=$_loginTime');
        notifyListeners();
        return;
      }
    }

    // Fall back to SharedPreferences (works reliably on Android)
    if (Platform.isIOS) {
      // Use async methods for iOS
      _isLoggedIn = await prefs.getLoggedInAsync() ?? false;
      _token = await prefs.getTokenAsync() ?? '';
      _loginTime = await prefs.getLoginSessionAsync();
      debugPrint(
          'iOS: Loaded session from SharedPreferences: token=$_token, isLoggedIn=$_isLoggedIn, loginTime=$_loginTime');
    } else {
      // Use sync methods for Android
      _isLoggedIn = prefs.getLoggedIn() ?? false;
      _token = prefs.getToken() ?? '';
      _loginTime = prefs.getLoginSession();
      debugPrint(
          'Android: Loaded session: token=$_token, isLoggedIn=$_isLoggedIn, loginTime=$_loginTime');
    }

    notifyListeners();
  }

  bool get isSessionValid {
    if (_loginTime == null) return false;
    return DateTime.now().difference(_loginTime!).inHours < 8;
  }

  // Check if session is about to expire (less than 30 minutes remaining)
  bool get isSessionAboutToExpire {
    if (_loginTime == null) return false;
    final Duration timeLeft =
        Duration(hours: 8) - DateTime.now().difference(_loginTime!);
    return timeLeft.inMinutes > 0 && timeLeft.inMinutes < 30;
  }

  // Get remaining session time in minutes
  int get remainingSessionTimeInMinutes {
    if (_loginTime == null) return 0;
    final Duration timeLeft =
        Duration(hours: 8) - DateTime.now().difference(_loginTime!);
    return timeLeft.inMinutes > 0 ? timeLeft.inMinutes : 0;
  }

  // Check session status and show expiry dialog if needed
  Future<void> checkSessionStatus(BuildContext context) async {
    if (!_isLoggedIn) return;

    if (!isSessionValid && !_isShowingExpiryDialog) {
      _isShowingExpiryDialog = true;
      await showSessionExpiredDialog(context);
      _isShowingExpiryDialog = false;
    } else if (isSessionAboutToExpire) {
      // Schedule a notification if session is about to expire
      await scheduleSessionExpiryNotification();
    }
  }

  // Show session expired dialog and redirect to login
  Future<void> showSessionExpiredDialog(BuildContext context) async {
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context);

    // Show dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n?.tokenExpiredTitle ?? 'Session Expired'),
          content: Text(l10n?.tokenExpiredMessage ??
              'Your session has expired. Please log in again.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    // Logout and redirect to login page
    await logout();
    navigator.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  // Schedule a notification to alert user about session expiry
  Future<void> scheduleSessionExpiryNotification() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // Only schedule if we have more than 1 minute left
    if (remainingSessionTimeInMinutes <= 1) return;

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

    // Schedule the notification
    await flutterLocalNotificationsPlugin.show(
      sessionExpiryNotificationId,
      'Session Expiring Soon',
      'Your session will expire in ${remainingSessionTimeInMinutes} minutes. Please save your work.',
      platformChannelSpecifics,
    );
  }

  Future<void> setLoginTime() async {
    _loginTime = DateTime.now();
    prefs.setLoginSession(_loginTime.toString());
    notifyListeners();
  }

  // Update the current user and notify listeners
  void updateUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  // Fetch user data from API and update current user
  Future<void> fetchAndUpdateUser() async {
    final String? token = prefs.getToken();

    if (token == null) {
      debugPrint('No token found');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/display/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> userJson =
            jsonDecode(response.body)['results'][0];

        List<String> roles = (userJson['roles'] as String).split(',');

        User loggedInUser = User(
          id: userJson['id'],
          name: userJson['employee_name'],
          roles: roles,
        );

        updateUser(loggedInUser);
      } else {
        debugPrint(
            'Failed to fetch user data. Status code: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error occurred while fetching user data: $e');
    }
  }

  // Log in the user, save token and notify listeners
  Future<void> login(String token) async {
    _isLoggedIn = true;
    _token = token;
    _loginTime = DateTime.now();
    _isShowingExpiryDialog = false;

    // Store in SharedPreferences (works well for Android)
    prefs.setLoggedIn(true);
    prefs.setToken(token);
    await setLoginTime(); // Save login time immediately after login

    // Also store in secure storage (more reliable for iOS)
    if (Platform.isIOS) {
      await _secureStorage.write(key: 'secure_token', value: token);
      await _secureStorage.write(
          key: 'secure_login_time', value: _loginTime.toString());
      await _secureStorage.write(key: 'secure_is_logged_in', value: 'true');
    }

    notifyListeners();
  }

  // Log out the user, clear token and notify listeners
  Future<void> logout() async {
    _isLoggedIn = false;
    _token = '';
    _loginTime = null;

    // Clear SharedPreferences
    await prefs.setLoggedOff();
    await prefs.removeToken();
    await prefs.removeLoginSession();

    // Also clear secure storage
    if (Platform.isIOS) {
      await _secureStorage.delete(key: 'secure_token');
      await _secureStorage.delete(key: 'secure_login_time');
      await _secureStorage.delete(key: 'secure_is_logged_in');
    }

    notifyListeners();
  }
}
