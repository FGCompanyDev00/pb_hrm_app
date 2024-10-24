import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationDetailPage extends StatefulWidget {
  final String id;
  final String types;
  final String status;

  const NotificationDetailPage({
    Key? key,
    required this.id,
    required this.types,
    required this.status,
  }) : super(key: key);

  @override
  _NotificationDetailPageState createState() => _NotificationDetailPageState();
}

class _NotificationDetailPageState extends State<NotificationDetailPage> {
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
    String apiUrl;
    bool isPending = isPendingStatus(widget.status);

    try {
      final String? token = await _getToken();
      if (token == null) {
        _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
        return;
      }

      http.Response response;

      if (widget.types.toLowerCase() == 'meeting') {
        // For 'meeting', use a different endpoint and method
        apiUrl = '$baseUrl/api/office-administration/book_meeting_room/${widget.id}';

        response = await http.get(
          Uri.parse(apiUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
      } else {
        // For 'leave' and 'car', use the pending or history endpoint
        if (isPending) {
          // Pending item
          apiUrl = '$baseUrl/api/app/tasks/approvals/pending/${widget.id}';
        } else {
          // History item
          apiUrl = '$baseUrl/api/app/tasks/approvals/history/${widget.id}';
        }

        // Prepare the request body
        Map<String, dynamic> requestBody = {
          'types': widget.types,
          // Use 'status' or 'is_approve' based on the type
          widget.types.toLowerCase() == 'leave' ? 'is_approve' : 'status': widget.status,
        };

        response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody),
        );
      }

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

  bool isPendingStatus(String status) {
    return status.toLowerCase() == 'waiting' ||
        status.toLowerCase() == 'pending' ||
        status.toLowerCase() == 'processing' ||
        status.toLowerCase() == 'branch waiting' ||
        status.toLowerCase() == 'branch processing';
  }

  String formatDate(String? dateStr) {
    try {
      if (dateStr == null || dateStr.isEmpty) {
        return 'N/A';
      }
      DateTime parsedDate;

      if (dateStr.contains('T')) {
        parsedDate = DateTime.parse(dateStr);
      } else if (RegExp(r"^\d{4}-\d{1,2}-\d{1,2}$").hasMatch(dateStr)) {
        List<String> dateParts = dateStr.split('-');
        int year = int.parse(dateParts[0]);
        int month = int.parse(dateParts[1]);
        int day = int.parse(dateParts[2]);
        parsedDate = DateTime(year, month, day);
      } else {
        parsedDate = DateTime.parse(dateStr);
      }

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
            if (widget.types.toLowerCase() != 'meeting' && isPendingStatus(widget.status))
              _buildCommentInputSection(),
            if (!isPendingStatus(widget.status) && widget.status.toLowerCase() == 'Reject'.toLowerCase())
              _buildDenyReasonSection(),
            const SizedBox(height: 22),
            if (widget.types.toLowerCase() != 'meeting' && isPendingStatus(widget.status))
              _buildActionButtons(context),
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
        _buildInfoRow('Meeting ID', approvalData?['meeting_id']?.toString() ?? 'N/A', Icons.meeting_room, Colors.green),
        const SizedBox(height: 8),
        _buildInfoRow('Title', approvalData?['title'] ?? 'N/A', Icons.title, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Status', approvalData?['status']?.toString() ?? 'Pending', Icons.stairs, Colors.red),
        const SizedBox(height: 8),
        _buildInfoRow('From Date', approvalData?['from_date_time'] != null ? formatDate(approvalData!['from_date_time']) : 'N/A', Icons.calendar_today, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('To Date', approvalData?['to_date_time'] != null ? formatDate(approvalData!['to_date_time']) : 'N/A', Icons.calendar_today, Colors.blue),
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

  Widget _buildDenyReasonSection() {
    String denyReason = approvalData?['deny_reason'] ?? 'No reason provided.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Deny Reason', style: TextStyle(fontSize: 16, color: Colors.black)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            denyReason,
            style: const TextStyle(fontSize: 16, color: Colors.black),
          ),
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
    Map<String, dynamic> body = {'details': comment}; // Body structure as per instructions

    switch (widget.types.toLowerCase()) {
      case 'meeting':
        endpoint = action == 'approve'
            ? '$baseUrl/api/office-administration/book_meeting_room/approve/${widget.id}'
            : '$baseUrl/api/office-administration/book_meeting_room/disapprove/${widget.id}';
        break;
      case 'car':
        endpoint = action == 'approve'
            ? '$baseUrl/api/office-administration/car_permit/approved/${widget.id}'
            : '$baseUrl/api/office-administration/car_permit/disapproved/${widget.id}';
        break;
      case 'leave':
        String isApprove = approvalData?['is_approve']?.toString()?.toLowerCase() ?? '';
        if (isApprove == 'waiting') {
          endpoint = action == 'approve'
              ? '$baseUrl/api/leave_approve/${widget.id}'
              : '$baseUrl/api/leave_reject/${widget.id}';
        } else if (isApprove == 'processing') {
          endpoint = action == 'approve'
              ? '$baseUrl/api/leave_processing/${widget.id}'
              : '$baseUrl/api/leave_reject/${widget.id}';
        } else {
          _showErrorDialog('Error', 'Invalid leave status for approval.');
          setState(() {
            isFinalized = false;
          });
          return;
        }
        break;
      default:
        _showErrorDialog('Error', 'Invalid request type.');
        setState(() {
          isFinalized = false;
        });
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
