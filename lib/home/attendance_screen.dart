import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _isAuthorized = false;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
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

  Future<void> _authenticate(BuildContext context, bool isCheckIn) async {
    bool authenticated = false;

    if (!_canCheckBiometrics) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric authentication is not available.'),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCheckIn ? 'Checked In Successfully' : 'Checked Out Successfully'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCheckIn ? 'Check In Failed' : 'Check Out Failed'),
        ),
      );
    }

    setState(() {
      _isAuthorized = authenticated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      body: Stack(
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
              AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  'Attendance',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, isDarkMode),
                      const SizedBox(height: 16),
                      _buildSummaryRow('08:30:00', '17:25:00', '11:55:00', isDarkMode),
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDarkMode) {
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
              const Icon(Icons.fingerprint, size: 100, color: Colors.green),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildSummaryCard('Check In', checkIn, Icons.login, isDarkMode),
        _buildSummaryCard('Check Out', checkOut, Icons.logout, isDarkMode),
        _buildSummaryCard('Working Hours', workingHours, Icons.timer, isDarkMode),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String time, IconData icon, bool isDarkMode) {
    return Card(
      color: Colors.white.withOpacity(0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.green, size: 36),
            const SizedBox(height: 8),
            Text(time, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.black : Colors.black)),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: isDarkMode ? Colors.black : Colors.black)),
          ],
        ),
      ),
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
        subtitle: Wrap(
          alignment: WrapAlignment.spaceAround,
          children: [
            Text('Check In: $checkIn', style: TextStyle(color: isDarkMode ? Colors.black : Colors.black)),
            Text('Check Out: $checkOut', style: TextStyle(color: isDarkMode ? Colors.black : Colors.black)),
            Text('Working Hours: $workingHours', style: TextStyle(color: isDarkMode ? Colors.black : Colors.black)),
          ],
        ),
      ),
    );
  }
}
