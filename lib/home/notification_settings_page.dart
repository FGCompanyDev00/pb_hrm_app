import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:platform/platform.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> _initializeDevices() async {
    await _fetchDeviceToken(); // Get device token first
    await _fetchDeviceId(); // Get device ID
    await _loadDevices(); // Then load devices
    
    // Check if current device exists in the list
    if (_deviceToken != null) {
      bool deviceExists = _devices.any((device) => device.token == _deviceToken);
      if (!deviceExists) {
        // Auto show add device modal if current device not found
        if (mounted) {
          _showAddDeviceDialog();
        }
      }
    }
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
      bool updated = await _apiService.updateDeviceStatus(device, !device.status);
      if (updated) {
        setState(() {
          device.status = !device.status;
        });
        _showSnackBar('Notification setting updated successfully');
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
  Future<void> _addDevice(String deviceId, String deviceToken, String platform) async {
    setState(() {
      _isLoading = true;
    });
    try {
      bool added = await _apiService.addDevice(deviceId, deviceToken, platform);
      if (added) {
        // Show success validation modal
        _showValidationModal('Device added successfully', true);
        // Reload devices after successful addition
        _loadDevices();
      } else {
        // Show failure validation modal
        _showValidationModal('Failed to add device', false);
      }
    } catch (e) {
      // Handle error and show failure validation modal
      _showValidationModal('Error adding device: $e', false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Displays the API message in a dialog after adding the device
  void _showValidationModal(String message, bool isSuccess) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing the dialog manually
      builder: (context) {
        return AlertDialog(
          title: Text(isSuccess ? 'Success' : 'Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the validation modal
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    ).then((_) {
      // Auto-refresh devices after dialog is closed if success
      if (isSuccess) {
        _loadDevices(); // Refresh device list
      }
    });
  }

  /// Displays the dialog to add a new device.
  void _showAddDeviceDialog() {
    final formKey = GlobalKey<FormState>();
    String platform = defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Device'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Device ID'),
                    initialValue: _deviceId,
                    enabled: false, // Cannot be edited
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Device Token'),
                    initialValue: _deviceToken, // Auto-fill the token
                    enabled: false, // Prevent editing
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Platform'),
                    initialValue: platform, // Automatically set platform
                    enabled: false, // Prevent editing
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_biometricEnabled) {
                  await _addDevice(_deviceId, _deviceToken ?? '', platform);
                } else {
                  Navigator.of(context).pop();
                  _showBiometricPrompt();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  /// Prompts the user to enable biometric authentication in Settings.
  void _showBiometricPrompt() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fingerprint, size: 24, color: Colors.blueAccent),
              SizedBox(height: 12),
              Text(
                'Biometric Authentication',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: const Text(
            'Enable biometric authentication in Settings to register a new device.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.redAccent,
            ),
          ),
        );
      },
    );
  }

  /// Handles biometric authentication (if needed in the future).
  Future<void> _enableBiometrics(bool enable) async {
    // Since biometric settings are managed in settings_page.dart,
    // this function can be left empty or used for future enhancements.
  }

  /// Displays a SnackBar with the provided message.
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
            image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
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
                    bool isCurrentDevice = device.token == _deviceToken;
                    return ListTile(
                      leading: Image.asset(
                        device.platform == 'android' ? 'assets/android_device.png' : 'assets/ios_device.png',
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
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
                      subtitle: Text('Last login: ${device.lastLoginFormatted}'),
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
                              onChanged: null, // Disabled interaction
                              activeColor: Colors.green,
                              activeTrackColor: Colors.green.withOpacity(0.5),
                              inactiveThumbColor: Colors.grey,
                              inactiveTrackColor: Colors.grey.withOpacity(0.5),
                            ),
                      onTap: isCurrentDevice ? () => _showAddDeviceDialog() : null,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      // Removed floating action button as requested
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
      platform = json['device_id'].toString().toLowerCase().contains('iphone') ? 'ios' : 'android';
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
        List<Device> devices = (data['results'] as List).map((e) => Device.fromJson(e)).toList();
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

  Future<bool> addDevice(String deviceId, String deviceToken, String platform) async {
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
