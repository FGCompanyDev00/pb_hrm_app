//theme/theme.dart

import 'package:flutter/material.dart';

class ThemeNotifier extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeMode get currentTheme => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  String get backgroundImage => _isDarkMode ? 'assets/darkbg.png' : 'assets/background.png';

  TextStyle get textStyle => TextStyle(color: _isDarkMode ? Colors.white : Colors.black);

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}
