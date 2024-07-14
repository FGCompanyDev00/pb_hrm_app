import 'package:flutter/material.dart';
import 'package:pb_hrsystem/main.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back),
        //   onPressed: () {
        //     Navigator.pushReplacement(
        //       context,
        //       MaterialPageRoute(builder: (context) => MainScreen()),
        //     );
        //   },
        // ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monday March 01 - 2024, 07:45:00',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  const Icon(Icons.fingerprint, size: 100, color: Colors.green),
                  const SizedBox(height: 8),
                  const Text(
                    'Register Your Presence and Start Your Work',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
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
                          // Handle Check In
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: const Text('Check In'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Handle Check Out
                        },
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
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('08:30:00', '17:25:00', '11:55:00'),
            const SizedBox(height: 16),
            const Text('February - 2024', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            _buildAttendanceList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String checkIn, String checkOut, String workingHours) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildSummaryCard('Check In', checkIn, Icons.login),
        _buildSummaryCard('Check Out', checkOut, Icons.logout),
        _buildSummaryCard('Working Hours', workingHours, Icons.timer),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String time, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.green, size: 36),
        const SizedBox(height: 8),
        Text(time, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(title),
      ],
    );
  }

  Widget _buildAttendanceList() {
    return Column(
      children: [
        _buildAttendanceRow('Thursday February 29 - 2024', '08:05:00', '17:30:00', '08:00:00'),
        _buildAttendanceRow('Wednesday February 28 - 2024', '08:05:00', '17:30:00', '08:00:00'),
        _buildAttendanceRow('Tuesday February 27 - 2024', '08:05:00', '17:30:00', '08:00:00'),
      ],
    );
  }

  Widget _buildAttendanceRow(String date, String checkIn, String checkOut, String workingHours) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text('Check In: $checkIn'),
            Text('Check Out: $checkOut'),
            Text('Working Hours: $workingHours'),
          ],
        ),
      ),
    );
  }
}
