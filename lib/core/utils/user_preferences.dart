// lib/core/utils/user_preferences.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class UserPreferences {
  UserPreferences(this.prefs);

  final SharedPreferences prefs;

  static const String _defaultLang = "DEFAULT_LANGUAGE";
  static const String _defaultLocale = "DEFAULT_Locale";

  Future<void> setDefaultLanguage(String lang) => prefs.setString(_defaultLang, lang);

  String? getDefaultLanguage() => prefs.getString(_defaultLang);

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
