import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';

class DetailsPage extends StatefulWidget {
  final String id;
  final String types;
  final String status;

  const DetailsPage({super.key, required this.id, required this.types, required this.status});

  @override
  _DetailsPageState createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  Map<String, dynamic>? _itemDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    final String apiUrl = 'https://demo-application-api.flexiflows.co/api/app/users/history/pending/${widget.id}';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'types': widget.types,
          'status': widget.status,
        }),
      );
      if (response.statusCode == 200) {
        setState(() {
          _itemDetails = jsonDecode(response.body)['results'];
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch details');
      }
    } catch (e) {
      print('Error fetching details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'disapproved':
      case 'rejected':
      case 'cancel':
        return Colors.red;
      case 'waiting':
      case 'pending':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final statusColor = _getStatusColor(widget.status);
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        toolbarHeight: 80,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _itemDetails == null
          ? const Center(child: Text('Failed to load details'))
          : Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title (Purpose, Name, etc.)
            Text(
              _itemDetails![widget.types == 'car'
                  ? 'purpose'
                  : widget.types == 'leave'
                  ? 'take_leave_reason'
                  : 'title'] ??
                  'N/A',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Status Highlight
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 16.0),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12.0),
                gradient: LinearGradient(
                  colors: [statusColor.withOpacity(0.7), statusColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.status,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // Dynamic fields based on types
            if (widget.types == 'car') ...[
              _buildDetailRow(
                  Icons.directions_car, 'Vehicle ID', _itemDetails!['vehicle_id'] ?? 'N/A', textColor, Colors.blueAccent),
              _buildDetailRow(
                  Icons.person, 'Requestor ID', _itemDetails!['requestor_id'] ?? 'N/A', textColor, Colors.orange),
              _buildDetailRow(Icons.calendar_today, 'Date Out',
                  _itemDetails!['date_out'] ?? 'N/A', textColor, Colors.purple),
              _buildDetailRow(Icons.calendar_today, 'Date In',
                  _itemDetails!['date_in'] ?? 'N/A', textColor, Colors.green),
              _buildDetailRow(Icons.speed, 'Total Distance',
                  _itemDetails!['total_distance'].toString(), textColor, Colors.redAccent),
            ] else if (widget.types == 'leave') ...[
              _buildDetailRow(
                  Icons.person, 'Requestor ID', _itemDetails!['requestor_id'] ?? 'N/A', textColor, Colors.orange),
              _buildDetailRow(Icons.calendar_today, 'Leave From',
                  _itemDetails!['take_leave_from'] ?? 'N/A', textColor, Colors.green),
              _buildDetailRow(Icons.calendar_today, 'Leave To',
                  _itemDetails!['take_leave_to'] ?? 'N/A', textColor, Colors.redAccent),
              _buildDetailRow(Icons.timelapse, 'Days',
                  _itemDetails!['days'].toString(), textColor, Colors.blue),
            ] else if (widget.types == 'meeting') ...[
              _buildDetailRow(Icons.room, 'Room ID',
                  _itemDetails!['room_id'] ?? 'N/A', textColor, Colors.teal),
              _buildDetailRow(Icons.person, 'Employee ID',
                  _itemDetails!['employee_id'] ?? 'N/A', textColor, Colors.orange),
              _buildDetailRow(Icons.calendar_today, 'From',
                  _itemDetails!['from_date_time'] ?? 'N/A', textColor, Colors.green),
              _buildDetailRow(Icons.calendar_today, 'To',
                  _itemDetails!['to_date_time'] ?? 'N/A', textColor, Colors.redAccent),
              _buildDetailRow(Icons.create, 'Created Date',
                  _itemDetails!['date_create'] ?? 'N/A', textColor, Colors.blue),
            ],
          ],
        ),
      ),
    );
  }

  // Method to build each row of details with a customized icon color
  Widget _buildDetailRow(
      IconData icon, String label, String value, Color textColor, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
