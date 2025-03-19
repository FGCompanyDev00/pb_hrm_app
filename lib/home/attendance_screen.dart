// attendance_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/services/offline_service.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../settings/theme_notifier.dart';
import 'monthly_attendance_record.dart';
import '../hive_helper/model/attendance_record.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  AttendanceScreenState createState() => AttendanceScreenState();
}

class AttendanceScreenState extends State<AttendanceScreen> {
  // Add memory efficient caching
  static final Map<String, String> _cachedTimes = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  DateTime? _lastCacheUpdate;

  // Optimize state variables
  late final LocalAuthentication auth;
  late final FlutterSecureStorage _storage;
  late final UserPreferences userPreferences;

  // Time and date tracking
  DateTime? _checkInDateTime;
  DateTime? _checkOutDateTime;
  Duration _workingHours = Duration.zero;
  String _deviceId = '';

  // Timers and subscriptions
  Timer? _timer;
  Timer? _refreshTimer;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Use ValueNotifier for reactive state management
  final ValueNotifier<bool> _isCheckInActive = ValueNotifier<bool>(false);
  final ValueNotifier<String> _checkInTime = ValueNotifier<String>('--:--:--');
  final ValueNotifier<String> _checkOutTime = ValueNotifier<String>('--:--:--');
  final ValueNotifier<String> _limitTime = ValueNotifier<String>('--:--:--');
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _isOffsite = ValueNotifier<bool>(false);
  final ValueNotifier<List<Map<String, String>>> _weeklyRecords =
      ValueNotifier<List<Map<String, String>>>([]);

  // Add detailed loading state
  final ValueNotifier<String> _loadingMessage =
      ValueNotifier<String>('Initializing...');
  final ValueNotifier<bool> _isInteractive = ValueNotifier<bool>(false);

  // Optimize location tracking
  Position? _lastKnownPosition;
  DateTime? _lastLocationUpdate;
  static const Duration _locationUpdateThreshold = Duration(minutes: 1);

  late String baseUrl;
  late String officeApiUrl;
  late String offsiteApiUrl;

  static const double _officeRange = 500;
  static LatLng officeLocation = const LatLng(2.891589, 101.524822);

  @override
  void initState() {
    super.initState();

    // Initialize services efficiently
    auth = LocalAuthentication();
    _storage = const FlutterSecureStorage();
    userPreferences = sl<UserPreferences>();

    baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';
    officeApiUrl = '$baseUrl/api/attendance/checkin-checkout/office';
    offsiteApiUrl = '$baseUrl/api/attendance/checkin-checkout/offsite';

    _isOffsite.value = false;

    // Make screen interactive immediately
    _isInteractive.value = true;

    // Initialize in parallel
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Perform the most critical state restoration first
    await _retrieveSavedState();

    // Update loading message
    _loadingMessage.value = 'Retrieving device info...';
    await _retrieveDeviceId();

    _loadingMessage.value = 'Setting up location services...';
    _startLocationMonitoring();
    _startTimerForLiveTime();

    _loadingMessage.value = 'Loading time limits...';
    await _fetchLimitTime();

    // Fetch records in background
    _fetchWeeklyRecordsInBackground();

    // Optimize connectivity listener
    connectivityResult.onConnectivityChanged.listen(_handleConnectivityChange);

    // Refresh timer with optimal interval
    _refreshTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      if (!mounted) return;
      _fetchWeeklyRecordsInBackground();
    });

    // Hide loading indicator after essential services are initialized
    if (mounted) {
      _isLoading.value = false;
    }
  }

  // New method to fetch weekly records in background
  Future<void> _fetchWeeklyRecordsInBackground() async {
    if (!mounted) return;

    try {
      final String? token = userPreferences.getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('$baseUrl/api/attendance/checkin-checkout/offices/weekly/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _updateWeeklyRecords(data);
        _lastCacheUpdate = DateTime.now();
      }
    } catch (e) {
      debugPrint('Error fetching weekly records in background: $e');
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> source) {
    if (!mounted) return;

    final bool hasInternet = source.contains(ConnectivityResult.wifi) ||
        source.contains(ConnectivityResult.mobile);

    offlineProvider.autoOffline(!hasInternet);
    if (hasInternet) {
      offlineProvider.syncPendingAttendance();
    }
  }

  // Optimize location monitoring
  void _startLocationMonitoring() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    // Optimize location updates
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        timeLimit: Duration(seconds: 30),
      ),
    ).listen(_handleLocationUpdate);
  }

  void _handleLocationUpdate(Position position) {
    if (!mounted) return;

    final now = DateTime.now();
    if (_lastLocationUpdate != null &&
        now.difference(_lastLocationUpdate!) < _locationUpdateThreshold) {
      return;
    }

    _lastLocationUpdate = now;
    _lastKnownPosition = position;
    // _determineSectionFromPosition(position);
  }

  // Optimize API calls with caching
  Future<void> _fetchWeeklyRecords() async {
    if (!mounted) return;

    final now = DateTime.now();
    if (_lastCacheUpdate != null &&
        now.difference(_lastCacheUpdate!) < _cacheExpiry) {
      return;
    }

    // Only show loading indicator if we don't have cached data
    bool showLoading = _weeklyRecords.value.isEmpty;

    if (showLoading && mounted) {
      _isLoading.value = true;
      _loadingMessage.value = 'Fetching attendance records...';
    }

    try {
      final String? token = userPreferences.getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('$baseUrl/api/attendance/checkin-checkout/offices/weekly/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _updateWeeklyRecords(data);
        _lastCacheUpdate = now;
      }
    } catch (e) {
      debugPrint('Error fetching weekly records: $e');
    } finally {
      if (mounted && showLoading) {
        _isLoading.value = false;
      }
    }
  }

  void _updateWeeklyRecords(Map<String, dynamic> data) {
    if (!mounted) return;

    final monthlyData = data['TotalWorkDurationForMonth'];
    final weeklyRecords = (data['weekly'] as List)
        .map((item) => {
              'date': item['check_in_date'].toString(),
              'checkIn': item['check_in_time'].toString(),
              'checkOut': item['check_out_time'].toString(),
              'workingHours': item['workDuration'].toString(),
              'checkInStatus': item['check_in_status']?.toString() ?? 'unknown',
              'checkOutStatus':
                  item['check_out_status']?.toString() ?? 'unknown',
            })
        .toList();

    _weeklyRecords.value = weeklyRecords;
    _cachedTimes['totalCheckInDelay'] =
        monthlyData['totalCheckInDelay']?.toString() ?? '--:--:--';
    _cachedTimes['totalCheckOutDelay'] =
        monthlyData['totalCheckOutDelay']?.toString() ?? '--:--:--';
    _cachedTimes['totalWorkDuration'] =
        monthlyData['totalWorkDuration']?.toString() ?? '--:--:--';
  }

  @override
  void dispose() {
    // Clean up resources
    _timer?.cancel();
    _positionStreamSubscription?.cancel();
    _refreshTimer?.cancel();
    _isCheckInActive.dispose();
    _checkInTime.dispose();
    _checkOutTime.dispose();
    _limitTime.dispose();
    _isLoading.dispose();
    _isOffsite.dispose();
    _weeklyRecords.dispose();
    _loadingMessage.dispose();
    _isInteractive.dispose();
    super.dispose();
  }

  Future<void> _fetchLimitTime() async {
    final String endpoint =
        '$baseUrl/api/attendance/checkin-checkout/offices/weekly/me';

    try {
      String? token = userPreferences.getToken();

      if (token == null) {
        throw Exception('No token found');
      }

      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String limitTime = data['settings']['limit_time'] ?? '--:--:--';

        setState(() {
          _limitTime.value = limitTime;
        });
      } else {
        throw Exception('Failed to load limit time');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching limit time: $e');
      }
    }
  }

  Future<void> _determineAndShowLocationModal() async {
    // Don't show loading indicator here
    Position? currentPosition = await _getCurrentPosition();
    if (currentPosition != null) {
      // _determineSectionFromPosition(currentPosition);
    }
  }

  String _getCurrentApiUrl() {
    return _isOffsite.value ? offsiteApiUrl : officeApiUrl;
  }

  String _formatDuration(Duration duration) {
    int hours = duration.inHours;
    int minutes = duration.inMinutes % 60;
    int seconds = duration.inSeconds % 60;
    String hoursStr = hours.toString().padLeft(2, '0');
    String minutesStr = minutes.toString().padLeft(2, '0');
    String secondsStr = seconds.toString().padLeft(2, '0');
    return '$hoursStr:$minutesStr:$secondsStr';
  }

  Future<void> _retrieveSavedState() async {
    String? savedCheckInTime = userPreferences.getCheckInTime();
    String? savedCheckOutTime = userPreferences.getCheckOutTime();
    String? lastAction = userPreferences
        .getLastAction(); // New: Track last action (checkIn/checkOut)
    Duration? savedWorkingHours = userPreferences.getWorkingHours();

    setState(() {
      _checkInTime.value = savedCheckInTime ?? '--:--:--';
      _checkOutTime.value = savedCheckOutTime ?? '--:--:--';
      _checkInDateTime = savedCheckInTime != null
          ? DateFormat('HH:mm:ss').parse(savedCheckInTime)
          : null;
      _checkOutDateTime = savedCheckOutTime != null
          ? DateFormat('HH:mm:ss').parse(savedCheckOutTime)
          : null;
      _isCheckInActive.value = lastAction ==
          "checkIn"; // Determines if next action should be check-out
      _workingHours = savedWorkingHours ?? Duration.zero;
    });

    if (_isCheckInActive.value) {
      _startTimerForWorkingHours();
    }
  }

  Future<void> _retrieveDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      _deviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      _deviceId = iosInfo.identifierForVendor!;
    }
    setState(() {
      sl<UserPreferences>().setDevice(_deviceId);
      if (kDebugMode) {
        print('Device ID retrieved: $_deviceId');
      }
    });
  }

  Future<void> _performCheckIn(DateTime now) async {
    AttendanceRecord record = AttendanceRecord(
      deviceId: _deviceId,
      latitude: '',
      longitude: '',
      section: _isOffsite.value ? 'Offsite' : 'Office',
      type: 'checkIn',
      timestamp: now,
    );

    Position? currentPosition = await _getCurrentPosition();
    if (currentPosition != null) {
      record.latitude = currentPosition.latitude.toString();
      record.longitude = currentPosition.longitude.toString();

      // Validate location is within allowed areas if not offsite
      if (!_isOffsite.value && !await _isWithinAllowedArea(currentPosition)) {
        await _showValidationModal(true, false, 'Location Verification Failed',
            'You are not within an approved work location. Please check in from an authorized location or select "Offsite" if working remotely.');
        return;
      }
    } else {
      // No position available
      if (!_isOffsite.value) {
        await _showValidationModal(true, false, 'Location Required',
            'Unable to verify your location. Please enable location services and try again, or select "Offsite" if working remotely.');
        return;
      }
    }

    bool success = await _sendCheckInOutRequest(record);
    if (success) {
      _applyCheckInState(now);
      await _showValidationModal(true, true, 'Check-In Successful',
          'Your check-in was recorded successfully.');
      await _showCheckInNotification(
          _checkInTime.value); // ✅ Only trigger if successful
    } else {
      await _showValidationModal(true, false, 'Check-In Failed',
          'There was an issue checking in. Please try again.');
    }
  }

  void _applyCheckInState(DateTime now) {
    setState(() {
      _checkInTime.value = DateFormat('HH:mm:ss').format(now);
      _checkInDateTime = now;
      _checkOutTime.value = '--:--:--';
      _checkOutDateTime = null;
      _workingHours = Duration.zero;
      _isCheckInActive.value = true;
    });

    userPreferences.storeCheckInTime(_checkInTime.value);
    userPreferences.storeCheckOutTime(_checkOutTime.value);
    userPreferences
        .storeLastAction("checkIn"); // 🔹 Save last action as check-in
    _startTimerForWorkingHours();
  }

  Future<void> _showCheckInNotification(String checkInTime) async {
    if (kDebugMode) {
      print('Attempting to show Check-in notification with time: $checkInTime');
    }

    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'attendance_channel_id',
        'Attendance Notifications',
        channelDescription: 'Notifications for check-in/check-out',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        100, // Unique Notification ID for Check-in
        'Check-in Successful', // Title
        'Check-in Time: $checkInTime', // Body
        notificationDetails,
        payload: 'check_in', // Optional payload
      );

      if (kDebugMode) {
        print('Check-in notification displayed successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error displaying Check-in notification: $e');
      }
    }
  }

  Future<void> _performCheckOut(DateTime now) async {
    AttendanceRecord record = AttendanceRecord(
      deviceId: _deviceId,
      latitude: '',
      longitude: '',
      section: _isOffsite.value ? 'Offsite' : 'Office',
      type: 'checkOut',
      timestamp: now,
    );

    Position? currentPosition = await _getCurrentPosition();
    if (currentPosition != null) {
      record.latitude = currentPosition.latitude.toString();
      record.longitude = currentPosition.longitude.toString();
    }

    bool success = await _sendCheckInOutRequest(record);
    if (success) {
      _applyCheckOutState(now);
      await _showValidationModal(false, true, 'Check-Out Successful',
          'Your check-out was recorded successfully.');
      await _showCheckOutNotification(
          _checkOutTime.value, _workingHours); // ✅ Only trigger if successful
    } else {
      await _showValidationModal(false, false, 'Check-Out Failed',
          'There was an issue checking out. Please try again.');
    }
  }

  /// Applies the local changes for check-out
  void _applyCheckOutState(DateTime now) {
    setState(() {
      _checkOutTime.value = DateFormat('HH:mm:ss').format(now);
      _checkOutDateTime = now;
      if (_checkInDateTime != null) {
        _workingHours = now.difference(_checkInDateTime!);
        _isCheckInActive.value = false;
        _timer?.cancel();
      }
    });

    userPreferences.storeCheckOutTime(_checkOutTime.value);
    userPreferences.storeWorkingHours(_workingHours);
    userPreferences
        .storeLastAction("checkOut"); // 🔹 Save last action as check-out
  }

  // Method to show notification for check-out
  Future<void> _showCheckOutNotification(
      String checkOutTime, Duration workingHours) async {
    if (kDebugMode) {
      print(
          'Attempting to show Check-out notification with time: $checkOutTime and working hours: $workingHours');
    }

    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'attendance_channel_id',
        'Attendance Notifications',
        channelDescription: 'Notifications for check-in/check-out',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      String workingHoursString = _formatDuration(workingHours);

      await flutterLocalNotificationsPlugin.show(
        101, // Unique Notification ID for Check-out
        'Check-out Successful', // Title
        'Check-out Time: $checkOutTime\nWorking Hours: $workingHoursString', // Body
        notificationDetails,
        payload: 'check_out', // Optional payload
      );

      if (kDebugMode) {
        print('Check-out notification displayed successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error displaying Check-out notification: $e');
      }
    }
  }

  Future<void> _showValidationModal(
      bool isCheckIn, bool isSuccess, String title, String message) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        Color backgroundColor = isSuccess ? Colors.green : Colors.red;
        Color iconColor = isSuccess ? Colors.greenAccent : Colors.redAccent;
        IconData iconData =
            isSuccess ? Icons.check_circle_outline : Icons.cancel_outlined;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isDarkMode ? Colors.grey[900] : Colors.white,
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title and Status
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Center(
                    child: Text(
                      isCheckIn ? "Check-In Status" : "Check-Out Status",
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Icon
                Icon(iconData, size: 50, color: iconColor),
                const SizedBox(height: 16),

                // Title
                Text(title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                // API Error Message
                Text(message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16)),

                const SizedBox(height: 20),

                // Close Button
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: backgroundColor),
                  child: const Text("Close",
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _sendCheckInOutRequest(AttendanceRecord record) async {
    if (sl<OfflineProvider>().isOfflineService.value) {
      return false;
    }

    String url = _getCurrentApiUrl();
    String? token = userPreferences.getToken();

    if (token == null) {
      if (mounted) {
        _showCustomDialog(
          "Error",
          "No token found. Please log in again.",
          isSuccess: false,
        );
      }
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "device_id": record.deviceId,
          "latitude": record.latitude,
          "longitude": record.longitude,
        }),
      );

      if (response.statusCode == 201) {
        return true; // ✅ Check-in/Check-out was successful
      } else if (response.statusCode == 202 && url == officeApiUrl) {
        // ❌ Office Check-in/Check-out failed due to location restrictions
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final String errorMessage = data['message'] ??
            "Check-in/check-out not allowed due to location restrictions.";

        if (mounted) {
          _showValidationModal(record.type == 'checkIn', false,
              "Location Error", errorMessage // ✅ Show API message in modal
              );
        }
        return false; // ❌ Prevent state updates
      } else {
        throw Exception('Failed with status code ${response.statusCode}');
      }
    } catch (error) {
      if (mounted) {
        _showCustomDialog(
          "Error",
          'Check-in/check-out failed: $error',
          isSuccess: false,
        );
      }
      return false;
    }
  }

  void _startTimerForLiveTime() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {}); // Update the UI every second
    });
  }

  void _startTimerForWorkingHours() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_checkInDateTime != null && _checkOutDateTime == null) {
        setState(() {
          _workingHours = DateTime.now().difference(_checkInDateTime!);
        });

        // Save the working hours in SharedPreferences
        userPreferences.storeWorkingHours(_workingHours);
      }
    });
  }

  Future<void> _authenticate(BuildContext context, bool isCheckIn) async {
    // Dynamically check biometric capabilities and settings
    bool canCheckBiometrics = await auth.canCheckBiometrics;
    bool isDeviceSupported = await auth.isDeviceSupported();
    String? biometricEnabledStored =
        await _storage.read(key: 'biometricEnabled');

    // Update the biometricEnabled state based on current settings
    bool biometricEnabled = (biometricEnabledStored == 'true') &&
        canCheckBiometrics &&
        isDeviceSupported;

    if (!biometricEnabled) {
      if (context.mounted) {
        _showCustomDialog(
          AppLocalizations.of(context)!.biometricNotEnabled,
          AppLocalizations.of(context)!.enableBiometricFirst,
          isSuccess: false,
        );
      }

      return;
    }

    // Proceed with authentication
    bool didAuthenticate = await _authenticateWithBiometrics();

    if (!didAuthenticate) {
      if (context.mounted) {
        _showCustomDialog(
          AppLocalizations.of(context)!.authenticationFailed,
          AppLocalizations.of(context)!.authenticateToContinue,
          isSuccess: false,
        );
      }
      return;
    }

    // Perform Check-In or Check-Out based on the flag
    if (isCheckIn) {
      _performCheckIn(DateTime.now());
    } else {
      _performCheckOut(DateTime.now());
    }
  }

  Future<bool> _authenticateWithBiometrics() async {
    try {
      return await auth.authenticate(
        localizedReason: AppLocalizations.of(context)!.authenticateToLogin,
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error using biometrics: $e');
      }
      return false;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase() ?? 'unknown') {
      case 'office':
        return Colors.green;
      case 'offsite':
        return Colors.red;
      case 'home':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showCustomDialog(
            "Location Required",
            "Please enable location services to check in/out.",
            isSuccess: false,
          );
        }
        return null;
      }

      // Check if we have permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showCustomDialog(
              "Permission Denied",
              "Location permission is required for attendance.",
              isSuccess: false,
            );
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showCustomDialog(
            "Permission Denied",
            "Location permission is permanently denied. Please enable it in settings.",
            isSuccess: false,
          );
        }
        return null;
      }

      // Get position with high accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // Check for fake location indicators
      if (!await _isLocationReal(position)) {
        if (mounted) {
          _showCustomDialog(
            "Security Alert",
            "Fake location detected. Please disable any mock location apps and try again.",
            isSuccess: false,
          );
        }
        return null;
      }

      return position;
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving location: $e');
      }
      if (mounted) {
        _showCustomDialog(
          "Location Error",
          "Unable to get your location. Please try again.",
          isSuccess: false,
        );
      }
      return null;
    }
  }

  /// Checks if the location is real or fake using multiple indicators
  Future<void> _logFakeLocationAttempt(
      Position fakePosition, Position? realPosition) async {
    try {
      String? token = userPreferences.getToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse('$baseUrl/api/attendance/checkin-checkout/logs'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'device_id': _deviceId,
          'latitude': fakePosition.latitude.toString(),
          'longitude': fakePosition.longitude.toString(),
          'latitude_fake': realPosition?.latitude.toString() ??
              fakePosition.latitude.toString(),
          'longitude_fake': realPosition?.longitude.toString() ??
              fakePosition.longitude.toString(),
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
            'Failed to log fake location attempt: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error logging fake location attempt: $e');
    }
  }

  Future<bool> _isLocationReal(Position position) async {
    try {
      Position? realPosition;

      // 1. Check if mock location setting is enabled (Android only)
      if (Platform.isAndroid) {
        if (position.isMocked) {
          debugPrint('Mock location detected via isMocked flag');
          // Try to get real location for logging
          try {
            realPosition = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
                forceAndroidLocationManager:
                    true // This might help bypass mock locations
                );
          } catch (e) {
            debugPrint('Could not get real location: $e');
          }
          await _logFakeLocationAttempt(position, realPosition);
          return false;
        }
      }

      // 2. Check for unrealistic accuracy (too perfect)
      if (position.accuracy < 1.0) {
        debugPrint(
            'Suspiciously perfect accuracy detected: ${position.accuracy}m');
        await _logFakeLocationAttempt(position, null);
        return false;
      }

      // 3. Check for unrealistic speed changes
      Position? lastPosition = await _getLastStoredPosition();
      if (lastPosition != null) {
        final distance = Geolocator.distanceBetween(
          lastPosition.latitude,
          lastPosition.longitude,
          position.latitude,
          position.longitude,
        );

        final timeDiff =
            position.timestamp.difference(lastPosition.timestamp).inSeconds;
        if (timeDiff > 0) {
          // Calculate speed in meters per second
          final speed = distance / timeDiff;

          // If speed is greater than 100 m/s (360 km/h), it's likely fake
          // This catches teleportation between locations
          if (speed > 100 && distance > 1000) {
            debugPrint('Unrealistic movement detected: $speed m/s');
            await _logFakeLocationAttempt(position, null);
            return false;
          }
        }
      }

      // 4. Check for location jumps (teleportation)
      if (lastPosition != null) {
        final distance = Geolocator.distanceBetween(
          lastPosition.latitude,
          lastPosition.longitude,
          position.latitude,
          position.longitude,
        );

        final timeDiff = position.timestamp
            .difference(lastPosition.timestamp)
            .inMilliseconds;
        if (timeDiff < 1000 && distance > 500) {
          // 500m in less than 1 second
          debugPrint(
              'Teleportation detected: $distance meters in $timeDiff ms');
          await _logFakeLocationAttempt(position, null);
          return false;
        }
      }

      // 5. Store this position for future comparisons
      await _storePosition(position);

      return true;
    } catch (e) {
      debugPrint('Error in fake location check: $e');
      // Default to allowing the location if our checks fail
      return true;
    }
  }

  /// Stores the position for future comparison
  Future<void> _storePosition(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'last_position',
          jsonEncode({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'altitude': position.altitude,
            'speed': position.speed,
            'speedAccuracy': position.speedAccuracy,
            'altitudeAccuracy': position.altitudeAccuracy,
            'headingAccuracy': position.headingAccuracy,
            'heading': position.heading,
            'timestamp': position.timestamp.millisecondsSinceEpoch,
          }));
    } catch (e) {
      debugPrint('Error storing position: $e');
    }
  }

  /// Retrieves the last stored position
  Future<Position?> _getLastStoredPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final positionJson = prefs.getString('last_position');
      if (positionJson == null) return null;

      final data = jsonDecode(positionJson) as Map<String, dynamic>;
      return Position(
        latitude: data['latitude'],
        longitude: data['longitude'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp']),
        accuracy: data['accuracy'],
        altitude: data['altitude'],
        heading: data['heading'],
        speed: data['speed'],
        speedAccuracy: data['speedAccuracy'],
        altitudeAccuracy: 0.0, // Required parameter in newer versions
        headingAccuracy: 0.0, // Required parameter in newer versions
        floor: null,
        isMocked: false,
      );
    } catch (e) {
      debugPrint('Error retrieving stored position: $e');
      return null;
    }
  }

  /// Checks if the user's location is within allowed work areas
  Future<bool> _isWithinAllowedArea(Position position) async {
    try {
      // First try to get allowed locations from the server
      final allowedLocations = await _fetchAllowedLocations();

      // If we have server-defined locations, use those
      if (allowedLocations.isNotEmpty) {
        return _checkAgainstServerLocations(position, allowedLocations);
      }

      // Fallback to locally defined office locations if server didn't provide any
      return _checkAgainstLocalLocations(position);
    } catch (e) {
      debugPrint('Error checking allowed areas: $e');
      // Default to allowing the check-in if our verification fails
      // This prevents blocking legitimate check-ins due to technical issues
      return true;
    }
  }

  /// Fetches allowed check-in locations from the server
  Future<List<Map<String, dynamic>>> _fetchAllowedLocations() async {
    try {
      final url = '${_getCurrentApiUrl()}/allowed-locations';
      final token = userPreferences.getToken();

      if (token == null) {
        return [];
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }

      return [];
    } catch (e) {
      debugPrint('Error fetching allowed locations: $e');
      return [];
    }
  }

  /// Checks the position against server-provided allowed locations
  bool _checkAgainstServerLocations(
      Position position, List<Map<String, dynamic>> allowedLocations) {
    for (final location in allowedLocations) {
      try {
        final double latitude = double.parse(location['latitude'].toString());
        final double longitude = double.parse(location['longitude'].toString());
        final double radius =
            double.parse(location['radius'].toString()); // radius in meters

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          latitude,
          longitude,
        );

        if (distance <= radius) {
          return true; // Within an allowed area
        }
      } catch (e) {
        debugPrint('Error processing location $location: $e');
      }
    }

    return false; // Not within any allowed area
  }

  /// Checks the position against locally defined office locations
  /// This is a fallback when server locations aren't available
  bool _checkAgainstLocalLocations(Position position) {
    // Define office locations with their coordinates and radius
    final officeLocations = [
      // Phongsavanh Bank Headquarters in Laos
      {
        'name': 'Phongsavanh Bank HQ',
        'latitude': 17.9757, // Vientiane, Laos coordinates
        'longitude': 102.6331, // Vientiane, Laos coordinates
        'radius': 200.0, // 200 meters radius
      },
      // Phongsavanh Bank Branch Office
      {
        'name': 'Phongsavanh Bank Branch',
        'latitude': 17.9662, // Another Vientiane location
        'longitude': 102.6127, // Another Vientiane location
        'radius': 150.0, // 150 meters radius
      },
    ];

    for (final office in officeLocations) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        office['latitude'] as double,
        office['longitude'] as double,
      );

      if (distance <= (office['radius'] as double)) {
        return true; // Within an allowed office area
      }
    }

    return false; // Not within any defined office
  }

  Widget _buildPageContent(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchWeeklyRecords();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Your attendance data has been refreshed successfully",
                style: TextStyle(fontSize: 13, color: Colors.white),
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
              margin: EdgeInsets.all(20),
              duration: Duration(seconds: 3),
            ),
          );
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14.0),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildHeaderContent(context),
            _buildWeeklyRecordsList(),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const MonthlyAttendanceReport()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: Theme.of(context).brightness ==
                          Brightness.dark
                      ? const Color(
                          0xFFDBB342) // Dark mode background color (#DBB342)
                      : Colors.green, // Light mode background color (green)
                  elevation: 4,
                ),
                icon: const Icon(Icons.view_agenda, color: Colors.white),
                label: Text(
                  AppLocalizations.of(context)!.viewAll,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  void _showCustomDialog(String title, String message,
      {bool isSuccess = true}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isDarkMode ? Colors.grey[900] : Colors.white,
              border: Border.all(
                color: isDarkMode ? Colors.white24 : Colors.black12,
                width: 1,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: constraints.maxWidth < 400
                        ? constraints.maxWidth * 0.9
                        : 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Attendance icon and text row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/attendance.png',
                              width: 40,
                              color:
                                  isDarkMode ? const Color(0xFFDBB342) : null,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              AppLocalizations.of(context)!.attendance,
                              style: TextStyle(
                                fontSize: constraints.maxWidth < 400 ? 18 : 20,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Tick icon and title row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSuccess
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color: isSuccess
                                  ? (isDarkMode
                                      ? Colors.greenAccent
                                      : Colors.green)
                                  : (isDarkMode
                                      ? Colors.redAccent
                                      : Colors.red),
                              size: constraints.maxWidth < 400 ? 40 : 50,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              title, // Example: 'Check IN success!'
                              style: TextStyle(
                                fontSize: constraints.maxWidth < 400 ? 18 : 20,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Message text
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: constraints.maxWidth < 400 ? 14 : 16,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.grey : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Close button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                  0xFFDBB342), // Gold color for button
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.0),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.close,
                              style: TextStyle(
                                fontSize: constraints.maxWidth < 400 ? 14 : 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceRow(Map<String, String> record) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final DateTime date = DateFormat('yyyy-MM-dd').parse(record['date']!);
    final String day = DateFormat('EEEE').format(date); // Day part
    final String datePart = DateFormat('dd-MM-yyyy').format(date); // Date part

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: isDarkMode
          ? Colors.grey[800]
          : Colors.white, // Adjust background color based on theme
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          children: [
            // Centered Date Display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: day, // Weekday
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : const Color(0xFF003366),
                        ),
                      ),
                      const TextSpan(text: ', '), // Comma separator
                      TextSpan(
                        text: datePart, // Date part
                        style: TextStyle(
                          fontSize: 15,
                          color: isDarkMode ? Colors.white70 : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Optional Status Icon for Check-Out
                _buildAttendanceStatusIcon(record['checkOut']!),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
            const SizedBox(height: 8),
            // Attendance Items Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttendanceItem(
                  AppLocalizations.of(context)!.checkIn,
                  record['checkIn'] ?? '--:--:--',
                  _getStatusColor(record['checkInStatus']),
                ),
                _buildAttendanceItem(
                  AppLocalizations.of(context)!.checkOut,
                  record['checkOut'] ?? '--:--:--',
                  _getStatusColor(record['checkOutStatus']),
                ),
                _buildAttendanceItem(AppLocalizations.of(context)!.workingHours,
                    record['workingHours']!, Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceStatusIcon(String checkOutTime) {
    return Icon(
      checkOutTime != '--:--:--' ? Icons.check_circle : Icons.hourglass_empty,
      color: checkOutTime != '--:--:--' ? Colors.green : Colors.orange,
      size: 20,
    );
  }

  Widget _buildAttendanceItem(String title, String time, Color color) {
    return Column(
      children: [
        Text(
          time,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: const TextStyle(color: Colors.black87, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildHeaderContent(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    BoxDecoration fingerprintDecoration;
    if (_isOffsite.value) {
      fingerprintDecoration = const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.red,
      );
    } else {
      fingerprintDecoration = const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.orange, Colors.green],
        ),
      );
    }

    final now = DateTime.now();
    final checkInTimeAllowed = DateTime(now.year, now.month, now.day, 0, 0);
    final checkInDisabledTime = DateTime(now.year, now.month, now.day, 22, 0);
    bool isCheckInEnabled = !_isCheckInActive.value &&
        now.isAfter(checkInTimeAllowed) &&
        now.isBefore(checkInDisabledTime);

    return GestureDetector(
      onTap: () async {
        DateTime now = DateTime.now();
        DateTime checkInTimeAllowed =
            DateTime(now.year, now.month, now.day, 0, 0);
        DateTime checkInDisabledTime =
            DateTime(now.year, now.month, now.day, 22, 0);

        if (!_isCheckInActive.value) {
          if (now.isBefore(checkInTimeAllowed) ||
              now.isAfter(checkInDisabledTime)) {
            _showCustomDialog(
              AppLocalizations.of(context)!.checkInNotAllowed,
              AppLocalizations.of(context)!.checkInLateNotAllowed,
              isSuccess: false,
            );
          } else {
            // Authenticate before check-in
            await _authenticate(context, true);
          }
        } else {
          // Authenticate before check-out
          await _authenticate(context, false);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black54 : Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              children: [
                Text(
                  DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm:ss').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white70 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  _isCheckInActive.value
                      ? "Check-Out"
                      : "Check-In", // Shows action based on saved state
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.orange : Colors.green,
                  ),
                ),
                const SizedBox(height: 20),

                // Fingerprint Button
                Container(
                  width: 80,
                  height: 80,
                  decoration: fingerprintDecoration,
                  child: const Icon(
                    Icons.fingerprint,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Divider and Register Presence Text
                Container(
                  width: double.infinity,
                  height: 1,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.registerPresenceStartWork,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.white70 : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 1,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),

                Text(
                  DateFormat('MMMM - yyyy').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      AppLocalizations.of(context)!.checkIn,
                      _cachedTimes['totalCheckInDelay'] ?? '--:--:--',
                      Icons.login,
                      Colors.green,
                      isDarkMode:
                          Theme.of(context).brightness == Brightness.dark,
                    ),
                    _buildSummaryItem(
                      AppLocalizations.of(context)!.checkOut,
                      _cachedTimes['totalCheckOutDelay'] ?? '--:--:--',
                      Icons.logout,
                      Colors.red,
                      isDarkMode:
                          Theme.of(context).brightness == Brightness.dark,
                    ),
                    _buildSummaryItem(
                      AppLocalizations.of(context)!.workingHours,
                      _cachedTimes['totalWorkDuration'] ?? '--:--:--',
                      Icons.timer,
                      Colors.blue,
                      isDarkMode:
                          Theme.of(context).brightness == Brightness.dark,
                    ),
                  ],
                ),
              ],
            ),

            // Time Reminder
            Positioned(
              top: 50,
              right: 0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double screenWidth = MediaQuery.of(context).size.width;
                  double screenHeight = MediaQuery.of(context).size.height;

                  // Dynamic font size and padding based on screen width
                  double fontSize = screenWidth < 360 ? 8 : 10;
                  double paddingHorizontal = screenWidth < 360 ? 8 : 12;
                  double paddingVertical = screenWidth < 360 ? 3 : 4;

                  return Container(
                    padding: EdgeInsets.symmetric(
                      vertical: paddingVertical,
                      horizontal: paddingHorizontal,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Time Reminder',
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                          ),
                        ),
                        // const SizedBox(height: 2),
                        Text(
                          _limitTime.value,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
      String title, String time, IconData icon, Color color,
      {required bool isDarkMode}) {
    return Column(
      children: [
        // Icon with dynamic color based on dark mode
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 4),

        // Time Text with dynamic color based on dark mode
        Text(
          time,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color:
                isDarkMode ? Colors.white : Colors.black, // Adjust time color
          ),
        ),

        // Title Text with dynamic color based on dark mode
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode
                ? Colors.white70
                : Colors.black87, // Adjust title color
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyRecordsList() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_weeklyRecords.value.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          AppLocalizations.of(context)!.noWeeklyRecordsFound,
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.black54,
            fontSize: 16,
          ),
        ),
      );
    }

    return Column(
      children: [
        // Header Row
        Container(
          margin: const EdgeInsets.only(top: 16, bottom: 8),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.green : const Color(0xFFD5AD32),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.5)
                    : Colors.black.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.checkIn,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.checkOut,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.workingHours,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Weekly Records List
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _weeklyRecords.value.length,
          itemBuilder: (context, index) {
            return _buildAttendanceRow(_weeklyRecords.value[index]);
          },
        ),
      ],
    );
  }

  Widget _buildSectionContainer() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Only Offsite button:
    Color offsiteBgColor = _isOffsite.value
        ? Colors.red
        : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200);

    Color offsiteIconColor = _isOffsite.value ? Colors.white : Colors.red;
    Color offsiteTextColor = _isOffsite.value
        ? Colors.white
        : (isDarkMode ? Colors.white : Colors.black);

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: GestureDetector(
          onTap: () async {
            setState(() {
              _isOffsite.value = !_isOffsite.value;
            });

            // Show dialog based on the new state
            if (_isOffsite.value) {
              _showCustomDialog(
                AppLocalizations.of(context)!.offsiteModeTitle,
                AppLocalizations.of(context)!.offsiteModeMessage,
                isSuccess: true,
              );
            } else {
              _showCustomDialog(
                AppLocalizations.of(context)!.officeModeTitle,
                AppLocalizations.of(context)!.officeModeMessage,
                isSuccess: true,
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: offsiteBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/offsite.png',
                  width: 20,
                  height: 20,
                  color: offsiteIconColor,
                ),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context)!.offsite,
                  style: TextStyle(
                    color: offsiteTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            flexibleSpace: PreferredSize(
              preferredSize: const Size.fromHeight(80.0),
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(isDarkMode
                        ? 'assets/darkbg.png'
                        : 'assets/ready_bg.png'),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 26),
                      child: Text(
                        AppLocalizations.of(context)!.attendance,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            centerTitle: true,
            toolbarHeight: 100,
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: Stack(
            children: [
              _buildPageContent(context),
              if (_isLoading.value) _buildLoadingIndicator(),
            ],
          ),
        ),
        // Positioned container above the AppBar area
        Positioned(
          top: MediaQuery.of(context).padding.top + 84,
          left: 270,
          right: 0,
          child: Center(
            child: _buildSectionContainer(),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return IgnorePointer(
      ignoring: _isInteractive.value,
      child: Container(
        color: Colors.black.withOpacity(_isInteractive.value ? 0.2 : 0.5),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _loadingMessage.value,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _determineSectionFromPosition(Position position) {
    if (!mounted) return;

    double distanceToOffice = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      officeLocation.latitude,
      officeLocation.longitude,
    );

    if (kDebugMode) {
      print('Current position: (${position.latitude}, ${position.longitude})');
      print('Distance to office: $distanceToOffice meters');
    }

    if (mounted) {
      setState(() {
        _isOffsite.value = distanceToOffice > _officeRange;
      });
    }
  }
}
