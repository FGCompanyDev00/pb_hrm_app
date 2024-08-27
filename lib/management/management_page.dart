import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pb_hrsystem/home/dashboard/Card/approval/admin_approvals_view_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approval/approvals_view_page.dart';

class ManagementApprovalsPage extends StatefulWidget {
  const ManagementApprovalsPage({super.key});

  @override
  _ManagementApprovalsPageState createState() => _ManagementApprovalsPageState();
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
      if (kDebugMode) {
        print('Token is available: $token');
      } // Debugging: show token in console
      fetchData();
    } else {
      if (kDebugMode) {
        print('No token found');
      }
    }
  }

  Future<void> retrieveToken() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      token = prefs.getString('token'); // Ensure this key matches what you use in other parts of the app
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving token: $e');
      }
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

        // Ensure approvalData is a Map and contains 'results' key
        if (approvalData is Map<String, dynamic> && approvalData.containsKey('results')) {
          final List<dynamic>? approvalItemsData = approvalData['results'];

          // Safely map the results if not null
          if (approvalItemsData != null) {
            approvalItems = approvalItemsData
                .whereType<Map<String, dynamic>>()
                .map((item) => item)
                .toList();
          }
        } else {
          if (kDebugMode) {
            print('Approval data is null or does not contain expected results key.');
          }
        }
      } else {
        if (kDebugMode) {
          print('Failed to load approvals: ${approvalResponse.statusCode}');
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

        // Ensure historyData is a Map and contains 'results' key
        if (historyData is Map<String, dynamic> && historyData.containsKey('results')) {
          final List<dynamic>? historyItemsData = historyData['results'];

          // Safely map the results if not null
          if (historyItemsData != null) {
            historyItems = historyItemsData
                .whereType<Map<String, dynamic>>()
                .map((item) => item)
                .toList();
          }
        } else {
          if (kDebugMode) {
            print('History data is null or does not contain expected results key.');
          }
        }
      } else {
        if (kDebugMode) {
          print('Failed to load history: ${historyResponse.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching data: $e');
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Waiting':
        return Colors.orange;
      case 'Approved':
        return Colors.green;
      case 'Unknown':
        return Colors.grey;
      default:
        return Colors.red;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // AppBar section with custom background and title
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.18,
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
                  top: 40,
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, size: 30, color: Colors.black),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 50.0),
                    child: Text(
                      'Approvals',
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
          // TabBar section with Approval and History tabs
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
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Center(
                        child: Text(
                          'Approval',
                          style: TextStyle(
                            color: _isApprovalSelected ? Colors.black : Colors.grey[600],
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
                        color: !_isApprovalSelected ? Colors.amber : Colors.grey[300],
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Center(
                        child: Text(
                          'History',
                          style: TextStyle(
                            color: !_isApprovalSelected ? Colors.black : Colors.grey[600],
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
          // ListView section for displaying approval items
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
              padding: const EdgeInsets.all(16.0),
              children: _isApprovalSelected
                  ? approvalItems.map((item) => _buildApprovalCard(item)).toList()
                  : historyItems.map((item) => _buildHistoryCard(item)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => _openApprovalDetail(item), // Navigate to the detail page
      child: Card(
        margin: const EdgeInsets.only(bottom: 16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.meeting_room, color: _getStatusColor(item['status']), size: 40),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['requestor_name'] ?? 'No Name', // Handle null requestor_name
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'Reason: ${item['take_leave_reason'] ?? 'No Reason Provided'}', // Handle null reason
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'From: ${item['take_leave_from'] ?? 'N/A'} To: ${item['take_leave_to'] ?? 'N/A'}', // Handle null dates
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: _getStatusColor(item['status']),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Text(
                            item['status'] ?? 'Unknown', // Handle null status
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              CircleAvatar(
                backgroundImage: item['img_name'] != null
                    ? NetworkImage(item['img_name'])
                    : const AssetImage('assets/default_avatar.png') as ImageProvider, // Handle null image
                radius: 25,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.directions_car, color: Colors.blue, size: 40),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['requestor_name'] ?? 'No Title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4.0),
                  Text('Purpose: ${item['purpose'] ?? ''}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8.0),
                  Text('From: ${item['date_out']} To: ${item['date_in']}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: _getStatusColor(item['status']),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Text(item['status'], style: const TextStyle(color: Colors.black)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16.0),
            CircleAvatar(
              backgroundImage: NetworkImage(item['img_name']),
              radius: 25,
            ),
          ],
        ),
      ),
    );
  }
}
