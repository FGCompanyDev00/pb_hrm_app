import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'approvals_view_page.dart';

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
      print('Token is null');
      return;
    } else {
      print('Token is available: $token');
    }

    try {
      // Fetch approval data
      final approvalResponse = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/app/tasks/approvals/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // Fetch history data
      final historyResponse = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/app/tasks/approvals/history'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (approvalResponse.statusCode == 200 && historyResponse.statusCode == 200) {
        final List<dynamic> approvalResults = json.decode(approvalResponse.body)['results']; // assuming the key is 'results'
        final List<dynamic> historyResults = json.decode(historyResponse.body)['results']; // assuming the key is 'results'

        setState(() {
          _approvalItems = List<Map<String, dynamic>>.from(approvalResults);
          _historyItems = List<Map<String, dynamic>>.from(historyResults);
        });
      } else {
        print('Failed to load data: Approvals - ${approvalResponse.statusCode}, History - ${historyResponse.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }


  Color _getStatusColor(String status) {
    switch (status) {
      case 'Waiting':
        return Colors.amber;
      case 'Approved':
        return Colors.green;
      case 'Reject':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  void _showApprovalDetail(BuildContext context, Map<String, dynamic> item, bool isDarkMode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApprovalsViewPage(item: item), // Navigate to approvals_view_page.dart
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      body: Column(
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
                    'Approvals',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 48), // Keeps the text centered
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
                        borderRadius: BorderRadius.circular(15.0), // Rounded corner
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
                        borderRadius: BorderRadius.circular(15.0), // Rounded corner
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
            child: Container(
              // decoration: BoxDecoration(
              //   image: DecorationImage(
              //     image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
              //     fit: BoxFit.cover,
              //   ),
              // ),
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
    return Slidable(
      key: Key(item['take_leave_request_id'].toString() ?? 'unknown_key'), // Provide a default key
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _showEditApproval(context, item, isDarkMode),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
          ),
        ],
      ),
      endActionPane: null,
      child: GestureDetector(
        onTap: () => _showApprovalDetail(context, item, isDarkMode),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(color: _getStatusColor(item['status'] ?? 'Unknown')), // Provide a default status
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
                  color: _getStatusColor(item['status'] ?? 'Unknown'), // Provide a default status
                  size: 40,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'No Title', // Provide a default title
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'From: ${item['take_leave_from'] ?? 'N/A'} To: ${item['take_leave_to'] ?? 'N/A'}', // Provide default date values
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Days: ${item['days']?.toString() ?? 'N/A'}', // Safely access days and convert to string
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['take_leave_reason'] ?? 'No Reason', // Provide a default reason
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
                              color: _getStatusColor(item['status'] ?? 'Unknown'), // Provide a default status
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
                      'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'), // Provide a default image
                  radius: 30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditApproval(BuildContext context, Map<String, dynamic> item, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: EditApprovalPopup(
              item: item,
              isDarkMode: isDarkMode,
              onSave: (editedItem) {
                setState(() {
                  final index = _approvalItems.indexWhere((i) => i['take_leave_request_id'] == editedItem['take_leave_request_id']);
                  if (index != -1) {
                    _approvalItems[index] = editedItem;
                  }
                });
                Navigator.pop(context);
                _showConfirmationDialog(context);
              },
            ),
          ),
        );
      },
    );
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text('The changes have been saved successfully.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

class EditApprovalPopup extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isDarkMode;
  final ValueChanged<Map<String, dynamic>> onSave;

  const EditApprovalPopup({
    super.key,
    required this.item,
    required this.isDarkMode,
    required this.onSave,
  });

  @override
  _EditApprovalPopupState createState() => _EditApprovalPopupState();
}

class _EditApprovalPopupState extends State<EditApprovalPopup> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController(text: widget.item['take_leave_reason']);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Edit Request',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _reasonController,
            decoration: InputDecoration(
              labelText: 'Reason',
              labelStyle: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a reason';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final editedItem = {
                  'take_leave_request_id': widget.item['take_leave_request_id'],
                  'leave_type_name': widget.item['leave_type_name'],
                  'take_leave_reason': _reasonController.text,
                  'take_leave_from': widget.item['take_leave_from'],
                  'take_leave_to': widget.item['take_leave_to'],
                };
                widget.onSave(editedItem);
              }
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: isDarkMode ? Colors.grey[800] : Colors.amber,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
