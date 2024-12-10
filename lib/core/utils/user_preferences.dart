// lib/core/utils/user_preferences.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class UserPreferences {
  UserPreferences(this.prefs);

  final SharedPreferences prefs;

  static const String _token = "token";
  static const String _isLoggedIn = "LOGGED_IN";
  static const String _loginSession = "LOGIN_SESSION";
  static const String _defaultLang = "DEFAULT_LANGUAGE";
  static const String _device = "DEVICE";
  static const String _defaultLocale = "DEFAULT_Locale";
  static const String _checkInTime = "CHECK_IN_TIME";
  static const String _checkOutTime = "CHECK_OUT_TIME";
  static const String _workingHours = "WORKING_HOURS";

  // Store the token
  Future<void> setToken(String token) => prefs.setString(_token, token);
  Future<void> removeToken() => prefs.remove(_token);
  String? getToken() => prefs.getString(_token);

  // Is Logged In
  Future<void> setLoggedIn(bool isAccess) => prefs.setBool(_isLoggedIn, isAccess);
  Future<void> setLoggedOff() => prefs.remove(_isLoggedIn);
  bool? getLoggedIn() => prefs.getBool(_isLoggedIn);

  // Login Session
  Future<void> setLoginSession(String loginTime) => prefs.setString(_loginSession, loginTime);
  Future<void> removeLoginSession() => prefs.remove(_loginSession);
  DateTime? getLoginSession() {
    final sessionString = prefs.getString(_loginSession);

    // If sessionString is null or empty, return null
    if (sessionString == null || sessionString.isEmpty) {
      return null;
    }

    // Try parsing the string
    return DateTime.tryParse(sessionString);
  }

  // Store the default language
  Future<void> setDefaultLanguage(String lang) => prefs.setString(_defaultLang, lang);
  String? getDefaultLanguage() => prefs.getString(_defaultLang);

  // Store the device
  Future<void> setDevice(String device) => prefs.setString(_device, device);
  String? getDevice() => prefs.getString(_device);

  // Store the default locale
  Future<void> setLocalizeSupport(String langCode) => prefs.setString(_defaultLocale, langCode);
  Locale getLocalizeSupport() {
    String getLocal = prefs.getString(_defaultLocale) ?? 'en';
    if (getLocal.isEmpty) {
      return const Locale('en');
    } else {
      return Locale(getLocal);
    }
  }

  // Store Check-In Time
  Future<void> storeCheckInTime(String checkInTime) => prefs.setString(_checkInTime, checkInTime);
  String? getCheckInTime() => prefs.getString(_checkInTime);

  // Store Check-Out Time
  Future<void> storeCheckOutTime(String checkOutTime) => prefs.setString(_checkOutTime, checkOutTime);
  String? getCheckOutTime() => prefs.getString(_checkOutTime);

  // Remove Check-Out Time
  Future<void> removeCheckOutTime() => prefs.remove(_checkOutTime);

  // Store Working Hours
  Future<void> storeWorkingHours(Duration workingHours) => prefs.setString(_workingHours, workingHours.toString());
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
