import 'package:flutter/material.dart';
import 'package:flutter_in_store_app_version_checker/flutter_in_store_app_version_checker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pb_hrsystem/widgets/update_dialog.dart';
import 'update_service.dart';

/// A service for checking and handling app updates
class AppUpdateChecker {
  /// Check if an app update is available and show dialog if needed
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final bool needsUpdate = await _isUpdateRequired();

      if (needsUpdate) {
        if (context.mounted) {
          // Use the existing UpdateDialogService for force update
          await UpdateDialogService.showUpdateDialog(context);
        }
      }
    } catch (e) {
      debugPrint('Error checking for app updates: $e');
    }
  }

  /// Determine if an update is required based on version comparison
  static Future<bool> _isUpdateRequired() async {
    try {
      // First attempt: Use the flutter_in_store_app_version_checker package
      final checker = InStoreAppVersionChecker();
      final result = await checker.checkUpdate();

      debugPrint('Current version: ${result.currentVersion}');
      debugPrint('Store version: ${result.newVersion}');

      if (result.canUpdate != null && result.canUpdate!) {
        debugPrint('Update available: ${result.newVersion}');
        return true;
      }

      // Second attempt: Use our custom update service as fallback
      return await UpdateService.needsUpdate();
    } catch (e) {
      debugPrint('Error checking app version: $e');
      // Fallback to custom update service on error
      return await UpdateService.needsUpdate();
    }
  }

  /// Get current app version
  static Future<String> getCurrentVersion() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }
}
