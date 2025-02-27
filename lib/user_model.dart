//user_model.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pb_hrsystem/services/network_service.dart';
import 'dart:async';

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
  final _storage = const FlutterSecureStorage();
  final _networkService = NetworkService();
  User _currentUser = User(id: '1', name: 'Default User', roles: ['User']);
  bool _isLoggedIn = false;
  String _token = '';
  DateTime? _loginTime;
  Timer? _tokenRefreshTimer;
  bool _isRefreshing = false;

  User get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  String get token => _token;

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  UserProvider() {
    _initializeProvider();
  }

  Future<void> _initializeProvider() async {
    await _networkService.initialize();
    await loadUser();
    _startTokenRefreshTimer();
  }

  void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    // Refresh token every 7 hours (before 8-hour expiry)
    _tokenRefreshTimer = Timer.periodic(const Duration(hours: 7), (timer) {
      _refreshTokenIfNeeded();
    });
  }

  Future<void> _refreshTokenIfNeeded() async {
    if (!_isLoggedIn || _isRefreshing) return;

    try {
      _isRefreshing = true;

      // Check if we need to refresh (token is older than 7 hours)
      if (_loginTime != null &&
          DateTime.now().difference(_loginTime!).inHours >= 7) {
        // Check network connectivity first
        if (await _networkService.isConnected()) {
          final response = await http.post(
            Uri.parse('$baseUrl/api/refresh-token'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_token',
            },
          );

          if (response.statusCode == 200) {
            final Map<String, dynamic> data = jsonDecode(response.body);
            final String newToken = data['token'];

            // Update token in all storage locations
            await _storage.write(key: 'token', value: newToken);
            await prefs.setToken(newToken);

            // Update login time
            _loginTime = DateTime.now();
            await _storage.write(
                key: 'loginTime', value: _loginTime!.toIso8601String());
            await prefs.setLoginSession(_loginTime!.toIso8601String());

            _token = newToken;
            notifyListeners();
          } else if (response.statusCode == 401) {
            // Token is invalid/expired, force logout
            await logout();
          }
        }
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      // Don't logout on network errors, will try again next time
    } finally {
      _isRefreshing = false;
    }
  }

  // Enhanced loadUser method
  Future<void> loadUser() async {
    try {
      // First try secure storage
      String? token = await _storage.read(key: 'token');
      String? loginTimeStr = await _storage.read(key: 'loginTime');

      // If not found in secure storage, try shared preferences as fallback
      if (token == null) {
        token = prefs.getToken();
        _loginTime = prefs.getLoginSession();
      } else {
        _loginTime = loginTimeStr != null ? DateTime.parse(loginTimeStr) : null;
      }

      _isLoggedIn = token != null && _loginTime != null;
      _token = token ?? '';

      if (_isLoggedIn) {
        // Validate session and refresh token if needed
        if (!isSessionValid) {
          await logout();
        } else {
          await _refreshTokenIfNeeded();
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user session: $e');
      await logout();
    }
  }

  bool get isSessionValid {
    if (_loginTime == null) return false;
    return DateTime.now().difference(_loginTime!).inHours < 8;
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

  // Enhanced login method
  Future<void> login(String token) async {
    _isLoggedIn = true;
    _token = token;
    _loginTime = DateTime.now();

    // Store in both secure storage and shared preferences
    await _storage.write(key: 'token', value: token);
    await _storage.write(
        key: 'loginTime', value: _loginTime!.toIso8601String());

    await prefs.setLoggedIn(true);
    await prefs.setToken(token);
    await prefs.setLoginSession(_loginTime!.toIso8601String());

    // Start token refresh timer
    _startTokenRefreshTimer();

    notifyListeners();
  }

  // Enhanced logout method
  Future<void> logout() async {
    _tokenRefreshTimer?.cancel();
    _isLoggedIn = false;
    _token = '';
    _loginTime = null;

    // Clear both storage mechanisms
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'loginTime');
    await prefs.setLoggedOff();
    await prefs.removeToken();
    await prefs.removeLoginSession();

    notifyListeners();
  }

  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    super.dispose();
  }
}
