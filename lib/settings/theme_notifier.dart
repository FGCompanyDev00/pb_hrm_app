import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  bool _isDarkMode = false;
  SharedPreferences? _prefs;

  bool get isDarkMode => _isDarkMode;
  ThemeMode get currentTheme => _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  String get backgroundImage => _isDarkMode ? 'assets/darkbg.png' : 'assets/background.png';
  TextStyle get textStyle => TextStyle(color: _isDarkMode ? Colors.white : Colors.black);

  ThemeNotifier() {
    _loadTheme();  // Load the saved theme when the notifier is created
  }

  Future<void> _loadTheme() async {
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs?.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _prefs?.setBool('isDarkMode', _isDarkMode);  // Save the updated preference
    notifyListeners();
  }
}
