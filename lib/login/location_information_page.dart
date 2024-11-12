// location_information_page.dart

import 'package:flutter/material.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/login/camera_page.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationInformationPage extends StatelessWidget {
  const LocationInformationPage({super.key});

  Future<void> _requestLocationPermission(BuildContext context) async {
    PermissionStatus status = await Permission.locationWhenInUse.status;

    if (status.isGranted || status.isLimited) {
      // Permission is granted (limited status is iOS-specific)
      Navigator.push(context, MaterialPageRoute(builder: (context) => const CameraPage()));
      return;
    }

    // Request permission
    PermissionStatus newStatus = await Permission.locationWhenInUse.request();

    if (newStatus.isGranted || newStatus.isLimited) {
      // Permission granted (or limited)
      Navigator.push(context, MaterialPageRoute(builder: (context) => const CameraPage()));
    } else if (newStatus.isDenied) {
      // Permission denied but not permanently
      _showPermissionDeniedDialog(context, false);
    } else if (newStatus.isPermanentlyDenied) {
      // Permission permanently denied
      _showPermissionDeniedDialog(context, true);
    } else if (newStatus.isRestricted) {
      // iOS-specific restricted status
      _showErrorDialog(context, localizations!.permissionRestricted);
    } else {
      // Other statuses like error or failed
      _showErrorDialog(context, '${localizations!.permissionStatus}: $newStatus');
    }
  }

  void _showPermissionDeniedDialog(BuildContext context, bool isPermanentlyDenied) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations!.permissionDenied),
          content: Text(isPermanentlyDenied ? localizations!.locationAccessPermanentlyDenied : localizations!.locationPermissionRequired),
          actions: [
            TextButton(
              onPressed: () {
                if (isPermanentlyDenied) {
                  openAppSettings(); // Prompt user to manually change settings
                }
                Navigator.of(context).pop();
              },
              child: Text(localizations!.ok),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations!.error), // Ensure 'error' key exists
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text(localizations!.ok),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
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
                  'assets/location_image.png',
                  width: 200,
                  height: 200,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  localizations!.locationInformation,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  localizations!.weCollectInformation,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
              const Spacer(),
              Center(
                child: ElevatedButton(
                  onPressed: () => _requestLocationPermission(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: Text(localizations!.next, style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPageIndicator(context, isActive: false),
                    _buildPageIndicator(context, isActive: true),
                    _buildPageIndicator(context, isActive: false),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  localizations!.pageIndicator2of3, // Ensure this key exists
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(BuildContext context, {required bool isActive}) {
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
