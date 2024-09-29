import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/management/admin_approvals_view_page.dart';
import 'package:pb_hrsystem/management/admin_history_view_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../home/dashboard/dashboard.dart';

class ManagementApprovalsPage extends StatefulWidget {
  const ManagementApprovalsPage({super.key});

  @override
  _ManagementApprovalsPageState createState() =>
      _ManagementApprovalsPageState();
}

class _ManagementApprovalsPageState extends State<ManagementApprovalsPage> {
  bool _isApprovalSelected = true;
  List<Map<String, dynamic>> approvalItems = [];
  List<Map<String, dynamic>> historyItems = [];
  bool isLoading = true;
  String? token;

  @override
  void initState() {
    super.initState();
    fetchTokenAndData();
  }

  Future<void> fetchTokenAndData() async {
    await retrieveToken();
    if (token != null) {
      fetchData();
    }
  }

  Future<void> retrieveToken() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      token = prefs.getString('token');
    } catch (e) {
      print('Error retrieving token: $e');
    }
  }

  Future<void> fetchData() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';

    try {
      // Fetch Approvals data
      final approvalResponse = await http.get(
        Uri.parse('$baseUrl/api/app/tasks/approvals/pending'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (approvalResponse.statusCode == 200) {
        final dynamic approvalData = json.decode(approvalResponse.body);

        if (approvalData is Map<String, dynamic> &&
            approvalData.containsKey('results')) {
          final List<dynamic> results = approvalData['results'];
          approvalItems = results
              .whereType<Map<String, dynamic>>()
              .where((item) => item['status'] == 'Waiting')
              .map((item) => _formatItem(item))
              .toList();
        }
      }

      // Fetch History data
      final historyResponse = await http.get(
        Uri.parse('$baseUrl/api/app/tasks/approvals/history'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (historyResponse.statusCode == 200) {
        final dynamic historyData = json.decode(historyResponse.body);

        if (historyData is Map<String, dynamic> &&
            historyData.containsKey('results')) {
          final List<dynamic> results = historyData['results'];
          historyItems = results
              .whereType<Map<String, dynamic>>()
              .where((item) =>
          item['status'] == 'Approved' ||
              item['status'] == 'Rejected')
              .map((item) => _formatItem(item))
              .toList();
        }
      }
    } catch (e) {
      print('Error fetching data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Map<String, dynamic> _formatItem(Map<String, dynamic> item) {
    String types = item['types'] ?? 'Unknown';

    Map<String, dynamic> formattedItem = {
      'types': types,
      'status': item['status'] ?? 'Unknown',
      'statusColor': _getStatusColor(item['status']),
      'icon': _getStatusIcon(item['status']),
      'iconColor': _getStatusColor(item['status']),
      'img_name': item['img_name'] ?? 'https://via.placeholder.com/150',
    };

    if (types == 'meeting') {
      formattedItem['title'] = item['title'] ?? 'No Title';
      formattedItem['startDate'] = item['from_date_time'] ?? 'N/A';
      formattedItem['endDate'] = item['to_date_time'] ?? 'N/A';
      formattedItem['room'] = item['room_name'] ?? 'No Room Info';
      formattedItem['details'] = item['remark'] ?? 'No Details Provided';
      formattedItem['employee_name'] = item['employee_name'] ?? 'N/A';
    } else if (types == 'leave') {
      formattedItem['title'] = item['take_leave_name'] ?? 'No Title';

      formattedItem['startDate'] = (item['take_leave_from'] != null && item['take_leave_from'].isNotEmpty)
          ? item['take_leave_from']
          : 'N/A';

      formattedItem['endDate'] = (item['take_leave_to'] != null && item['take_leave_to'].isNotEmpty)
          ? item['take_leave_to']
          : 'N/A';

      formattedItem['room'] =  item['room_name'] ?? 'No Place Info';
      formattedItem['details'] = item['take_leave_reason'] ?? 'No Details Provided';
      formattedItem['employee_name'] = item['requestor_name'] ?? 'N/A';
    }
    else if (types == 'car') {
      formattedItem['title'] = item['purpose'] ?? 'No Title';

      formattedItem['startDate'] = (item['date_in'] != null && item['date_in'].isNotEmpty)
          ? item['date_in']
          : 'N/A';

      formattedItem['time'] = (item['time_in'] != null && item['time_in'].isNotEmpty)
          ? item['time_in']
          : 'N/A';
      
      
      formattedItem['time_end'] = (item['time_out'] != null && item['time_out'].isNotEmpty)
          ? item['time_out']
          : 'N/A';
     
      formattedItem['endDate'] = (item['date_out'] != null && item['date_out'].isNotEmpty)
          ? item['date_in']
          : 'N/A';

      formattedItem['room'] = item['place'] ?? 'No Place Info';
      formattedItem['details'] = item['purpose'] ?? 'No Details Provided';
      formattedItem['employee_name'] = item['requestor_name'] ?? 'N/A';
     
    }
    else {
      // Default processing
      formattedItem['title'] = 'Unknown Type';
    }
    return formattedItem;
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'waiting':
      case 'branch waiting':
      case 'pending':
        return Colors.amber;
      case 'approved':
        return Colors.green;
      case 'rejected':
      case 'disapproved':
      case 'cancel':
        return Colors.red;
      case 'processing':
        return Colors.blue;
      case 'unknown':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'waiting':
      case 'branch waiting':
      case 'pending':
        return Icons.hourglass_empty;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
      case 'disapproved':
      case 'cancel':
        return Icons.cancel;
      case 'processing':
        return Icons.timelapse;
      case 'unknown':
        return Icons.help_outline;
      default:
        return Icons.info;
    }
  }

  Widget getIconForType(String type) {
    switch (type.toLowerCase()) {
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

  void _openApprovalDetail(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminApprovalsViewPage(item: item),
      ),
    );
  }

  void _openHistoryDetail(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminHistoryViewPage(item: item),
      ),
    );
  }

String formatDate(String? dateStr) {
  try {
    if (dateStr == null || dateStr.isEmpty) {
      return 'N/A';
    }

    // Split the date string by "-"
    List<String> parts = dateStr.split('-');
    if (parts.length == 3) {
      // Pad the month and day with a leading zero if needed
      String year = parts[0];
      String month = parts[1].padLeft(2, '0'); // Ensure month has 2 digits
      String day = parts[2].padLeft(2, '0');   // Ensure day has 2 digits

      // Rebuild the date string in the format YYYY-MM-DD
      String formattedDateStr = '$year-$month-$day';

      // Parse and format the date
      final DateTime parsedDate = DateTime.parse(formattedDateStr);
      return DateFormat('dd-MM-yyyy, HH:mm').format(parsedDate);
    } else {
      return 'Invalid Date';
    }
  } catch (e) {
    return 'Invalid Date';
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: fetchData,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.15,
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('assets/ready_bg.png'),
                  fit: BoxFit.cover,
                ),
                color: Colors.amber[700],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 80,
                    left: 10,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          size: 30, color: Colors.black),
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const Dashboard()),
                              (Route<dynamic> route) => false,
                        );
                      },
                    ),
                  ),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 65.0),
                      child: Text(
                        'Approvals ',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // TabBar Section for Approval and History tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isApprovalSelected = true;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        decoration: BoxDecoration(
                          color: _isApprovalSelected
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
                            Icon(Icons.grid_view_rounded,
                                size: 24,
                                color: _isApprovalSelected
                                    ? Colors.white
                                    : Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Approval',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isApprovalSelected
                                    ? Colors.white
                                    : Colors.grey[600],
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
                          _isApprovalSelected = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        decoration: BoxDecoration(
                          color: !_isApprovalSelected
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
                                color: !_isApprovalSelected
                                    ? Colors.white
                                    : Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'History',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: !_isApprovalSelected
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            // ListView section for displaying approval items
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                padding: const EdgeInsets.all(16.0),
                children: _isApprovalSelected
                    ? approvalItems
                    .map((item) => _buildCard(item))
                    .toList()
                    : historyItems
                    .map((item) => _buildCard(item))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final String types = item['types'] ?? 'Unknown';

    String title = item['title'] ?? 'No Title';
    String startDate = item['startDate'] ?? 'N/A';
    String endDate = item['endDate'] ?? 'N/A';
    String room = item['room'] ?? 'No Info';
    String status = item['status'] ?? 'Pending';
    String employeeName = item['employee_name'] ?? 'N/A';
    String employeeImage =
        item['img_name'] ?? 'https://via.placeholder.com/150';

    Color statusColor = _getStatusColor(status);
    Color typeColor = getTypeColor(types);
 print('title: $title');
    print('Start Date: $startDate');
  print('End Date: $endDate');
  print('room: $room');

    return GestureDetector(
      onTap: () {
        if (_isApprovalSelected) {
          _openApprovalDetail(item);
        } else {
          _openHistoryDetail(item);
        }
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left section for icon
                    getIconForType(types),
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
                            'Date: ${formatDate(startDate)} To ${formatDate(endDate)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Room or Place
                          Text(
                            'Room: $room',
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 4.0),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Text(
                                  status,
                                  style: const TextStyle(
                                      color: Colors.black,
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
                    CircleAvatar(
                      backgroundImage: NetworkImage(employeeImage),
                      radius: 30,
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
