// approvals_details_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApprovalsDetailsPage extends StatefulWidget {
  final String id;
  final String types;
  final String status;

  const ApprovalsDetailsPage({
    Key? key,
    required this.id,
    required this.types,
    required this.status,
  }) : super(key: key);

  @override
  _ApprovalsDetailsPageState createState() => _ApprovalsDetailsPageState();
}

class _ApprovalsDetailsPageState extends State<ApprovalsDetailsPage> {
  final TextEditingController _descriptionController = TextEditingController();
  bool isLoading = true;
  bool isFinalized = false;
  Map<String, dynamic>? approvalData;
  String? requestorImage;

  @override
  void initState() {
    super.initState();
    _fetchApprovalDetails();
  }

  Future<void> _fetchApprovalDetails() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    final String apiUrl = '$baseUrl/api/app/tasks/approvals/pending/${widget.id}';

    try {
      final String? token = await _getToken();
      if (token == null) {
        _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
        return;
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'types': widget.types,
          'status': widget.status,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          approvalData = data['results'];
          requestorImage = approvalData!['img_name'] ??
              'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
          isLoading = false;
        });
      } else {
        _showErrorDialog('Error', 'Failed to load approval details.');
      }
    } catch (e) {
      _showErrorDialog('Error', 'An unexpected error occurred.');
    }
  }

  String formatDate(String? dateStr) {
    try {
      if (dateStr == null || dateStr.isEmpty) {
        return 'N/A';
      }
      DateTime parsedDate = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy, HH:mm').format(parsedDate);
    } catch (e) {
      print('Date parsing error: $e');
      return 'Invalid Date';
    }
  }

  Future<String?> _getToken() async {
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
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            _buildRequestorSection(),
            const SizedBox(height: 20),
            _buildBlueSection(),
            const SizedBox(height: 5),
            _buildDetailsSection(),
            const SizedBox(height: 30),
            if (widget.types.toLowerCase() != 'meeting') _buildCommentInputSection(),
            const SizedBox(height: 22),
            if (widget.types.toLowerCase() != 'meeting') _buildActionButtons(context),
          ],
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
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
      ),
      centerTitle: true,
      title: const Text(
        'Approval Details',
        style: TextStyle(color: Colors.black, fontSize: 24),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 24),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      toolbarHeight: 90,
      elevation: 0,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildRequestorSection() {
    String requestorName = approvalData?['employee_name'] ?? 'No Name';
    String submittedOn = approvalData?['created_at'] != null
        ? formatDate(approvalData!['created_at'])
        : 'N/A';

    String profileImage = requestorImage ??
        'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('Requestor', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(profileImage),
              radius: 35,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(requestorName, style: const TextStyle(color: Colors.black, fontSize: 18)),
                const SizedBox(height: 6),
                Text('Submitted on $submittedOn', style: const TextStyle(fontSize: 16, color: Colors.black54)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBlueSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
        decoration: BoxDecoration(
          color: Colors.lightBlueAccent.withOpacity(0.4),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          _getTypeHeader(),
          style: const TextStyle(color: Colors.black, fontSize: 18),
        ),
      ),
    );
  }

  String _getTypeHeader() {
    switch (widget.types.toLowerCase()) {
      case 'meeting_room':
        return 'MEETING ROOM BOOKING REQUEST';
      case 'meeting':
        return 'MEETING REQUEST';
      case 'car':
        return 'CAR BOOKING REQUEST';
      case 'leave':
        return 'LEAVE REQUEST';
      default:
        return 'Approval Details';
    }
  }

  Widget _buildDetailsSection() {
    switch (widget.types.toLowerCase()) {
      case 'leave':
        return _buildLeaveDetails();
      case 'car':
        return _buildCarDetails();
      case 'meeting_room':
        return _buildMeetingRoomDetails();
      case 'meeting':
        return _buildMeetingDetails();
      default:
        return const Center(
          child: Text(
            'Unknown Request Type',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        );
    }
  }

  Widget _buildLeaveDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Leave Request ID', approvalData?['take_leave_request_id']?.toString() ?? 'N/A', Icons.assignment, Colors.green),
        const SizedBox(height: 8), // Spacing between rows
        _buildInfoRow('Leave Type', approvalData?['name'] ?? 'N/A', Icons.person, Colors.purple),
        const SizedBox(height: 8),
        _buildInfoRow('Reason', approvalData?['take_leave_reason'] ?? 'N/A', Icons.book, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('From Date', formatDate(approvalData?['take_leave_from']), Icons.calendar_today, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Until Date', formatDate(approvalData?['take_leave_to']), Icons.calendar_today, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Days', approvalData?['days']?.toString() ?? 'N/A', Icons.today, Colors.orange),
      ],
    );
  }

  Widget _buildCarDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Car Booking ID', approvalData?['id']?.toString() ?? 'N/A', Icons.directions_car, Colors.green),
        const SizedBox(height: 8),
        _buildInfoRow('Purpose', approvalData?['purpose'] ?? 'N/A', Icons.bookmark, Colors.green),
        const SizedBox(height: 8),
        _buildInfoRow('Date Out', formatDate(approvalData?['date_out']), Icons.calendar_today, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Date In', formatDate(approvalData?['date_in']), Icons.calendar_today, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Place', approvalData?['place'] ?? 'N/A', Icons.place, Colors.orange),
        const SizedBox(height: 8),
        _buildInfoRow('Status', approvalData?['status'] ?? 'Pending', Icons.stairs, Colors.red),
      ],
    );
  }

  Widget _buildMeetingRoomDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Meeting Room Booking ID', approvalData?['meeting_id']?.toString() ?? 'N/A', Icons.meeting_room, Colors.green),
        const SizedBox(height: 8),
        _buildInfoRow('Title', approvalData?['title'] ?? 'N/A', Icons.title, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('From Date Time', formatDate(approvalData?['from_date_time']), Icons.calendar_today, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('To Date Time', formatDate(approvalData?['to_date_time']), Icons.calendar_today, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Room Name', approvalData?['room_name'] ?? 'N/A', Icons.meeting_room, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Room Floor', approvalData?['room_floor']?.toString() ?? 'N/A', Icons.layers, Colors.orange),
      ],
    );
  }

  Widget _buildMeetingDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Meeting ID', approvalData?['meeting_id'] ?? 'N/A', Icons.meeting_room, Colors.green),
        const SizedBox(height: 8),
        _buildInfoRow('Title', approvalData?['title'] ?? 'N/A', Icons.title, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Status', approvalData?['s_name']?.toString() ?? 'Pending', Icons.stairs, Colors.red),
        const SizedBox(height: 8),
        _buildInfoRow('From Date', approvalData?['from_date'] != null ? formatDate(approvalData!['from_date']) : 'N/A', Icons.calendar_today, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('To Date', approvalData?['to_date'] != null ? formatDate(approvalData!['to_date']) : 'N/A', Icons.calendar_today, Colors.blue),
      ],
    );
  }

  Widget _buildInfoRow(String title, String content, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text('$title: $content', style: const TextStyle(fontSize: 16, color: Colors.black)),
        ),
      ],
    );
  }

  Widget _buildCommentInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Comments', style: TextStyle(fontSize: 16, color: Colors.black)),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
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
        _buildStyledButton(label: 'Reject', icon: Icons.close, backgroundColor: Colors.red, textColor: Colors.white, onPressed: isFinalized ? null : () => _handleReject(context)),
        _buildStyledButton(label: 'Approve', icon: Icons.check_circle_outline, backgroundColor: Colors.green, textColor: Colors.white, onPressed: isFinalized ? null : () => _handleApprove(context)),
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
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      icon: Icon(icon, color: textColor, size: 20),
      label: Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  Future<void> _handleApprove(BuildContext context) async {
    await _sendApprovalStatus('approve', context);
  }

  Future<void> _handleReject(BuildContext context) async {
    await _sendApprovalStatus('reject', context);
  }

  Future<void> _sendApprovalStatus(String action, BuildContext context) async {
    final String comment = _descriptionController.text.trim();
    if (comment.isEmpty) {
      _showErrorDialog('Validation Error', 'Please enter comments before proceeding.');
      return;
    }

    setState(() {
      isFinalized = true;
    });

    final String baseUrl = 'https://demo-application-api.flexiflows.co';
    final String? token = await _getToken();
    if (token == null) {
      _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
      return;
    }

    String endpoint;
    String method = 'PUT'; // Using PUT for all API requests
    Map<String, dynamic> body = {'details': comment}; // Default body structure

    switch (widget.types.toLowerCase()) {
      case 'meeting':
        endpoint = action == 'approve'
            ? '$baseUrl/api/office-administration/book_meeting_room/approve/${widget.id}'
            : '$baseUrl/api/office-administration/book_meeting_room/disapprove/${widget.id}';
        break;
      case 'car':
        if (action == 'approve') {
          // car approval has extra data to send
          endpoint = '$baseUrl/api/office-administration/car_permit/approved/${widget.id}';
          body = {
            'vehicle_id': {
              'vehicle_uid': approvalData?['vehicle_uid'] ?? 'default_uid',
            },
            'branch_vehicle': {
              'vehicle_uid': approvalData?['vehicle_uid'] ?? '',
              'permit_id': approvalData?['permit_id'] ?? '',
            },
            'comment': comment
          };
        } else {
          endpoint = '$baseUrl/api/office-administration/car_permit/disapproved/${widget.id}';
          body = {'comment': comment};
        }
        break;
      case 'leave':
        endpoint = action == 'approve'
            ? '$baseUrl/api/leave_approve/${widget.id}'
            : '$baseUrl/api/leave_reject/${widget.id}';
        break;
      default:
        _showErrorDialog('Error', 'Invalid request type.');
        return;
    }

    try {
      final response = await http.put(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessDialog('Success', 'Request has been $action successfully.');
      } else {
        _showErrorDialog('Error', 'Failed to $action the request.');
      }
    } catch (e) {
      _showErrorDialog('Error', 'An unexpected error occurred.');
    } finally {
      setState(() {
        isFinalized = false;
      });
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

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
}
