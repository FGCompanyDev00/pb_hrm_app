import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approval/staff_approvals_view_page.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'finish_staff_approvals_page.dart';

class StaffApprovalsPage extends StatefulWidget {
  const StaffApprovalsPage({super.key});

  @override
  _StaffApprovalsPageState createState() => _StaffApprovalsPageState();
}

class _StaffApprovalsPageState extends State<StaffApprovalsPage> {
  bool _isApprovalSelected = true;
  List<Map<String, dynamic>> _approvalItems = [];
  final List<Map<String, dynamic>> _historyItems = [];

  @override
  void initState() {
    super.initState();
    _fetchApprovalsData();

    // Example data for the history section
    _historyItems.add({
      'name': 'Ms. Zhao Lusi (Test Data)',
      'is_approve': 'Rejected',
      'take_leave_from': '2024-05-14',
      'take_leave_to': '2024-05-14',
      'days': 1,
      'take_leave_reason': 'Marketing meeting',
      'submission_date': '2024-02-26 11:30:00',
      'time_from': '09:00 AM',
      'time_to': '12:00 PM',
      'discretion': '020 7866511',
      'description': 'Tel 0207865511 Marketing create new product For App',
      'rejection_date': '2024-05-14 09:00:11',
      'img_name': '',
      'approver_image': '',
      'supervisor_image': '',
    });
  }

  Future<void> _fetchApprovalsData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (kDebugMode) {
        print('Token is null');
      }
      return;
    } else {
      if (kDebugMode) {
        print('Token is available: $token');
      }
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
          _approvalItems = List<Map<String, dynamic>>.from(approvalResults);
          _historyItems.addAll(List<Map<String, dynamic>>.from(historyResults));
        });
      } else {
        if (kDebugMode) {
          print('Failed to load data: Approvals - ${approvalResponse.statusCode}, History - ${historyResponse.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Waiting':
        return Colors.amber;
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  void _showApprovalDetail(BuildContext context, Map<String, dynamic> item) {
    if (_isApprovalSelected) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ApprovalsViewPage(item: item), // Navigate to staff_approvals_view_page.dart
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FinishStaffApprovalsPage(item: item), // Navigate to finish_staff_approvals_page.dart
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
            height: size.height * 0.13,
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
              padding: EdgeInsets.only(top: size.height * 0.05, left: 16.0, right: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const Dashboard()),
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
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      child: Center(
                        child: Text(
                          'Approval',
                          style: TextStyle(
                            color: _isApprovalSelected ? Colors.black : Colors.black,
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
                        _isApprovalSelected = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      decoration: BoxDecoration(
                        color: _isApprovalSelected ? Colors.grey[300] : Colors.amber,
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      child: Center(
                        child: Text(
                          'History',
                          style: TextStyle(
                            color: _isApprovalSelected ? Colors.black : Colors.black,
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchApprovalsData, // Pull to refresh
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
    return GestureDetector(
      onTap: () => _showApprovalDetail(context, item),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: _getStatusColor(item['status'] ?? 'Unknown')),
        ),
        elevation: 5,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.event_note,
                color: _getStatusColor(item['status'] ?? 'Unknown'),
                size: 40,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? 'No Title',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'From: ${item['take_leave_from'] ?? 'N/A'} To: ${item['take_leave_to'] ?? 'N/A'}',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Days: ${item['days']?.toString() ?? 'N/A'}',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['take_leave_reason'] ?? 'No Reason',
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
                            color: _getStatusColor(item['is_approve'] ?? 'Unknown'),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Text(
                            item['is_approve'] ?? 'Unknown',
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
                backgroundImage: NetworkImage(item['img_name'] ??
                    'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
                radius: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
