import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/user_model.dart';
import 'package:pb_hrsystem/login/login_page.dart';
import 'package:pb_hrsystem/core/widgets/snackbar/snackbar.dart';

/// Centralized authentication utilities for handling token validation and redirects
class AuthUtils {
  /// Check if token is valid and handle redirect if null
  /// Returns true if token is valid, false if null (and handles redirect)
  static Future<bool> validateTokenAndRedirect(String? token,
      {String? customMessage}) async {
    if (token == null || token.isEmpty) {
      // Show error message
      final message = customMessage ??
          'Authentication Error: Token is null. Please log in again.';
      showSnackBar(message);

      // Handle token null scenario by redirecting to login
      await _handleTokenNullRedirect();
      return false;
    }
    return true;
  }

  /// Handle token null scenario by logging out user and redirecting to login
  static Future<void> _handleTokenNullRedirect() async {
    try {
      // Get the navigator key from UserProvider
      final navigatorKey = UserProvider.navigatorKey;
      final context = navigatorKey.currentContext;

      if (context != null) {
        // Get UserProvider and logout the user to clear all stored data
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.logout();

        // Navigate to login page and clear the navigation stack
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false, // Remove all previous routes
          );
        }
      }
    } catch (e) {
      // If navigation fails for any reason, at least log the error
      debugPrint('Error during token null redirect: $e');
    }
  }

  /// Handle authentication error and redirect to login
  /// Use this when you encounter authentication errors from API responses
  static Future<void> handleAuthenticationError({String? customMessage}) async {
    final message =
        customMessage ?? 'Authentication failed. Please log in again.';
    showSnackBar(message);
    await _handleTokenNullRedirect();
  }

  /// Quick validation helper for token with error handling
  /// Returns token if valid, null if invalid (and handles redirect)
  static Future<String?> getValidatedToken(String? token,
      {String? customMessage}) async {
    if (await validateTokenAndRedirect(token, customMessage: customMessage)) {
      return token;
    }
    return null;
  }
}
