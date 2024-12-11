// lib/login/camera_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pb_hrsystem/login/ready_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../settings/theme_notifier.dart'; // Correct import for ThemeNotifier

class CameraPage extends StatelessWidget {
  const CameraPage({super.key});

  /// Requests camera permission from the user.
  Future<void> _requestCameraPermission(BuildContext context) async {
    // Check the current status of the camera permission.
    PermissionStatus status = await Permission.camera.status;

    if (status.isGranted) {
      // If permission is already granted, navigate to ReadyPage.
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ReadyPage()),
      );
    } else if (status.isRestricted || status.isPermanentlyDenied) {
      // Handle cases where permission is restricted or permanently denied.
      _showPermissionDeniedDialog(context, isPermanentlyDenied: true);
    } else if (status.isDenied) {
      // Request camera permission if it's denied but not permanently.
      PermissionStatus newStatus = await Permission.camera.request();
      if (newStatus.isGranted) {
        // If the user grants permission after the request, navigate to ReadyPage.
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ReadyPage()),
        );
      } else {
        // If the user denies permission again, show a denial dialog.
        _showPermissionDeniedDialog(context, isPermanentlyDenied: false);
      }
    }
  }

  /// Displays a dialog informing the user that camera permission was denied.
  void _showPermissionDeniedDialog(BuildContext context, {required bool isPermanentlyDenied}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.permissionDenied),
          content: Text(
            isPermanentlyDenied
                ? AppLocalizations.of(context)!.cameraAccessPermanentlyDenied
                : AppLocalizations.of(context)!.cameraPermissionRequired,
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (isPermanentlyDenied) {
                  // If permission is permanently denied, open app settings.
                  openAppSettings();
                }
                Navigator.of(context).pop(); // Close the dialog.
              },
              child: Text(AppLocalizations.of(context)!.ok),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Access the ThemeNotifier using context.watch to listen for theme changes.
    final ThemeNotifier themeNotifier = context.watch<ThemeNotifier>();
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            // Use different background images based on the current theme.
            image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Spacer(),
              Center(
                child: Image.asset(
                  'assets/camera_image.png',
                  width: 200,
                  height: 200,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  AppLocalizations.of(context)!.cameraAndPhoto,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black, // Adjust text color based on theme.
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  AppLocalizations.of(context)!.manyFunctions,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white70 : Colors.black54, // Adjust text color based on theme.
                  ),
                ),
              ),
              const Spacer(),
              Center(
                child: ElevatedButton(
                  onPressed: () => _requestCameraPermission(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.next,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPageIndicator(isActive: false),
                    _buildPageIndicator(isActive: false),
                    _buildPageIndicator(isActive: true),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  AppLocalizations.of(context)!.pageIndicator3of3,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white70 : Colors.black54, // Adjust text color based on theme.
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a single page indicator dot.
  Widget _buildPageIndicator({required bool isActive}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      width: isActive ? 12.0 : 8.0,
      height: isActive ? 12.0 : 8.0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.green : Colors.grey,
      ),
    );
  }
}
