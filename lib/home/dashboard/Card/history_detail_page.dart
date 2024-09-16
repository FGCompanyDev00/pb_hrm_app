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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(85.0),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/background.png"),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: const Center(
                child: Column(
                  children: [
                    SizedBox(height: 65),
                    Text(
                      'Details',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 55,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2), // External shadow
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
                  color: textColor, // Text color based on theme
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // Dynamic fields based on types
            if (widget.types == 'car') ...[
              _buildDetailRow('Vehicle ID', _itemDetails!['vehicle_id'] ?? 'N/A', textColor),
              _buildDetailRow('Requestor ID', _itemDetails!['requestor_id'] ?? 'N/A', textColor),
              _buildDetailRow('Date Out', _itemDetails!['date_out'] ?? 'N/A', textColor),
              _buildDetailRow('Date In', _itemDetails!['date_in'] ?? 'N/A', textColor),
              _buildDetailRow('Total Distance', _itemDetails!['total_distance'].toString(), textColor),
            ] else if (widget.types == 'leave') ...[
              _buildDetailRow('Requestor ID', _itemDetails!['requestor_id'] ?? 'N/A', textColor),
              _buildDetailRow('Leave From', _itemDetails!['take_leave_from'] ?? 'N/A', textColor),
              _buildDetailRow('Leave To', _itemDetails!['take_leave_to'] ?? 'N/A', textColor),
              _buildDetailRow('Days', _itemDetails!['days'].toString(), textColor),
            ] else if (widget.types == 'meeting') ...[
              _buildDetailRow('Room ID', _itemDetails!['room_id'] ?? 'N/A', textColor),
              _buildDetailRow('Employee ID', _itemDetails!['employee_id'] ?? 'N/A', textColor),
              _buildDetailRow('From', _itemDetails!['from_date_time'] ?? 'N/A', textColor),
              _buildDetailRow('To', _itemDetails!['to_date_time'] ?? 'N/A', textColor),
              _buildDetailRow('Created Date', _itemDetails!['date_create'] ?? 'N/A', textColor),
            ],
          ],
        ),
      ),
    );
  }

  // Method to build each row of details
  Widget _buildDetailRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
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
