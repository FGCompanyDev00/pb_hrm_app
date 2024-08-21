import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/services/attendance_service.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import "package:pb_hrsystem/home/monthly_attendance_record.dart";

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();
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
  String _deviceId = '';
  List<Map<String, String>> _weeklyRecords = [];

  static const double _officeRange = 20; // Office location is considered within 20 meters
  static const LatLng _officeLocation = LatLng(
      18.019683463911665, 102.65139957427881);

  @override
  void initState() {
    super.initState();
    _retrieveDeviceId();
    _fetchWeeklyRecords();
    _startLocationMonitoring();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _retrieveDeviceId() async {
    try {
      const uuid = Uuid();
      setState(() {
        _deviceId = uuid.v4();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get device ID: $e');
      }
    }
  }

  Future<void> _fetchWeeklyRecords() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String endpoint = '$baseUrl/api/attendance/checkin-checkout/offices/weekly/me';

    try {
      // Retrieve the token from SharedPreferences
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
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _weeklyRecords = data.map((item) {
            return {
              'date': item['date'].toString(),
              'checkIn': item['checkIn'].toString(),
              'checkOut': item['checkOut'].toString(),
              'workingHours': item['workingHours'].toString(),
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

    setState(() {
      if (distanceToOffice <= _officeRange) {
        _currentSection = 'Office';
        _selectedIndex = 0;
      } else {
        _currentSection = 'Home';
        _selectedIndex = 0;
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_checkInDateTime != null && _checkOutDateTime == null) {
        setState(() {
          _workingHours = DateTime.now().difference(_checkInDateTime!);
        });
      }
    });
  }

  Future<void> _authenticate(BuildContext context, bool isCheckIn) async {
    final now = DateTime.now();
    Position? currentPosition = await _getCurrentPosition();
    if (currentPosition != null) {
      _determineSectionFromPosition(currentPosition);
    }

    if (isCheckIn) {
      await _sendAttendanceDataToAPI(isCheckIn);
      _performCheckIn(now);
      _showCustomDialog(
          context, 'Check-In Successful', 'You have checked in successfully.');
    } else {
      await _sendAttendanceDataToAPI(isCheckIn);
      _performCheckOut(now);
    }

    setState(() {});
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
        final String checkInTime = isCheckIn
            ? DateFormat('HH:mm:ss').format(DateTime.now())
            : _checkInTime; // Use saved check-in time for checkout
        final String checkOutTime = isCheckIn ? "00:00:00" : DateFormat(
            'HH:mm:ss').format(DateTime.now());
        final String workDuration = isCheckIn
            ? "00:00:00"
            : _workingHours
            .toString()
            .split('.')
            .first
            .padLeft(8, '0');
        final String officeStatus = _currentSection.toLowerCase();

        final attendanceData = {
          'employee_id': "PSV-00-000002",
          'employee_name': "John Doe",
          'device_token': _deviceId,
          'check_in_time': checkInTime,
          'check_out_time': checkOutTime,
          'latitude': position.latitude.toString(),
          'longitude': position.longitude.toString(),
          'office_status': officeStatus,
          'workDuration': workDuration,
        };

        await _attendanceService.checkInOrCheckOut(isCheckIn, attendanceData);
      } else {
        _showCustomDialog(context, 'Error', 'Failed to retrieve location.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending attendance data to API: $e');
      }
      _showCustomDialog(
          context, 'Error', 'Failed to send attendance data to the server.');
    }
  }

  void _performCheckIn(DateTime now) {
    setState(() {
      _checkInTime = DateFormat('HH:mm:ss').format(now);
      _checkInDateTime = now;
      _checkOutDateTime = null;
      _workingHours = Duration.zero;
      _isCheckInActive = true;
      _startTimer();
    });
  }

  void _performCheckOut(DateTime now) {
    setState(() {
      _checkOutTime = DateFormat('HH:mm:ss').format(now);
      _checkOutDateTime = now;
      if (_checkInDateTime != null) {
        _workingHours = now.difference(_checkInDateTime!);
        _isCheckInActive = false;
        _timer?.cancel();
        _showWorkingHoursDialog(context);
      }
    });
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
                'You worked for ${_workingHours
                    .toString()
                    .split('.')
                    .first
                    .padLeft(8, '0')} hours today.',
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
        title: Text(record['date']!,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildAttendanceItem('Check In', record['checkIn']!,
                isHome ? Colors.orange : Colors.green),
            _buildAttendanceItem('Check Out', record['checkOut']!,
                isOffice ? Colors.green : Colors.red),
            _buildAttendanceItem(
                'Working Hours', record['workingHours']!, Colors.blue),
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
    final checkInTimeAllowed = DateTime(
        now.year, now.month, now.day, 8, 0); // 8:00 AM
    final checkInDisabledTime = DateTime(
        now.year, now.month, now.day, 13, 0); // 1:00 PM
    bool isCheckInEnabled = !_isCheckInActive &&
        now.isAfter(checkInTimeAllowed) && now.isBefore(checkInDisabledTime);
    bool isCheckOutEnabled = _isCheckInActive &&
        _workingHours >= const Duration(hours: 8);

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
                        _showCustomDialog(context, 'Too Early',
                            'Check-in will be available at 8:00 AM.');
                      } else if (isCheckInEnabled) {
                        _authenticate(context, true);
                      } else if (_isCheckInActive) {
                        _showCustomDialog(context, 'Already Checked In',
                            'You have already checked in.');
                      } else {
                        _showCustomDialog(context, 'Check-In Disabled',
                            'Check-in is only available between 8:00 AM and 1:00 PM.');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCheckInEnabled
                          ? fingerprintColor
                          : Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text('Check In'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_isCheckInActive && !isCheckOutEnabled) {
                        _showCustomDialog(context, 'Too Early',
                            'Wait until working hours hit 8 hours of working time.');
                      } else if (isCheckOutEnabled) {
                        _authenticate(context, false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCheckOutEnabled ? Colors.red : Colors
                          .grey,
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
                    _buildSummaryRow(
                        _checkInTime, _checkOutTime, _workingHours
                        .toString()
                        .split('.')
                        .first
                        .padLeft(8, '0')),
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

  Widget _buildSummaryRow(String checkIn, String checkOut,
      String workingHours) {
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
            _buildSummaryItem(
                'Working Hours', workingHours, Icons.timer, Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String time, IconData icon,
      Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 36),
        const SizedBox(height: 8),
        Text(time,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        // Header section (already added)
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
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Check Out',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Working Hours',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Weekly records list
        Column(
          children: _weeklyRecords.map((record) => _buildAttendanceRow(record))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSectionButton(int index, String title, IconData icon,
      Color activeColor, Color inactiveColor) {
    final bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.black),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeColor = _currentSection == 'Home' ? Colors.orange : Colors.grey
        .shade200;
    final officeColor = _currentSection == 'Office' ? Colors.green : Colors.grey
        .shade200;
    final offsiteColor = _selectedIndex == 1 ? Colors.red : Colors.grey
        .shade200;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(MediaQuery
            .of(context)
            .size
            .height * 0.1),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/background.png"),
              // Use the background image
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
          Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildSectionButton(
                        0, 'Home', Icons.home, homeColor, Colors.grey.shade200),
                    const SizedBox(width: 8),
                    _buildSectionButton(
                        0, 'Office', Icons.apartment, officeColor,
                        Colors.grey.shade200),
                    const SizedBox(width: 8),
                    _buildSectionButton(
                        1, 'Offsite', Icons.location_on, offsiteColor,
                        Colors.grey.shade200),
                  ],
                ),
              ),
              Expanded(
                child: _buildTabContent(context),
              ),
            ],
          ),
          Positioned(
            bottom: 16, // Position it just above the bottom navigation bar
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const MonthlyAttendanceReport()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}