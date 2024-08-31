
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'monthly_attendance_record.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final _storage = FlutterSecureStorage();
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

  static const double _officeRange = 500;
  static const LatLng _officeLocation = LatLng(2.891589, 101.524822);

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
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        setState(() {
          _deviceId = androidInfo.id;
        });
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        setState(() {
          _deviceId = iosInfo.identifierForVendor ?? 'Unknown Device ID';
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get device ID: $e');
      }
      setState(() {
        _deviceId = 'Unknown Device ID';
      });
    }
  }

  Future<void> _fetchWeeklyRecords() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String endpoint = '$baseUrl/api/attendance/checkin-checkout/offices/weekly/me';

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

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
        throw Exception('Failed to load weekly records');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching weekly records: $e');
      }
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

  // Function to store the check-in time locally
  Future<void> _storeCheckInTime(String checkInTime) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('checkInTime', checkInTime);
  }

  // Function to store the check-out time locally
  Future<void> _storeCheckOutTime(String checkOutTime) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('checkOutTime', checkOutTime);
  }

  // Function to store the working hours locally
  Future<void> _storeWorkingHours(Duration workingHours) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('workingHours', workingHours.toString());
  }

  // Function to retrieve the check-in time
  Future<String?> _getCheckInTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('checkInTime');
  }

  // Function to retrieve the check-out time
  Future<String?> _getCheckOutTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('checkOutTime');
  }

  // Function to retrieve the working hours
  Future<Duration?> _getWorkingHours() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? workingHoursStr = prefs.getString('workingHours');
    if (workingHoursStr != null) {
      List<String> parts = workingHoursStr.split(':');
      if (parts.length == 3) {
        int hours = int.parse(parts[0]);
        int minutes = int.parse(parts[1]);
        double secondsDouble = double.parse(parts[2]);
        int seconds = secondsDouble.round();

        return Duration(hours: hours, minutes: minutes, seconds: seconds);
      }
    }
    return null;
  }

  Future<void> _authenticate(BuildContext context, bool isCheckIn) async {
    if (!_biometricEnabled) {
      _showCustomDialog(context, 'Biometric Not Enabled', 'Please enable biometric authentication in the settings first.');
      return;
    }

    bool didAuthenticate = await _authenticateWithBiometrics();

    if (!didAuthenticate) {
      _showCustomDialog(context, 'Authentication Failed', 'You must authenticate to continue.');
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
        localizedReason: 'Please authenticate to Check-In or Check-Out',
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
      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving location: $e');
      }
      return null;
    }
  }

  Future<void> _sendAttendanceDataToAPI(bool isCheckIn) async {
    try {
      Position? position = await _getCurrentPosition();
      if (position != null) {
        final attendanceData = {
          'device_id': _deviceId,
          'latitude': position.latitude.toString(),
          'longitude': position.longitude.toString(),
        };

        const String baseUrl = 'https://demo-application-api.flexiflows.co';
        final String endpoint = isCheckIn
            ? '$baseUrl/api/attendance/checkin'
            : '$baseUrl/api/attendance/checkout';

        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? token = prefs.getString('token');

        if (token == null) {
          throw Exception('No token found');
        }

        final response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(attendanceData),
        );

        if (response.statusCode == 200) {
          if (kDebugMode) {
            print('Attendance data sent successfully.');
          }
        } else {
          throw Exception('Failed to send attendance data. Status code: ${response.statusCode}');
        }
      } else {
        _showCustomDialog(context, 'Error', 'Failed to retrieve location.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending attendance data to API: $e');
      }
      _showCustomDialog(context, 'Error', 'Failed to send attendance data to the server.');
    }
  }

  void _performCheckIn(DateTime now) async {
    setState(() {
      _checkInTime = DateFormat('HH:mm:ss').format(now);
      _checkInDateTime = now;
      _checkOutDateTime = null;
      _workingHours = Duration.zero;
      _isCheckInActive = true;
      _isCheckOutAvailable = true;
      _startTimerForWorkingHours();
    });

    // Store check-in time locally
    await _storeCheckInTime(_checkInTime);
  }

  void _performCheckOut(DateTime now) async {
    setState(() {
      _checkOutTime = DateFormat('HH:mm:ss').format(now);
      _checkOutDateTime = now;
      if (_checkInDateTime != null) {
        _workingHours = now.difference(_checkInDateTime!);
        _isCheckInActive = false;
        _isCheckOutAvailable = false; // Disable check-out button after checkout
        _timer?.cancel();
        _showWorkingHoursDialog(context);
      }
    });

    // Store check-out time and working hours locally
    await _storeCheckOutTime(_checkOutTime);
    await _storeWorkingHours(Duration.zero); // Reset working hours after checkout
  }

  void _showLocationModal(BuildContext context, String location) {
    final isHome = location == 'Home';
    final primaryColor = isHome ? Colors.orange : Colors.green;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10, // Adds depth (shadow) to the modal
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      isHome ? Icons.home : Icons.apartment,
                      color: Colors.white,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Location Detected",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "You are currently at ${isHome ? 'Home' : 'the Office'}.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold, // Bold the location text
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
                    backgroundColor: primaryColor, // Button color follows location
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    shadowColor: Colors.black.withOpacity(0.25), // Add deep shadow effect
                    elevation: 8, // Elevate button for a deeper 3D effect
                  ),
                  child: const Text(
                    "OK",
                    style: TextStyle(
                      fontSize: 18,
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
    );
  }

  Widget _buildPageContent(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _buildSectionContainer(),
        ),
        Expanded(
          child: _buildTabContent(context),
        ),
      ],
    );
  }

  void _showCustomDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info, color: Colors.red, size: 50),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDAA520), // gold color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWorkingHoursDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time, color: Colors.blue, size: 50),
              const SizedBox(height: 16),
              const Text(
                'Work Summary',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You worked for ${_workingHours.toString().split('.').first.padLeft(8, '0')} hours today.',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDAA520), // gold color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttendanceRow(Map<String, String> record) {
    final isHome = _currentSection == 'Home';
    final isOffice = _currentSection == 'Office';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(record['date']!, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildAttendanceItem('Check In', record['checkIn']!, isHome ? Colors.orange : Colors.green),
            _buildAttendanceItem('Check Out', record['checkOut']!, isOffice ? Colors.green : Colors.red),
            _buildAttendanceItem('Working Hours', record['workingHours']!, Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceItem(String title, String time, Color color) {
    return Column(
      children: [
        Text(
          time,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: const TextStyle(color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildHeaderContent(BuildContext context) {
    final fingerprintColor = _currentSection == 'Office'
        ? Colors.green
        : _currentSection == 'Home'
            ? Colors.orange
            : Colors.red;
    final now = DateTime.now();
    final checkInTimeAllowed = DateTime(now.year, now.month, now.day, 8, 0); // 8:00 AM
    final checkInDisabledTime = DateTime(now.year, now.month, now.day, 13, 0); // 1:00 PM
    bool isCheckInEnabled = !_isCheckInActive && now.isAfter(checkInTimeAllowed) && now.isBefore(checkInDisabledTime);
    bool isCheckOutEnabled = _isCheckInActive && _workingHours >= const Duration(hours: 0) && _isCheckOutAvailable;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            DateFormat('EEEE MMMM dd - yyyy, HH:mm:ss').format(DateTime.now()),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Icon(Icons.fingerprint, size: 100, color: fingerprintColor),
              const SizedBox(height: 8),
              const Text(
                'Register Your Presence and Start Your Work',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                'Check in time can be late by 01:00',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      if (now.isBefore(checkInTimeAllowed)) {
                        _showCustomDialog(context, 'Too Early', 'Check-in will be available at 8:00 AM.');
                      } else if (isCheckInEnabled) {
                        _authenticate(context, true);
                      } else if (_isCheckInActive) {
                        _showCustomDialog(context, 'Already Checked In', 'You have already checked in.');
                      } else {
                        _showCustomDialog(context, 'Check-In Disabled', 'Check-in is only available between 8:00 AM and 1:00 PM.');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCheckInEnabled ? fingerprintColor : Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text('Check In'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_isCheckInActive && !isCheckOutEnabled) {
                        _showCustomDialog(context, 'Too Early', 'Wait until working hours hit 8 hours of working time.');
                      } else if (isCheckOutEnabled) {
                        _authenticate(context, false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCheckOutEnabled ? Colors.red : Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text('Check Out'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: _selectedIndex == 1
                ? LinearGradient(
                    colors: [
                      Colors.red.shade50,
                      Colors.red.shade100,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : LinearGradient(
                    colors: [
                      Colors.orange.shade50,
                      Colors.green.shade50,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.5, 0.5],
                  ),
          ),
        ),
        Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderContent(context),
                    const SizedBox(height: 16),
                    _buildSummaryRow(_checkInTime, _checkOutTime, _workingHours.toString().split('.').first.padLeft(8, '0')),
                    const SizedBox(height: 16),
                    _buildWeeklyRecordsList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String checkIn, String checkOut, String workingHours) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem('Check In', checkIn, Icons.login, Colors.green),
            _buildSummaryItem('Check Out', checkOut, Icons.logout, Colors.red),
            _buildSummaryItem('Working Hours', workingHours, Icons.timer, Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String time, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 36),
        const SizedBox(height: 8),
        Text(time, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(color: Colors.black)),
      ],
    );
  }

  Widget _buildWeeklyRecordsList() {
    if (_weeklyRecords.isEmpty) {
      return const Center(
        child: Text(
          'No weekly records found.',
          style: TextStyle(color: Colors.black),
        ),
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFDAA520), // Gold color
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    'Check In',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Check Out',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Working Hours',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ),
        Column(
          children: _weeklyRecords.map((record) => _buildAttendanceRow(record)).toList(),
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
            padding: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade400, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      // Disable home if the detected location is Office or Offsite
                      if (_detectedLocation == 'Office' || _detectedLocation == 'Offsite') {
                        return;
                      }
                      if (_currentSection == 'Home' || _selectedIndex == 1) {
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.home,
                            color: (_currentSection == 'Home' && _selectedIndex != 1) ? Colors.white : Colors.orange,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Home',
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
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  color: Colors.grey.shade500,
                  width: 1,
                  height: 40,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      // Disable office if the detected location is Home
                      if (_detectedLocation == 'Home') {
                        return;
                      }
                      if (_currentSection == 'Office' || _selectedIndex == 1) {
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.apartment,
                            color: (_currentSection == 'Office' && _selectedIndex != 1) ? Colors.white : Colors.green,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Office',
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
        const SizedBox(width: 20),
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedIndex = 1;
              _currentSection = 'Offsite';
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 25),
            decoration: BoxDecoration(
              color: _selectedIndex == 1 ? Colors.red : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on,
                  color: _selectedIndex == 1 ? Colors.white : Colors.red,
                ),
                const SizedBox(height: 4),
                Text(
                  'Offsite',
                  style: TextStyle(
                    color: _selectedIndex == 1 ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(MediaQuery.of(context).size.height * 0.1),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/background.png"),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: const Center(
            child: Column(
              children: [
                SizedBox(height: 20),
                Text(
                  'Attendance',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          _buildPageContent(context),
          if (_isLoading) _buildLoadingIndicator(), // Show loading indicator if loading
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 30,
            child: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MonthlyAttendanceReport()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
      ),
    );
  }
}
