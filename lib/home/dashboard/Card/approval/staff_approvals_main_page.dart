// staff_approvals_main_page.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approval/staff_request_approvals_result.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approval/staff_approvals_view_page.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:intl/intl.dart';

class StaffApprovalsPage extends StatefulWidget {
  const StaffApprovalsPage({super.key});

  @override
  _StaffApprovalsPageState createState() => _StaffApprovalsPageState();
}

class _StaffApprovalsPageState extends State<StaffApprovalsPage> {
  bool _isApprovalSelected = true;
  List<Map<String, dynamic>> _approvalItems = [];
  List<Map<String, dynamic>> _historyItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchApprovalsData();
  }

  Future<void> _fetchApprovalsData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final approvalResponse = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/app/tasks/approvals/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final historyResponse = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/app/tasks/approvals/history'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (approvalResponse.statusCode == 200 && historyResponse.statusCode == 200) {
        final List<dynamic> approvalResults = json.decode(approvalResponse.body)['results'];
        final List<dynamic> historyResults = json.decode(historyResponse.body)['results'];

        setState(() {
          _approvalItems = approvalResults.map((item) => _formatItem(item)).toList();
          _historyItems = historyResults.map((item) => _formatItem(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
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
      'typeColor': _getTypeColor(type),
      'timestamp': DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
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
      case 'rejected':
      case 'reject':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.amber;
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

  String _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'leave':
        return 'assets/leave_calendar.png';
      case 'car':
        return 'assets/car.png';
      case 'meeting':
        return 'assets/calendar.png';
      default:
        return 'assets/default_icon.png';
    }
  }

  void _showApprovalDetail(BuildContext context, Map<String, dynamic> item) {
    if (_isApprovalSelected) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ApprovalsViewPage(item: item),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FinishStaffApprovalsPage(item: item),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      body: Column(
        children: [
          Container(
            height: size.height * 0.15,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
                fit: BoxFit.cover,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(top: size.height * 0.05, left: 16.0, right: 16.0),
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
                    'Approvals',
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
                        _isApprovalSelected = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      decoration: BoxDecoration(
                        color: _isApprovalSelected ? Colors.amber : Colors.grey[300],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20.0),
                          bottomLeft: Radius.circular(20.0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.approval_rounded, size: 24, color: _isApprovalSelected ? Colors.white : Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Approval',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isApprovalSelected ? Colors.white : Colors.grey[600],
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
                        _isApprovalSelected = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      decoration: BoxDecoration(
                        color: !_isApprovalSelected ? Colors.amber : Colors.grey[300],
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(20.0),
                          bottomRight: Radius.circular(20.0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded, size: 24, color: !_isApprovalSelected ? Colors.white : Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'History',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: !_isApprovalSelected ? Colors.white : Colors.grey[600],
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
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _fetchApprovalsData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _isApprovalSelected ? _approvalItems.length : _historyItems.length,
                itemBuilder: (context, index) {
                  final item = _isApprovalSelected ? _approvalItems[index] : _historyItems[index];
                  return _buildApprovalCard(context, item, isDarkMode);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalCard(BuildContext context, Map<String, dynamic> item, bool isDarkMode) {
    String type = item['type'] ?? 'unknown';
    String title = item['title'] ?? 'No Title';
    String status = item['status'] ?? 'Pending';
    String employeeName = item['employee_name'] ?? 'N/A';
    String employeeImage = item['img_name'] ?? 'https://via.placeholder.com/150';
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
      onTap: () => _showApprovalDetail(context, item),
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
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          item['icon'],
                          width: 24,
                          height: 24,
                          color: typeColor,
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
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
