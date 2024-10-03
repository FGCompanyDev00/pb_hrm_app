import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';

class DetailsPage extends StatefulWidget {
  final String id;
  final String types;
  final String status;

  const DetailsPage({
    Key? key,
    required this.id,
    required this.types,
    required this.status,
  }) : super(key: key);

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
    final String apiUrl =
        'https://demo-application-api.flexiflows.co/api/app/users/history/pending/${widget.id}';
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

  // Assign unique colors to each icon based on the label
  Map<String, Color> _iconColors(String types) {
    switch (types) {
      case 'car':
        return {
          'Vehicle ID': Colors.blueAccent,
          'Requestor ID': Colors.orange,
          'Date Out': Colors.purple,
          'Date In': Colors.green,
          'Total Distance': Colors.redAccent,
        };
      case 'leave':
        return {
          'Requestor ID': Colors.orange,
          'Leave From': Colors.green,
          'Leave To': Colors.redAccent,
          'Days': Colors.blue,
        };
      case 'meeting':
        return {
          'Room ID': Colors.teal,
          'Employee ID': Colors.orange,
          'From': Colors.green,
          'To': Colors.redAccent,
          'Created Date': Colors.blue,
        };
      default:
        return {
          'Default': Colors.grey,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final statusColor = _getStatusColor(widget.status);
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 24,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3366FF), Color(0xFF00CCFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Image or Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [Colors.black, Colors.grey[850]!]
                    : [Colors.blue[50]!, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Main Content
          _isLoading
              ? const Center(
            child: CircularProgressIndicator(),
          )
              : _itemDetails == null
              ? const Center(
            child: Text(
              'Failed to load details',
              style: TextStyle(fontSize: 18),
            ),
          )
              : Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16.0, vertical: 100.0),
            child: ListView(
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
                const SizedBox(height: 24),
                // Status Highlight
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: statusColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.circle,
                        color: statusColor,
                        size: 12,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Dynamic fields based on types
                ..._buildDetailCards(textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build a list of detail cards based on the type
  List<Widget> _buildDetailCards(Color textColor) {
    final type = widget.types;
    final details = <Widget>[];
    final iconColorMap = _iconColors(type);

    if (type == 'car') {
      details.addAll([
        _buildDetailCard(
            Icons.directions_car, 'Vehicle ID', _itemDetails!['vehicle_id'] ?? 'N/A', iconColorMap['Vehicle ID']!, textColor),
        _buildDetailCard(
            Icons.person, 'Requestor ID', _itemDetails!['requestor_id'] ?? 'N/A', iconColorMap['Requestor ID']!, textColor),
        _buildDetailCard(
            Icons.calendar_today, 'Date Out', _itemDetails!['date_out'] ?? 'N/A', iconColorMap['Date Out']!, textColor),
        _buildDetailCard(
            Icons.calendar_today, 'Date In', _itemDetails!['date_in'] ?? 'N/A', iconColorMap['Date In']!, textColor),
        _buildDetailCard(
            Icons.speed, 'Total Distance', _itemDetails!['total_distance']?.toString() ?? 'N/A', iconColorMap['Total Distance']!, textColor),
      ]);
    } else if (type == 'leave') {
      details.addAll([
        _buildDetailCard(
            Icons.person, 'Requestor ID', _itemDetails!['requestor_id'] ?? 'N/A', iconColorMap['Requestor ID']!, textColor),
        _buildDetailCard(
            Icons.calendar_today, 'Leave From', _itemDetails!['take_leave_from'] ?? 'N/A', iconColorMap['Leave From']!, textColor),
        _buildDetailCard(
            Icons.calendar_today, 'Leave To', _itemDetails!['take_leave_to'] ?? 'N/A', iconColorMap['Leave To']!, textColor),
        _buildDetailCard(
            Icons.timelapse, 'Days', _itemDetails!['days']?.toString() ?? 'N/A', iconColorMap['Days']!, textColor),
      ]);
    } else if (type == 'meeting') {
      details.addAll([
        _buildDetailCard(
            Icons.room, 'Room ID', _itemDetails!['room_id'] ?? 'N/A', iconColorMap['Room ID']!, textColor),
        _buildDetailCard(
            Icons.person, 'Employee ID', _itemDetails!['employee_id'] ?? 'N/A', iconColorMap['Employee ID']!, textColor),
        _buildDetailCard(
            Icons.calendar_today, 'From', _itemDetails!['from_date_time'] ?? 'N/A', iconColorMap['From']!, textColor),
        _buildDetailCard(
            Icons.calendar_today, 'To', _itemDetails!['to_date_time'] ?? 'N/A', iconColorMap['To']!, textColor),
        _buildDetailCard(
            Icons.create, 'Created Date', _itemDetails!['date_create'] ?? 'N/A', iconColorMap['Created Date']!, textColor),
      ]);
    }

    return details;
  }

  // Method to build each detail card with a customized icon color
  Widget _buildDetailCard(
      IconData icon, String label, String value, Color iconColor, Color textColor) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor,
          size: 28,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 18,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
