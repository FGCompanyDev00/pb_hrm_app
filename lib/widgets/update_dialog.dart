// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pb_hrsystem/services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isLoading = false;
  bool _hasError = false;
  int _retryCount = 0;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background card
          Container(
            padding: const EdgeInsets.only(
              top: 110,
              left: 24,
              right: 24,
              bottom: 24,
            ),
            margin: const EdgeInsets.only(top: 60),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Update Required',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                const SizedBox(height: 16),
                Text(
                  _hasError
                      ? 'Unable to open app store. Please update manually from the store.'
                      : 'A new version of PSVB Next is available. You need to update to the latest version to continue using this app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
                const SizedBox(height: 32),
                _buildUpdateButton(context, isDarkMode).animate().scale(
                      duration: 600.ms,
                      delay: 600.ms,
                      curve: Curves.elasticOut,
                    ),
                const SizedBox(height: 16),
                _buildStoreInfo(context, isDarkMode)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 800.ms),
                if (_hasError) ...[
                  const SizedBox(height: 16),
                  Text(
                    'App Store: ${Platform.isIOS ? _appStoreUrl() : _playStoreUrl()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Top app image
          Positioned(
            top: 0,
            child: CircleAvatar(
              backgroundColor:
                  isDarkMode ? const Color(0xFF383838) : Colors.white,
              radius: 80,
              child: Image.asset(
                'assets/logo.png',
                width: 120,
                height: 120,
              )
                  .animate()
                  .slideY(
                    begin: -0.2,
                    end: 0,
                    curve: Curves.easeOut,
                    duration: 800.ms,
                  )
                  .then(delay: 200.ms)
                  .shake(duration: 500.ms, hz: 2),
            ),
          ),
        ],
      ),
    );
  }

  // Get Play Store URL for display
  String _playStoreUrl() {
    return 'https://play.google.com/store/apps/details?id=com.phongsavanh.pb_hrsystem';
  }

  // Get App Store URL for display
  String _appStoreUrl() {
    return 'https://apps.apple.com/us/app/psvb-next/id6742818675';
  }

  Widget _buildUpdateButton(BuildContext context, bool isDarkMode) {
    return ElevatedButton(
      onPressed: _isLoading
          ? null
          : () async {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });

              try {
                // Track the attempt
                _retryCount++;

                // If we've already tried 3 times, just show the error
                if (_retryCount >= 3) {
                  setState(() {
                    _isLoading = false;
                    _hasError = true;
                  });
                  return;
                }

                await UpdateService.openStore();

                // Wait 3 seconds to see if the app store opens
                await Future.delayed(const Duration(seconds: 3));

                // If we're still here, it probably failed to open the store
                // But we don't set hasError yet in case it just took time to open
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              } catch (e) {
                debugPrint('Error opening store: $e');

                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _hasError = true;
                  });
                }
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: _hasError
            ? Colors.red.shade700
            : const Color(0xFFDBB342), // Gold color from screenshot
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black38,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_hasError ? Icons.refresh : Icons.system_update, size: 24),
                const SizedBox(width: 12),
                Text(
                  _hasError ? 'Retry Update' : 'Update Now',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStoreInfo(BuildContext context, bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Platform.isAndroid ? Icons.android : Icons.apple,
          size: 20,
          color: isDarkMode ? Colors.white70 : Colors.black54,
        ),
        const SizedBox(width: 8),
        Text(
          Platform.isAndroid ? 'Google Play Store' : 'App Store',
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }
}

/// A dialog service to show the update dialog
class UpdateDialogService {
  static bool _isDialogShowing = false;

  /// Show the update dialog if it's not already showing
  static Future<void> showUpdateDialog(BuildContext context) async {
    if (_isDialogShowing) return;

    _isDialogShowing = true;

    // Check if needs update
    final bool needsUpdate = await UpdateService.needsUpdate();

    if (needsUpdate && context.mounted) {
      // Replace Navigator screen instead of showing dialog to prevent dismissal
      await Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (BuildContext context, _, __) {
            return WillPopScope(
              onWillPop: () async => false, // Prevent back button
              child: Scaffold(
                backgroundColor: Colors.black.withOpacity(0.85),
                body: const Center(
                  child: UpdateDialog(),
                ),
              ),
            );
          },
        ),
        (route) => false, // Remove all routes below
      );
    }

    _isDialogShowing = false;
  }
}
