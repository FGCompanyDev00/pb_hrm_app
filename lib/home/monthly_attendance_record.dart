// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../services/http_service.dart';

class MonthlyAttendanceReport extends StatefulWidget {
  const MonthlyAttendanceReport({super.key});

  @override
  MonthlyAttendanceReportState createState() => MonthlyAttendanceReportState();
}

class MonthlyAttendanceReportState extends State<MonthlyAttendanceReport> {
  List<Map<String, String>> _attendanceRecords = [];
  DateTime _currentMonth = DateTime.now();
  bool _errorFetchingData = false;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceRecords();
  }

  Future<void> _fetchAttendanceRecords() async {
    String? token = await _getToken();
    if (token == null || token.isEmpty) {
      _showCustomDialog(context, 'Error', 'Unable to retrieve authentication token.');
      return;
    }

    String url = '$baseUrl/api/attendance/checkin-checkout/offices/months/me';
    String formattedMonth = DateFormat('yyyy-MM').format(_currentMonth);

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'month': formattedMonth,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> monthlyRecords = data['monthly'] ?? [];

        setState(() {
          _attendanceRecords = monthlyRecords.where((item) {
            String checkInDate = item['check_in_date']?.toString() ?? '';
            if (checkInDate.isEmpty) return false;
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
              'officeStatus': item['office_status']?.toString() ?? 'office',
              'checkInStatus': item['check_in_status']?.toString() ?? 'unknown',
              'checkOutStatus': item['check_out_status']?.toString() ?? 'unknown',
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
                  backgroundColor: const Color(0xFFDAA520),
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

  Widget _buildAttendanceRow(Map<String, String> record) {
    // Retrieve colors based on check_in_status and check_out_status
    Color checkInColor = _getStatusColor(record['checkInStatus']);
    Color checkOutColor = _getStatusColor(record['checkOutStatus']);

    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDarkMode ? Colors.grey[800] : Colors.white.withOpacity(0.8),
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Center(
            child: Text(
          record['date']!,
          style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
        )),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Pass checkInColor for Check In
            _buildAttendanceItem('Check In', record['checkIn']!, checkInColor),
            // Pass checkOutColor for Check Out
            _buildAttendanceItem('Check Out', record['checkOut']!, checkOutColor),
            _buildAttendanceItem('Working Hours', record['workDuration']!, Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceItem(String title, String time, Color color) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthNavigationHeader() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black : Colors.white,
        borderRadius: const BorderRadius.only(
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
                    _fetchAttendanceRecords();
                  });
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _currentMonth.month == DateTime.now().month && _currentMonth.year == DateTime.now().year
                    ? null
                    : () {
                        setState(() {
                          _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                          _fetchAttendanceRecords();
                        });
                      },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.lightGreen : const Color(0xFFDAA520),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildMonthNavigationHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchAttendanceRecords,
              child: _errorFetchingData
                  ? ListView(
                      // To enable pull-to-refresh when there's an error,
                      // wrap the Center widget in a ListView
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: Center(
                            child: Text(
                              "No attendance record data for this month.",
                              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(), // Ensures the list can always be scrolled to trigger refresh
                      itemCount: _attendanceRecords.length,
                      itemBuilder: (context, index) {
                        return _buildAttendanceRow(_attendanceRecords[index]);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      flexibleSpace: Container(
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
      ),
      centerTitle: true,
      title: Text(
        'Monthly Attendance',
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            _fetchAttendanceRecords();
          },
          tooltip: 'Refresh',
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ],
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: isDarkMode ? Colors.white : Colors.black,
          size: 22,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      toolbarHeight: 80,
      elevation: 0,
      backgroundColor: Colors.transparent,
    );
  }
}
