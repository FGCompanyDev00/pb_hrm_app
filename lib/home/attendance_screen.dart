import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _isAuthorized = false;
  bool _biometricEnabled = false;
  List<BiometricType> _availableBiometrics = [];
  Color _indicatorColor = Colors.yellow;
  Color _fingerprintColor = Colors.yellow;
  String _checkInTime = '--:--:--';
  String _checkOutTime = '--:--:--';

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _loadBiometricSetting();
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
      final now = TimeOfDay.now();
      setState(() {
        if (isCheckIn) {
          _checkInTime = now.format(context);
        } else {
          _checkOutTime = now.format(context);
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

    setState(() {
      _isAuthorized = authenticated;
    });
  }

  Widget _buildPopupDialog(BuildContext context, bool isCheckIn) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 50),
          SizedBox(height: 16),
          Text(
            'Attendance',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Text(
            isCheckIn ? 'Check IN success!' : 'Check OUT success!',
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFDAA520), // gold color
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: Text('Close'),
          ),
        ],
      ),
    );
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
              Icon(Icons.info, color: Colors.red, size: 50),
              SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFDAA520), // gold color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text('Close'),
              ),
            ],
          ),
        );
      },
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
                  _buildTabContent(context, isDarkMode, Colors.yellow, Colors.yellow),
                  _buildTabContent(context, isDarkMode, Colors.green, Colors.green),
                  _buildTabContent(context, isDarkMode, Colors.red, Colors.red),
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
                        _fingerprintColor = Colors.yellow;
                        break;
                      case 1:
                        _indicatorColor = Colors.green;
                        _fingerprintColor = Colors.green;
                        break;
                      case 2:
                        _indicatorColor = Colors.red;
                        _fingerprintColor = Colors.red;
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
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: EdgeInsets.all(5),
                tabs: [
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

  Widget _buildTabContent(BuildContext context, bool isDarkMode, Color indicatorColor, Color fingerprintColor) {
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
                    _buildSummaryRow(_checkInTime, _checkOutTime, '11:55:00', isDarkMode),
                    const SizedBox(height: 16),
                    Text(
                      'February - 2024',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
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
            'Monday March 01 - 2024, 07:45:00',
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
        Icon(icon, color: title == 'Check In' ? Colors.green : title == 'Check Out' ? Colors.yellow : Colors.red, size: 36),
        const SizedBox(height: 8),
        Text(time, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.black : Colors.black)),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(color: isDarkMode ? Colors.black : Colors.black)),
      ],
    );
  }

  Widget _buildAttendanceList(bool isDarkMode) {
    return Column(
      children: [
        _buildAttendanceRow('Thursday February 29 - 2024', '08:05:00', '17:30:00', '08:00:00', isDarkMode),
        _buildAttendanceRow('Wednesday February 28 - 2024', '08:05:00', '17:30:00', '08:00:00', isDarkMode),
        _buildAttendanceRow('Tuesday February 27 - 2024', '08:05:00', '17:30:00', '08:00:00', isDarkMode),
      ],
    );
  }

  Widget _buildAttendanceRow(String date, String checkIn, String checkOut, String workingHours, bool isDarkMode) {
    return Card(
      color: Colors.white.withOpacity(0.8),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(date, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.black : Colors.black)),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildAttendanceItem('Check In', checkIn, Colors.green, isDarkMode),
            _buildAttendanceItem('Check Out', checkOut, Colors.red, isDarkMode),
            _buildAttendanceItem('Working Hours', workingHours, Colors.blue, isDarkMode),
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
}
