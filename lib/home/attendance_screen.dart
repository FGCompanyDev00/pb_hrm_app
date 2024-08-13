import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:pb_hrsystem/home/monthly_attendance_record.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();
  bool _canCheckBiometrics = false;
  bool _biometricEnabled = false;
  List<BiometricType> _availableBiometrics = [];
  Color _indicatorColor = Colors.yellow;
  String _checkInTime = '--:--:--';
  String _checkOutTime = '--:--:--';
  DateTime? _checkInDateTime;
  DateTime? _checkOutDateTime;
  Duration _workingHours = Duration.zero;
  Timer? _timer;
  Map<String, List<Map<String, String>>> _attendanceRecords = {};
  String _currentMonthKey = '';
  String _currentSection = 'Home';
  bool _isCheckInActive = false;
  String _activeSection = '';

  static const double _allowedDistance = 500; // 500 meters
  static const LatLng _officeLocation = LatLng(3.1390, 101.6869); // Coordinates for Kementerian Pendidikan Malaysia

  @override
  void initState() {
    super.initState();
    _initializeBackgroundService();
    _checkBiometrics();
    _loadBiometricSetting();
    _loadAttendanceRecords();
    _currentMonthKey = DateFormat('MMMM - yyyy').format(DateTime.now());
    _loadCurrentSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeBackgroundService() async {
    const androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: 'PBHR Attendance',
      notificationText: 'Running in background',
      notificationImportance: AndroidNotificationImportance.Default,
      enableWifiLock: true,
    );

    await requestPermissions();

    bool initialized = await FlutterBackground.initialize(androidConfig: androidConfig);
    if (initialized) {
      await FlutterBackground.enableBackgroundExecution();
    }
  }

  Future<void> requestPermissions() async {
    var status = await Permission.ignoreBatteryOptimizations.request();
    if (status.isGranted) {
      if (kDebugMode) {
        print("Ignore battery optimizations permission granted");
      }
    } else {
      if (kDebugMode) {
        print("Ignore battery optimizations permission denied");
      }
    }
  }

  Future<void> _checkBiometrics() async {
    bool canCheckBiometrics;
    try {
      canCheckBiometrics = await auth.canCheckBiometrics;
      _availableBiometrics = await auth.getAvailableBiometrics();
    } catch (e) {
      canCheckBiometrics = false;
      if (kDebugMode) {
        print('Error checking biometrics: $e');
      }
    }

    if (!mounted) return;

    setState(() {
      _canCheckBiometrics = canCheckBiometrics;
    });

    if (kDebugMode) {
      print('Can check biometrics: $_canCheckBiometrics');
    }
    if (kDebugMode) {
      print('Available biometrics: $_availableBiometrics');
    }
  }

  Future<void> _loadBiometricSetting() async {
    bool? isEnabled = await _storage.read(key: 'biometricEnabled') == 'true';
    setState(() {
      _biometricEnabled = isEnabled;
    });
  }

  Future<void> _loadAttendanceRecords() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? attendanceRecords = prefs.getString('attendanceRecords');
    if (attendanceRecords != null) {
      setState(() {
        // Decode and cast the data safely
        final decodedData = jsonDecode(attendanceRecords) as Map<String, dynamic>;
        _attendanceRecords = decodedData.map((key, value) {
          // Explicitly cast each item in the list to Map<String, String>
          List<Map<String, String>> castedList = List<Map<String, String>>.from(
            value.map((item) => Map<String, String>.from(item)),
          );
          return MapEntry(key, castedList);
        });
      });
    }
  }

  Future<void> _saveAttendanceRecords() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('attendanceRecords', jsonEncode(_attendanceRecords));
  }

  Future<void> _loadCurrentSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? checkInTime = prefs.getString('checkInTime');
    String? section = prefs.getString('section');
    if (checkInTime != null && section != null) {
      setState(() {
        _checkInDateTime = DateTime.parse(checkInTime);
        _checkInTime = DateFormat('HH:mm:ss').format(_checkInDateTime!);
        _activeSection = section;
        _isCheckInActive = true;
        _startTimer();
      });
    }
  }

  Future<void> _saveCurrentSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('checkInTime', _checkInDateTime?.toIso8601String() ?? '');
    await prefs.setString('section', _activeSection);
  }

  Future<void> _clearCurrentSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('checkInTime');
    await prefs.remove('section');
    setState(() {
      _checkInDateTime = null;
      _checkInTime = '--:--:--';
      _checkOutTime = '--:--:--';
      _workingHours = Duration.zero;
      _isCheckInActive = false;
      _activeSection = '';
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
    if (!_biometricEnabled) {
      _showCustomDialog(context, 'Biometric Disabled', 'Please enable biometric authentication in settings.');
      return;
    }

    bool authenticated = false;

    if (!_canCheckBiometrics) {
      _showCustomDialog(context, 'Biometric Not Available', 'Biometric authentication is not available.');
      return;
    }

    try {
      authenticated = await auth.authenticate(
        localizedReason: isCheckIn ? 'Please authenticate to check in' : 'Please authenticate to check out',
        options: const AuthenticationOptions(
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error during authentication: $e');
      }
    }

    if (authenticated) {
      final now = DateTime.now();
      if (isCheckIn) {
        if (_currentSection == 'Office') {
          Position position = await _getCurrentPosition();
          double distanceToOffice = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            _officeLocation.latitude,
            _officeLocation.longitude,
          );

          if (distanceToOffice <= _allowedDistance) {
            _performCheckIn(now);
            _showCustomDialog(context, 'Check-In Successful', 'You have checked in successfully.');
          } else {
            _showCustomDialog(context, 'Check-In Failed', 'You are not within the allowed distance to check in.');
          }
        } else {
          // For Home and Offsite sections, send the user's location to the API
          await _sendLocationToAPI();
          _performCheckIn(now);
          _showCustomDialog(context, 'Check-In Successful', 'You have checked in successfully.');
        }
      } else {
        _performCheckOut(now);
      }
    } else {
      _showCustomDialog(context, 'Authentication Failed', isCheckIn ? 'Check In Failed' : 'Check Out Failed');
    }

    setState(() {});
  }

  Future<void> _sendLocationToAPI() async {
    try {
      Position position = await _getCurrentPosition();
      final response = await http.post(
        Uri.parse('https://demo-application-api.flexiflows.co/api/attendance/checkin-checkout/clock-in-out'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'device_id': '0090290', // You might want to replace this with a dynamic value
          'latitude': position.latitude.toString(),
          'longitude': position.longitude.toString(),
        }),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('Location sent successfully');
        }
      } else {
        if (kDebugMode) {
          print('Failed to send location');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending location to API: $e');
      }
    }
  }

  void _performCheckIn(DateTime now) {
    setState(() {
      _checkInTime = DateFormat('HH:mm:ss').format(now);
      _checkInDateTime = now;
      _checkOutDateTime = null;
      _workingHours = Duration.zero;
      _startTimer();
      _saveCurrentSession();
      _isCheckInActive = true;
      _activeSection = _currentSection;
    });
  }

  void _performCheckOut(DateTime now) {
    setState(() {
      _checkOutTime = DateFormat('HH:mm:ss').format(now);
      _checkOutDateTime = now;
      if (_checkInDateTime != null) {
        _workingHours = now.difference(_checkInDateTime!);
        _timer?.cancel();
        _saveAttendanceRecord();
        _clearCurrentSession();
        _showWorkingHoursDialog(context);
      }
    });
  }

  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return Future.error('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  void _saveAttendanceRecord() {
    final now = DateTime.now();
    final record = {
      'date': DateFormat('EEEE MMMM dd - yyyy').format(now),
      'checkIn': _checkInTime,
      'checkOut': _checkOutTime,
      'workingHours': _workingHours.toString().split('.').first.padLeft(8, '0'),
    };

    String key = '$_activeSection $_currentMonthKey';
    if (_attendanceRecords[key] == null) {
      _attendanceRecords[key] = [];
    }
    _attendanceRecords[key]!.add(record);
    if (_attendanceRecords[key]!.length > 30) {
      _attendanceRecords[key] = _attendanceRecords[key]!.sublist(1);
    }

    _saveAttendanceRecords();
  }

  void _showCustomDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildAttendanceRow(Map<String, String> record, bool isDarkMode) {
    return Card(
      color: Colors.white.withOpacity(0.8),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(record['date']!, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.black : Colors.black)),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildAttendanceItem('Check In', record['checkIn']!, Colors.green, isDarkMode),
            _buildAttendanceItem('Check Out', record['checkOut']!, Colors.red, isDarkMode),
            _buildAttendanceItem('Working Hours', record['workingHours']!, Colors.blue, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceItem(String title, String time, Color color, bool isDarkMode) {
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
          style: TextStyle(
            color: isDarkMode ? Colors.black : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceList(bool isDarkMode) {
    List<Widget> attendanceList = [];
    String key = '$_currentSection $_currentMonthKey';
    if (_attendanceRecords[key] != null) {
      attendanceList = _attendanceRecords[key]!
          .map((record) => _buildAttendanceRow(record, isDarkMode))
          .toList();
    }
    return Column(children: attendanceList);
  }

  Widget _buildSummaryRow(String checkIn, String checkOut, String workingHours, bool isDarkMode) {
    return Card(
      color: Colors.white.withOpacity(0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem('Check In', checkIn, Icons.login, isDarkMode),
            _buildSummaryItem('Check Out', checkOut, Icons.logout, isDarkMode),
            _buildSummaryItem('Working Hours', workingHours, Icons.timer, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String time, IconData icon, bool isDarkMode) {
    return Column(
      children: [
        Icon(icon, color: title == 'Check In' ? Colors.green : title == 'Check Out' ? Colors.red : Colors.blue, size: 36),
        const SizedBox(height: 8),
        Text(time, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.black : Colors.black)),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(color: isDarkMode ? Colors.black : Colors.black)),
      ],
    );
  }

  Widget _buildHeaderContent(BuildContext context, bool isDarkMode, Color fingerprintColor, String section) {
    final now = DateTime.now();
    final checkInTimeAllowed = DateTime(now.year, now.month, now.day, 8, 0); // 8:00 AM
    final checkInDisabledTime = DateTime(now.year, now.month, now.day, 13, 0); // 1:00 PM
    bool isCheckInEnabled = !_isCheckInActive && now.isAfter(checkInTimeAllowed) && now.isBefore(checkInDisabledTime);
    bool isCheckOutEnabled = _isCheckInActive && _workingHours >= const Duration(hours: 8);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.black : Colors.black),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Icon(Icons.fingerprint, size: 100, color: fingerprintColor),
              const SizedBox(height: 8),
              Text(
                'Register Your Presence and Start Your Work',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: isDarkMode ? Colors.black : Colors.black),
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
                      backgroundColor: isCheckInEnabled ? Colors.green : Colors.grey,
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

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: _buildHeader(context, isDarkMode),
        body: Stack(
          children: [
            Column(
              children: [
                _buildTabs(context),
                Expanded(
                  child: TabBarView(
                    physics: const NeverScrollableScrollPhysics(), // Disable swipe gesture
                    children: [
                      _buildTabContent(context, isDarkMode, Colors.yellow, Colors.yellow, 'Home'),
                      _buildTabContent(context, isDarkMode, Colors.green, Colors.green, 'Office'),
                      _buildTabContent(context, isDarkMode, Colors.red, Colors.red, 'Offsite'),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 30.0,
              left: 0.0,
              right: 0.0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MonthlyAttendanceReport()),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    child: const Text(
                      'View More',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHeader(BuildContext context, bool isDarkMode) {
    return PreferredSize(
      preferredSize: Size.fromHeight(MediaQuery.of(context).size.height * 0.1),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
            fit: BoxFit.cover,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              'Attendance',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                onTap: (index) {
                  if (!_isCheckInActive) {
                    setState(() {
                      switch (index) {
                        case 0:
                          _indicatorColor = Colors.yellow;
                          _currentSection = 'Home';
                          break;
                        case 1:
                          _indicatorColor = Colors.green;
                          _currentSection = 'Office';
                          break;
                        case 2:
                          _indicatorColor = Colors.red;
                          _currentSection = 'Offsite';
                          break;
                      }
                    });
                  }
                },
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _indicatorColor,
                  boxShadow: [
                    BoxShadow(
                      color: _indicatorColor.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(5),
                tabs: const [
                  Tab(text: 'Home', icon: Icon(Icons.home)),
                  Tab(text: 'Office', icon: Icon(Icons.business)),
                  Tab(text: 'Offsite', icon: Icon(Icons.location_on)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, bool isDarkMode, Color indicatorColor, Color fingerprintColor, String section) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
              fit: BoxFit.cover,
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
                    _buildHeaderContent(context, isDarkMode, fingerprintColor, section),
                    const SizedBox(height: 16),
                    _buildSummaryRow(_checkInTime, _checkOutTime, _workingHours.toString().split('.').first.padLeft(8, '0'), isDarkMode),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_currentSection $_currentMonthKey',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
                              onPressed: () {
                                setState(() {
                                  final previousMonth = DateTime.now().subtract(Duration(days: DateTime.now().day));
                                  _currentMonthKey = DateFormat('MMMM - yyyy').format(previousMonth);
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.arrow_forward, color: isDarkMode ? Colors.white : Colors.black),
                              onPressed: () {
                                setState(() {
                                  final nextMonth = DateTime.now().add(Duration(days: 30 - DateTime.now().day));
                                  _currentMonthKey = DateFormat('MMMM - yyyy').format(nextMonth);
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    _buildAttendanceList(isDarkMode),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
