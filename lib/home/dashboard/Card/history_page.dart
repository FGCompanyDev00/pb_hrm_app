import 'package:flutter/material.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pb_hrsystem/theme/theme.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _isPendingSelected = true;
  List<Map<String, dynamic>> _pendingItems = [];
  List<Map<String, dynamic>> _historyItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistoryData();
  }

  Future<void> _fetchHistoryData() async {
    const String pendingApiUrl = 'https://demo-application-api.flexiflows.co/api/app/users/history/pending';
    const String historyApiUrl = 'https://demo-application-api.flexiflows.co/api/app/users/history';

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('User not authenticated');
      }

      // Fetch pending items
      final pendingResponse = await http.get(
        Uri.parse(pendingApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Fetch history items
      final historyResponse = await http.get(
        Uri.parse(historyApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (pendingResponse.statusCode == 200 && historyResponse.statusCode == 200) {
        final List<dynamic> pendingData = jsonDecode(pendingResponse.body)['results'];
        final List<dynamic> historyData = jsonDecode(historyResponse.body)['results'];

        setState(() {
          _pendingItems = pendingData.map((item) => _formatPendingItem(item)).toList();
          _historyItems = historyData.map((item) => _formatHistoryItem(item)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      print('Error fetching history data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _formatPendingItem(Map<String, dynamic> item) {
    return {
      'title': item['name'] ?? 'No Title',
      'date': item['take_leave_from'] ?? "N/A",
      'room': 'Leave Type',
      'status': item['status'] ?? 'Unknown',
      'statusColor': _getStatusColor(item['status']),
      'icon': _getIconForType(item['types'], item['status']),
      'iconColor': _getStatusColor(item['status']),
      'details': item['take_leave_reason'] ?? 'No Details Provided',
      'timestamp': DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
      'img_name': item['img_name'] ?? 'https://via.placeholder.com/150',
      'types': item['types'] ?? 'Unknown',
    };
  }

  Map<String, dynamic> _formatHistoryItem(Map<String, dynamic> item) {
    return {
      'title': item['name'] ?? 'No Title',
      'date': item['take_leave_from'] ?? "N/A",
      'room': 'Leave Type',
      'status': item['status'] ?? 'Unknown',
      'statusColor': _getStatusColor(item['status']),
      'icon': _getIconForType(item['types'], item['status']),
      'iconColor': _getStatusColor(item['status']),
      'details': item['take_leave_reason'] ?? 'No Details Provided',
      'timestamp': DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
      'img_name': item['img_name'] ?? 'https://via.placeholder.com/150',
      'types': item['types'] ?? 'Unknown',
    };
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'disapproved':
      case 'rejected':
      case 'cancel':
        return Colors.red;
      case 'pending':
      case 'waiting':
        return Colors.amber;
      case 'processing':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForType(String? type, String? status) {
    if (status?.toLowerCase() == 'approved') {
      return Icons.check_circle; // Approved icon
    } else if (status?.toLowerCase() == 'rejected' || status?.toLowerCase() == 'disapproved') {
      return Icons.cancel; // Rejected icon
    } else {
      // Default icon based on type
      switch (type?.toLowerCase()) {
        case 'meeting':
          return Icons.meeting_room;
        case 'leave':
          return Icons.event;
        default:
          return Icons.info;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(isDarkMode),
              const SizedBox(height: 10),
              _buildTabBar(),
              const SizedBox(height: 8),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: _isPendingSelected
                      ? _pendingItems.map((item) => _buildHistoryCard(context, item)).toList()
                      : _historyItems.map((item) => _buildHistoryCard(context, item)).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png',
          ),
          fit: BoxFit.cover,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 40.0, left: 16.0, right: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MainScreen()),
                );
              },
            ),
            Text(
              'My History',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isPendingSelected = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  color: _isPendingSelected ? Colors.amber : Colors.grey[300], // Selected tab color
                  borderRadius: BorderRadius.circular(15.0), // Rounded corner
                ),
                child: Center(
                  child: Text(
                    'Pending',
                    style: TextStyle(
                      color: _isPendingSelected ? Colors.black : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isPendingSelected = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  color: _isPendingSelected ? Colors.grey[300] : Colors.amber, // Selected tab color
                  borderRadius: BorderRadius.circular(15.0), // Rounded corner
                ),
                child: Center(
                  child: Text(
                    'History',
                    style: TextStyle(
                      color: _isPendingSelected ? Colors.black : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> item) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;

    final Color iconColor = _getStatusColor(item['status']); // Ensure icon color is non-null

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsPage(item: item),
          ),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
          side: BorderSide(color: iconColor, width: 1.5), // Use non-null color here
        ),
        elevation: 6, // Slightly increased elevation for better shadow
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(
                    item['icon'] ?? Icons.info, // Ensure non-null icon
                    color: iconColor,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['types'] ?? 'N/A',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] ?? 'N/A',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['date'] ?? 'N/A',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['room'] ?? 'No Room Info',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Status: ',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: iconColor,
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Text(
                            item['status'] ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                backgroundImage: NetworkImage(item['img_name'] ?? 'https://via.placeholder.com/150'),
                radius: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DetailsPage extends StatelessWidget {
  final Map<String, dynamic> item;

  const DetailsPage({super.key, required this.item});

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
    final statusColor = _getStatusColor(item['status']);
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title
            Text(
              item['title'] ?? 'N/A',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32), // Increased spacing for better layout

            // Status Highlight
            Container(
              width: double.infinity, // Full width of the screen
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              decoration: BoxDecoration(
                color: statusColor,  // Full color for status box
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),  // External shadow
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
               item['status'] ?? "Unknown",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,  // Text color based on theme
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // Date Section
            _buildDateSection(item, isDarkMode),

            // Room Info (only for History items)
            if (item['types'] == 'meeting')
              _buildInfoRow(Icons.room, 'Room', item['room'] ?? 'No Room Info', isDarkMode, iconColor: Colors.red),

            // Additional Details
            const Spacer(), // Pushes details towards the bottom

            Text(
              'Details:',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity, // Full width of the screen
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.black.withOpacity(0.1) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                item['details'] ?? 'No Details Provided',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.green,  // Details content in green
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(), // Pushes details towards the bottom
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection(Map<String, dynamic> item, bool isDarkMode) {
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, color: Colors.blue, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Start Date:',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item['date']?.split(' To: ')?.first ?? 'N/A',
                style: TextStyle(
                  fontSize: 20,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, color: Colors.blue, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'End Date:',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item['date']?.split(' To: ')?.last ?? 'N/A',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.red,  // End date in red
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDarkMode, {Color iconColor = Colors.black54}) {
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              '$label: $value',
              style: TextStyle(
                fontSize: 20,
                color: textColor,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}


