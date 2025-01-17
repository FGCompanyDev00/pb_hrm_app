// attendance_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  AttendanceScreenState createState() => AttendanceScreenState();
}

class AttendanceScreenState extends State<AttendanceScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();
  final userPreferences = sl<UserPreferences>();
// 0 for Home/Office, 1 for Offsite
  bool _isCheckInActive = false;
  String _checkInTime = '--:--:--';
  String _checkOutTime = '--:--:--';
  String _limitTime = '--:--:--';
  DateTime? _checkInDateTime;
  DateTime? _checkOutDateTime;
  Duration _workingHours = Duration.zero;
  Timer? _timer;
  StreamSubscription<Position>? _positionStreamSubscription;
  String _deviceId = '';
  List<Map<String, String>> _weeklyRecords = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  bool _isOffsite = false;
  String _totalCheckInDelay = '--:--:--';
  String _totalCheckOutDelay = '--:--:--';
  String _totalWorkDuration = '--:--:--';
  static const String officeApiUrl = 'https://demo-application-api.flexiflows.co/api/attendance/checkin-checkout/office';
  static const String offsiteApiUrl = 'https://demo-application-api.flexiflows.co/api/attendance/checkin-checkout/offsite';

  static const double _officeRange = 500;
  static LatLng officeLocation = const LatLng(2.891589, 101.524822);

  @override
  void initState() {
    super.initState();
    _fetchWeeklyRecords();
    _retrieveSavedState();
    _retrieveDeviceId();
    _fetchLimitTime();
    _startLocationMonitoring();
    _startTimerForLiveTime();
    _determineAndShowLocationModal();
    connectivityResult.onConnectivityChanged.listen((source) {
      if (source.contains(ConnectivityResult.wifi) || source.contains(ConnectivityResult.mobile)) {
        offlineProvider.autoOffline(false);
        offlineProvider.syncPendingAttendance();
      }
    });
    _refreshTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _fetchWeeklyRecords();
    });
  }

  Future<void> _fetchLimitTime() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String endpoint = '$baseUrl/api/attendance/checkin-checkout/offices/weekly/me';

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
          _limitTime = limitTime;
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
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    Position? currentPosition = await _getCurrentPosition();
    if (currentPosition != null) {
      _determineSectionFromPosition(currentPosition);
    }

    setState(() {
      _isLoading = false;
    });

    // _showLocationModal(_isOffsite ? 'Offsite' : 'Office');
  }

  String _getCurrentApiUrl() {
    return _isOffsite ? offsiteApiUrl : officeApiUrl;
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
    Duration? savedWorkingHours = userPreferences.getWorkingHours();

    setState(() {
      _checkInTime = savedCheckInTime ?? '--:--:--';
      _checkInDateTime = savedCheckInTime != null ? DateFormat('HH:mm:ss').parse(savedCheckInTime) : null;
      _checkOutTime = savedCheckOutTime ?? '--:--:--'; // Restore checkout time
      _isCheckInActive = savedCheckInTime != null && savedCheckOutTime == null;
// Check if checkout is available
      _workingHours = savedWorkingHours ?? Duration.zero;
    });

    if (_isCheckInActive) {
      _startTimerForWorkingHours();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStreamSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
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
    // 1) Build a record
    AttendanceRecord record = AttendanceRecord(
      deviceId: _deviceId,
      latitude: '',
      longitude: '',
      section: _isOffsite ? 'Offsite' : 'Office',
      type: 'checkIn',
      timestamp: now,
    );

    // 2) Attempt to get current position
    Position? currentPosition = await _getCurrentPosition();
    if (currentPosition != null) {
      record.latitude = currentPosition.latitude.toString();
      record.longitude = currentPosition.longitude.toString();
    }

    // 3) Check connectivity
    final hasConnection = await connectivityResult.checkConnectivity();
    final isOffline = hasConnection.contains(ConnectivityResult.none);

    if (isOffline) {
      // a) Offline => store locally, treat as "checked in" since user can't verify with server
      await offlineProvider.addPendingAttendance(record);
      await offlineProvider.autoOffline(true);
      if (kDebugMode) {
        print('No internet. Check-in stored locally.');
      }
      // b) Now setState to reflect local check-in
      _applyCheckInState(now);
      // c) Optionally show local check-in notification
      await _showCheckInNotification(_checkInTime);
    } else {
      // 4) Online => attempt to send to server first
      bool success = await _sendCheckInOutRequest(record);
      if (!success) {
        // => If returns false, it means status 202 or error => DO NOTHING
        // => Do not set the time, do not show any notification
        if (kDebugMode) {
          print('Check-in request not allowed or failed. No UI changes.');
        }
        return;
      }

      // 5) If success == true => proceed with setState, store prefs, notify user
      _applyCheckInState(now);
      await _showCheckInNotification(_checkInTime);
    }
  }

  void _applyCheckInState(DateTime now) {
    setState(() {
      _checkInTime = DateFormat('HH:mm:ss').format(now);
      _checkOutTime = '--:--:--';
      _checkInDateTime = now;
      _checkOutDateTime = null;
      _workingHours = Duration.zero;
      _isCheckInActive = true;
    });

    // Store check-in time locally
    userPreferences.storeCheckInTime(_checkInTime);
    userPreferences.storeCheckOutTime(_checkOutTime);
    // Start the working hours timer
    _startTimerForWorkingHours();
  }

  Future<void> _showCheckInNotification(String checkInTime) async {
    if (kDebugMode) {
      print('Attempting to show Check-in notification with time: $checkInTime');
    }

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
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
    // 1) Build the record
    AttendanceRecord record = AttendanceRecord(
      deviceId: _deviceId,
      latitude: '',
      longitude: '',
      section: _isOffsite ? 'Offsite' : 'Office',
      type: 'checkOut',
      timestamp: now,
    );

    // 2) Get current position
    Position? currentPosition = await _getCurrentPosition();
    if (currentPosition != null) {
      record.latitude = currentPosition.latitude.toString();
      record.longitude = currentPosition.longitude.toString();
    }

    // 3) Check connectivity
    final hasConnection = await connectivityResult.checkConnectivity();
    final isOffline = hasConnection.contains(ConnectivityResult.none);

    // 4) If offline, store locally + update UI
    if (isOffline) {
      await offlineProvider.addPendingAttendance(record);
      if (kDebugMode) {
        print('No internet connection. Check-out stored locally.');
      }
      _applyCheckOutState(now);
      await _showCheckOutNotification(_checkOutTime, _workingHours);
      return;
    }

    // 5) Online => ask server first
    bool success = await _sendCheckInOutRequest(record);
    if (!success) {
      // => If server says "202" or error => do nothing
      return;
    }

    // 6) If success => update UI
    _applyCheckOutState(now);
    await _showCheckOutNotification(_checkOutTime, _workingHours);
  }

  /// Applies the local changes for check-out
  void _applyCheckOutState(DateTime now) {
    setState(() {
      _checkOutTime = DateFormat('HH:mm:ss').format(now);
      _checkOutDateTime = now;
      if (_checkInDateTime != null) {
        _workingHours = now.difference(_checkInDateTime!);
        _isCheckInActive = false;
        _timer?.cancel(); // Stop the working hours timer if any
      }
    });
    // Store times + working hours
    userPreferences.storeCheckOutTime(_checkOutTime);
    userPreferences.storeWorkingHours(_workingHours);
  }

  // Method to show notification for check-out
  Future<void> _showCheckOutNotification(String checkOutTime, Duration workingHours) async {
    if (kDebugMode) {
      print('Attempting to show Check-out notification with time: $checkOutTime and working hours: $workingHours');
    }

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
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

  Future<bool> _sendCheckInOutRequest(AttendanceRecord record) async {
    // If offline mode is forcibly on, do nothing and return false
    if (sl<OfflineProvider>().isOfflineService.value) {
      return false;
    }

    String url = _getCurrentApiUrl();
    String? token = userPreferences.getToken();

    if (token == null) {
      if (mounted) {
        _showCustomDialog(
          AppLocalizations.of(context)!.error,
          AppLocalizations.of(context)!.noTokenFound,
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
        // Check-in/Check-out was successful
        return true;
      }
      // If the URL is the "office" API and we get 202 => location is out of range
      else if (response.statusCode == 202 && url == officeApiUrl) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final serverMessage = data['message'] ?? AppLocalizations.of(context)!.checkInNotAllowedMessage;

        if (mounted) {
          _showCheckInNotAllowedModalLocation(serverMessage);
        }
        // Return false => do NOT proceed with local setState, notifications, etc.
        return false;
      } else {
        // Some other error from the server
        throw Exception('Failed with status code ${response.statusCode}');
      }
    } catch (error) {
      if (mounted) {
        // If sending fails, save to local storage
        await offlineProvider.addPendingAttendance(record);
        // Show a dialog or just keep silent
        if (mounted) {
          _showCustomDialog(
            AppLocalizations.of(context)!.error,
            '${AppLocalizations.of(context)!.failedToCheckInOut}: $error',
            isSuccess: false,
          );
        }
      }
      return false;
    }
  }

  Future<void> _fetchWeeklyRecords() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String endpoint = '$baseUrl/api/attendance/checkin-checkout/offices/weekly/me';

    try {
      String? token = userPreferences.getToken();

      if (token == null) {
        if (mounted) {
          throw Exception(AppLocalizations.of(context)!.noTokenFound);
        }
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
        final monthlyData = data['TotalWorkDurationForMonth'];

        setState(() {
          _weeklyRecords = (data['weekly'] as List).map((item) {
            return {
              'date': item['check_in_date'].toString(),
              'checkIn': item['check_in_time'].toString(),
              'checkOut': item['check_out_time'].toString(),
              'workingHours': item['workDuration'].toString(),
              'checkInStatus': item['check_in_status']?.toString() ?? 'unknown',
              'checkOutStatus': item['check_out_status']?.toString() ?? 'unknown',
            };
          }).toList();

          // Extract monthly totals
          _totalCheckInDelay = monthlyData['totalCheckInDelay']?.toString() ?? '--:--:--';
          _totalCheckOutDelay = monthlyData['totalCheckOutDelay']?.toString() ?? '--:--:--';
          _totalWorkDuration = monthlyData['totalWorkDuration']?.toString() ?? '--:--:--';
        });
      } else {
        if (mounted) {
          throw Exception(AppLocalizations.of(context)!.failedToLoadWeeklyRecords);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching weekly records: $e');
      }
      // Optionally, show a dialog or snackbar
    }
  }

  void _showCheckInNotAllowedModalLocation(String serverMessage) {
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
                    width: constraints.maxWidth < 400 ? constraints.maxWidth * 0.9 : 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/attendance.png',
                          width: 40,
                          color: isDarkMode ? const Color(0xFFDBB342) : null,
                        ),
                        const SizedBox(height: 16),
                        // Title
                        Text(
                          AppLocalizations.of(context)!.checkInNotAllowed,
                          style: TextStyle(
                            fontSize: constraints.maxWidth < 400 ? 18 : 20,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // **Display the API message here**:
                        Text(
                          serverMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: constraints.maxWidth < 400 ? 14 : 16,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.grey : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Close Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDBB342), // Gold color
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
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

  void _startLocationMonitoring() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Notify if the user moves 10 meters or more
      ),
    ).listen((Position position) {
      _determineSectionFromPosition(position);
    });
  }

  void _determineSectionFromPosition(Position position) {
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

    setState(() {
      if (distanceToOffice <= _officeRange) {
      } else {}
    });
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
    String? biometricEnabledStored = await _storage.read(key: 'biometricEnabled');

    // Update the biometricEnabled state based on current settings
    bool biometricEnabled = (biometricEnabledStored == 'true') && canCheckBiometrics && isDeviceSupported;

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
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving location: $e');
      }
      return null;
    }
  }

  // void _showLocationModal(String location) {
  //   final isHome = location == 'Home';
  //   final primaryColor = isHome ? Colors.orange : Colors.green;
  //
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (BuildContext context) {
  //       return Dialog(
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(20),
  //         ),
  //         elevation: 10,
  //         child: LayoutBuilder(
  //           builder: (context, constraints) {
  //             return SizedBox(
  //               width: constraints.maxWidth < 400 ? constraints.maxWidth * 0.9 : 400,
  //               child: Column(
  //                 mainAxisSize: MainAxisSize.min,
  //                 children: [
  //                   Container(
  //                     padding: const EdgeInsets.all(16.0),
  //                     decoration: BoxDecoration(
  //                       color: primaryColor,
  //                       borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
  //                     ),
  //                     child: Row(
  //                       crossAxisAlignment: CrossAxisAlignment.center,
  //                       children: [
  //                         Icon(
  //                           isHome ? Icons.home : Icons.apartment,
  //                           color: Colors.white,
  //                           size: constraints.maxWidth < 400 ? 30 : 40, // Responsive icon size
  //                         ),
  //                         const SizedBox(width: 16),
  //                         Expanded(
  //                           child: Text(
  //                             AppLocalizations.of(context)!.locationDetected,
  //                             style: TextStyle(
  //                               fontSize: constraints.maxWidth < 400 ? 18 : 20,
  //                               // Responsive font size
  //                               fontWeight: FontWeight.bold,
  //                               color: Colors.white,
  //                             ),
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                   Padding(
  //                     padding: const EdgeInsets.all(16.0),
  //                     child: Text(
  //                       AppLocalizations.of(context)!.youAreCurrentlyAt(
  //                         isHome ? AppLocalizations.of(context)!.home : AppLocalizations.of(context)!.office,
  //                       ),
  //                       textAlign: TextAlign.center,
  //                       style: TextStyle(
  //                         fontSize: constraints.maxWidth < 400 ? 14 : 16,
  //                         // Responsive font size
  //                         fontWeight: FontWeight.w500,
  //                         color: Colors.black87,
  //                       ),
  //                     ),
  //                   ),
  //                   Padding(
  //                     padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  //                     child: ElevatedButton(
  //                       onPressed: () {
  //                         Navigator.of(context).pop();
  //                       },
  //                       style: ElevatedButton.styleFrom(
  //                         backgroundColor: primaryColor,
  //                         padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
  //                         shape: RoundedRectangleBorder(
  //                           borderRadius: BorderRadius.circular(20),
  //                         ),
  //                         shadowColor: Colors.black.withOpacity(0.25),
  //                         elevation: 5,
  //                       ),
  //                       child: Text(
  //                         AppLocalizations.of(context)!.ok,
  //                         style: TextStyle(
  //                           fontSize: constraints.maxWidth < 400 ? 14 : 16,
  //                           // Responsive font size
  //                           fontWeight: FontWeight.bold,
  //                           color: Colors.white,
  //                         ),
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             );
  //           },
  //         ),
  //       );
  //     },
  //   );
  // }

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
        padding: const EdgeInsets.all(16.0),
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
                    MaterialPageRoute(builder: (context) => const MonthlyAttendanceReport()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFDBB342) // Dark mode background color (#DBB342)
                      : Colors.green, // Light mode background color (green)
                  elevation: 4,
                ),
                icon: const Icon(Icons.view_agenda, color: Colors.white),
                label: Text(
                  AppLocalizations.of(context)!.viewAll,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  void _showCustomDialog(String title, String message, {bool isSuccess = true}) {
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
                    width: constraints.maxWidth < 400 ? constraints.maxWidth * 0.9 : 400,
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
                              color: isDarkMode ? const Color(0xFFDBB342) : null,
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
                              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                              color: isSuccess ? (isDarkMode ? Colors.greenAccent : Colors.green) : (isDarkMode ? Colors.redAccent : Colors.red),
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
                              backgroundColor: const Color(0xFFDBB342), // Gold color for button
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
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

  // void _showWorkingHoursDialog(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return Dialog(
  //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //         child: Padding(
  //           padding: const EdgeInsets.all(16.0),
  //           child: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               const Icon(Icons.access_time, color: Colors.blue, size: 50),
  //               const SizedBox(height: 16),
  //               Text(
  //                 AppLocalizations.of(context)!.workSummary,
  //                 style: const TextStyle(
  //                   fontSize: 20,
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),
  //               const SizedBox(height: 16),
  //               Text(
  //                 AppLocalizations.of(context)!.youWorkedForHoursToday(_workingHours.toString().split('.').first.padLeft(8, '0')),
  //                 style: const TextStyle(fontSize: 16),
  //                 textAlign: TextAlign.center,
  //               ),
  //               const SizedBox(height: 16),
  //               ElevatedButton(
  //                 onPressed: () {
  //                   Navigator.of(context).pop();
  //                 },
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: const Color(0xFFDAA520), // gold color
  //                   padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
  //                   shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(8.0),
  //                   ),
  //                 ),
  //                 child: Text(
  //                   AppLocalizations.of(context)!.close,
  //                   style: const TextStyle(
  //                     fontSize: 16,
  //                     fontWeight: FontWeight.bold,
  //                     color: Colors.white,
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  Widget _buildAttendanceRow(Map<String, String> record) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final DateTime date = DateFormat('yyyy-MM-dd').parse(record['date']!);
    final String day = DateFormat('EEEE').format(date); // Day part
    final String datePart = DateFormat('dd-MM-yyyy').format(date); // Date part

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: isDarkMode ? Colors.grey[800] : Colors.white, // Adjust background color based on theme
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
                          color: isDarkMode ? Colors.white : const Color(0xFF003366),
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
                _buildAttendanceItem(AppLocalizations.of(context)!.workingHours, record['workingHours']!, Colors.blue),
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
    if (_isOffsite) {
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
    bool isCheckInEnabled = !_isCheckInActive && now.isAfter(checkInTimeAllowed) && now.isBefore(checkInDisabledTime);

    return GestureDetector(
      onTap: () async {
        if (!_isCheckInActive) {
          if (now.isBefore(checkInTimeAllowed) || now.isAfter(checkInDisabledTime)) {
            _showCustomDialog(
              AppLocalizations.of(context)!.checkInNotAllowed,
              AppLocalizations.of(context)!.checkInLateNotAllowed,
              isSuccess: false,
            );
          } else if (isCheckInEnabled) {
            await _authenticate(context, true);
          }
        } else if (_isCheckInActive) {
          await _authenticate(context, false);
        } else {
          _showCustomDialog(
            AppLocalizations.of(context)!.alreadyCheckedIn,
            AppLocalizations.of(context)!.alreadyCheckedInMessage,
            isSuccess: false,
          );
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
                      _totalCheckInDelay,
                      Icons.login,
                      Colors.green,
                      isDarkMode: Theme.of(context).brightness == Brightness.dark,
                    ),
                    _buildSummaryItem(
                      AppLocalizations.of(context)!.checkOut,
                      _totalCheckOutDelay,
                      Icons.logout,
                      Colors.red,
                      isDarkMode: Theme.of(context).brightness == Brightness.dark,
                    ),
                    _buildSummaryItem(
                      AppLocalizations.of(context)!.workingHours,
                      _totalWorkDuration,
                      Icons.timer,
                      Colors.blue,
                      isDarkMode: Theme.of(context).brightness == Brightness.dark,
                    ),
                  ],
                ),
              ],
            ),

            // Time Reminder positioned at the top-right
            Positioned(
              top: 50,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 18),
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
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _limitTime,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String time, IconData icon, Color color, {required bool isDarkMode}) {
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
            color: isDarkMode ? Colors.white : Colors.black, // Adjust time color
          ),
        ),

        // Title Text with dynamic color based on dark mode
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white70 : Colors.black87, // Adjust title color
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyRecordsList() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_weeklyRecords.isEmpty) {
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
                color: isDarkMode ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.15),
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
          itemCount: _weeklyRecords.length,
          itemBuilder: (context, index) {
            return _buildAttendanceRow(_weeklyRecords[index]);
          },
        ),
      ],
    );
  }

  Widget _buildSectionContainer() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Only Offsite button:
    Color offsiteBgColor = _isOffsite ? Colors.red : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200);

    Color offsiteIconColor = _isOffsite ? Colors.white : Colors.red;
    Color offsiteTextColor = _isOffsite ? Colors.white : (isDarkMode ? Colors.white : Colors.black);

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: GestureDetector(
          onTap: () async {
            setState(() {
              _isOffsite = !_isOffsite;
            });

            // Show dialog based on the new state
            if (_isOffsite) {
              _showCustomDialog(
                AppLocalizations.of(context)!.offsiteModeTitle, // e.g., "Offsite Mode"
                AppLocalizations.of(context)!.offsiteModeMessage, // e.g., "You're in offsite attendance mode."
                isSuccess: true,
              );
            } else {
              _showCustomDialog(
                AppLocalizations.of(context)!.officeModeTitle, // e.g., "Office Mode"
                AppLocalizations.of(context)!.officeModeMessage, // e.g., "You're in office/home attendance mode."
                isSuccess: true,
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: offsiteBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/offsite.png',
                  width: 18,
                  height: 18,
                  color: offsiteIconColor,
                ),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context)!.offsite, // Ensure this localization key exists
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
                    image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
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
              if (_isLoading) _buildLoadingIndicator(),
            ],
          ),
        ),
        // Positioned container above the AppBar area
        Positioned(
          top: MediaQuery.of(context).padding.top + 84,
          left: 200,
          right: 0,
          child: Center(
            child: _buildSectionContainer(),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
      ),
    );
  }
}
