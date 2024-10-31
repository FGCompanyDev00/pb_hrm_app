import 'package:flutter/material.dart';
import 'package:pb_hrsystem/services/navigation_service.dart';

/// Displays a SnackBar with the provided message
void showSnackBar(String message) {
  ScaffoldMessenger.of(NavigationService.ctx!).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.redAccent,
    ),
  );
}
