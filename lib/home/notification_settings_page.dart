import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:platform/platform.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../services/http_service.dart';
import '../settings/theme_notifier.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  NotificationSettingsPageState createState() =>
      NotificationSettingsPageState();
}

class NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final ApiService _apiService = ApiService();
  final LocalAuthentication auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Add a global key for loading dialog
  final GlobalKey<State> _loadingDialogKey = GlobalKey<State>();
  Timer? _loadingDialogTimer;

  String _deviceId = '';

  List<Device> _devices = [];
  bool _isLoading = false;
  bool _biometricEnabled = false;
  String? _deviceToken;

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
    _initializeDevices();
  }

  @override
  void dispose() {
    _loadingDialogTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeDevices() async {
    await _fetchDeviceToken(); // Get device token first
    await _fetchDeviceId(); // Get device ID
    await _loadDevices(); // Then load devices
  }

  /// Fetches the device ID using device_info_plus
  Future<void> _fetchDeviceId() async {
    try {
      // First try to get from storage
      String? storedDeviceId = await _storage.read(key: 'deviceId');
      if (storedDeviceId != null && storedDeviceId.isNotEmpty) {
        setState(() {
          _deviceId = storedDeviceId;
        });
        return;
      }

      // If not in storage, generate new device ID
      final platform = defaultTargetPlatform;
      if (platform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? '';

        if (_deviceId.isEmpty) {
          _deviceId = 'ios_${DateTime.now().millisecondsSinceEpoch}';
        }
      } else if (platform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        final Map<String, String> deviceInfoMap = {
          'id': androidInfo.id,
          'brand': androidInfo.brand,
          'device': androidInfo.device,
          'model': androidInfo.model,
          'product': androidInfo.product,
          'hardware': androidInfo.hardware,
          'manufacturer': androidInfo.manufacturer,
          'serialNumber': androidInfo.serialNumber ?? '',
        };

        // Filter out empty values and join with underscore
        final List<String> deviceInfoParts =
            deviceInfoMap.values.where((value) => value.isNotEmpty).toList();

        if (deviceInfoParts.isNotEmpty) {
          _deviceId = deviceInfoParts.join('_');
        } else {
          _deviceId = 'android_${DateTime.now().millisecondsSinceEpoch}';
        }
      }

      // Save the device ID
      if (_deviceId.isNotEmpty) {
        await _storage.write(key: 'deviceId', value: _deviceId);
      }

      setState(() {}); // Update UI
    } catch (e) {
      debugPrint('Error getting device info: $e');
      // Generate fallback ID if all else fails
      _deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}_fallback';
      await _storage.write(key: 'deviceId', value: _deviceId);
    }
  }

  /// Fetches the FCM token
  Future<void> _fetchDeviceToken() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        print("Retrieved APNs Token: $apnsToken"); // Print here
        if (apnsToken != null) {
          setState(() {
            _deviceToken = apnsToken;
          });
        } else {
          print("APNs token is null. Check APNs setup in Firebase.");
        }
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        String? fcmToken = await FirebaseMessaging.instance.getToken();
        print("Retrieved FCM Token: $fcmToken"); // Print here
        if (fcmToken != null) {
          setState(() {
            _deviceToken = fcmToken;
          });
        }
      } else {
        print("Unsupported platform.");
      }
    } catch (e) {
      print("Error getting device token: $e");
    }
  }

  /// Loads the biometric setting from secure storage.
  Future<void> _loadBiometricSetting() async {
    String? isEnabled = await _storage.read(key: 'biometricEnabled');
    setState(() {
      _biometricEnabled = isEnabled == 'true';
    });
  }

  /// Fetches the list of devices from the API.
  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
    });
    try {
      List<Device> devices = await _apiService.fetchDevices();
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      _showSnackBar('Error loading devices: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Toggles the notification setting for a specific device.
  Future<void> _toggleNotification(Device device) async {
    setState(() {
      device.isUpdating = true;
    });
    try {
      bool updated =
          await _apiService.updateDeviceStatus(device, !device.status);
      if (updated) {
        setState(() {
          device.status = !device.status;
        });

        // Show a more visually appealing snackbar with animation
        final bool isEnabled = device.status;
        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            padding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            elevation: 0,
            content: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isEnabled
                    ? (isDarkMode
                        ? Colors.green.shade800
                        : Colors.green.shade700)
                    : (isDarkMode
                        ? const Color(0xFF424242)
                        : Colors.blueGrey.shade700),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? (isDarkMode
                              ? Colors.green.shade200
                              : Colors.green.shade100)
                          : (isDarkMode
                              ? Colors.grey.shade300
                              : Colors.blueGrey.shade100),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEnabled
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                      color: isEnabled
                          ? (isDarkMode
                              ? Colors.green.shade800
                              : Colors.green.shade700)
                          : (isDarkMode
                              ? const Color(0xFF424242)
                              : Colors.blueGrey.shade700),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEnabled
                          ? 'Notifications enabled successfully'
                          : 'Notifications disabled successfully',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        _showSnackBar('Failed to update notification setting');
      }
    } catch (e) {
      _showSnackBar('Error updating device: $e');
    } finally {
      setState(() {
        device.isUpdating = false;
      });
    }
  }

  /// Adds a new device by interacting with the API.
  Future<void> _addDevice(
      String deviceId, String deviceToken, String platform) async {
    setState(() {
      _isLoading = true;
    });
    try {
      bool added = await _apiService.addDevice(deviceId, deviceToken, platform);
      if (added) {
        // Reload devices after successful addition
        await _loadDevices();

        // Show success animation
        _showSuccessAnimation('Device registered successfully');
      } else {
        _showErrorAnimation('Failed to register device');
      }
    } catch (e) {
      _showErrorAnimation('Error registering device: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Shows a success animation dialog
  void _showSuccessAnimation(String message) {
    // Store navigator context locally
    final BuildContext currentContext = context;

    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // Close dialog after animation completes using dialog's context
        Future.delayed(const Duration(milliseconds: 1500), () {
          // Check if dialog context is still mounted before popping
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        });

        final bool isDarkMode =
            Theme.of(dialogContext).brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.green.shade600
                              : const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Shows an error animation dialog
  void _showErrorAnimation(String message) {
    // Store navigator context locally
    final BuildContext currentContext = context;

    showDialog(
      context: currentContext,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        final bool isDarkMode =
            Theme.of(dialogContext).brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.red.shade700 : Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    // Use dialog's context to pop
                    Navigator.of(dialogContext).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor:
                        isDarkMode ? Colors.orange : Colors.orange.shade800,
                  ),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Shows loading dialog with animation using a global key for better control
  void _showLoadingDialog(String message) {
    // Cancel any existing timer
    _loadingDialogTimer?.cancel();

    // Dismiss any existing dialog first
    _dismissLoadingDialog();

    // Create a timer to automatically dismiss the dialog after 15 seconds
    _loadingDialogTimer = Timer(const Duration(seconds: 15), () {
      _dismissLoadingDialog();
      if (mounted) {
        _showSnackBar('Operation timed out');
      }
    });

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final bool isDarkMode =
            Theme.of(dialogContext).brightness == Brightness.dark;

        return AlertDialog(
          key: _loadingDialogKey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDarkMode
                      ? Colors.orange
                      : Theme.of(dialogContext).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      // Cancel the timeout timer when dialog is closed
      _loadingDialogTimer?.cancel();
      _loadingDialogTimer = null;
    });
  }

  /// Safely dismiss loading dialog from anywhere
  void _dismissLoadingDialog() {
    _loadingDialogTimer?.cancel();
    _loadingDialogTimer = null;

    if (mounted) {
      Navigator.of(context, rootNavigator: true).popUntil((route) {
        return route.isFirst || route.settings.name == 'main_route';
      });
    }
  }

  /// Authenticate with biometrics
  Future<bool> _authenticateWithBiometrics(String reason) async {
    // If biometrics is not enabled, dismiss dialog and return false immediately
    if (!_biometricEnabled) {
      _dismissLoadingDialog();
      _showSnackBar('Biometric authentication is not enabled');
      return false;
    }

    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        _dismissLoadingDialog();
        _showSnackBar('Biometric authentication not available on this device');
        return false;
      }

      // Close the loading dialog before showing biometric prompt
      _dismissLoadingDialog();

      // Let's wrap the authentication in a try-catch to ensure we can handle errors properly
      try {
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: reason,
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );

        if (!didAuthenticate) {
          _showSnackBar('Authentication failed');
        }

        return didAuthenticate;
      } catch (authError) {
        debugPrint('Biometric authentication error: $authError');
        _showSnackBar(
            'Authentication error: ${authError.toString().split('\n').first}');
        return false;
      }
    } catch (e) {
      _dismissLoadingDialog();
      _showSnackBar(
          'Error with biometric authentication: ${e.toString().split('\n').first}');
      return false;
    }
  }

  /// Shows a confirmation dialog for registering the current device
  void _showRegisterDevicePrompt() {
    String platform =
        defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        final bool isDarkMode =
            Theme.of(dialogContext).brightness == Brightness.dark;
        final Color primaryColor = isDarkMode ? Colors.orange : Colors.blue;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Icon(Icons.devices, size: 48, color: primaryColor),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Register Device',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Do you want to register this device for notifications?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.grey.shade800.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            platform == 'android'
                                ? 'assets/android_device.png'
                                : 'assets/ios_device.png',
                            width: 24,
                            height: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Platform: ${platform.toUpperCase()}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Device ID: ${_deviceId.substring(0, min(_deviceId.length, 15))}...',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor:
                    isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
              child: const Text('No'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDarkMode ? Colors.orange : const Color(0xFFFF9800),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                // Show loading indicator
                _showLoadingDialog('Registering device...');

                try {
                  // Check if biometric is enabled
                  if (_biometricEnabled) {
                    bool authenticated = await _authenticateWithBiometrics(
                        "Authenticate to register device");

                    if (authenticated) {
                      await _addDevice(_deviceId, _deviceToken ?? '', platform);
                    }
                  } else {
                    // If biometric is not enabled, dismiss loading dialog
                    _dismissLoadingDialog();

                    // Then show the biometric prompt
                    _showBiometricPrompt();
                  }
                } catch (e) {
                  // Ensure dialog is dismissed in case of errors
                  _dismissLoadingDialog();
                  _showSnackBar('Error: $e');
                }
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  /// Handles the toggle notification with confirmation dialog and biometric
  Future<void> _handleToggleNotification(Device device) async {
    final String action = device.status ? "disable" : "enable";

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final bool isDarkMode =
            Theme.of(dialogContext).brightness == Brightness.dark;
        final Color buttonColor = device.status
            ? (isDarkMode ? Colors.redAccent : Colors.red)
            : (isDarkMode ? Colors.green.shade600 : Colors.green);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.bounceOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Icon(
                      device.status
                          ? Icons.notifications_off
                          : Icons.notifications_active,
                      size: 48,
                      color: buttonColor,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                device.status
                    ? 'Disable Notifications'
                    : 'Enable Notifications',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            'Do you want to $action notifications for this device?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor:
                    isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                // Show loading indicator
                _showLoadingDialog('Processing request...');

                try {
                  // Check if biometric is enabled
                  if (_biometricEnabled) {
                    // Authentication needs to happen with the loading dialog already shown
                    bool authenticated = await _authenticateWithBiometrics(
                        "Authenticate to $action notifications");

                    if (authenticated) {
                      // If authenticated, toggle notification
                      await _toggleNotification(device);
                    }
                  } else {
                    // If biometric not enabled, dismiss loading dialog
                    _dismissLoadingDialog();

                    // Then show biometric prompt
                    _showBiometricPrompt();
                  }
                } catch (e) {
                  // Ensure dialog is dismissed in case of errors
                  _dismissLoadingDialog();
                  _showSnackBar('Error: $e');
                }
              },
              child: Text(device.status ? 'Disable' : 'Enable'),
            ),
          ],
        );
      },
    );
  }

  /// Prompts the user to enable biometric authentication in Settings.
  void _showBiometricPrompt() {
    // Store navigator context locally
    final BuildContext currentContext = context;

    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final bool isDarkMode =
            Theme.of(dialogContext).brightness == Brightness.dark;
        final Color primaryColor = isDarkMode ? Colors.orange : Colors.blue;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child:
                        Icon(Icons.fingerprint, size: 48, color: primaryColor),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Biometric Authentication Required',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.orange.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.orange.shade700
                        : Colors.orange.shade300,
                    width: 1,
                  ),
                ),
                child: Text(
                  'For security reasons, you must enable biometric authentication to manage device notifications.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDarkMode ? Colors.orange : const Color(0xFFFF9800),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  // Enable biometrics
                  await _enableBiometrics(true);
                  // Show confirmation
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Biometric authentication enabled. Please try your operation again.'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.settings),
                label: const Text('Enable Biometrics'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor:
                    isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Handles biometric authentication setup.
  Future<void> _enableBiometrics(bool enable) async {
    try {
      await _storage.write(key: 'biometricEnabled', value: enable.toString());
      setState(() {
        _biometricEnabled = enable;
      });

      if (enable) {
        _showSnackBar('Biometric authentication enabled successfully');
      }
    } catch (e) {
      _showSnackBar('Error enabling biometric authentication: $e');
    }
  }

  /// Displays a SnackBar with the provided message.
  void _showSnackBar(String message) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isDarkMode ? Colors.grey.shade800 : null,
      ),
    );
  }

  /// Builds the AppBar with custom styling.
  PreferredSizeWidget _buildAppBar() {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    return AppBar(
      backgroundColor: Colors.transparent,
      centerTitle: true,
      title: Text(
        'Notification Settings',
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
          fontSize: 22,
          fontWeight: FontWeight.w500,
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
          size: 20,
        ),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      toolbarHeight: 80,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
            fit: BoxFit.cover,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadDevices,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _devices.isEmpty
                        ? const Center(child: Text('No devices found.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _devices.length,
                            itemBuilder: (context, index) {
                              final device = _devices[index];
                              bool isCurrentDevice =
                                  device.token == _deviceToken;
                              return ListTile(
                                leading: Image.asset(
                                  device.platform == 'android'
                                      ? 'assets/android_device.png'
                                      : 'assets/ios_device.png',
                                  width: 30,
                                  height: 40,
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        device.deviceId,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    if (isCurrentDevice) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Current',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                    'Last login: ${device.lastLoginFormatted}'),
                                trailing: device.isUpdating
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Switch(
                                        value: device.status,
                                        onChanged: (_) =>
                                            _handleToggleNotification(device),
                                        activeColor: isDarkMode
                                            ? Colors.green.shade600
                                            : Colors.green,
                                        activeTrackColor: isDarkMode
                                            ? Colors.green.shade800
                                                .withOpacity(0.5)
                                            : Colors.green.withOpacity(0.5),
                                        inactiveThumbColor: isDarkMode
                                            ? Colors.grey.shade400
                                            : Colors.grey,
                                        inactiveTrackColor: isDarkMode
                                            ? Colors.grey.shade700
                                                .withOpacity(0.5)
                                            : Colors.grey.withOpacity(0.5),
                                      ),
                                onTap: null,
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRegisterDevicePrompt(),
        backgroundColor: isDarkMode ? Colors.orange : const Color(0xFFFF9800),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

/// Represents a device with its notification settings.
class Device {
  final String deviceId;
  final String token;
  final String platform;
  bool status;
  final DateTime lastLogin;
  bool isUpdating;

  Device({
    required this.deviceId,
    required this.token,
    required this.platform,
    required this.status,
    required this.lastLogin,
    this.isUpdating = false,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    String platform = json['platform'] ?? 'android';
    if (platform.isEmpty) {
      platform = json['device_id'].toString().toLowerCase().contains('iphone')
          ? 'ios'
          : 'android';
    }
    return Device(
      deviceId: json['device_id'],
      token: json['token'],
      platform: platform,
      status: json['status'],
      lastLogin: DateTime.parse(json['last_login']),
    );
  }

  String get lastLoginFormatted {
    return "${lastLogin.year}-${_twoDigits(lastLogin.month)}-${_twoDigits(lastLogin.day)} "
        "${_twoDigits(lastLogin.hour)}:${_twoDigits(lastLogin.minute)}";
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}

/// Handles all API interactions related to notification settings.
class ApiService {
  Future<List<Device>> fetchDevices() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/notifications/settings/device/all'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['statusCode'] == 200 && data['results'] != null) {
        List<Device> devices =
            (data['results'] as List).map((e) => Device.fromJson(e)).toList();
        return devices;
      } else {
        throw Exception(data['message'] ?? 'Failed to load devices');
      }
    } else {
      throw Exception('Failed to load devices: ${response.reasonPhrase}');
    }
  }

  Future<bool> updateDeviceStatus(Device device, bool newStatus) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/notifications/settings/device'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        "deviceId": device.deviceId,
        "deviceToken": device.token,
        "platform": device.platform,
        "status": newStatus,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['statusCode'] == 200;
    } else {
      return false;
    }
  }

  Future<bool> addDevice(
      String deviceId, String deviceToken, String platform) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/notifications/settings/device'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        "deviceId": deviceId,
        "deviceToken": deviceToken,
        "platform": platform,
        "status": true,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['statusCode'] == 200;
    } else {
      return false;
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
}
