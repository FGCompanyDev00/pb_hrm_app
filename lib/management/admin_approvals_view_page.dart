// admin_approvals_view_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminApprovalsViewPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final String type;
  final String id;

  const AdminApprovalsViewPage({
    super.key,
    required this.item,
    required this.type,
    required this.id,
  });

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
  bool isFinalized = false; // To prevent multiple submissions
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApproval();
  }

  Future<void> _initializeApproval() async {
    await _fetchImages();
    await _checkStatus();
    setState(() {
      isLoading = false;
    });
  }

  // Fetch line manager and HR images
  Future<void> _fetchImages() async {
    setState(() {
      lineManagerImage = widget.item['line_manager_img'] ??
          'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
      hrImage = widget.item['hr_img'] ??
          'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
    });
  }

  // Fetch current approval status
  Future<void> _checkStatus() async {
    final String type = widget.type.toLowerCase();
    final String id = widget.id;

    const String baseUrl = 'https://demo-application-api.flexiflows.co';

    try {
      String endpoint = '';
      if (type == 'leave') {
        endpoint = '$baseUrl/api/leave_requestprocessing/$id';
      } else {
        // For other types, define appropriate endpoints if needed
        // Currently, assuming no additional status fetching is required
        return;
      }

      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          setState(() {
            isLineManagerApproved = data['results'][0]['is_approve'] == 'Approved';
            isHrApproved = data['results'][0]['hr_approve'] == 'Approved';
          });
        }
      } else {
        _showErrorDialog('Error', 'Failed to fetch approval status: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error checking status: $e');
      _showErrorDialog('Error', 'An unexpected error occurred while checking status.');
    }
  }

  String formatDate(String? dateStr) {
    try {
      if (dateStr == null || dateStr.isEmpty) {
        return 'N/A';
      }
      final DateTime parsedDate = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy, HH:mm').format(parsedDate);
    } catch (e) {
      print('Date parsing error: $e');
      return 'Invalid Date';
    }
  }

  // Show error dialog
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Optionally, navigate back or take other actions
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Show success dialog
  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Close the dialog
              Navigator.of(context).pop(); // Navigate back
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Retrieve token
  Future<String?> get token async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      print('Error retrieving token: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView( // Make the page scrollable
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            // Removed mainAxisSize: MainAxisSize.min to allow the column to take up available space
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildRequestorSection(),
              _buildBlueSection(),
              const SizedBox(height: 12),
              _buildDetailsSection(),
              const SizedBox(height: 12),
              _buildWorkflowSection(),
              const SizedBox(height: 12),
              _buildCommentInputSection(),
              const SizedBox(height: 20),
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
      title: const Text('Approval Details', style: TextStyle(color: Colors.black)),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  Widget _buildRequestorSection() {
    String requestorName = widget.item['employee_name'] ?? 'No Name';
    String submittedOn = formatDate(widget.item['created_at']);

    final String types = widget.type.toLowerCase();
    if (types == 'leave') {
      submittedOn = widget.item['created_at']?.split("T")[0] ?? 'N/A';
    } else if (types == 'meeting') {
      submittedOn = widget.item['date_create']?.split("T")[0] ?? 'N/A';
    } else if (types == 'car') {
      submittedOn = widget.item['created_date']?.split("T")[0] ?? 'N/A';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 30.0), // Reduced padding for compactness
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Center alignment
        children: [
          // Requestor Text
          const Text(
            'Requestor',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18, // Increased font size
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(widget.item['img_name'] ??
                    'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
                radius: 30, // Reduced size for compactness
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requestorName,
                    style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Submitted on $submittedOn',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlueSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.lightBlueAccent.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _getTypeHeader(),
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
    );
  }

  String _getTypeHeader() {
    switch (widget.type.toLowerCase()) {
      case 'meeting':
        return 'Meeting and Booking Meeting Room';
      case 'leave':
        return 'Leave Request';
      case 'car':
        return 'Car Permit Request';
      default:
        return 'Approval Details';
    }
  }

  Widget _buildDetailsSection() {
    final String type = widget.type.toLowerCase();

    if (type == 'meeting') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildInfoRow(Icons.bookmark, 'Title', widget.item['title'] ?? 'No Title', Colors.green),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.calendar_today, 'Date',
              '${widget.item['startDate'] ?? 'N/A'} - ${widget.item['endDate'] ?? 'N/A'}', Colors.blue),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.meeting_room, 'Room', widget.item['room'] ?? 'No Room Info', Colors.orange),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.description, 'Details', widget.item['details'] ?? 'No Details Provided', Colors.purple),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.person, 'Employee', widget.item['employee_name'] ?? 'N/A', Colors.red),
        ],
      );
    } else if (type == 'leave') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildInfoRow(Icons.bookmark, 'Title', widget.item['title'] ?? 'No Title', Colors.green),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.calendar_today, 'Date',
              '${widget.item['startDate'] ?? 'N/A'} - ${widget.item['endDate'] ?? 'N/A'}', Colors.blue),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.time_to_leave, 'Reason', widget.item['details'] ?? 'No Reason Provided', Colors.purple),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.person, 'Employee', widget.item['employee_name'] ?? 'N/A', Colors.red),
        ],
      );
    } else if (type == 'car') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildInfoRow(Icons.bookmark, 'Title', widget.item['title'] ?? 'No Title', Colors.green),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.calendar_today, 'Date',
              '${widget.item['startDate'] ?? 'N/A'} - ${widget.item['endDate'] ?? 'N/A'}', Colors.blue),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.access_time_rounded, 'Time','${widget.item['time'] ?? 'N/A'} - ${widget.item['time_end']?? 'N/A'}', Colors.blue),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.place, 'Room', widget.item['room'] ?? 'N/A', Colors.orange),
          const SizedBox(height: 8),
        ],
      );
    } else {
      return const Center(
        child: Text(
          'Unknown Request Type',
          style: TextStyle(fontSize: 16, color: Colors.red),
        ),
      );
    }
  }

  Widget _buildWorkflowSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildUserAvatar(widget.item['img_name'], radius: 20, label: 'Requester'),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward, color: Colors.green),
        const SizedBox(width: 8),
        _buildUserAvatar(lineManagerImage, radius: 20, label: 'Line Manager'),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward, color: Colors.green),
        const SizedBox(width: 8),
        _buildUserAvatar(hrImage, radius: 20, label: 'HR'),
      ],
    );
  }

  Widget _buildUserAvatar(String? imageUrl, {double radius = 20, String label = ''}) {
    return Column(
      children: [
        CircleAvatar(
          backgroundImage: NetworkImage(imageUrl ??
              'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
          radius: radius,
          backgroundColor: Colors.grey[300],
        ),
        if (label.isNotEmpty)
          Text(
            label,
            style: const TextStyle(fontSize: 10),
          ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String content, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$title: $content',
            style: const TextStyle(fontSize: 14, color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Align to start for better readability
      children: [
        const Text('Description', style: TextStyle(fontSize: 14, color: Colors.black)),
        const SizedBox(height: 4),
        TextField(
          controller: _descriptionController,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
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
        _buildStyledButton(
          label: 'Reject',
          icon: Icons.close,
          backgroundColor: Colors.grey.shade300,
          textColor: Colors.black,
          onPressed: isFinalized ? null : () => _handleReject(context),
        ),
        _buildStyledButton(
          label: 'Approve',
          icon: Icons.check_circle_outline,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          onPressed: isFinalized ? null : () => _handleApprove(context),
        ),
      ],
    );
  }

  Widget _buildStyledButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      icon: Icon(
        icon,
        color: textColor,
        size: 18,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Future<void> _handleApprove(BuildContext context) async {
    final String comment = _descriptionController.text.trim();

    if (comment.isEmpty) {
      _showErrorDialog('Validation Error', 'Please enter comments before approving.');
      return;
    }

    setState(() {
      isFinalized = true; // Prevent multiple submissions
    });

    final String type = widget.type.toLowerCase();
    final String id = widget.id;

    switch (type) {
      case 'meeting':
        await _approveMeeting(context, id, comment);
        break;
      case 'leave':
        await _approveLeave(context, id, comment);
        break;
      case 'car':
        await _approveCar(context, id, comment);
        break;
      default:
        _showErrorDialog('Error', 'Unknown request type.');
    }

    setState(() {
      isFinalized = false; // Re-enable buttons after processing
    });
  }

  Future<void> _handleReject(BuildContext context) async {
    final String comment = _descriptionController.text.trim();

    if (comment.isEmpty) {
      _showErrorDialog('Validation Error', 'Please enter comments before rejecting.');
      return;
    }

    setState(() {
      isFinalized = true; // Prevent multiple submissions
    });

    final String type = widget.type.toLowerCase();
    final String id = widget.id;

    switch (type) {
      case 'meeting':
        await _rejectMeeting(context, id, comment);
        break;
      case 'leave':
        await _rejectLeave(context, id, comment);
        break;
      case 'car':
        await _rejectCar(context, id, comment);
        break;
      default:
        _showErrorDialog('Error', 'Unknown request type.');
    }

    setState(() {
      isFinalized = false; // Re-enable buttons after processing
    });
  }

  // Approve Meeting Request
  Future<void> _approveMeeting(BuildContext context, String id, String comment) async {
    final String baseUrl = 'https://demo-application-api.flexiflows.co';

    if (id.isEmpty) {
      _showErrorDialog('Invalid Data', 'Meeting ID is missing.');
      return;
    }

    final String? tokenValue = await token;
    if (tokenValue == null) {
      _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
      return;
    }

    final response = await http.put(
      Uri.parse('$baseUrl/api/office-administration/book_meeting_room/approve/$id'),
      headers: {
        'Authorization': 'Bearer $tokenValue',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "details": comment,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      setState(() {
        lineManagerDecision = 'Approved';
        isLineManagerApproved = true;
      });
      _showSuccessDialog('Success', 'Meeting request approved successfully.');
    } else {
      _showErrorDialog('Error', 'Failed to approve meeting: ${response.reasonPhrase}');
    }
  }

  // Reject Meeting Request
  Future<void> _rejectMeeting(BuildContext context, String id, String comment) async {
    final String baseUrl = 'https://demo-application-api.flexiflows.co';

    if (id.isEmpty) {
      _showErrorDialog('Invalid Data', 'Meeting ID is missing.');
      return;
    }

    final String? tokenValue = await token;
    if (tokenValue == null) {
      _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
      return;
    }

    final response = await http.put(
      Uri.parse('$baseUrl/api/office-administration/book_meeting_room/disapprove/$id'),
      headers: {
        'Authorization': 'Bearer $tokenValue',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "details": comment,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      setState(() {
        lineManagerDecision = 'Rejected';
        isLineManagerApproved = false;
      });
      _showSuccessDialog('Success', 'Meeting request rejected.');
    } else {
      _showErrorDialog('Error', 'Failed to reject meeting: ${response.reasonPhrase}');
    }
  }

  // Approve Car Permit
  Future<void> _approveCar(BuildContext context, String id, String comment) async {
    final String baseUrl = 'https://demo-application-api.flexiflows.co';

    if (id.isEmpty) {
      _showErrorDialog('Invalid Data', 'Car permit ID is missing.');
      return;
    }

    final String? tokenValue = await token;
    if (tokenValue == null) {
      _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
      return;
    }

    final response = await http.put(
      Uri.parse('$baseUrl/api/office-administration/car_permit/approved/$id'),
      headers: {
        'Authorization': 'Bearer $tokenValue',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "details": comment,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      setState(() {
        lineManagerDecision = 'Approved';
        isLineManagerApproved = true;
      });
      _showSuccessDialog('Success', 'Car permit approved successfully.');
    } else {
      _showErrorDialog('Error', 'Failed to approve car permit: ${response.reasonPhrase}');
    }
  }

  // Reject Car Permit
  Future<void> _rejectCar(BuildContext context, String id, String comment) async {
    final String baseUrl = 'https://demo-application-api.flexiflows.co';

    if (id.isEmpty) {
      _showErrorDialog('Invalid Data', 'Car permit ID is missing.');
      return;
    }

    final String? tokenValue = await token;
    if (tokenValue == null) {
      _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
      return;
    }

    final response = await http.put(
      Uri.parse('$baseUrl/api/office-administration/car_permit/disapproved/$id'),
      headers: {
        'Authorization': 'Bearer $tokenValue',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "details": comment,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      setState(() {
        lineManagerDecision = 'Rejected';
        isLineManagerApproved = false;
      });
      _showSuccessDialog('Success', 'Car permit rejected.');
    } else {
      _showErrorDialog('Error', 'Failed to reject car permit: ${response.reasonPhrase}');
    }
  }

  // Approve Leave Request (Line Manager and then HR)
  Future<void> _approveLeave(BuildContext context, String id, String comment) async {
    final String baseUrl = 'https://demo-application-api.flexiflows.co';

    if (id.isEmpty) {
      _showErrorDialog('Invalid Data', 'Leave request ID is missing.');
      return;
    }

    final String? tokenValue = await token;
    if (tokenValue == null) {
      _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
      return;
    }

    try {
      // Line Manager Approval
      final lmResponse = await http.put(
        Uri.parse('$baseUrl/api/leave_processing/$id'),
        headers: {
          'Authorization': 'Bearer $tokenValue',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "decide": "Approve",
          "details": comment,
        }),
      );

      if (lmResponse.statusCode == 200 || lmResponse.statusCode == 201) {
        setState(() {
          lineManagerDecision = 'Approved';
          isLineManagerApproved = true;
        });

        // Proceed to HR Approval
        final hrResponse = await http.put(
          Uri.parse('$baseUrl/api/leave_approve/$id'),
          headers: {
            'Authorization': 'Bearer $tokenValue',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            "decide": "Approve",
            "details": comment,
          }),
        );

        if (hrResponse.statusCode == 200 || hrResponse.statusCode == 201) {
          setState(() {
            hrDecision = 'Approved';
            isHrApproved = true;
          });
          _showSuccessDialog('Success', 'Leave request approved successfully.');
        } else {
          _showErrorDialog('Error', 'HR approval failed: ${hrResponse.reasonPhrase}');
        }
      } else {
        _showErrorDialog('Error', 'Line Manager approval failed: ${lmResponse.reasonPhrase}');
      }
    } catch (e) {
      print('Error approving leave: $e');
      _showErrorDialog('Error', 'An unexpected error occurred during leave approval.');
    }
  }

  // Reject Leave Request
  Future<void> _rejectLeave(BuildContext context, String id, String comment) async {
    final String baseUrl = 'https://demo-application-api.flexiflows.co';

    if (id.isEmpty) {
      _showErrorDialog('Invalid Data', 'Leave request ID is missing.');
      return;
    }

    final String? tokenValue = await token;
    if (tokenValue == null) {
      _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
      return;
    }

    try {
      if (!isLineManagerApproved) {
        // If Line Manager hasn't approved yet, reject directly
        final response = await http.put(
          Uri.parse('$baseUrl/api/leave_reject/$id'),
          headers: {
            'Authorization': 'Bearer $tokenValue',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            "details": comment,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          setState(() {
            lineManagerDecision = 'Rejected';
            isFinalized = true;
          });
          _showSuccessDialog('Success', 'Leave request rejected by Line Manager.');
        } else {
          _showErrorDialog('Error', 'Failed to reject leave request: ${response.reasonPhrase}');
        }
      } else {
        // If Line Manager has approved, reject via HR
        final hrResponse = await http.put(
          Uri.parse('$baseUrl/api/leave_approve/$id'),
          headers: {
            'Authorization': 'Bearer $tokenValue',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            "decide": "Reject",
            "details": comment,
          }),
        );

        if (hrResponse.statusCode == 200 || hrResponse.statusCode == 201) {
          setState(() {
            hrDecision = 'Rejected';
            isHrApproved = false;
          });
          _showSuccessDialog('Success', 'Leave request rejected by HR.');
        } else {
          _showErrorDialog('Error', 'HR rejection failed: ${hrResponse.reasonPhrase}');
        }
      }
    } catch (e) {
      print('Error rejecting leave: $e');
      _showErrorDialog('Error', 'An unexpected error occurred during leave rejection.');
    }
  }
}
