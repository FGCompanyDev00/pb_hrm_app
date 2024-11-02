// lib/core/utils/user_preferences.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class UserPreferences {
  /// Retrieves the default language as a String.
  Future<String?> getDefaultLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('defaultLanguage');
  }

  /// Sets the default language.
  Future<void> setDefaultLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('defaultLanguage', language);
  }

  /// Retrieves the supported locale.
  Future<Locale?> getLocalizeSupport() async {
    final prefs = await SharedPreferences.getInstance();
    String? localeCode = prefs.getString('localizeSupport');
    if (localeCode != null) {
      return Locale(localeCode);
    }
    return null;
  }

  /// Sets the supported locale.
  Future<void> setLocalizeSupport(String localeCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('localizeSupport', localeCode);
  }
}
