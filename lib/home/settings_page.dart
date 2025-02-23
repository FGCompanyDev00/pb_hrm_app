// lib/settings/settings_page.dart

import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:pb_hrsystem/home/notification_settings_page.dart';
import 'package:pb_hrsystem/settings/change_password.dart';
import 'package:pb_hrsystem/settings/edit_profile.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  final LocalAuthentication auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();
  bool _biometricEnabled = false;
  bool _isLoading = false;
  late Future<UserProfile> futureUserProfile;
  String _appVersion = 'PSBV Next Demo v1.0.56(56)';
  late Box<String> userProfileBox;
  late Box<List<String>> bannersBox;

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
    _loadNotificationSetting();
    futureUserProfile = fetchUserProfile();
    _loadAppVersion();
    _initializeHiveBoxes();
  }

  Future<void> _initializeHiveBoxes() async {
    userProfileBox = await Hive.openBox<String>('userProfileBox');
    bannersBox = await Hive.openBox<List<String>>('bannersBox');
  }

  Future<void> _loadAppVersion() async {
    setState(() {
      _appVersion = 'PSBV Next Demo v1.0.56(56)';
      // _appVersion = 'PSBV Next v${packageInfo.version}';
    });
  }

  Future<void> _loadBiometricSetting() async {
    bool isEnabled =
        (await _storage.read(key: 'biometricEnabled') ?? 'false') == 'true';
    setState(() {
      _biometricEnabled = isEnabled;
    });
  }

  Future<void> _loadNotificationSetting() async {
    setState(() {});
  }

  Future<void> _saveBiometricSetting(bool enabled) async {
    await _storage.write(key: 'biometricEnabled', value: enabled.toString());
    debugPrint('Saved biometric, Enabled as: $enabled'); // Debugging
  }

  Future<void> _showBiometricModal() async {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/fingerprint.png',
                  height: 60,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Setup biometric login',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF9C640C),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Do you want to use biometric authentication as a preferred login method for the next time?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F1E0),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _enableBiometrics(true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDBB342),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _enableBiometrics(bool enable) async {
    if (enable) {
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.biometricNotAvailable),
            ),
          );
        }
        return;
      }
      try {
        bool authenticated = await auth.authenticate(
          localizedReason:
              AppLocalizations.of(context)!.authenticateToEnableBiometrics,
          options: const AuthenticationOptions(
            stickyAuth: true,
            useErrorDialogs: true,
          ),
        );
        if (authenticated) {
          setState(() {
            _biometricEnabled = true;
          });
          await _saveBiometricSetting(true);
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error enabling biometrics: $e');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .errorEnablingBiometrics(e.toString())),
            ),
          );
        }
      }
    } else {
      setState(() {
        _biometricEnabled = false;
      });
      await _storage.delete(key: 'biometricEnabled');
      await _saveBiometricSetting(false);
    }
  }

  Future<UserProfile> fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/api/display/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> results = jsonDecode(response.body)['results'];
      final userProfile = UserProfile.fromJson(results[0]);
      return userProfile;
    } else {
      throw Exception(AppLocalizations.of(context)!.failedToLoadUserProfile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return WillPopScope(
      onWillPop: () async {
        // Schedule the navigation to occur after the current frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const Dashboard()),
            (route) => false,
          );
        });
        // Prevent the default pop action
        return false;
      },
      child: Scaffold(
        backgroundColor: themeNotifier.isDarkMode ? Colors.black : Colors.white,
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  themeNotifier.isDarkMode
                      ? 'assets/darkbg.png'
                      : 'assets/background.png',
                ),
                fit: BoxFit.cover,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
          centerTitle: true,
          title: Text(
            AppLocalizations.of(context)!.settings,
            style: TextStyle(
              color: themeNotifier.isDarkMode ? Colors.white : Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: themeNotifier.isDarkMode ? Colors.white : Colors.black,
              size: 20,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          toolbarHeight: 100,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Account Settings Header
                    Row(
                      children: [
                        Image.asset(
                          'assets/account_settings.png',
                          width: 24,
                          height: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          AppLocalizations.of(context)!.accountSettings,
                          style: themeNotifier.textStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: themeNotifier.isDarkMode
                                ? Colors.grey[300]
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Change Password Tile
                    _buildSettingsTile(
                      context,
                      title: AppLocalizations.of(context)!.changePassword,
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ChangePasswordPage()),
                        );
                      },
                    ),
                    // Edit Profile Tile
                    _buildSettingsTile(
                      context,
                      title: AppLocalizations.of(context)!.editProfile,
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const EditProfilePage()),
                        );
                      },
                    ),
                    // Enable Biometric Authentication Switch
                    _buildSettingsTile(
                      context,
                      title: AppLocalizations.of(context)!.enableBiometricAuth,
                      trailing: Switch(
                        value: _biometricEnabled,
                        onChanged: (bool value) {
                          if (value) {
                            _showBiometricModal();
                          } else {
                            _enableBiometrics(false); // Disable biometrics
                          }
                        },
                        activeColor: const Color(0xFFDBB342),
                        inactiveTrackColor: themeNotifier.isDarkMode
                            ? Colors.grey[700]
                            : Colors.grey[300],
                      ),
                    ),
                    // Enable Dark Mode Switch
                    _buildSettingsTile(
                      context,
                      title: 'Dark Mode',
                      trailing: Switch(
                        value: themeNotifier.isDarkMode,
                        onChanged: (bool value) {
                          themeNotifier.toggleTheme();
                        },
                        activeColor: const Color(0xFFDBB342),
                        inactiveThumbColor: themeNotifier.isDarkMode
                            ? Colors.grey[600]
                            : Colors.grey,
                      ),
                    ),
                    // Notification Tile
                    _buildSettingsTile(
                      context,
                      title: AppLocalizations.of(context)!.notification,
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const NotificationSettingsPage()),
                        );
                      },
                    ),
                    // PIN Fallback Page Test Tile
                    // _buildSettingsTile(
                    //   context,
                    //   title: AppLocalizations.of(context)!.password,
                    //   icon: Icons.arrow_forward_ios,
                    //   onTap: () {
                    //     Navigator.push(
                    //       context,
                    //       MaterialPageRoute(builder: (context) => const PinEntryPage()),
                    //     );
                    //   },
                    // ),
                    // Display App Version
                    const SizedBox(height: 20),
                    // Debug Mode Section (Only visible in debug mode)
                    if (kDebugMode) ...[
                      Row(
                        children: [
                          Image.asset(
                            'assets/debug.png',
                            width: 24,
                            height: 24,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.bug_report),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Debug Mode',
                            style: themeNotifier.textStyle.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: themeNotifier.isDarkMode
                                  ? Colors.grey[300]
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Test Local Notification
                      _buildSettingsTile(
                        context,
                        title: 'Test Notification',
                        icon: Icons.notifications_active,
                        onTap: () => _showTestNotification(),
                      ),
                      // Test Network Performance
                      _buildSettingsTile(
                        context,
                        title: 'Test Network Performance',
                        icon: Icons.speed,
                        onTap: () => _testNetworkPerformance(),
                      ),
                      // Test App State
                      _buildSettingsTile(
                        context,
                        title: 'Test App State',
                        icon: Icons.app_settings_alt,
                        onTap: () => _testAppState(),
                      ),
                      // Test Location Services
                      _buildSettingsTile(
                        context,
                        title: 'Test Location Services',
                        icon: Icons.location_on,
                        onTap: () => _testLocationServices(),
                      ),
                      // Test Cache Management
                      _buildSettingsTile(
                        context,
                        title: 'Test Cache Management',
                        icon: Icons.storage,
                        onTap: () => _testCacheManagement(),
                      ),
                      // Performance Profiling
                      _buildSettingsTile(
                        context,
                        title: 'Performance Profiling',
                        icon: Icons.assessment,
                        onTap: () => _testPerformance(),
                      ),
                      // Network Connectivity Test
                      _buildSettingsTile(
                        context,
                        title: 'Network Connectivity Test',
                        icon: Icons.network_check,
                        onTap: () => _testNetworkConnectivity(),
                      ),
                      // Device Info Test
                      _buildSettingsTile(
                        context,
                        title: 'Device Info',
                        icon: Icons.devices,
                        onTap: () => _testDeviceInfo(),
                      ),
                    ],
                    Center(
                      child: Text(
                        _appVersion,
                        style: themeNotifier.textStyle.copyWith(
                          fontSize: 14,
                          color: themeNotifier.isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required String title,
    Widget? trailing,
    IconData? icon,
    void Function()? onTap,
  }) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        tileColor: isDarkMode ? Colors.grey[800] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 16,
          ),
        ),
        trailing: trailing ??
            Icon(icon, color: isDarkMode ? Colors.white70 : Colors.grey),
        onTap: onTap,
      ),
    );
  }

  // Add these new methods for debug testing
  Future<void> _showTestNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'debug_channel',
      'Debug Notifications',
      channelDescription: 'Channel for debug notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Debug Test Notification',
      'This is a test notification from debug mode',
      platformChannelSpecifics,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification sent!')),
      );
    }
  }

  Future<void> _testNetworkPerformance() async {
    setState(() => _isLoading = true);
    try {
      final stopwatch = Stopwatch()..start();

      // Test API response time
      final response = await http.get(Uri.parse('$baseUrl/api/display/me'));
      final responseTime = stopwatch.elapsedMilliseconds;

      // Test download speed with a small payload
      stopwatch.reset();
      await http.get(Uri.parse('$baseUrl/api/app/promotions/files'));
      final downloadTime = stopwatch.elapsedMilliseconds;

      stopwatch.stop();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Network Performance Results'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('API Response Time: ${responseTime}ms'),
                Text('Download Time: ${downloadTime}ms'),
                Text('Status Code: ${response.statusCode}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error testing network: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testAppState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> state = {
        'token': await prefs.getString('token'),
        'isFirstLogin': await prefs.getBool('isFirstLogin'),
        'biometricEnabled': await _storage.read(key: 'biometricEnabled'),
        'deviceInfo': {
          'platform': defaultTargetPlatform.toString(),
          'version': _appVersion,
        },
        'cacheStatus': {
          'userProfile': await userProfileBox.get('userProfile') != null,
          'banners': await bannersBox.get('banners') != null,
        },
      };

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('App State'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: state.entries
                    .map((e) => Text('${e.key}: ${e.value}'))
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error testing app state: $e')),
        );
      }
    }
  }

  // Add new testing methods
  Future<void> _testLocationServices() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final locationData = {
        'Latitude': position.latitude,
        'Longitude': position.longitude,
        'Accuracy': '${position.accuracy} meters',
        'Altitude': '${position.altitude} meters',
        'Speed': '${position.speed} m/s',
        'Time': DateTime.fromMillisecondsSinceEpoch(
          position.timestamp?.millisecondsSinceEpoch ?? 0,
        ).toString(),
      };

      if (mounted) {
        _showDebugDialog('Location Services Test', locationData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $e')),
        );
      }
    }
  }

  Future<void> _testCacheManagement() async {
    try {
      final cacheStats = {
        'Hive Boxes': {
          'User Profile': await userProfileBox.length,
          'Banners': await bannersBox.length,
        },
        'Shared Preferences': await SharedPreferences.getInstance().then(
          (prefs) => prefs.getKeys().length,
        ),
        'Secure Storage': await _storage.readAll().then(
              (values) => values.length,
            ),
      };

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cache Management'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await _clearAllCache();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cache cleared!')),
                    );
                  },
                  child: const Text('Clear All Cache'),
                ),
                const SizedBox(height: 20),
                const Text('Cache Statistics:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...cacheStats.entries.map((e) => Text('${e.key}: ${e.value}')),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cache management error: $e')),
        );
      }
    }
  }

  Future<void> _testPerformance() async {
    final stopwatch = Stopwatch()..start();
    final performanceData = <String, dynamic>{};

    try {
      // Test UI rendering
      performanceData['UI Render Time'] = '${stopwatch.elapsedMilliseconds}ms';
      stopwatch.reset();

      // Test memory usage
      performanceData['Memory Usage'] =
          '${(ProcessInfo.currentRss / 1024 / 1024).toStringAsFixed(2)}MB';

      // Test disk usage
      final tempDir = await getTemporaryDirectory();
      final appDir = await getApplicationDocumentsDirectory();
      performanceData['Disk Usage'] = {
        'Temp Directory': '${await _getDirSize(tempDir)}MB',
        'App Directory': '${await _getDirSize(appDir)}MB',
      };

      // Test database performance
      stopwatch.reset();
      await userProfileBox.get('userProfile');
      performanceData['Database Read Time'] =
          '${stopwatch.elapsedMilliseconds}ms';

      if (mounted) {
        _showDebugDialog('Performance Profile', performanceData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Performance test error: $e')),
        );
      }
    } finally {
      stopwatch.stop();
    }
  }

  Future<void> _testNetworkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasInternet = await InternetConnectionChecker().hasConnection;

      final speedTest = await _performSpeedTest();

      final connectivityData = {
        'Connection Type': connectivityResult.toString(),
        'Internet Available': hasInternet,
        'Download Speed': '${speedTest['download']} MB/s',
        'Upload Speed': '${speedTest['upload']} MB/s',
        'Latency': '${speedTest['latency']} ms',
      };

      if (mounted) {
        _showDebugDialog('Network Connectivity', connectivityData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network test error: $e')),
        );
      }
    }
  }

  Future<void> _testDeviceInfo() async {
    try {
      final deviceData = {
        'Platform': Platform.operatingSystem,
        'OS Version': Platform.operatingSystemVersion,
        'App Version': _appVersion,
        'Device Locale': Platform.localeName,
        'Screen Size':
            '${MediaQuery.of(context).size.width.toStringAsFixed(1)} x ${MediaQuery.of(context).size.height.toStringAsFixed(1)}',
        'Screen Density':
            MediaQuery.of(context).devicePixelRatio.toStringAsFixed(2),
        'Time Zone': DateTime.now().timeZoneName,
      };

      if (mounted) {
        _showDebugDialog('Device Info', deviceData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Device info error: $e')),
        );
      }
    }
  }

  void _showDebugDialog(String title, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.entries.map((e) {
              if (e.value is Map) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e.key}:',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    ...((e.value as Map).entries.map(
                          (subEntry) => Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: Text('${subEntry.key}: ${subEntry.value}'),
                          ),
                        )),
                  ],
                );
              }
              return Text('${e.key}: ${e.value}');
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllCache() async {
    await userProfileBox.clear();
    await bannersBox.clear();
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<double> _getDirSize(Directory dir) async {
    int totalSize = 0;
    try {
      if (dir.existsSync()) {
        dir
            .listSync(recursive: true, followLinks: false)
            .forEach((FileSystemEntity entity) {
          if (entity is File) {
            totalSize += entity.lengthSync();
          }
        });
      }
    } catch (e) {
      print('Error calculating directory size: $e');
    }
    return totalSize / (1024 * 1024); // Convert to MB
  }

  Future<Map<String, double>> _performSpeedTest() async {
    final stopwatch = Stopwatch()..start();

    // Simulate download test
    await http.get(Uri.parse('$baseUrl/api/app/promotions/files'));
    final downloadTime = stopwatch.elapsedMilliseconds;

    // Simulate upload test
    stopwatch.reset();
    await http.post(Uri.parse('$baseUrl/api/login'), body: {'test': 'data'});
    final uploadTime = stopwatch.elapsedMilliseconds;

    // Simulate latency test
    stopwatch.reset();
    await http.get(Uri.parse('$baseUrl/api/ping'));
    final latency = stopwatch.elapsedMilliseconds;

    stopwatch.stop();

    return {
      'download': 1024 / downloadTime, // Simulated MB/s
      'upload': 1024 / uploadTime, // Simulated MB/s
      'latency': latency.toDouble(),
    };
  }
}

class UserProfile {
  final String id;
  final String name;
  final String surname;
  final String email;
  final String imgName;
  final String roles;

  UserProfile({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    required this.imgName,
    required this.roles,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      name: json['employee_name'],
      surname: json['employee_surname'],
      email: json['employee_email'],
      imgName: json['images'],
      roles: json['roles'],
    );
  }
}
