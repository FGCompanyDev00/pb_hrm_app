import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';

    try {
      // Fetch Approvals data
      final approvalResponse = await http.get(
        Uri.parse('$baseUrl/api/app/tasks/approvals/pending'),
      );

      if (approvalResponse.statusCode == 200) {
        final List<dynamic> approvalData = json.decode(approvalResponse.body);
        approvalItems = approvalData.map((item) => Map<String, dynamic>.from(item)).toList();
      }

      // Fetch History data
      final historyResponse = await http.get(
        Uri.parse('$baseUrl/api/app/tasks/approvals/history'),
      );

      if (historyResponse.statusCode == 200) {
        final List<dynamic> historyData = json.decode(historyResponse.body);
        historyItems = historyData.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      print('Error fetching data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
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
                image: AssetImage('assets/ready.png'), // Replace with your background image asset
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
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 50.0),
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
                ? Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: _isApprovalSelected
                        ? approvalItems.map((item) => _buildApprovalCard(item)).toList()
                        : historyItems.map((item) => _buildHistoryCard(item)).toList(),
                  ),
          ),
        ],
      ),
      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.fingerprint), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: ''),
        ],
        selectedItemColor: Colors.amber[700],
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: 1, // Highlight the home button
        onTap: (index) {
          // Handle navigation logic
        },
      ),
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.meeting_room, color: Colors.green, size: 40),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['requestor_name'] ?? 'No Title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4.0),
                  Text('Reason: ${item['take_leave_reason'] ?? ''}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8.0),
                  Text('From: ${item['take_leave_from']} To: ${item['take_leave_to']}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: Colors.yellow[700],
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

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.directions_car, color: Colors.blue, size: 40),
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
                          color: Colors.yellow[700],
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
