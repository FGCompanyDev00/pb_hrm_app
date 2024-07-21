import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final LocalAuthentication auth = LocalAuthentication();
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

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _loadBiometricSetting();
    _loadAttendanceRecords();
    _currentMonthKey = DateFormat('MMMM - yyyy').format(DateTime.now());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    bool canCheckBiometrics;
    try {
      canCheckBiometrics = await auth.canCheckBiometrics;
      _availableBiometrics = await auth.getAvailableBiometrics();
    } catch (e) {
      canCheckBiometrics = false;
      print('Error checking biometrics: $e');
    }

    if (!mounted) return;

    setState(() {
      _canCheckBiometrics = canCheckBiometrics;
    });

    print('Can check biometrics: $_canCheckBiometrics');
    print('Available biometrics: $_availableBiometrics');
  }

  Future<void> _loadBiometricSetting() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = prefs.getBool('biometricEnabled') ?? false;
    });
  }

  Future<void> _loadAttendanceRecords() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _attendanceRecords = Map<String, List<Map<String, String>>>.from(
          prefs.getString('attendanceRecords') != null
              ? Map<String, dynamic>.from(prefs.getString('attendanceRecords') as Map)
              : {});
    });
  }

  Future<void> _saveAttendanceRecords() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('attendanceRecords', _attendanceRecords.toString());
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_checkInDateTime != null && _checkOutDateTime == null) {
          _workingHours = DateTime.now().difference(_checkInDateTime!);
        }
      });
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
      print('Error during authentication: $e');
    }

    if (authenticated) {
      final now = DateTime.now();
      setState(() {
        if (isCheckIn) {
          _checkInTime = DateFormat('HH:mm:ss').format(now);
          _checkInDateTime = now;
          _workingHours = Duration.zero; // Reset working hours on check-in
          _startTimer(); // Start the timer to update working hours
        } else {
          _checkOutTime = DateFormat('HH:mm:ss').format(now);
          _checkOutDateTime = now;
          if (_checkInDateTime != null) {
            _workingHours = now.difference(_checkInDateTime!);
            _timer?.cancel(); // Stop the timer on check-out
            _saveAttendanceRecord();
          }
        }
      });

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return _buildPopupDialog(context, isCheckIn);
        },
      );
    } else {
      _showCustomDialog(context, 'Authentication Failed', isCheckIn ? 'Check In Failed' : 'Check Out Failed');
    }

    setState(() {});
  }

  void _saveAttendanceRecord() {
    final now = DateTime.now();
    final record = {
      'date': DateFormat('EEEE MMMM dd - yyyy').format(now),
      'checkIn': _checkInTime,
      'checkOut': _checkOutTime,
      'workingHours': _workingHours.toString().split('.').first.padLeft(8, '0'),
    };

    String key = '$_currentSection $_currentMonthKey';
    if (_attendanceRecords[key] == null) {
      _attendanceRecords[key] = [];
    }
    _attendanceRecords[key]!.add(record);

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

  Widget _buildPopupDialog(BuildContext context, bool isCheckIn) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 50),
          const SizedBox(height: 16),
          const Text(
            'Attendance',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isCheckIn ? 'Check IN success!' : 'Check OUT success!',
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

  Widget _buildHeaderContent(BuildContext context, bool isDarkMode, Color fingerprintColor) {
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
                    onPressed: () => _authenticate(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text('Check In'),
                  ),
                  ElevatedButton(
                    onPressed: () => _authenticate(context, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
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
        body: Column(
          children: [
            _buildTabs(context),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTabContent(context, isDarkMode, Colors.yellow, Colors.yellow, 'Home'),
                  _buildTabContent(context, isDarkMode, Colors.green, Colors.green, 'Office'),
                  _buildTabContent(context, isDarkMode, Colors.red, Colors.red, 'Offsite'),
                ],
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
            bottomLeft: Radius.circular(50),
            bottomRight: Radius.circular(50),
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
                    _buildHeaderContent(context, isDarkMode, fingerprintColor),
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
