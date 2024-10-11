import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DetailsPage extends StatefulWidget {
  final String id;
  final String types;
  final String status;

  const DetailsPage({
    super.key,
    required this.id,
    required this.types,
    required this.status,
  });

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
    final statusColor = _getStatusColor(widget.status);
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3366FF), Color(0xFF00CCFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                _buildAppBar(),
                Expanded(
                  child: _isLoading
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
                      : _buildContent(statusColor, textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      height: 80,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 16),
          const Text(
            'Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Color statusColor, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: ListView(
        children: [
          // Title
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
          // Status
          Center(
            child: Chip(
              avatar: Icon(
                Icons.circle,
                color: statusColor,
                size: 12,
              ),
              label: Text(
                widget.status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: statusColor.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: statusColor),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Details
          ..._buildDetailCards(textColor),
        ],
      ),
    );
  }

  List<Widget> _buildDetailCards(Color textColor) {
    final type = widget.types;
    final details = <Widget>[];
    final iconColorMap = _iconColors(type);

    if (type == 'car') {
      details.addAll([
        _buildDetailCard(
            Icons.directions_car,
            'Vehicle ID',
            _itemDetails!['vehicle_id']?.toString() ?? 'N/A',
            iconColorMap['Vehicle ID']!,
            textColor),
        _buildDetailCard(
            Icons.person,
            'Requestor ID',
            _itemDetails!['requestor_id']?.toString() ?? 'N/A',
            iconColorMap['Requestor ID']!,
            textColor),
        _buildDetailCard(
            Icons.calendar_today,
            'Date Out',
            _itemDetails!['date_out'] ?? 'N/A',
            iconColorMap['Date Out']!,
            textColor),
        _buildDetailCard(
            Icons.calendar_today,
            'Date In',
            _itemDetails!['date_in'] ?? 'N/A',
            iconColorMap['Date In']!,
            textColor),
        _buildDetailCard(
            Icons.speed,
            'Total Distance',
            _itemDetails!['total_distance']?.toString() ?? 'N/A',
            iconColorMap['Total Distance']!,
            textColor),
      ]);
    } else if (type == 'leave') {
      details.addAll([
        _buildDetailCard(
            Icons.person,
            'Requestor ID',
            _itemDetails!['requestor_id']?.toString() ?? 'N/A',
            iconColorMap['Requestor ID']!,
            textColor),
        _buildDetailCard(
            Icons.calendar_today,
            'Leave From',
            _itemDetails!['take_leave_from'] ?? 'N/A',
            iconColorMap['Leave From']!,
            textColor),
        _buildDetailCard(
            Icons.calendar_today,
            'Leave To',
            _itemDetails!['take_leave_to'] ?? 'N/A',
            iconColorMap['Leave To']!,
            textColor),
        _buildDetailCard(
            Icons.timelapse,
            'Days',
            _itemDetails!['days']?.toString() ?? 'N/A',
            iconColorMap['Days']!,
            textColor),
      ]);
    } else if (type == 'meeting') {
      details.addAll([
        _buildDetailCard(
            Icons.room,
            'Room ID',
            _itemDetails!['room_id']?.toString() ?? 'N/A',
            iconColorMap['Room ID']!,
            textColor),
        _buildDetailCard(
            Icons.person,
            'Employee ID',
            _itemDetails!['employee_id']?.toString() ?? 'N/A',
            iconColorMap['Employee ID']!,
            textColor),
        _buildDetailCard(
            Icons.calendar_today,
            'From',
            _itemDetails!['from_date_time'] ?? 'N/A',
            iconColorMap['From']!,
            textColor),
        _buildDetailCard(
            Icons.calendar_today,
            'To',
            _itemDetails!['to_date_time'] ?? 'N/A',
            iconColorMap['To']!,
            textColor),
        _buildDetailCard(
            Icons.create,
            'Created Date',
            _itemDetails!['date_create'] ?? 'N/A',
            iconColorMap['Created Date']!,
            textColor),
      ]);
    }

    return details;
  }

  Widget _buildDetailCard(IconData icon, String label, String value, Color iconColor, Color textColor) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: textColor.withOpacity(0.6),
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: 18,
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
