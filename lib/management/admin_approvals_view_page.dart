import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart'; // For file downloads

class AdminApprovalsViewPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final String type;
  final String id;

  const AdminApprovalsViewPage({
    Key? key,
    required this.item,
    required this.type,
    required this.id,
  }) : super(key: key);

  @override
  _AdminApprovalsViewPageState createState() =>
      _AdminApprovalsViewPageState();
}

class _AdminApprovalsViewPageState extends State<AdminApprovalsViewPage> {
  final TextEditingController _descriptionController = TextEditingController();
  String? requestorImage;
  String? lineManagerImage;
  String? hrImage;
  String? employeeImage; // For meeting room booking
  String lineManagerDecision = 'Pending';
  String hrDecision = 'Pending';
  bool isFinalized = false; // To prevent multiple submissions
  bool isLoading = true;
  List<String> meetingFiles = [];
  List<dynamic> meetingMembers = [];

  @override
  void initState() {
    super.initState();
    _initializeApproval();
  }

  Future<void> _initializeApproval() async {
    final String type = widget.type.toLowerCase();
    await _extractProfileImages();
    await _fetchAdditionalData();
    setState(() {
      isLoading = false;
    });
  }

  // Extract profile images directly from the item based on type
  Future<void> _extractProfileImages() async {
    final String type = widget.type.toLowerCase();

    switch (type) {
      case 'leave':
        requestorImage = widget.item['img_path'] ??
            'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
        // Assuming line_manager_id and hr_id are part of the leave request
        lineManagerImage = widget.item['line_manager_img_path'] ??
            'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
        hrImage = widget.item['hr_img_path'] ??
            'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
        break;
      case 'car':
        requestorImage = widget.item['img_name'] ??
            'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
        break;
      case 'meeting_room':
        requestorImage = widget.item['img_name'] ??
            'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
        break;
      case 'meeting':
        requestorImage = widget.item['img_name'] ??
            'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
        // Extract members
        meetingMembers = widget.item['members'] ?? [];
        break;
      default:
        requestorImage = 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
    }
  }

  // Fetch additional data based on type
  Future<void> _fetchAdditionalData() async {
    final String type = widget.type.toLowerCase();
    final String id = widget.id;

    const String baseUrl = 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com';
    String? tokenValue = await _getToken();

    if (tokenValue == null) {
      _showErrorDialog('Authentication Error',
          'Token not found. Please log in again.');
      return;
    }

    switch (type) {
      case 'leave':
        await _fetchLeaveStatus(id, tokenValue);
        break;
      case 'meeting':
      // For meetings, already have members from the initial data
        break;
      default:
      // For other types, implement if needed
        break;
    }
  }

  // Fetch leave request status
  Future<void> _fetchLeaveStatus(String id, String token) async {
    final String endpoint = 'https://demo-application-api.flexiflows.co/api/leave_request/all/$id';

    try {
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // Handle the leave status and other necessary fields here
        });
      } else {
        _showErrorDialog('Error', 'Failed to fetch leave status');
      }
    } catch (e) {
      _showErrorDialog('Error', 'An unexpected error occurred.');
    }
  }

  // Format date strings
  String formatDate(String? dateStr) {
    try {
      if (dateStr == null || dateStr.isEmpty) {
        return 'N/A';
      }
      // Handle different date formats
      DateTime parsedDate;
      if (dateStr.contains('T')) {
        parsedDate = DateTime.parse(dateStr);
      } else {
        parsedDate = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      }
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
        // Make the page scrollable
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
              if (widget.type.toLowerCase() == 'leave')
                _buildWorkflowSection(),
              const SizedBox(height: 12),
              if (widget.type.toLowerCase() != 'meeting')
                _buildCommentInputSection(),
              const SizedBox(height: 20),
              if (widget.type.toLowerCase() != 'meeting')
                _buildActionButtons(context),
              const SizedBox(height: 16),
              if (widget.type.toLowerCase() == 'meeting')
                _buildMeetingFilesSection(),
              if (widget.type.toLowerCase() == 'meeting')
                _buildMeetingMembersSection(),
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
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
      ),
      centerTitle: true,
      title: const Text(
        'Approvals Detail',
        style: TextStyle(
          color: Colors.black,
          fontSize: 22,
        ),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.black,
          size: 20,
        ),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      toolbarHeight: 80,
      elevation: 0,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildRequestorSection() {
    String requestorName = widget.item['employee_name'] ?? 'No Name';
    String submittedOn = 'N/A';
    final String type = widget.type.toLowerCase();

    // Determine submitted date based on type
    switch (type) {
      case 'leave':
        submittedOn = widget.item['created_at'] != null
            ? formatDate(widget.item['created_at'])
            : 'N/A';
        break;
      case 'car':
        submittedOn = widget.item['created_date'] != null
            ? formatDate(widget.item['created_date'])
            : 'N/A';
        break;
      case 'meeting_room':
        submittedOn = widget.item['date_create'] != null
            ? formatDate(widget.item['date_create'])
            : 'N/A';
        break;
      case 'meeting':
        submittedOn = widget.item['date_create'] != null
            ? formatDate(widget.item['date_create'])
            : 'N/A';
        break;
      default:
        submittedOn = 'N/A';
    }

    // Determine profile image
    String profileImage = requestorImage ??
        'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';

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
                backgroundImage: NetworkImage(profileImage),
                radius: 30, // Reduced size for compactness
                backgroundColor: Colors.grey[300],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requestorName,
                    style:
                    const TextStyle(color: Colors.black, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Submitted on $submittedOn',
                    style: const TextStyle(
                        fontSize: 14, color: Colors.black54),
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
        padding:
        const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
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
    final String type = widget.type.toLowerCase();

    switch (type) {
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
            style: TextStyle(fontSize: 16, color: Colors.red),
          ),
        );
    }
  }

  Widget _buildLeaveDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Leave Request ID',
            widget.item['take_leave_request_id']?.toString() ?? 'N/A',
            Icons.assignment, Colors.green),
        const SizedBox(height: 8),
        _buildInfoRow('Leave Type',
            widget.item['name'] ?? 'N/A', Icons.person, Colors.purple),
        const SizedBox(height: 8),
        _buildInfoRow('Reason',
            widget.item['take_leave_reason'] ?? 'N/A', Icons.book, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('From Date',
            formatDate(widget.item['take_leave_from']), Icons.calendar_today, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Until Date',
            formatDate(widget.item['take_leave_to']), Icons.calendar_today, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Days',
            widget.item['days']?.toString() ?? 'N/A', Icons.today, Colors.orange),
        const SizedBox(height: 8),
        _buildInfoRow('Overall Status',
            _determineOverallStatus(), Icons.stairs, Colors.red),
      ],
    );
  }

  Widget _buildCarDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Car Booking ID',
            widget.item['id']?.toString() ?? 'N/A', Icons.directions_car, Colors.green),
        const SizedBox(height: 8),
        _buildInfoRow('Purpose',
            widget.item['purpose'] ?? 'N/A', Icons.bookmark, Colors.green),
        const SizedBox(height: 8),
        _buildInfoRow('Date Out',
            formatDate(widget.item['date_out']), Icons.calendar_today, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Date In',
            formatDate(widget.item['date_in']), Icons.calendar_today, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Time Out',
            widget.item['time_out'] ?? 'N/A', Icons.access_time, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Time In',
            widget.item['time_in'] ?? 'N/A', Icons.access_time, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Place',
            widget.item['place'] ?? 'N/A', Icons.place, Colors.orange),
        const SizedBox(height: 8),
        _buildInfoRow('Status',
            widget.item['status'] ?? 'Pending', Icons.stairs, Colors.red),
      ],
    );
  }

  Widget _buildMeetingRoomDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Meeting Room Booking ID',
            widget.item['meeting_id']?.toString() ?? 'N/A',
            Icons.meeting_room, Colors.green),
        const SizedBox(height: 8),
        _buildInfoRow('Title',
            widget.item['title'] ?? 'N/A', Icons.title, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('From Date Time',
            formatDate(widget.item['from_date_time']),
            Icons.calendar_today, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('To Date Time',
            formatDate(widget.item['to_date_time']),
            Icons.calendar_today, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Employee Phone Number',
            widget.item['employee_tel'] ?? 'N/A', Icons.phone, Colors.orange),
        const SizedBox(height: 8),
        _buildInfoRow('Department Name',
            widget.item['department_name'] ?? 'N/A',
            Icons.business, Colors.purple),
        const SizedBox(height: 8),
        _buildInfoRow('Room Name',
            widget.item['room_name'] ?? 'N/A',
            Icons.meeting_room, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Room Floor',
            widget.item['room_floor']?.toString() ?? 'N/A',
            Icons.layers, Colors.orange),
        const SizedBox(height: 8),
        _buildInfoRow('Room No.',
            widget.item['room_no']?.toString() ?? 'N/A',
            Icons.numbers, Colors.orange),
        const SizedBox(height: 8),
        _buildInfoRow('Status',
            widget.item['status'] ?? 'Pending',
            Icons.stairs, Colors.red),
      ],
    );
  }

  Widget _buildMeetingDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Meeting ID',
            widget.item['meeting_id'] ?? 'N/A', Icons.meeting_room, Colors.green),
        const SizedBox(height: 8),
        _buildInfoRow('Project ID',
            widget.item['projects_id'] ?? 'N/A', Icons.work, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Title',
            widget.item['title'] ?? 'N/A', Icons.title, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Description',
            widget.item['description'] ?? 'No Details Provided',
            Icons.description, Colors.purple),
        const SizedBox(height: 8),
        _buildInfoRow('Status',
            widget.item['s_name']?.toString() ?? 'Pending',
            Icons.stairs, Colors.red),
        const SizedBox(height: 8),
        _buildInfoRow('From Date',
            widget.item['from_date'] != null
                ? formatDate(widget.item['from_date'])
                : 'N/A',
            Icons.calendar_today, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('To Date',
            widget.item['to_date'] != null
                ? formatDate(widget.item['to_date'])
                : 'N/A',
            Icons.calendar_today, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Start Time',
            widget.item['start_time'] ?? 'N/A',
            Icons.access_time, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('End Time',
            widget.item['end_time'] ?? 'N/A',
            Icons.access_time, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Created By',
            widget.item['create_by'] ?? 'N/A',
            Icons.person, Colors.red),
      ],
    );
  }

  Widget _buildInfoRow(String title, String content, IconData icon, Color color) {
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

  Widget _buildWorkflowSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildUserAvatar(
              requestorImage,
              label: 'Requester',
              showStatus: false,
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, color: Colors.green),
            const SizedBox(width: 8),
            _buildUserAvatar(
              lineManagerImage,
              label: 'Line Manager',
              status: lineManagerDecision,
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, color: Colors.green),
            const SizedBox(width: 8),
            _buildUserAvatar(
              hrImage,
              label: 'HR',
              status: hrDecision,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildStatusIndicator(),
      ],
    );
  }

  Widget _buildUserAvatar(String? imageUrl,
      {double radius = 25,
        String label = '',
        String status = 'Pending',
        bool showStatus = true}) {
    Color? statusColor;
    if (showStatus) {
      switch (status.toLowerCase()) {
        case 'approved':
          statusColor = Colors.green;
          break;
        case 'rejected':
          statusColor = Colors.red;
          break;
        case 'pending':
        default:
          statusColor = Colors.orange;
      }
    }

    return Column(
      children: [
        CircleAvatar(
          backgroundImage: NetworkImage(imageUrl ??
              'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
          radius: radius,
          backgroundColor: Colors.grey[300],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
        if (showStatus) ...[
          const SizedBox(height: 2),
          Text(
            status.capitalizeFirstLetter(),
            style: TextStyle(fontSize: 10, color: statusColor),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusIndicator() {
    return Column(
      children: [
        // Overall Status
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Overall Status: ',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              _determineOverallStatus(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _getOverallStatusColor(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _determineOverallStatus() {
    final String type = widget.type.toLowerCase();
    if (type == 'leave') {
      if (lineManagerDecision == 'rejected' || hrDecision == 'rejected') {
        return 'Rejected';
      } else if (lineManagerDecision == 'approved' &&
          hrDecision == 'approved') {
        return 'Approved';
      } else {
        return 'Pending';
      }
    } else if (type == 'car') {
      String status = widget.item['status']?.toLowerCase() ?? 'pending';
      switch (status) {
        case 'waiting':
          return 'Waiting';
        case 'approved':
          return 'Approved';
        case 'disapproved':
          return 'Rejected';
        default:
          return 'Pending';
      }
    } else if (type == 'meeting_room') {
      String status = widget.item['status']?.toLowerCase() ?? 'pending';
      switch (status) {
        case 'approve':
          return 'Approved';
        case 'disapprove':
        case 'cancel':
          return 'Rejected';
        default:
          return 'Pending';
      }
    } else if (type == 'meeting') {
      String status = widget.item['s_name']?.toLowerCase() ?? 'pending';
      switch (status) {
        case 'approved':
          return 'Approved';
        case 'rejected':
          return 'Rejected';
        case 'finished':
          return 'Finished';
        default:
          return 'Pending';
      }
    } else {
      return 'Unknown';
    }
  }

  Color _getOverallStatusColor() {
    String status = _determineOverallStatus();
    switch (status.toLowerCase()) {
      case 'approved':
      case 'finished':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'waiting':
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  Widget _buildCommentInputSection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start, // Align to start for better readability
      children: [
        const Text('Description',
            style: TextStyle(fontSize: 14, color: Colors.black)),
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
    final String type = widget.type.toLowerCase();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStyledButton(
          label: 'Reject',
          icon: Icons.close,
          backgroundColor: Colors.red, // Changed to red
          textColor: Colors.white,
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
        padding:
        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
      _showErrorDialog(
          'Validation Error', 'Please enter comments before approving.');
      return;
    }

    setState(() {
      isFinalized = true; // Prevent multiple submissions
    });

    final String type = widget.type.toLowerCase();
    final String id = widget.id;

    switch (type) {
      case 'meeting_room':
        await _approveMeetingRoom(context, id, comment);
        break;
      case 'car':
        await _approveCar(context, id, comment);
        break;
      case 'leave':
        await _approveLeave(context, id, comment);
        break;
      case 'meeting':
        await _approveMeeting(context, id, comment);
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
      _showErrorDialog(
          'Validation Error', 'Please enter comments before rejecting.');
      return;
    }

    setState(() {
      isFinalized = true; // Prevent multiple submissions
    });

    final String type = widget.type.toLowerCase();
    final String id = widget.id;

    switch (type) {
      case 'meeting_room':
        await _rejectMeetingRoom(context, id, comment);
        break;
      case 'car':
        await _rejectCar(context, id, comment);
        break;
      case 'leave':
        await _rejectLeave(context, id, comment);
        break;
      case 'meeting':
        await _rejectMeeting(context, id, comment);
        break;
      default:
        _showErrorDialog('Error', 'Unknown request type.');
    }

    setState(() {
      isFinalized = false; // Re-enable buttons after processing
    });
  }

  // Approve Meeting Room Booking
  Future<void> _approveMeetingRoom(
      BuildContext context, String uid, String comment) async {
    final String baseUrl = 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com';

    if (uid.isEmpty) {
      _showErrorDialog('Invalid Data', 'Meeting Room UID is missing.');
      return;
    }

    final String? tokenValue = await _getToken();
    if (tokenValue == null) {
      _showErrorDialog('Authentication Error',
          'Token not found. Please log in again.');
      return;
    }

    final String endpoint = 'https://demo-application-api.flexiflows.co/api/office-administration/book_meeting_room/approve/$uid';

    try {
      final response = await http.put(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $tokenValue',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "details": comment,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessDialog('Success', 'Meeting Room booking approved successfully.');
      } else {
        _showErrorDialog(
            'Error', 'Failed to approve meeting room booking: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error approving meeting room: $e');
      _showErrorDialog(
          'Error', 'An unexpected error occurred during approval.');
    }
  }

  // Reject Meeting Room Booking
  Future<void> _rejectMeetingRoom(
      BuildContext context, String uid, String comment) async {
    final String baseUrl = 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com';

    if (uid.isEmpty) {
      _showErrorDialog('Invalid Data', 'Meeting Room UID is missing.');
      return;
    }

    final String? tokenValue = await _getToken();
    if (tokenValue == null) {
      _showErrorDialog('Authentication Error',
          'Token not found. Please log in again.');
      return;
    }

    final String endpoint = 'https://demo-application-api.flexiflows.co/api/office-administration/book_meeting_room/disapprove/$uid';

    try {
      final response = await http.put(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $tokenValue',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "details": comment,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessDialog('Success', 'Meeting Room booking rejected.');
      } else {
        _showErrorDialog(
            'Error', 'Failed to reject meeting room booking: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error rejecting meeting room: $e');
      _showErrorDialog(
          'Error', 'An unexpected error occurred during rejection.');
    }
  }

  // Approve Car Booking
  Future<void> _approveCar(
      BuildContext context, String uid, String comment) async {
    final String baseUrl = 'https://demo-application-api.flexiflows.co';

    if (uid.isEmpty) {
      _showErrorDialog('Invalid Data', 'Car booking UID is missing.');
      return;
    }

    final String? tokenValue = await _getToken();
    if (tokenValue == null) {
      _showErrorDialog('Authentication Error',
          'Token not found. Please log in again.');
      return;
    }

    final String endpoint = '$baseUrl/api/office-administration/car_permit/approved/$uid';

    try {
      final response = await http.put(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $tokenValue',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "details": comment,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessDialog('Success', 'Car booking approved successfully.');
      } else {
        _showErrorDialog(
            'Error', 'Failed to approve car booking: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error approving car booking: $e');
      _showErrorDialog(
          'Error', 'An unexpected error occurred during approval.');
    }
  }

  // Reject Car Booking
  Future<void> _rejectCar(
      BuildContext context, String uid, String comment) async {
    final String baseUrl = 'https://demo-application-api.flexiflows.co';

    if (uid.isEmpty) {
      _showErrorDialog('Invalid Data', 'Car booking UID is missing.');
      return;
    }

    final String? tokenValue = await _getToken();
    if (tokenValue == null) {
      _showErrorDialog('Authentication Error',
          'Token not found. Please log in again.');
      return;
    }

    final String endpoint = '$baseUrl/api/office-administration/car_permit/disapproved/$uid';

    try {
      final response = await http.put(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $tokenValue',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "details": comment,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessDialog('Success', 'Car booking rejected.');
      } else {
        _showErrorDialog(
            'Error', 'Failed to reject car booking: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error rejecting car booking: $e');
      _showErrorDialog(
          'Error', 'An unexpected error occurred during rejection.');
    }
  }

  // Approve Leave Request
  Future<void> _approveLeave(
      BuildContext context, String id, String comment) async {
    final String baseUrl = 'https://demo-application-api.flexiflows.co';

    if (id.isEmpty) {
      _showErrorDialog('Invalid Data', 'Leave request ID is missing.');
      return;
    }

    final String? tokenValue = await _getToken();
    if (tokenValue == null) {
      _showErrorDialog('Authentication Error',
          'Token not found. Please log in again.');
      return;
    }

    final String lineManagerEndpoint = '$baseUrl/api/leave_processing/$id';
    final String hrEndpoint = '$baseUrl/api/leave_approve/$id';

    try {
      // Line Manager Approval
      final lmResponse = await http.put(
        Uri.parse(lineManagerEndpoint),
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
          lineManagerDecision = 'approved';
        });

        // Proceed to HR Approval
        final hrResponse = await http.put(
          Uri.parse(hrEndpoint),
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
            hrDecision = 'approved';
            isFinalized = true;
          });
          _showSuccessDialog(
              'Success', 'Leave request approved successfully.');
        } else {
          _showErrorDialog(
              'Error', 'HR approval failed: ${hrResponse.reasonPhrase}');
        }
      } else {
        _showErrorDialog(
            'Error', 'Line Manager approval failed: ${lmResponse.reasonPhrase}');
      }
    } catch (e) {
      print('Error approving leave: $e');
      _showErrorDialog(
          'Error', 'An unexpected error occurred during leave approval.');
    }
  }

  // Reject Leave Request
  Future<void> _rejectLeave(
      BuildContext context, String id, String comment) async {
    final String baseUrl = 'https://demo-application-api.flexiflows.co';

    if (id.isEmpty) {
      _showErrorDialog('Invalid Data', 'Leave request ID is missing.');
      return;
    }

    final String? tokenValue = await _getToken();
    if (tokenValue == null) {
      _showErrorDialog('Authentication Error',
          'Token not found. Please log in again.');
      return;
    }

    final String lineManagerRejectEndpoint = '$baseUrl/api/leave_reject/$id';
    final String hrRejectEndpoint = '$baseUrl/api/leave_approve/$id';

    try {
      if (lineManagerDecision.toLowerCase() != 'approved') {
        // If Line Manager hasn't approved yet, reject directly
        final response = await http.put(
          Uri.parse(lineManagerRejectEndpoint),
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
            lineManagerDecision = 'rejected';
            isFinalized = true;
          });
          _showSuccessDialog(
              'Success', 'Leave request rejected by Line Manager.');
        } else {
          _showErrorDialog('Error',
              'Failed to reject leave request: ${response.reasonPhrase}');
        }
      } else {
        // If Line Manager has approved, reject via HR
        final hrResponse = await http.put(
          Uri.parse(hrRejectEndpoint),
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
            hrDecision = 'rejected';
            isFinalized = true;
          });
          _showSuccessDialog('Success', 'Leave request rejected by HR.');
        } else {
          _showErrorDialog(
              'Error', 'HR rejection failed: ${hrResponse.reasonPhrase}');
        }
      }
    } catch (e) {
      print('Error rejecting leave: $e');
      _showErrorDialog(
          'Error', 'An unexpected error occurred during leave rejection.');
    }
  }

  // Approve Meeting
  Future<void> _approveMeeting(
      BuildContext context, String meetingId, String comment) async {
    final String baseUrl = 'https://demo-application-api.flexiflows.co';

    if (meetingId.isEmpty) {
      _showErrorDialog('Invalid Data', 'Meeting ID is missing.');
      return;
    }

    final String? tokenValue = await _getToken();
    if (tokenValue == null) {
      _showErrorDialog('Authentication Error',
          'Token not found. Please log in again.');
      return;
    }

    final String endpoint = '$baseUrl/api/work-tracking/meeting/approve-meeting/$meetingId';

    try {
      final response = await http.put(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $tokenValue',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "details": comment,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessDialog('Success', 'Meeting approved successfully.');
      } else {
        _showErrorDialog(
            'Error', 'Failed to approve meeting: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error approving meeting: $e');
      _showErrorDialog(
          'Error', 'An unexpected error occurred during approval.');
    }
  }

  // Reject Meeting
  Future<void> _rejectMeeting(
      BuildContext context, String meetingId, String comment) async {
    final String baseUrl = 'https://demo-application-api.flexiflows.co';

    if (meetingId.isEmpty) {
      _showErrorDialog('Invalid Data', 'Meeting ID is missing.');
      return;
    }

    final String? tokenValue = await _getToken();
    if (tokenValue == null) {
      _showErrorDialog('Authentication Error',
          'Token not found. Please log in again.');
      return;
    }

    final String endpoint = '$baseUrl/api/work-tracking/meeting/reject-meeting/$meetingId';

    try {
      final response = await http.put(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $tokenValue',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "details": comment,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessDialog('Success', 'Meeting rejected successfully.');
      } else {
        _showErrorDialog(
            'Error', 'Failed to reject meeting: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error rejecting meeting: $e');
      _showErrorDialog(
          'Error', 'An unexpected error occurred during rejection.');
    }
  }

  // Build Meeting Files Section
  Widget _buildMeetingFilesSection() {
    if (meetingFiles.isEmpty) {
      // If meetingFiles is empty, try to extract from the item
      meetingFiles = widget.item['file_name'] != null
          ? widget.item['file_name'] is List
          ? List<String>.from(widget.item['file_name'])
          : [widget.item['file_name']]
          : [];
    }

    if (meetingFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Files',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: meetingFiles.length,
          itemBuilder: (context, index) {
            String fileName = meetingFiles[index];
            return ListTile(
              leading: _getFileIcon(fileName),
              title: Text(fileName.split('/').last),
              onTap: () => _downloadFile(fileName),
            );
          },
        ),
      ],
    );
  }

  // Build Meeting Members Section
  Widget _buildMeetingMembersSection() {
    if (meetingMembers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 16.0),
        child: Text(
          'No members',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Members',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: meetingMembers.length,
          itemBuilder: (context, index) {
            var member = meetingMembers[index];
            String memberName = '${member['name']} ${member['surname']}';
            String memberEmail = member['email'] ?? 'No Email';
            String memberImage = member['img_ref'] ??
                'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(memberImage),
                backgroundColor: Colors.grey[300],
              ),
              title: Text(memberName),
              subtitle: Text(memberEmail),
            );
          },
        ),
      ],
    );
  }

  // Get appropriate icon based on file extension
  Widget _getFileIcon(String fileName) {
    String extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return const Icon(Icons.image, color: Colors.blue);
      case 'pdf':
        return const Icon(Icons.picture_as_pdf, color: Colors.red);
      case 'doc':
      case 'docx':
        return const Icon(Icons.description, color: Colors.blueGrey);
      default:
        return const Icon(Icons.insert_drive_file, color: Colors.grey);
    }
  }

  // Download file using url_launcher
  Future<void> _downloadFile(String filePath) async {
    final String fileUrl = filePath;

    if (await canLaunchUrl(Uri.parse(fileUrl))) {
      await launchUrl(Uri.parse(fileUrl),
          mode: LaunchMode.externalApplication);
    } else {
      _showErrorDialog('Error', 'Could not launch the file URL.');
    }
  }
}

// Extension method to capitalize the first letter
extension StringCasingExtension on String {
  String capitalizeFirstLetter() {
    if (this.isEmpty) return '';
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
