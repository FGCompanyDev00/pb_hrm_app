// attendance_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'monthly_attendance_record.dart';
import '../models/attendance_record.dart';
import '../services/offline_service.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();
  int _selectedIndex = 0; // 0 for Home/Office, 1 for Offsite
  bool _isCheckInActive = false;
  String _checkInTime = '--:--:--';
  String _checkOutTime = '--:--:--';
  DateTime? _checkInDateTime;
  DateTime? _checkOutDateTime;
  Duration _workingHours = Duration.zero;
  Timer? _timer;
  StreamSubscription<Position>? _positionStreamSubscription;
  String _currentSection = 'Home';
  String _detectedLocation = 'Home'; // New variable to store detected location
  String _deviceId = '';
  List<Map<String, String>> _weeklyRecords = [];
  bool _isLoading = true;
  bool _biometricEnabled = false;
  bool _isCheckOutAvailable = true;
  static const String officeApiUrl = 'https://demo-application-api.flexiflows.co/api/attendance/checkin-checkout/office';
  static const String offsiteApiUrl = 'https://demo-application-api.flexiflows.co/api/attendance/checkin-checkout/offsite';

  static const double _officeRange = 500;
  static LatLng _officeLocation = LatLng(2.891589, 101.524822);

  @override
  void initState() {
    super.initState();
    _initializeBackgroundService();
    _retrieveSavedState();
    _retrieveDeviceId();
    _fetchWeeklyRecords();
    _startLocationMonitoring();
    _startTimerForLiveTime();
    _determineAndShowLocationModal();
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

    _showLocationModal(context, _detectedLocation);
  }

  Future<void> _initializeBackgroundService() async {
    try {
      final bool initialized = await FlutterBackground.initialize();

      if (!initialized) {
        if (kDebugMode) {
          print('FlutterBackground plugin initialization failed');
        }
        return;
      }

      if (!FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.enableBackgroundExecution();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing background service: $e');
      }
    }
  }

  Future<void> _retrieveSavedState() async {
    String? savedCheckInTime = await _getCheckInTime();
    String? savedCheckOutTime = await _getCheckOutTime(); // Retrieve saved checkout time
    Duration? savedWorkingHours = await _getWorkingHours();
    String? biometricEnabled = await _storage.read(key: 'biometricEnabled');

    setState(() {
      _checkInTime = savedCheckInTime ?? '--:--:--';
      _checkInDateTime = savedCheckInTime != null ? DateFormat('HH:mm:ss').parse(savedCheckInTime) : null;
      _checkOutTime = savedCheckOutTime ?? '--:--:--'; // Restore checkout time
      _isCheckInActive = savedCheckInTime != null && savedCheckOutTime == null;
      _isCheckOutAvailable = savedCheckOutTime == null; // Check if checkout is available
      _workingHours = savedWorkingHours ?? Duration.zero;
      _biometricEnabled = biometricEnabled == 'true';
    });

    if (_isCheckInActive) {
      _startTimerForWorkingHours();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStreamSubscription?.cancel();
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
      if (kDebugMode) {
        print('Device ID retrieved: $_deviceId');
      }
    });
  }

  Future<void> _performCheckIn(DateTime now) async {
    setState(() {
      _checkInTime = DateFormat('HH:mm:ss').format(now);
      _checkOutTime = '--:--:--'; // Reset check-out time to placeholder
      _checkInDateTime = now;
      _checkOutDateTime = null;
      _workingHours = Duration.zero; // Reset working hours immediately on new check-in
      _isCheckInActive = true;
      _isCheckOutAvailable = true;
      _startTimerForWorkingHours(); // Start tracking working hours
    });

    // Store check-in time locally
    await _storeCheckInTime(_checkInTime); // Save the new check-in time
    await _storeCheckOutTime(_checkOutTime); // Reset stored check-out time to --:--:--

    // Create AttendanceRecord
    AttendanceRecord record = AttendanceRecord(
      deviceId: _deviceId,
      latitude: '', // Will be filled below
      longitude: '', // Will be filled below
      section: _currentSection,
      type: 'checkIn',
      timestamp: now,
    );

    // Get current position
    Position? currentPosition = await _getCurrentPosition();
    if (currentPosition != null) {
      record.latitude = currentPosition.latitude.toString();
      record.longitude = currentPosition.longitude.toString();
    }

    // Check connectivity
    var connectivityResult = await Connectivity().checkConnectivity();
    bool isOnline = connectivityResult != ConnectivityResult.none;

    if (isOnline) {
      // Send Check-in request for Home/Office or Offsite
      await _sendCheckInOutRequest(record);
    } else {
      // Save to local storage for later synchronization
      OfflineService offlineService = Provider.of<OfflineService>(context, listen: false);
      await offlineService.addPendingAttendance(record);
      if (mounted) _showCustomDialog(AppLocalizations.of(context)!.offlineMode, AppLocalizations.of(context)!.checkInSavedOffline, isSuccess: false);
    }
  }

  Future<void> _performCheckOut(DateTime now) async {
    setState(() {
      _checkOutTime = DateFormat('HH:mm:ss').format(now);
      _checkOutDateTime = now;
      if (_checkInDateTime != null) {
        _workingHours = now.difference(_checkInDateTime!); // Calculate working hours
        _isCheckInActive = false;
        _isCheckOutAvailable = false;
        _timer?.cancel(); // Stop the working hours timer
        _showWorkingHoursDialog(context); // Show the working hours summary
      }
    });

    // Store check-out time and working hours locally
    await _storeCheckOutTime(_checkOutTime); // Save the new check-out time
    await _storeWorkingHours(_workingHours); // Save the total working hours

    // Create AttendanceRecord
    AttendanceRecord record = AttendanceRecord(
      deviceId: _deviceId,
      latitude: '', // Will be filled below
      longitude: '', // Will be filled below
      section: _currentSection,
      type: 'checkOut',
      timestamp: now,
    );

    // Get current position
    Position? currentPosition = await _getCurrentPosition();
    if (currentPosition != null) {
      record.latitude = currentPosition.latitude.toString();
      record.longitude = currentPosition.longitude.toString();
    }

    // Check connectivity
    var connectivityResult = await Connectivity().checkConnectivity();
    bool isOnline = connectivityResult != ConnectivityResult.none;

    if (isOnline) {
      // Send Check-out request for Home/Office or Offsite
      await _sendCheckInOutRequest(record);
    } else {
      // Save to local storage for later synchronization
      OfflineService offlineService = Provider.of<OfflineService>(context, listen: false);
      await offlineService.addPendingAttendance(record);
      if (mounted) _showCustomDialog(AppLocalizations.of(context)!.offlineMode, AppLocalizations.of(context)!.checkOutSavedOffline, isSuccess: false);
    }
  }

  Future<void> _resetSessionData() async {
    setState(() {
      _checkInTime = '--:--:--';
      _checkOutTime = '--:--:--';
      _workingHours = Duration.zero;
      _checkInDateTime = null;
      _checkOutDateTime = null;
    });

    // Reset stored values in SharedPreferences
    await _storeCheckInTime(_checkInTime);
    await _storeCheckOutTime(_checkOutTime);
    await _storeWorkingHours(Duration.zero);
  }

  Future<void> _sendCheckInOutRequest(AttendanceRecord record) async {
    String url;
    if (record.section == 'Home' || record.section == 'Office') {
      url = officeApiUrl;
    } else {
      url = offsiteApiUrl;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (token == null) {
      if (mounted) {
        _showCustomDialog(
          AppLocalizations.of(context)!.error,
          AppLocalizations.of(context)!.noTokenFound,
          isSuccess: false,
        );
      }
      return;
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

      if (response.statusCode == 201 || response.statusCode == 202) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (mounted) _showCustomDialog(AppLocalizations.of(context)!.success, responseData['message'] ?? AppLocalizations.of(context)!.checkInOutSuccessful, isSuccess: true);
      } else {
        throw Exception('Failed with status code ${response.statusCode}');
      }
    } catch (error) {
      // If sending fails, save to local storage
      OfflineService offlineService = Provider.of<OfflineService>(context, listen: false);
      await offlineService.addPendingAttendance(record);
      if (mounted) _showCustomDialog(AppLocalizations.of(context)!.error, '${AppLocalizations.of(context)!.failedToCheckInOut}: $error', isSuccess: false);
    }
  }

  Future<void> _fetchWeeklyRecords() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String endpoint = '$baseUrl/api/attendance/checkin-checkout/offices/weekly/me';

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      if (token == null) {
        if (mounted) throw Exception(AppLocalizations.of(context)!.noTokenFound);
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

        setState(() {
          _weeklyRecords = (data['weekly'] as List).map((item) {
            return {
              'date': item['check_in_date'].toString(),
              'checkIn': item['check_in_time'].toString(),
              'checkOut': item['check_out_time'].toString(),
              'workingHours': item['workDuration'].toString(),
            };
          }).toList();
        });
      } else {
        if (mounted) throw Exception(AppLocalizations.of(context)!.failedToLoadWeeklyRecords);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching weekly records: $e');
      }
      // Optionally, show a dialog or snackbar
    }
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
      _officeLocation.latitude,
      _officeLocation.longitude,
    );

    if (kDebugMode) {
      print('Current position: (${position.latitude}, ${position.longitude})');
      print('Distance to office: $distanceToOffice meters');
    }

    setState(() {
      if (distanceToOffice <= _officeRange) {
        _detectedLocation = 'Office';
        _currentSection = 'Office';
        _selectedIndex = 0;
      } else {
        _detectedLocation = 'Home';
        _currentSection = 'Home';
        _selectedIndex = 0;
      }
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
        await _storeWorkingHours(_workingHours);
      }
    });
  }

  Future<void> _storeCheckInTime(String checkInTime) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('checkInTime', checkInTime);
  }

  Future<void> _storeCheckOutTime(String checkOutTime) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('checkOutTime', checkOutTime);
  }

  Future<void> _storeWorkingHours(Duration workingHours) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('workingHours', workingHours.toString());
  }

  Future<String?> _getCheckInTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    return null;
  }

  Future<String?> _getCheckOutTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('checkOutTime');
  }

  Future<Duration?> _getWorkingHours() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? workingHoursStr = prefs.getString('workingHours');
    if (workingHoursStr != null) {
      List<String> parts = workingHoursStr.split(':');
      return Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1]), seconds: int.parse(parts[2]));
    }
    return null;
  }

  Future<void> _authenticate(BuildContext context, bool isCheckIn) async {
    if (!_biometricEnabled) {
      _showCustomDialog(AppLocalizations.of(context)!.biometricNotEnabled, AppLocalizations.of(context)!.enableBiometricFirst, isSuccess: false);
      return;
    }

    bool didAuthenticate = await _authenticateWithBiometrics();

    if (!didAuthenticate) {
      if (context.mounted) _showCustomDialog(AppLocalizations.of(context)!.authenticationFailed, AppLocalizations.of(context)!.authenticateToContinue, isSuccess: false);
      return;
    }

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

  void _showLocationModal(BuildContext context, String location) {
    final isHome = location == 'Home';
    final primaryColor = isHome ? Colors.orange : Colors.green;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: constraints.maxWidth < 400 ? constraints.maxWidth * 0.9 : 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            isHome ? Icons.home : Icons.apartment,
                            color: Colors.white,
                            size: constraints.maxWidth < 400 ? 30 : 40, // Responsive icon size
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)!.locationDetected,
                              style: TextStyle(
                                fontSize: constraints.maxWidth < 400 ? 18 : 20, // Responsive font size
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        AppLocalizations.of(context)!.youAreCurrentlyAt(
                          isHome ? AppLocalizations.of(context)!.home : AppLocalizations.of(context)!.office,
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: constraints.maxWidth < 400 ? 14 : 16, // Responsive font size
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          shadowColor: Colors.black.withOpacity(0.25),
                          elevation: 5,
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.ok,
                          style: TextStyle(
                            fontSize: constraints.maxWidth < 400 ? 14 : 16, // Responsive font size
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPageContent(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchWeeklyRecords,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildSectionContainer(),
            const SizedBox(height: 16),
            _buildHeaderContent(context),
            const SizedBox(height: 16),
            _buildWeeklyRecordsList(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _showCustomDialog(String title, String message, {bool isSuccess = true}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: constraints.maxWidth < 400 ? constraints.maxWidth * 0.9 : 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                        color: isSuccess ? Colors.green : Colors.red,
                        size: constraints.maxWidth < 400 ? 40 : 50, // Responsive icon size
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: constraints.maxWidth < 400 ? 18 : 20, // Responsive font size
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: constraints.maxWidth < 400 ? 14 : 16, // Responsive font size
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSuccess ? const Color(0xFFDAA520) : Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.close,
                          style: TextStyle(
                            fontSize: constraints.maxWidth < 400 ? 14 : 16, // Responsive font size
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showWorkingHoursDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time, color: Colors.blue, size: 50),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.workSummary,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.youWorkedForHoursToday(_workingHours.toString().split('.').first.padLeft(8, '0')),
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDAA520), // gold color
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.close,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceRow(Map<String, String> record) {
    final DateTime date = DateFormat('yyyy-MM-dd').parse(record['date']!);
    final String day = DateFormat('EEEE').format(date); // Day part
    final String datePart = DateFormat('yyyy-MM-dd').format(date); // Date part

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF003366), // Dark blue color
                        ),
                      ),
                      const TextSpan(text: ', '), // Comma separator
                      TextSpan(
                        text: datePart, // Date part
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black, // Black color
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
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 8),
            // Attendance Items Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttendanceItem(AppLocalizations.of(context)!.checkIn, record['checkIn']!, Colors.orange),
                _buildAttendanceItem(AppLocalizations.of(context)!.checkOut, record['checkOut']!, Colors.green),
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
    final fingerprintBackgroundColor = _currentSection == 'Office'
        ? Colors.green
        : _currentSection == 'Home'
            ? Colors.orange
            : Colors.red;

    final now = DateTime.now();
    final checkInTimeAllowed = DateTime(now.year, now.month, now.day, 8, 0);
    final checkInDisabledTime = DateTime(now.year, now.month, now.day, 13, 0);
    bool isCheckInEnabled = !_isCheckInActive && now.isAfter(checkInTimeAllowed) && now.isBefore(checkInDisabledTime);
    bool isCheckOutEnabled = _isCheckInActive && _workingHours >= const Duration(hours: 0) && _isCheckOutAvailable;

    return GestureDetector(
      onTap: () async {
        if (!_isCheckInActive) {
          if (now.isBefore(checkInTimeAllowed) || now.isAfter(checkInDisabledTime)) {
            _showCustomDialog(AppLocalizations.of(context)!.checkInNotAllowed, AppLocalizations.of(context)!.checkInLateNotAllowed, isSuccess: false);
          } else if (isCheckInEnabled) {
            bool isAuthenticated = await _authenticateWithBiometrics();
            if (isAuthenticated) {
              _performCheckIn(DateTime.now());
              if (context.mounted) _showCustomDialog(AppLocalizations.of(context)!.checkInSuccess, AppLocalizations.of(context)!.checkInSuccessMessage, isSuccess: true);
            } else {
              if (context.mounted) _showCustomDialog(AppLocalizations.of(context)!.authenticationFailed, AppLocalizations.of(context)!.authenticateToContinue, isSuccess: false);
            }
          }
        } else if (_isCheckInActive && isCheckOutEnabled) {
          bool isAuthenticated = await _authenticateWithBiometrics();
          if (isAuthenticated) {
            _performCheckOut(DateTime.now());
            if (context.mounted) _showCustomDialog(AppLocalizations.of(context)!.checkOutSuccess, AppLocalizations.of(context)!.checkOutSuccessMessage, isSuccess: true);
          } else {
            if (context.mounted) _showCustomDialog(AppLocalizations.of(context)!.authenticationFailed, AppLocalizations.of(context)!.authenticateToContinue, isSuccess: false);
          }
        } else if (_isCheckInActive) {
          _showCustomDialog(AppLocalizations.of(context)!.alreadyCheckedIn, AppLocalizations.of(context)!.alreadyCheckedInMessage, isSuccess: false);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Date and Time
            Text(
              DateFormat('EEEE, MMMM dd, yyyy').format(DateTime.now()),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm:ss').format(DateTime.now()),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Fingerprint button with dynamic background color
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fingerprintBackgroundColor,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.fingerprint,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Check In/Check Out button text
            Text(
              _isCheckInActive ? AppLocalizations.of(context)!.checkOut : AppLocalizations.of(context)!.checkIn,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Register presence text
            Text(
              AppLocalizations.of(context)!.registerPresenceStartWork,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),

            // Month and Year display (e.g., February - 2024)
            Text(
              DateFormat('MMMM - yyyy').format(DateTime.now()),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Summary Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(AppLocalizations.of(context)!.checkIn, _checkInTime, Icons.login, Colors.green),
                _buildSummaryItem(AppLocalizations.of(context)!.checkOut, _checkOutTime, Icons.logout, Colors.red),
                _buildSummaryItem(AppLocalizations.of(context)!.workingHours, _workingHours.toString().split('.').first.padLeft(8, '0'), Icons.timer, Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String time, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          time,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(
          title,
          style: const TextStyle(color: Colors.black87, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTabContent(BuildContext context) {
    return Container(); // Placeholder since all content is now on a single page
  }

  Widget _buildWeeklyRecordsList() {
    if (_weeklyRecords.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          AppLocalizations.of(context)!.noWeeklyRecordsFound,
          style: const TextStyle(color: Colors.black54, fontSize: 16),
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
            color: const Color(0xFFD5AD32),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.checkOut,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.workingHours,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
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
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(5.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade400, width: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_detectedLocation != 'Office' && _detectedLocation != 'Offsite') {
                        setState(() {
                          _selectedIndex = 0;
                          _currentSection = 'Home';
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: (_currentSection == 'Home' && _selectedIndex != 1) ? Colors.orange : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.home,
                            color: (_currentSection == 'Home' && _selectedIndex != 1) ? Colors.white : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.home,
                            style: TextStyle(
                              color: (_currentSection == 'Home' && _selectedIndex != 1) ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.0),
                  color: Colors.grey.shade500,
                  width: 1,
                  height: 20,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_detectedLocation != 'Home') {
                        setState(() {
                          _selectedIndex = 0;
                          _currentSection = 'Office';
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: (_currentSection == 'Office' && _selectedIndex != 1) ? Colors.green : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.apartment,
                            color: (_currentSection == 'Office' && _selectedIndex != 1) ? Colors.white : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.office,
                            style: TextStyle(
                              color: (_currentSection == 'Office' && _selectedIndex != 1) ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 1,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = 1;
                _currentSection = 'Offsite';
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _selectedIndex == 1 ? Colors.red : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on,
                    color: _selectedIndex == 1 ? Colors.white : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.offsite,
                    style: TextStyle(
                      color: _selectedIndex == 1 ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fetch screen size for responsiveness
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: PreferredSize(
          preferredSize: const Size.fromHeight(100.0),
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Text(
                    'Attendance',
                    style: TextStyle(
                      color: Colors.black,
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
          Positioned(
            left: 0,
            right: 0,
            bottom: mediaQuery.padding.bottom + 20,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MonthlyAttendanceReport()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: Colors.green,
                  elevation: 5,
                ),
                icon: const Icon(Icons.report, color: Colors.white),
                label: Text(
                  AppLocalizations.of(context)!.viewAll,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
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
