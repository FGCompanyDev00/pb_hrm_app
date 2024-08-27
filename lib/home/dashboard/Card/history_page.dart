
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
    const String apiUrl = 'https://demo-application-api.flexiflows.co/api/app/users/history';

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        List<Map<String, dynamic>> pendingItems = [];
        List<Map<String, dynamic>> historyItems = [];

        for (var item in data['results']) {
          Map<String, dynamic> formattedItem = {
            'title': item['title'] ?? 'No Title',
            'date': 'From: ${item['from_date_time'] ?? "N/A"} To: ${item['to_date_time'] ?? "N/A"}',
            'room': item['room_name'] ?? 'No Room Info',
            'status': item['status'] ?? 'Unknown',
            'statusColor': _getStatusColor(item['status']),
            'icon': _getIconForType(item['types'], item['status']),
            'iconColor': _getStatusColor(item['status']),
            'details': item['remark'] ?? 'No Details Provided',
            'timestamp': DateTime.tryParse(item['from_date_time'] ?? '') ?? DateTime.now(),
            'img_name': item['img_name'] ?? 'https://via.placeholder.com/150',
            'types': item['types'] ?? 'Unknown'
          };

          if (item['status']?.toLowerCase() == 'pending') {
            pendingItems.add(formattedItem);
          } else {
            historyItems.add(formattedItem);
          }
        }

        setState(() {
          _pendingItems = pendingItems;
          _historyItems = historyItems;
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

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'disapproved':
      case 'rejected':
      case 'cancel':
        return Colors.red;
      case 'pending':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForType(String? type, String? status) {
    // Determine which door icon to show based on type and status
    if (status?.toLowerCase() == 'approved') {
      return Icons.door_back_door; // Green door for approved
    } else if (status?.toLowerCase() == 'rejected' || status?.toLowerCase() == 'disapproved') {
      return Icons.door_front_door; // Red door for rejected
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
              Container(
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
              ),
              const SizedBox(height: 10),
              Padding(
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
              ),
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

 Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> item) {
  final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
  final bool isDarkMode = themeNotifier.isDarkMode;

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
        side: BorderSide(color: item['iconColor'], width: 1.5), // Adjusted border width
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
                  item['icon'],
                  color: item['iconColor'],
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
                          color: item['statusColor'],
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

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.amber,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['title'] ?? 'N/A',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              item['date'] ?? 'N/A',
              style: TextStyle(
                fontSize: 18,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              item['room'] ?? 'No Room Info',
              style: TextStyle(
                fontSize: 18,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Status: ${item['status'] ?? "Unknown"}',
              style: TextStyle(
                fontSize: 18,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              item['details'] ?? 'No Details Provided',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
