// lib/core/utils/user_preferences.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io' show Platform;

class UserPreferences {
  UserPreferences(this.prefs);

  final SharedPreferences prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _token = "token";
  static const String _isLoggedIn = "LOGGED_IN";
  static const String _loginSession = "LOGIN_SESSION";
  static const String _defaultLang = "DEFAULT_LANGUAGE";
  static const String _device = "DEVICE";
  static const String _defaultLocale = "DEFAULT_Locale";
  static const String _checkInTime = "CHECK_IN_TIME";
  static const String _checkOutTime = "CHECK_OUT_TIME";
  static const String _workingHours = "WORKING_HOURS";
  static const languageKey = 'preferred_language';
  static const String _lastAction =
      "LAST_ACTION"; // New: Store last action (Check-In/Check-Out)

  // Store the token with iOS-specific handling
  Future<void> setToken(String token) async {
    await prefs.setString(_token, token);
    // Also store in secure storage for iOS
    if (Platform.isIOS) {
      await _secureStorage.write(key: 'secure_token', value: token);
    }
  }

  Future<void> removeToken() async {
    await prefs.remove(_token);
    // Also remove from secure storage for iOS
    if (Platform.isIOS) {
      await _secureStorage.delete(key: 'secure_token');
    }
  }

  Future<String?> getTokenAsync() async {
    // Try secure storage first for iOS
    if (Platform.isIOS) {
      final secureToken = await _secureStorage.read(key: 'secure_token');
      if (secureToken != null) {
        // Sync with SharedPreferences
        await prefs.setString(_token, secureToken);
        return secureToken;
      }
    }
    return prefs.getString(_token);
  }

  String? getToken() {
    return prefs.getString(_token);
  }

  // Is Logged In with iOS-specific handling
  Future<void> setLoggedIn(bool isAccess) async {
    await prefs.setBool(_isLoggedIn, isAccess);
    // Also store in secure storage for iOS
    if (Platform.isIOS) {
      await _secureStorage.write(
          key: 'secure_is_logged_in', value: isAccess.toString());
    }
  }

  Future<void> setLoggedOff() async {
    await prefs.remove(_isLoggedIn);
    // Also remove from secure storage for iOS
    if (Platform.isIOS) {
      await _secureStorage.delete(key: 'secure_is_logged_in');
    }
  }

  Future<bool?> getLoggedInAsync() async {
    // Try secure storage first for iOS
    if (Platform.isIOS) {
      final secureLoggedIn =
          await _secureStorage.read(key: 'secure_is_logged_in');
      if (secureLoggedIn != null) {
        final isLoggedIn = secureLoggedIn == 'true';
        // Sync with SharedPreferences
        await prefs.setBool(_isLoggedIn, isLoggedIn);
        return isLoggedIn;
      }
    }
    return prefs.getBool(_isLoggedIn);
  }

  bool? getLoggedIn() {
    return prefs.getBool(_isLoggedIn);
  }

  // Login Session with iOS-specific handling
  Future<void> setLoginSession(String loginTime) async {
    await prefs.setString(_loginSession, loginTime);
    // Also store in secure storage for iOS
    if (Platform.isIOS) {
      await _secureStorage.write(key: 'secure_login_time', value: loginTime);
    }
  }

  Future<void> removeLoginSession() async {
    await prefs.remove(_loginSession);
    // Also remove from secure storage for iOS
    if (Platform.isIOS) {
      await _secureStorage.delete(key: 'secure_login_time');
    }
  }

  Future<DateTime?> getLoginSessionAsync() async {
    // Try secure storage first for iOS
    if (Platform.isIOS) {
      final secureLoginTime =
          await _secureStorage.read(key: 'secure_login_time');
      if (secureLoginTime != null && secureLoginTime.isNotEmpty) {
        // Sync with SharedPreferences
        await prefs.setString(_loginSession, secureLoginTime);
        return DateTime.tryParse(secureLoginTime);
      }
    }

    final sessionString = prefs.getString(_loginSession);
    if (sessionString == null || sessionString.isEmpty) {
      return null;
    }
    return DateTime.tryParse(sessionString);
  }

  DateTime? getLoginSession() {
    final sessionString = prefs.getString(_loginSession);
    if (sessionString == null || sessionString.isEmpty) {
      return null;
    }
    return DateTime.tryParse(sessionString);
  }

  // Store the default language
  Future<void> setDefaultLanguage(String lang) =>
      prefs.setString(_defaultLang, lang);
  String? getDefaultLanguage() => prefs.getString(_defaultLang);

  // Store the device
  Future<void> setDevice(String device) => prefs.setString(_device, device);
  String? getDevice() => prefs.getString(_device);

  // ✅ Store Last Attendance Action (checkIn or checkOut)
  Future<void> storeLastAction(String action) =>
      prefs.setString(_lastAction, action);

  // ✅ Retrieve Last Attendance Action (checkIn or checkOut)
  String? getLastAction() => prefs.getString(_lastAction);

  // Store the default locale
  Future<void> setLocalizeSupport(String langCode) =>
      prefs.setString(_defaultLocale, langCode);
  Locale getLocalizeSupport() {
    String getLocal = prefs.getString(_defaultLocale) ?? 'en';
    if (getLocal.isEmpty) {
      return const Locale('en');
    } else {
      return Locale(getLocal);
    }
  }

  // Store Check-In Time
  Future<void> storeCheckInTime(String checkInTime) =>
      prefs.setString(_checkInTime, checkInTime);
  String? getCheckInTime() => prefs.getString(_checkInTime);

  // Store Check-Out Time
  Future<void> storeCheckOutTime(String checkOutTime) =>
      prefs.setString(_checkOutTime, checkOutTime);
  String? getCheckOutTime() => prefs.getString(_checkOutTime);

  // Remove Check-Out Time
  Future<void> removeCheckOutTime() => prefs.remove(_checkOutTime);

  // Store Working Hours
  Future<void> storeWorkingHours(Duration workingHours) =>
      prefs.setString(_workingHours, workingHours.toString());
  Duration? getWorkingHours() {
    String? workingHoursStr = prefs.getString(_workingHours);
    if (workingHoursStr != null) {
      List<String> parts = workingHoursStr.split(':');
      if (parts.length >= 3) {
        return Duration(
          hours: int.tryParse(parts[0]) ?? 0,
          minutes: int.tryParse(parts[1]) ?? 0,
          seconds: int.tryParse(parts[2]) ?? 0,
        );
      }
    }
    return null;
  }

  Future<void> reload() => prefs.reload();
  Future<void> log() async {
    final log = prefs.getStringList('log') ?? <String>[];
    log.add(DateTime.now().toIso8601String());
    await prefs.setStringList('log', log);
  }

  Future<void> onStartBackground(String msg) => prefs.setString('Hello', msg);
}
