import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
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
      height: 120,
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
        padding: const EdgeInsets.only(top: 40.0,left: 16.0, right: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const Dashboard()),
                      (Route<dynamic> route) => false,
                );
              },
            ),
            Text(
              'My History',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 22,
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
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
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
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    bottomLeft: Radius.circular(20.0),
                  ), // Rounded corner for left side
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hourglass_empty_rounded, size: 24, color: _isPendingSelected ? Colors.white : Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Pending',
                      style: TextStyle(
                        color: _isPendingSelected ? Colors.white : Colors.grey[600], // Text color changes based on selection
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 1),
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
                  color: !_isPendingSelected ? Colors.amber : Colors.grey[300], // Selected tab color
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20.0),
                    bottomRight: Radius.circular(20.0),
                  ), // Rounded corner for right side
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_rounded, size: 24, color: !_isPendingSelected ? Colors.white : Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'History',
                      style: TextStyle(
                        color: !_isPendingSelected ? Colors.white : Colors.grey[600], // Text color changes based on selection
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
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

    // Dynamic icon based on the 'types' field
    Widget _getIconForType(String type) {
      switch (type) {
        case 'meeting':
          return Image.asset('assets/calendar.png', width: 40, height: 40);
        case 'leave':
          return Image.asset('assets/leave_calendar.png', width: 40, height: 40);
        case 'car':
          return Image.asset('assets/car.png', width: 40, height: 40);
        default:
          return const Icon(Icons.info_outline, size: 40, color: Colors.grey);
      }
    }

    // Safe date formatting method
    String _formatDate(String? dateStr) {
      try {
        if (dateStr == null || dateStr.isEmpty) {
          return 'N/A'; // Return a default if the date is invalid
        }
        final DateTime parsedDate = DateTime.parse(dateStr);
        return DateFormat('dd-MM-yyyy, HH:mm').format(parsedDate);
      } catch (e) {
        return 'Invalid Date'; // Handle any errors that arise from parsing
      }
    }

    // Color for the status
    Color _getStatusColor(String status) {
      switch (status.toLowerCase()) {
        case 'approved':
          return Colors.green;
        case 'rejected':
        case 'disapproved':
          return Colors.red;
        case 'pending':
        case 'waiting':
          return Colors.amber;
        default:
          return Colors.grey;
      }
    }

    // Color for the left vertical line based on 'types'
    Color _getTypeColor(String type) {
      switch (type.toLowerCase()) {
        case 'meeting':
          return Colors.green; // Green for meeting
        case 'leave':
          return Colors.orange; // Orange for leave
        case 'car':
          return Colors.blue; // Blue for car
        default:
          return Colors.grey; // Grey for unknown types
      }
    }

    final String title = item['title'] ?? 'No Title';
    final String fromDateTime = item['from_date_time'] ?? '';
    final String toDateTime = item['to_date_time'] ?? '';
    final String room = item['room_name'] ?? 'No Room Info';
    final String roomFloor = item['room_floor'] ?? '';
    final String status = item['status'] ?? 'Pending';
    final String employeeName = item['employee_name'] ?? 'N/A';
    final String employeeImage = item['img_name'] ?? 'https://via.placeholder.com/150';
    final String type = item['types'] ?? 'Unknown';

    final Color statusColor = _getStatusColor(status); // Status color for the status label
    final Color typeColor = _getTypeColor(type); // Color for the left vertical line

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
          side: BorderSide(color: statusColor, width: 1.5), // Border color based on status
        ),
        elevation: 6,
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            // Left vertical colored line based on type
            Container(
              width: 5, // Thickness of the line
              height: 130, // Adjust height as per card height
              decoration: BoxDecoration(
                color: typeColor, // Color based on the type
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15.0),
                  bottomLeft: Radius.circular(15.0),
                ),
              ),
            ),
            const SizedBox(width: 8), // Space between the line and the card content
            // Card content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center, // Centering icon and profile image vertically
                  children: [
                    // Left section for icon
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center, // Center icon vertically
                      children: [
                        _getIconForType(type), // Display the appropriate icon
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Center section for details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Date range
                          Text(
                            'Date: ${_formatDate(fromDateTime)} To ${_formatDate(toDateTime)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Room information
                          Text(
                            'Room: $room $roomFloor',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Status row
                          Row(
                            children: [
                              const Text(
                                'Status: ',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                decoration: BoxDecoration(
                                  color: statusColor, // Background color based on status
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Text(
                                  status,
                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right section for employee image
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center, // Center image vertically
                      children: [
                        CircleAvatar(
                          backgroundImage: NetworkImage(employeeImage),
                          radius: 30,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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


