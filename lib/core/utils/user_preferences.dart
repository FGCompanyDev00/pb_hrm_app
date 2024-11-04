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
  static const String _defaultLocale = "DEFAULT_Locale";

  //Store the token
  Future<void> setToken(String token) => prefs.setString(_token, token);
  Future<void> removeToken() => prefs.remove(_token);
  String? getToken() => prefs.getString(_token);

  //Is Logged In
  Future<void> setLoggedIn(bool isAccess) => prefs.setBool(_isLoggedIn, isAccess);
  Future<void> setLoggedOff() => prefs.remove(_isLoggedIn);
  bool? getLoggedIn() => prefs.getBool(_isLoggedIn);

  //Login Session
  Future<void> setLoginSession(String loginTime) => prefs.setString(_loginSession, loginTime);
  Future<void> removeLoginSession() => prefs.remove(_loginSession);
  String? getLoginSession() => prefs.getString(_loginSession);

  //Store the default language
  Future<void> setDefaultLanguage(String lang) => prefs.setString(_defaultLang, lang);
  String? getDefaultLanguage() => prefs.getString(_defaultLang);

  //Store the default locale
  Future<void> setLocalizeSupport(String langCode) => prefs.setString(_defaultLocale, langCode);
  Locale getLocalizeSupport() {
    String getLocal = prefs.getString(_defaultLocale) ?? 'en';
    if (getLocal.isEmpty) {
      return const Locale('en');
    } else {
      return Locale(getLocal);
    }
  }
}
