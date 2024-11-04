import 'package:flutter/material.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';

/// Displays a SnackBar with the provided message
void showSnackBar(String message) {
  ScaffoldMessenger.of(navigatorKey.currentState!.context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.redAccent,
    ),
  );
}

/// Displays a SnackBar with a custom message and color.
void showSnackBarEvent(String message, Color color) {
  ScaffoldMessenger.of(navigatorKey.currentState!.context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}
