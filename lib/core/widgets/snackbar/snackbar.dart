import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
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

showToast(
  String message,
  Color color,
  IconData icon, {
  ToastGravity? gravity,
}) {
  fToast.init(navigatorKey.currentState!.context);
  Widget toast = Container(
    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(25.0),
      color: color,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        const SizedBox(
          width: 12.0,
        ),
        Text(message),
      ],
    ),
  );

  fToast.showToast(
    child: toast,
    gravity: gravity ?? ToastGravity.TOP,
    toastDuration: const Duration(seconds: 2),
  );
}
