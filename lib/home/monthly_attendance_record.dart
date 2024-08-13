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
  String _currentMonthKey = 'January 2024'; // Default month
  String _selectedType = 'Office'; // Default selected type
  String _dropdownValue = 'Office'; // For the dropdown
  bool _errorFetchingData = false;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceRecords();
  }

  Future<void> _fetchAttendanceRecords() async {
    String? token = await _getToken();
    if (token == null) {
      _showCustomDialog(context, 'Error', 'Unable to retrieve authentication token.');
      return;
    }

    String url = '';
    if (_selectedType == 'Home') {
      url = 'https://demo-application-api.flexiflows.co/api/attendance/checkin-checkout/home/months/me';
    } else if (_selectedType == 'Office') {
      url = 'https://demo-application-api.flexiflows.co/api/attendance/checkin-checkout/offices/months/me';
    } else if (_selectedType == 'Offsite') {
      url = 'https://demo-application-api.flexiflows.co/api/attendance/checkin-checkout/offices/offsite/me';
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _attendanceRecords = data.map<Map<String, String>>((item) {
            return {
              'checkIn': item['checkInTime']?.toString() ?? '--:--:--',
              'checkOut': item['checkOutTime']?.toString() ?? '--:--:--',
              'workingHours': item['workingHours']?.toString() ?? '00:00:00',
              'date': item['date']?.toString() ?? 'N/A',
            };
          }).toList();
          _errorFetchingData = _attendanceRecords.isEmpty;
        });
      } else {
        setState(() {
          _errorFetchingData = true;
        });
      }
    } catch (e) {
      setState(() {
        _errorFetchingData = true;
      });
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

  Widget _buildAttendanceRow(Map<String, String> record, Color iconColor) {
    return Card(
      color: Colors.white.withOpacity(0.8),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(record['date']!, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildAttendanceItem('Check In', record['checkIn']!, iconColor),
            _buildAttendanceItem('Check Out', record['checkOut']!, iconColor),
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
          style: const TextStyle(
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    switch (_selectedType) {
      case 'Home':
        iconColor = Colors.yellow;
        break;
      case 'Office':
        iconColor = Colors.green;
        break;
      case 'Offsite':
        iconColor = Colors.red;
        break;
      default:
        iconColor = Colors.green;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Report'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _errorFetchingData
                ? const Center(child: Text("Can't retrieve data at the moment", style: TextStyle(color: Colors.black)))
                : ListView.builder(
              itemCount: _attendanceRecords.length,
              itemBuilder: (context, index) {
                return _buildAttendanceRow(_attendanceRecords[index], iconColor);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.orange.shade300,
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
                    final previousMonth = DateTime.now().subtract(Duration(days: DateTime.now().day));
                    _currentMonthKey = DateFormat('MMMM yyyy').format(previousMonth);
                  });
                },
              ),
              Text(
                _currentMonthKey,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () {
                  setState(() {
                    final nextMonth = DateTime.now().add(Duration(days: 30 - DateTime.now().day));
                    _currentMonthKey = DateFormat('MMMM yyyy').format(nextMonth);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDropdownButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownButton() {
    return DropdownButton<String>(
      value: _dropdownValue,
      icon: const Icon(Icons.arrow_downward),
      iconSize: 24,
      elevation: 16,
      style: const TextStyle(color: Colors.black, fontSize: 16),
      underline: Container(
        height: 2,
        color: Colors.black,
      ),
      onChanged: (String? newValue) {
        setState(() {
          _dropdownValue = newValue!;
          _selectedType = newValue;
          _fetchAttendanceRecords();
        });
      },
      items: <String>['Home', 'Office', 'Offsite']
          .map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
    );
  }
}
