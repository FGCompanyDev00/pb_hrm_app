import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminApprovalsViewPage extends StatefulWidget {
  final Map<String, dynamic> item;

  const AdminApprovalsViewPage({super.key, required this.item});

  @override
  _AdminApprovalsViewPageState createState() => _AdminApprovalsViewPageState();
}

class _AdminApprovalsViewPageState extends State<AdminApprovalsViewPage> {
  final TextEditingController _descriptionController = TextEditingController();
  String? lineManagerImage;
  String? hrImage;
  String lineManagerDecision = 'Pending';
  String hrDecision = 'Pending';
  bool isLineManagerApproved = false;
  bool isHrApproved = false;

  @override
  void initState() {
    super.initState();
    _checkLeaveStatus();
  }

  // Check the status of the leave request via the API
  Future<void> _checkLeaveStatus() async {
    final response = await http.get(
      Uri.parse('https://demo-application-api.flexiflows.co/api/leave_requestprocessing'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Here, we check the leave processing data and update the UI accordingly
      if (data['results'] != null) {
        setState(() {
          isLineManagerApproved = data['results'][0]['is_approve'] == 'Approved';
        });
      }
    }
  }

  // Check final leave request approval state
  Future<void> _checkFinalLeaveStatus() async {
    final response = await http.get(
      Uri.parse('https://demo-application-api.flexiflows.co/api/leave_request/all/${widget.item['take_leave_request_id']}'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['results'] != null && data['results'][0]['is_approve'] == 'Completed') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request completed successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to complete leave request')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRequestorSection(),
              const SizedBox(height: 12),
              _buildBlueSection(),
              const SizedBox(height: 12),
              _buildDetailsSection(),
              const SizedBox(height: 12),
              _buildWorkflowSection(),
              const SizedBox(height: 12),
              _buildCommentInputSection(),
              const Spacer(),
              _buildActionButtons(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text('Approvals', style: TextStyle(color: Colors.black)),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  Widget _buildRequestorSection() {
    return Column(
      children: [
        CircleAvatar(
          backgroundImage: NetworkImage(widget.item['img_name'] ??
              'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
          radius: 40,
        ),
        const SizedBox(height: 8),
        Text(
          widget.item['requestor_name'] ?? 'No Name',
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'Submitted on ${widget.item['created_at']?.split("T")[0] ?? 'N/A'}',
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildBlueSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.lightBlueAccent.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Leave',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildInfoRow(Icons.bookmark, 'Title', widget.item['title'] ?? 'No Title'),
        const SizedBox(height: 8),
        _buildInfoRow(Icons.calendar_today, 'Date',
            '${widget.item['take_leave_from']} - ${widget.item['take_leave_to']}'),
        const SizedBox(height: 8),
        Text(
          'Type of leave: ${widget.item['take_leave_reason'] ?? 'No Reason'}',
          style: const TextStyle(fontSize: 14, color: Colors.orange),
        ),
      ],
    );
  }

  Widget _buildWorkflowSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildUserAvatar(widget.item['img_name']), // Requestor image
        const Icon(Icons.arrow_forward, color: Colors.green),
        _buildUserAvatar(lineManagerImage ??
            'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
        const Icon(Icons.arrow_forward, color: Colors.green),
        _buildUserAvatar(hrImage ??
            'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
      ],
    );
  }

  Widget _buildUserAvatar(String? imageUrl) {
    return CircleAvatar(
      backgroundImage: NetworkImage(imageUrl ??
          'https://fallback-image-url.com/default_avatar.jpg'),
      radius: 20,
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String content) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 4),
        Text('$title: $content', style: const TextStyle(fontSize: 14, color: Colors.black)),
      ],
    );
  }

  Widget _buildCommentInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('Description', style: TextStyle(fontSize: 14, color: Colors.black)),
        const SizedBox(height: 4),
        TextField(
          controller: _descriptionController,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            hintText: 'Enter approval/rejection comments',
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildButton(
          'Reject',
          Colors.grey.shade300,
          Colors.black,
          onPressed: isLineManagerApproved
              ? null
              : () => _submitLineManagerDecision(context, 'Reject'),
        ),
        _buildButton(
          'Approve',
          Colors.green,
          Colors.white,
          onPressed: isLineManagerApproved
              ? null
              : () => _submitLineManagerDecision(context, 'Approve'),
        ),
      ],
    );
  }

  Widget _buildButton(String label, Color color, Color textColor,
      {required VoidCallback? onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: textColor,
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }

  Future<void> _submitLineManagerDecision(
      BuildContext context, String decision) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final comment = _descriptionController.text;

    if (token == null || comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide valid inputs')),
      );
      return;
    }

    final response = await http.put(
      Uri.parse(
          'https://demo-application-api.flexiflows.co/api/leave_processing/${widget.item['take_leave_request_id']}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "decide": decision,
        "details": comment,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      setState(() {
        lineManagerImage = widget.item['line_manager_img']; // Update line manager image
        lineManagerDecision = decision;
        isLineManagerApproved = true;
      });
      _submitHRApproval(context, decision); // Proceed to HR approval
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to $decision: ${response.reasonPhrase}')),
      );
    }
  }

  Future<void> _submitHRApproval(BuildContext context, String decision) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.put(
      Uri.parse(
          'https://demo-application-api.flexiflows.co/api/leave_approve/${widget.item['take_leave_request_id']}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "decide": decision,
        "details": _descriptionController.text,
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        hrImage = widget.item['hr_img']; // Update HR image
        hrDecision = decision;
        isHrApproved = true;
      });
      _checkFinalLeaveStatus(); // Check final approval status
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('HR approval failed: ${response.reasonPhrase}')),
      );
    }
  }
}
