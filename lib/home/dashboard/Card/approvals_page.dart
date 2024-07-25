import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/theme/theme.dart';

class StaffApprovalsPage extends StatefulWidget {
  const StaffApprovalsPage({super.key});

  @override
  _StaffApprovalsPageState createState() => _StaffApprovalsPageState();
}

class _StaffApprovalsPageState extends State<StaffApprovalsPage> {
  bool _isApprovalSelected = true;
  List<Map<String, dynamic>> _approvalItems = [];
  List<Map<String, dynamic>> _historyItems = [];

  @override
  void initState() {
    super.initState();
    _fetchApprovalsData();
  }

  Future<void> _fetchApprovalsData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      // Handle missing token
      print('Token is null');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/leave_requests'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        print('Response received: ${response.body}');
        final List<dynamic> results = json.decode(response.body)['results'];
        print('Parsed results: $results');

        final List<Map<String, dynamic>> approvalItems = results
            .where((item) => item['is_approve'] == 'Waiting')
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        final List<Map<String, dynamic>> historyItems = results
            .where((item) => item['is_approve'] != 'Waiting')
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        setState(() {
          _approvalItems = approvalItems;
          _historyItems = historyItems;
          print('Approval Items: $_approvalItems');
          print('History Items: $_historyItems');
        });
      } else {
        // Handle error
        print('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      // Handle error
      print('Error: $e');
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
        return Colors.black;
    }
  }

  void _showApprovalDetail(BuildContext context, Map<String, dynamic> item, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ApprovalDetailPopup(
              item: item,
              isDarkMode: isDarkMode,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    final List<Map<String, dynamic>> approvalItems = _approvalItems;
    final List<Map<String, dynamic>> historyItems = _historyItems;

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.1,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
                fit: BoxFit.cover,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 25,
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, size: 30, color: Colors.black),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Text(
                      'Approvals',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
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
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Center(
                        child: Text(
                          'Approval',
                          style: TextStyle(
                            color: _isApprovalSelected ? Colors.black : Colors.black,
                            fontWeight: FontWeight.bold,
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
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Center(
                        child: Text(
                          'History',
                          style: TextStyle(
                            color: _isApprovalSelected ? Colors.black : Colors.black,
                            fontWeight: FontWeight.bold,
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
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: _isApprovalSelected
                  ? approvalItems.map((item) => _buildApprovalCard(context, item, isDarkMode)).toList()
                  : historyItems.map((item) => _buildApprovalCard(context, item, isDarkMode)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalCard(BuildContext context, Map<String, dynamic> item, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        _showApprovalDetail(context, item, isDarkMode);
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: BorderSide(color: _getStatusColor(item['is_approve'])),
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
                color: _getStatusColor(item['is_approve']),
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
                      'From: ${item['take_leave_from']} To: ${item['take_leave_to']}',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Days: ${item['days']}',
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
                            color: _getStatusColor(item['is_approve']),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Text(
                            item['is_approve'],
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
                backgroundImage: NetworkImage(item['img_path'] ?? 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
                radius: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ApprovalDetailPopup extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDarkMode;

  const ApprovalDetailPopup({
    super.key,
    required this.item,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    // Splitting the date string safely
    final dateParts = item['take_leave_from']?.split('\n') ?? [''];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Requestor',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(item['img_path'] ?? 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
              radius: 30,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['requestor_name'] ?? 'No Name',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Submitted on ${item['created_at']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          item['name'] ?? 'No Title',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 8),
            Text(
              'From: ${item['take_leave_from']} To: ${item['take_leave_to']}',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.access_time, size: 20),
            const SizedBox(width: 8),
            Text(
              'Days: ${item['days']}',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.book, size: 20),
            const SizedBox(width: 8),
            Text(
              item['take_leave_reason'] ?? 'No Reason',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (item['is_approve'] == 'Waiting')
          const Text(
            'Your request is pending and being processed.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.amber,
            ),
          )
        else
          Text(
            'This request has been ${item['is_approve'].toLowerCase()}.',
            style: TextStyle(
              fontSize: 16,
              color: _getStatusColor(item['is_approve']),
            ),
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.amber;
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.black;
    }
  }
}
