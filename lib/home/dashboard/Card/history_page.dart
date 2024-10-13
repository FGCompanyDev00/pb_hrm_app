// history_page.dart

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

      final pendingResponse = await http.get(
        Uri.parse(pendingApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

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
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _formatItem(Map<String, dynamic> item) {
    String type = item['types'] ?? 'unknown';
    Map<String, dynamic> formattedItem = {
      'type': type,
      'status': item['status'] ?? 'pending',
      'statusColor': _getStatusColor(item['status']),
      'icon': _getIconForType(type),
      'iconColor': _getTypeColor(type),
      'timestamp':
      DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
      'img_name': item['img_name'] ?? 'https://via.placeholder.com/150',
    };

    if (type == 'meeting') {
      formattedItem.addAll({
        'title': item['title'] ?? 'No Title',
        'startDate': item['from_date_time'] ?? '',
        'endDate': item['to_date_time'] ?? '',
        'room': item['room_name'] ?? 'No Room Info',
        'employee_name': item['employee_name'] ?? 'N/A',
      });
    } else if (type == 'leave') {
      formattedItem.addAll({
        'title': item['name'] ?? 'No Title',
        'startDate': item['take_leave_from'] ?? '',
        'endDate': item['take_leave_to'] ?? '',
        'leave_type': item['leave_type'] ?? 'N/A',
        'employee_name': item['requestor_name'] ?? 'N/A',
      });
    } else if (type == 'car') {
      formattedItem.addAll({
        'title': item['purpose'] ?? 'No Title',
        'startDate': item['date_out'] ?? '',
        'endDate': item['date_in'] ?? '',
        'telephone': item['telephone'] ?? 'N/A',
        'employee_name': item['requestor_name'] ?? 'N/A',
      });
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

  Color _getTypeColor(String type) {
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

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
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
      body: Column(
        children: [
          _buildHeader(isDarkMode),
          const SizedBox(height: 10),
          _buildTabBar(),
          const SizedBox(height: 8),
          _isLoading
              ? const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
              : Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _isPendingSelected
                  ? _pendingItems.length
                  : _historyItems.length,
              itemBuilder: (context, index) {
                final item = _isPendingSelected
                    ? _pendingItems[index]
                    : _historyItems[index];
                return _buildHistoryCard(context, item);
              },
            ),
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
        padding:
        const EdgeInsets.only(top: 60.0, left: 16.0, right: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back,
                  color: isDarkMode ? Colors.white : Colors.black),
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
    final String type = item['type'] ?? 'unknown';

    String title = item['title'] ?? 'No Title';
    String status = item['status'] ?? 'Pending';
    String employeeName = item['employee_name'] ?? 'N/A';
    String employeeImage =
        item['img_name'] ?? 'https://via.placeholder.com/150';
    Color typeColor = _getTypeColor(type);
    Color statusColor = _getStatusColor(status);

    String startDate = item['startDate'] ?? '';
    String endDate = item['endDate'] ?? '';

    String detailLabel = '';
    String detailValue = '';

    if (type == 'meeting') {
      detailLabel = 'Room';
      detailValue = item['room'] ?? 'No Room Info';
    } else if (type == 'leave') {
      detailLabel = 'Type';
      detailValue = item['leave_type'] ?? 'N/A';
    } else if (type == 'car') {
      detailLabel = 'Telephone';
      detailValue = item['telephone'] ?? 'N/A';
    }

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
          side: BorderSide(color: typeColor, width: 2),
        ),
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 100,
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15.0),
                  bottomLeft: Radius.circular(15.0),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 12.0, horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          item['icon'],
                          color: typeColor,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          type[0].toUpperCase() + type.substring(1),
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From: ${formatDate(startDate)}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'To: ${formatDate(endDate)}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$detailLabel: $detailValue',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Status: ',
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius:
                            BorderRadius.circular(12.0),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 8.0),
              child: CircleAvatar(
                backgroundImage: NetworkImage(employeeImage),
                radius: 24,
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
    final String type = item['type'] ?? 'unknown';

    String title = item['title'] ?? 'N/A';
    String status = item['status'] ?? 'Unknown';
    String employeeName = item['employee_name'] ?? 'N/A';

    String detailLabel1 = '';
    String detailValue1 = '';
    String detailLabel2 = '';
    String detailValue2 = '';
    String detailLabel3 = '';
    String detailValue3 = '';
    String detailLabel4 = '';
    String detailValue4 = '';
    String detailLabel5 = '';
    String detailValue5 = '';

    if (type == 'meeting') {
      detailLabel1 = 'From';
      detailValue1 = item['from_date_time'] ?? 'N/A';
      detailLabel2 = 'To';
      detailValue2 = item['to_date_time'] ?? 'N/A';
      detailLabel3 = 'Room';
      detailValue3 = item['room'] ?? 'N/A';
      detailLabel4 = 'Employee';
      detailValue4 = employeeName;
      detailLabel5 = 'Details';
      detailValue5 = item['details'] ?? 'No Details';
    } else if (type == 'leave') {
      detailLabel1 = 'From';
      detailValue1 = item['take_leave_from'] ?? 'N/A';
      detailLabel2 = 'To';
      detailValue2 = item['take_leave_to'] ?? 'N/A';
      detailLabel3 = 'Type';
      detailValue3 = item['leave_type'] ?? 'N/A';
      detailLabel4 = 'Employee';
      detailValue4 = employeeName;
      detailLabel5 = 'Reason';
      detailValue5 = item['take_leave_reason'] ?? 'N/A';
    } else if (type == 'car') {
      detailLabel1 = 'From';
      detailValue1 = item['date_out'] ?? 'N/A';
      detailLabel2 = 'To';
      detailValue2 = item['date_in'] ?? 'N/A';
      detailLabel3 = 'Telephone';
      detailValue3 = item['telephone'] ?? 'N/A';
      detailLabel4 = 'Employee';
      detailValue4 = employeeName;
      detailLabel5 = 'Purpose';
      detailValue5 = item['purpose'] ?? 'N/A';
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90.0),
        child: AppBar(
          automaticallyImplyLeading: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          leading: Padding(
            padding: const EdgeInsets.only(top: 25.0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
          title: const Padding(
            padding: EdgeInsets.only(top: 34.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Spacer(flex: 2),
                Text(
                  'History Details',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                Spacer(flex: 4),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color:
                  isDarkMode ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 16.0),
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
                status,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            _buildInfoRow(
                Icons.calendar_today, detailLabel1, detailValue1, _getIconColor(status)),
            _buildInfoRow(
                Icons.calendar_today, detailLabel2, detailValue2, _getIconColor(status)),
            _buildInfoRow(
                Icons.info_outline, detailLabel3, detailValue3, _getIconColor(status)),
            _buildInfoRow(
                Icons.person, detailLabel4, detailValue4, _getIconColor(status)),
            _buildInfoRow(
                Icons.notes, detailLabel5, detailValue5, _getIconColor(status)),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$label: $value',
              style: const TextStyle(
                fontSize: 20,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
