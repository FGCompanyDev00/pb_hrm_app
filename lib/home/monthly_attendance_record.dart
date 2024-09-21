import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class MonthlyAttendanceReport extends StatefulWidget {
  const MonthlyAttendanceReport({super.key});

  @override
  _MonthlyAttendanceReportState createState() => _MonthlyAttendanceReportState();
}

class _MonthlyAttendanceReportState extends State<MonthlyAttendanceReport> {
  List<Map<String, String>> _attendanceRecords = [];
  DateTime _currentMonth = DateTime.now();
  bool _errorFetchingData = false;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceRecords();
  }

  Future<void> _fetchAttendanceRecords() async {
    String? token = await _getToken(); // Fetch the authentication token from SharedPreferences
    if (token == null || token.isEmpty) {
      _showCustomDialog(context, 'Error', 'Unable to retrieve authentication token.');
      return;
    }

    const String url = 'https://demo-application-api.flexiflows.co/api/attendance/checkin-checkout/offices/months/me';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> monthlyRecords = data['monthly'] ?? [];

        setState(() {
          _attendanceRecords = monthlyRecords.where((item) {
            String checkInDate = item['check_in_date']?.toString() ?? '';
            DateTime parsedDate = DateFormat('yyyy-MM-dd').parse(checkInDate);
            return parsedDate.year == _currentMonth.year && parsedDate.month == _currentMonth.month;
          }).map<Map<String, String>>((item) {
            return {
              'checkIn': item['check_in_time']?.toString() ?? '--:--:--',
              'checkOut': item['check_out_time']?.toString() ?? '--:--:--',
              'workDuration': item['workDuration']?.toString() ?? '00:00:00',
              'date': DateFormat('EEEE MMMM dd - yyyy').format(
                DateFormat('yyyy-MM-dd').parse(
                  item['check_in_date']?.toString() ?? '',
                ),
              ),
              'officeStatus': item['office_status']?.toString() ?? 'office', // office, home, or offsite
            };
          }).toList();

          _errorFetchingData = _attendanceRecords.isEmpty;
        });
      } else {
        setState(() {
          _errorFetchingData = true;
        });
        _showCustomDialog(context, 'Error', 'Failed to retrieve data: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      setState(() {
        _errorFetchingData = true;
      });
      _showCustomDialog(context, 'Error', 'An error occurred while fetching data: $e');
    }
  }


  Future<String?> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
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

  Widget _buildAttendanceRow(Map<String, String> record) {
    Color iconColor;
    switch (record['officeStatus']) {
      case 'home':
        iconColor = Colors.yellow;
        break;
      case 'office':
        iconColor = Colors.green;
        break;
      case 'offsite':
        iconColor = Colors.red;
        break;
      default:
        iconColor = Colors.green;
    }

    return Card(
      color: Colors.white.withOpacity(0.8),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Center(child: Text(record['date']!, style: const TextStyle(fontWeight: FontWeight.bold))),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildAttendanceItem('Check In', record['checkIn']!, iconColor),
            _buildAttendanceItem('Check Out', record['checkOut']!, iconColor),
            _buildAttendanceItem('Working Hours', record['workDuration']!, Colors.blue),
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
          style: const TextStyle(
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildMonthNavigationHeader(),
          Expanded(
            child: _errorFetchingData
                ? const Center(
              child: Text(
                "No attendance record data for this month.",
                style: TextStyle(color: Colors.black),
              ),
            )
                : ListView.builder(
              itemCount: _attendanceRecords.length,
              itemBuilder: (context, index) {
                return _buildAttendanceRow(_attendanceRecords[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(50.50),
      child: AppBar(
        flexibleSpace: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0, // Remove shadow
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
          color: Colors.black,
        ),
        title: const Text(
          'Attendance Report',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildMonthNavigationHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                    _fetchAttendanceRecords(); // Fetch records for the previous month
                  });
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _currentMonth.month == DateTime.now().month && _currentMonth.year == DateTime.now().year
                    ? null
                    : () {
                  setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                    _fetchAttendanceRecords(); // Fetch records for the next month
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
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
        ],
      ),
    );
  }
}
