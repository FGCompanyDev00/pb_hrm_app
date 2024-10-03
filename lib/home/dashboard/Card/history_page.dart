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
    const String pendingApiUrl =
        'https://demo-application-api.flexiflows.co/api/app/users/history/pending';
    const String historyApiUrl =
        'https://demo-application-api.flexiflows.co/api/app/users/history';

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

      if (pendingResponse.statusCode == 200 &&
          historyResponse.statusCode == 200) {
        final List<dynamic> pendingData =
        jsonDecode(pendingResponse.body)['results'];
        final List<dynamic> historyData =
        jsonDecode(historyResponse.body)['results'];

        setState(() {
          _pendingItems =
              pendingData.map((item) => _formatItem(item)).toList();
          _historyItems =
              historyData.map((item) => _formatItem(item)).toList();
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

  Map<String, dynamic> _formatItem(Map<String, dynamic> item) {
    String types = item['types'] ?? 'Unknown';

    Map<String, dynamic> formattedItem = {
      'types': types,
      'status': item['status'] ?? 'Unknown',
      'statusColor': _getStatusColor(item['status']),
      'icon': _getIconForType(types, item['status']),
      'iconColor': _getStatusColor(item['status']),
      'timestamp':
      DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
      'img_name': item['img_name'] ?? 'https://via.placeholder.com/150',
    };

    if (types == 'meeting') {
      formattedItem['title'] = item['title'] ?? 'No Title';
      formattedItem['startDate'] = item['from_date_time'] ?? 'N/A';
      formattedItem['endDate'] = item['to_date_time'] ?? 'N/A';
      formattedItem['room'] = item['room_name'] ?? 'No Room Info';
      formattedItem['details'] = item['remark'] ?? 'No Details Provided';
      formattedItem['employee_name'] = item['employee_name'] ?? 'N/A';
      formattedItem['from_date_time'] = item['from_date_time'] ?? '';
      formattedItem['to_date_time'] = item['to_date_time'] ?? '';
      formattedItem['room_floor'] = item['room_floor'] ?? '';
    } else if (types == 'leave') {
      formattedItem['title'] = item['name'] ?? 'No Title';
      formattedItem['startDate'] = item['take_leave_from'] ?? 'N/A';
      formattedItem['endDate'] = item['take_leave_to'] ?? 'N/A';
      formattedItem['room'] = 'Leave Type';
      formattedItem['details'] =
          item['take_leave_reason'] ?? 'No Details Provided';
      formattedItem['employee_name'] = item['requestor_name'] ?? 'N/A';
      formattedItem['take_leave_from'] = item['take_leave_from'] ?? '';
      formattedItem['take_leave_to'] = item['take_leave_to'] ?? '';
    } else if (types == 'car') {
      formattedItem['title'] = item['purpose'] ?? 'No Title';
      formattedItem['startDate'] = item['date_out'] ?? 'N/A';
      formattedItem['endDate'] = item['date_in'] ?? 'N/A';
      formattedItem['room'] = item['place'] ?? 'No Place Info';
      formattedItem['details'] = item['purpose'] ?? 'No Details Provided';
      formattedItem['employee_name'] = item['requestor_name'] ?? 'N/A';
      formattedItem['date_out'] = item['date_out'] ?? '';
      formattedItem['date_in'] = item['date_in'] ?? '';
      formattedItem['time_out'] = item['time_out'] ?? '';
      formattedItem['time_in'] = item['time_in'] ?? '';
      formattedItem['place'] = item['place'] ?? '';
    } else {
      // Default processing
      formattedItem['title'] = 'Unknown Type';
    }

    return formattedItem;
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
    switch (type?.toLowerCase()) {
      case 'meeting':
        return Icons.meeting_room;
      case 'leave':
        return Icons.event;
      case 'car':
        return Icons.directions_car;
      default:
        return Icons.info;
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
                      ? _pendingItems
                      .map((item) => _buildHistoryCard(context, item))
                      .toList()
                      : _historyItems
                      .map((item) => _buildHistoryCard(context, item))
                      .toList(),
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
      height: 140,
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
        padding: const EdgeInsets.only(
            top: 60.0, left: 16.0, right: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back,
                  color: isDarkMode ? Colors.white : Colors.black),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const Dashboard()),
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
      padding:
      const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
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
                  color: _isPendingSelected
                      ? Colors.amber
                      : Colors.grey[300],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    bottomLeft: Radius.circular(20.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hourglass_empty_rounded,
                        size: 24,
                        color: _isPendingSelected
                            ? Colors.white
                            : Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Pending',
                      style: TextStyle(
                        color: _isPendingSelected
                            ? Colors.white
                            : Colors.grey[600],
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
                  color: !_isPendingSelected
                      ? Colors.amber
                      : Colors.grey[300],
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20.0),
                    bottomRight: Radius.circular(20.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_rounded,
                        size: 24,
                        color: !_isPendingSelected
                            ? Colors.white
                            : Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'History',
                      style: TextStyle(
                        color: !_isPendingSelected
                            ? Colors.white
                            : Colors.grey[600],
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

  Widget _buildHistoryCard(
      BuildContext context, Map<String, dynamic> item) {
    final themeNotifier =
    Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final String types = item['types'] ?? 'Unknown';

    // Dynamic icon based on the 'types' field
    Widget getIconForType(String type) {
      switch (type) {
        case 'meeting':
          return Image.asset('assets/calendar.png',
              width: 40, height: 40);
        case 'leave':
          return Image.asset('assets/leave_calendar.png',
              width: 40, height: 40);
        case 'car':
          return Image.asset('assets/car.png',
              width: 40, height: 40);
        default:
          return const Icon(Icons.info_outline,
              size: 40, color: Colors.grey);
      }
    }

Widget getTypeText(String type) {
  switch (type) {
    case 'meeting':
      return const Text(
        'Room',
        style: TextStyle(color: Colors.green), // Green color for meeting/room
      );
    case 'leave':
      return const Text(
        'Leave',
        style: TextStyle(color: Colors.yellow), // Yellow color for leave
      );
    case 'car':
      return const Text(
        'Car',
        style: TextStyle(color: Colors.blue), // Blue color for car
      );
    default:
      return const Icon(Icons.info_outline,
          size: 40, color: Colors.grey); // Default case for unknown types
  }
}

    // Safe date formatting method
    String formatDate(String? dateStr) {
      try {
        if (dateStr == null || dateStr.isEmpty) {
          return 'N/A';
        }
        final DateTime parsedDate = DateTime.parse(dateStr);
        return DateFormat('dd-MM-yyyy, HH:mm').format(parsedDate);
      } catch (e) {
        return 'Invalid Date';
      }
    }

    // Color for the status
    Color getStatusColor(String status) {
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
    Color getTypeColor(String type) {
      switch (type.toLowerCase()) {
        case 'meeting':
          return Colors.green;
        case 'leave':
          return Colors.orange;
        case 'car':
          return Colors.blue;
        default:
          return Colors.grey;
      }
    }

    

    final String title = item['title'] ?? 'No Title';
    final String status = item['status'] ?? 'Pending';
    final String employeeName = item['employee_name'] ?? 'N/A';
    final String employeeImage =
        item['img_name'] ?? 'https://via.placeholder.com/150';

    final Color statusColor = getStatusColor(status);
    final Color typeColor = getTypeColor(types);

    String startDate = '';
    String endDate = '';
    String room = '';

    if (types == 'meeting') {
      startDate = item['from_date_time'] ?? '';
      endDate = item['to_date_time'] ?? '';
      room = item['room_name'] ?? 'No Room Info';
    } else if (types == 'leave') {
      startDate = item['take_leave_from'] ?? '';
      endDate = item['take_leave_to'] ?? '';
      room = 'Leave Type';
    } else if (types == 'car') {
      startDate = item['date_out'] ?? '';
      endDate = item['date_in'] ?? '';
      room = item['place'] ?? 'No Place Info';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => DetailsPage(item: item)),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
          side: BorderSide(color: statusColor, width: 1.5),
        ),
        elevation: 6,
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            // Left vertical colored line
            Container(
              width: 5,
              height: 130,
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15.0),
                  bottomLeft: Radius.circular(15.0),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Card content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.center,
                  children: [
                    // Left section for icon
                    Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        getIconForType(types),
                        getTypeText(types),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Center section for details
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
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
                            'Date: ${formatDate(startDate)} To ${formatDate(endDate)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Room or Place
                          Text(
                            'Info: $room',
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
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 4.0),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius:
                                  BorderRadius.circular(12.0),
                                ),
                                child: Text(
                                  status,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
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
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundImage:
                          NetworkImage(employeeImage),
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

  Color _getIconColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'disapproved':
      case 'rejected':
      case 'cancel':
        return Colors.redAccent;
      case 'waiting':
      case 'pending':
        return Colors.orangeAccent;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final statusColor = _getStatusColor(item['status']);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final String types = item['types'] ?? 'Unknown';

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
                    SizedBox(height: 85),
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
              top: 75,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Center(
              child: Text(
                item['title'] ?? 'N/A',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
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
                    color: Colors.black.withOpacity(0.2),
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
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // Conditionally display details based on 'types'
            if (types == 'meeting') ...[
              _buildInfoRow(Icons.title, 'Title', item['title'] ?? 'N/A', _getIconColor(item['status'])),
              _buildInfoRow(Icons.calendar_today, 'From', item['from_date_time'] ?? 'N/A', _getIconColor(item['status'])),
              _buildInfoRow(Icons.calendar_today, 'To', item['to_date_time'] ?? 'N/A', _getIconColor(item['status'])),
              _buildInfoRow(Icons.room, 'Room', item['room_name'] ?? 'N/A', _getIconColor(item['status'])),
              _buildInfoRow(Icons.person, 'Employee', item['employee_name'] ?? 'N/A', _getIconColor(item['status'])),
              _buildInfoRow(Icons.notes, 'Details', item['details'] ?? 'No Details', _getIconColor(item['status'])),
            ] else if (types == 'leave') ...[
              _buildInfoRow(Icons.title, 'Leave Type', item['title'] ?? 'N/A', _getIconColor(item['status'])),
              _buildInfoRow(Icons.calendar_today, 'From', item['take_leave_from'] ?? 'N/A', _getIconColor(item['status'])),
              _buildInfoRow(Icons.calendar_today, 'To', item['take_leave_to'] ?? 'N/A', _getIconColor(item['status'])),
              _buildInfoRow(Icons.person, 'Employee', item['requestor_name'] ?? 'N/A', _getIconColor(item['status'])),
              _buildInfoRow(Icons.notes, 'Reason', item['take_leave_reason'] ?? 'N/A', _getIconColor(item['status'])),
            ] else if (types == 'car') ...[
              _buildInfoRow(Icons.title, 'Purpose', item['title'] ?? 'N/A', _getIconColor(item['status'])),
              _buildInfoRow(Icons.calendar_today, 'Date Out', item['date_out'] ?? 'N/A', _getIconColor(item['status'])),
              _buildInfoRow(Icons.calendar_today, 'Date In', item['date_in'] ?? 'N/A', _getIconColor(item['status'])),
              _buildInfoRow(Icons.access_time, 'Time Out', item['time_out'] ?? 'N/A', _getIconColor(item['status'])),
              _buildInfoRow(Icons.access_time, 'Time In', item['time_in'] ?? 'N/A', _getIconColor(item['status'])),
              _buildInfoRow(Icons.place, 'Place', item['place'] ?? 'N/A', _getIconColor(item['status'])),
              _buildInfoRow(Icons.person, 'Requestor', item['requestor_name'] ?? 'N/A', _getIconColor(item['status'])),
            ] else ...[
              // Default details
              Center(
                child: Text(
                  'No additional details available.',
                  style: TextStyle(
                    fontSize: 18,
                    color: textColor,
                  ),
                ),
              ),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }

  // Build the info row with custom icon color and improved design
  Widget _buildInfoRow(IconData icon, String title, String content, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 24, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$title: $content',
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

  Widget _buildInfoRow(IconData icon, String label, String value,
      bool isDarkMode,
      {Color iconColor = Colors.black54}) {
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$label: $value',
              style: TextStyle(
                fontSize: 20,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
