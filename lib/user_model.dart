//user_model.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pb_hrsystem/l10n/app_localizations.dart';
import 'package:hive/hive.dart';

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
    String? token;
    DateTime? loginTime;
    bool isLoggedIn = false;

    try {
      // Check Hive first
      final box = await Hive.openBox('loginBox');
      isLoggedIn = box.get('is_logged_in') ?? false;
      token = box.get('token');
      final hiveLoginTime = box.get('login_time');
      loginTime =
          hiveLoginTime != null ? DateTime.tryParse(hiveLoginTime) : null;

      // If not found in Hive, try secure storage
      if (token == null || loginTime == null) {
        token = await _secureStorage.read(key: 'secure_token');
        final secureLoginTime =
            await _secureStorage.read(key: 'secure_login_time');
        final secureIsLoggedIn =
            await _secureStorage.read(key: 'secure_is_logged_in');

        if (token != null &&
            secureIsLoggedIn == 'true' &&
            secureLoginTime != null) {
          loginTime = DateTime.tryParse(secureLoginTime);
          isLoggedIn = true;
        }
      }

      // If still not found, try SharedPreferences
      if (token == null || loginTime == null) {
        token = await prefs.getTokenAsync();
        loginTime = await prefs.getLoginSessionAsync();
        isLoggedIn = await prefs.getLoggedInAsync() ?? false;
      }

      // Update state if we found valid data
      if (token != null && isLoggedIn && loginTime != null) {
        // Validate session duration
        if (DateTime.now().difference(loginTime).inHours >= 8) {
          debugPrint('Session expired, logging out');
          await logout();
          return;
        }

        // Valid session found
        _token = token;
        _loginTime = loginTime;
        _isLoggedIn = true;

        // Sync data across all storage methods
        await _syncStorageData(token, loginTime, true);
      } else {
        // No valid session found
        debugPrint('No valid session found, logging out');
        await logout();
      }
    } catch (e) {
      debugPrint('Error during loadUser: $e');
      await logout();
    }

    notifyListeners();
  }

  // Helper method to sync data across storage methods
  Future<void> _syncStorageData(
      String token, DateTime loginTime, bool isLoggedIn) async {
    try {
      // Update SharedPreferences
      await prefs.setToken(token);
      await prefs.setLoginSession(loginTime.toString());
      await prefs.setLoggedIn(isLoggedIn);

      // Update secure storage
      await _secureStorage.write(key: 'secure_token', value: token);
      await _secureStorage.write(
          key: 'secure_login_time', value: loginTime.toString());
      await _secureStorage.write(
          key: 'secure_is_logged_in', value: isLoggedIn.toString());

      // Update Hive
      final box = await Hive.openBox('loginBox');
      await box.put('token', token);
      await box.put('login_time', loginTime.toString());
      await box.put('is_logged_in', isLoggedIn);
    } catch (e) {
      debugPrint('Error syncing storage data: $e');
    }
  }

  bool get isSessionValid {
    if (_loginTime == null || !_isLoggedIn || _token.isEmpty) return false;
    return DateTime.now().difference(_loginTime!).inHours < 8;
  }

  // Check if session is about to expire (less than 30 minutes remaining)
  bool get isSessionAboutToExpire {
    if (_loginTime == null) return false;
    final Duration timeLeft =
        const Duration(hours: 8) - DateTime.now().difference(_loginTime!);
    return timeLeft.inMinutes > 0 && timeLeft.inMinutes < 30;
  }

  // Get remaining session time in minutes
  int get remainingSessionTimeInMinutes {
    if (_loginTime == null) return 0;
    final Duration timeLeft =
        const Duration(hours: 8) - DateTime.now().difference(_loginTime!);
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
              child: const Text('OK'),
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
      'Your session will expire in $remainingSessionTimeInMinutes minutes. Please save your work.',
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
      }
    } catch (e) {
      // Silently handle connection errors
      if (!e.toString().contains('SocketException') &&
          !e.toString().contains('Failed host lookup')) {
        // Only log non-connection related errors
        debugPrint('Error occurred while fetching user data: $e');
      }
    }
  }

  // Log in the user, save token and notify listeners
  Future<void> login(String token,
      {bool rememberMe = false, String? username, String? password}) async {
    _isLoggedIn = true;
    _token = token;
    _loginTime = DateTime.now();
    _isShowingExpiryDialog = false;

    // Store in both SharedPreferences and secure storage for both platforms
    await prefs.setLoggedIn(true);
    await prefs.setToken(token);
    await prefs.setLoginSession(_loginTime.toString());

    // Store in secure storage for both platforms for better security
    await _secureStorage.write(key: 'secure_token', value: token);
    await _secureStorage.write(
        key: 'secure_login_time', value: _loginTime.toString());
    await _secureStorage.write(key: 'secure_is_logged_in', value: 'true');

    // Store in Hive for offline access
    final box = await Hive.openBox('loginBox');
    await box.put('token', token);
    await box.put('login_time', _loginTime.toString());
    await box.put('is_logged_in', true);

    // Store remember me state and credentials if enabled
    if (rememberMe && username != null && password != null) {
      await box.put('remember_me', true);
      await box.put('username', username);
      await box.put('password', password);
    }

    notifyListeners();
  }

  // Log out the user, clear token and notify listeners
  Future<void> logout() async {
    _isLoggedIn = false;
    _token = '';
    _loginTime = null;

    try {
      // Save remember me credentials before clearing
      final loginBox = await Hive.openBox('loginBox');
      final rememberedUsername = loginBox.get('username');
      final rememberedPassword = loginBox.get('password');
      final wasRememberMeEnabled = loginBox.get('remember_me') ?? false;

      // Clear SharedPreferences
      await prefs.setLoggedOff();
      await prefs.removeToken();
      await prefs.removeLoginSession();

      // Clear secure storage
      await _secureStorage.deleteAll();

      // Clear Hive storage but preserve remember me if enabled
      await loginBox.clear();
      await loginBox.put('is_logged_in', false); // Explicitly set to false

      // Restore remember me credentials if they existed
      if (wasRememberMeEnabled &&
          rememberedUsername != null &&
          rememberedPassword != null) {
        await loginBox.put('username', rememberedUsername);
        await loginBox.put('password', rememberedPassword);
        await loginBox.put('remember_me', true);
      }
      await loginBox.close();

      // Clear other Hive boxes that contain user data
      final attendanceBox = await Hive.openBox('attendanceBox');
      await attendanceBox.clear();
      await attendanceBox.close();

      final assignmentBox = await Hive.openBox('assignmentBox');
      await assignmentBox.clear();
      await assignmentBox.close();

      final calendarBox = await Hive.openBox('calendarBox');
      await calendarBox.clear();
      await calendarBox.close();

      final historyBox = await Hive.openBox('historyBox');
      await historyBox.clear();
      await historyBox.close();

      debugPrint(
          'Successfully cleared all storage locations during logout while preserving remember me settings');
    } catch (e) {
      debugPrint('Error during logout cleanup: $e');
    }

    notifyListeners();
  }
}
