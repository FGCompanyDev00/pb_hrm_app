import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ThemeNotifier extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeMode get currentTheme => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  String get backgroundImage => _isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png';

  TextStyle get textStyle => TextStyle(color: _isDarkMode ? Colors.white : Colors.black);

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}
