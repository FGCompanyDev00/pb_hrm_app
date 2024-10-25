import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationDetailPage extends StatefulWidget {
  final String id;
  final String type;

  const NotificationDetailPage({
    Key? key,
    required this.id,
    required this.type,
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

  // Base URL for images
  final String _imageBaseUrl =
      'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/';

  @override
  void initState() {
    super.initState();
    _fetchApprovalDetails();
  }

  Future<void> _fetchApprovalDetails() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    String apiUrl;

    try {
      final String? token = await _getToken();
      if (token == null) {
        _showErrorDialog('Authentication Error',
            'Token not found. Please log in again.');
        return;
      }

      http.Response response;

      // Determine the API URL based on the type
      if (widget.type == 'leave') {
        apiUrl = '$baseUrl/api/leave_request/all/${widget.id}';
      } else if (widget.type == 'car') {
        apiUrl =
        '$baseUrl/api/office-administration/car_permit/${widget.id}';
      } else if (widget.type == 'meeting') {
        apiUrl =
        '$baseUrl/api/office-administration/book_meeting_room/${widget.id}';
      } else {
        throw Exception('Unknown type: ${widget.type}');
      }

      response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Response Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if ((data['statusCode'] == 200 || data['statusCode'] == 201) &&
            data['results'] != null) {
          setState(() {
            approvalData = widget.type == 'leave'
                ? Map<String, dynamic>.from(data['results'][0])
                : Map<String, dynamic>.from(data['results']);

            // Updated profile image handling for leave type
            if (widget.type == 'leave') {
              String? imgPath = approvalData!['img_path']?.toString().trim();
              if (imgPath != null && imgPath.isNotEmpty) {
                requestorImage = imgPath;
              } else {
                requestorImage =
                'https://via.placeholder.com/150'; // Default image
              }
            } else {
              // Existing logic for car and meeting types
              String? imgName =
              approvalData!['img_name']?.toString().trim();
              String? imgPath =
              approvalData!['img_path']?.toString().trim();

              if (imgPath != null &&
                  imgPath.isNotEmpty &&
                  imgPath.startsWith('http')) {
                requestorImage = imgPath;
              } else if (imgPath != null && imgPath.isNotEmpty) {
                requestorImage = '$_imageBaseUrl$imgPath';
              } else if (imgName != null &&
                  imgName.isNotEmpty &&
                  imgName.startsWith('http')) {
                requestorImage = imgName;
              } else if (imgName != null && imgName.isNotEmpty) {
                requestorImage = '$_imageBaseUrl$imgName';
              } else {
                requestorImage = 'https://via.placeholder.com/150';
              }
            }

            isLoading = false;
          });
          print('Approval details loaded successfully.');
        } else {
          throw Exception(
              data['message'] ?? 'Failed to load approval details.');
        }
      } else if (response.statusCode == 403) {
        throw Exception('Access forbidden: ${response.statusCode}');
      } else if (response.statusCode == 404) {
        throw Exception('Approval details not found: ${response.statusCode}');
      } else {
        throw Exception(
            'Failed to load approval details: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Error fetching approval details: $e');
      print(stackTrace);
      _showErrorDialog('Error', e.toString());
      setState(() {
        isLoading = false;
      });
    }
  }

  bool isPendingStatus(String status) {
    return status.toLowerCase() == 'waiting' ||
        status.toLowerCase() == 'pending' ||
        status.toLowerCase() == 'processing' ||
        status.toLowerCase() == 'branch waiting' ||
        status.toLowerCase() == 'branch processing';
  }

  String formatDate(String? dateStr, {bool includeDay = false}) {
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

      if (includeDay) {
        String dayOfWeek = DateFormat('EEEE').format(parsedDate);
        String dateFormatted = DateFormat('yyyy-MM-dd').format(parsedDate);
        return '$dayOfWeek ($dateFormatted)';
      } else {
        return DateFormat('dd-MM-yyyy, HH:mm').format(parsedDate);
      }
    } catch (e, stackTrace) {
      print('Date parsing error for "$dateStr": $e');
      print(stackTrace);
      return 'Invalid Date';
    }
  }

  Future<String?> _getToken() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e, stackTrace) {
      print('Error retrieving token: $e');
      print(stackTrace);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    String status = (approvalData?['status']?.toString() ??
        approvalData?['is_approve']?.toString() ??
        'Pending')
        .trim();

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
            if (widget.type == 'leave' ||
                widget.type == 'car' ||
                widget.type == 'meeting') ...[
              if (isPendingStatus(status)) ...[
                _buildCommentInputSection(),
                const SizedBox(height: 22),
                _buildActionButtons(context),
              ],
              if (!isPendingStatus(status) &&
                  status.toLowerCase() == 'reject')
                _buildDenyReasonSection(),
            ],
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
        'Notification Details',
        style: TextStyle(color: Colors.black, fontSize: 24),
      ),
      leading: IconButton(
        icon:
        const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 24),
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
    String requestorName = approvalData?['employee_name'] ??
        approvalData?['requestor_name'] ??
        'No Name';

    // Adjusted to use 'created_date' for car types if 'created_at' is null
    String submittedOn = 'N/A';
    if (approvalData?['created_at'] != null &&
        approvalData!['created_at'].toString().isNotEmpty) {
      submittedOn = formatDate(approvalData!['created_at']);
    } else if (widget.type == 'car' &&
        approvalData?['created_date'] != null &&
        approvalData!['created_date'].toString().isNotEmpty) {
      submittedOn = formatDate(approvalData!['created_date']);
    }

    String profileImage = requestorImage ??
        'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('Requestor',
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(profileImage),
              radius: 35,
              backgroundColor: Colors.grey[300],
              onBackgroundImageError: (error, stackTrace) {
                print('Error loading requestor image: $error');
              },
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(requestorName,
                    style: const TextStyle(color: Colors.black, fontSize: 18)),
                const SizedBox(height: 6),
                Text('Submitted on $submittedOn',
                    style:
                    const TextStyle(fontSize: 16, color: Colors.black54)),
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
    if (widget.type == 'leave') {
      return 'LEAVE REQUEST';
    } else if (widget.type == 'car') {
      return 'CAR BOOKING REQUEST';
    } else if (widget.type == 'meeting') {
      return 'MEETING ROOM BOOKING REQUEST';
    } else {
      return 'Approval Details';
    }
  }

  Widget _buildDetailsSection() {
    if (widget.type == 'leave') {
      return _buildLeaveDetails();
    } else if (widget.type == 'car') {
      return _buildCarDetails();
    } else if (widget.type == 'meeting') {
      return _buildMeetingDetails();
    } else {
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
        _buildInfoRow(
            'Leave Request ID',
            approvalData?['take_leave_request_id']?.toString() ?? 'N/A',
            Icons.assignment,
            Colors.green),
        const SizedBox(height: 8), // Spacing between rows
        _buildInfoRow('Leave Type', approvalData?['name'] ?? 'N/A',
            Icons.person, Colors.purple),
        const SizedBox(height: 8),
        _buildInfoRow('Reason', approvalData?['take_leave_reason'] ?? 'N/A',
            Icons.book, Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow(
            'From Date',
            formatDate(approvalData?['take_leave_from'], includeDay: true),
            Icons.calendar_today,
            Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow(
            'Until Date',
            formatDate(approvalData?['take_leave_to'], includeDay: true),
            Icons.calendar_today,
            Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Days', approvalData?['days']?.toString() ?? 'N/A',
            Icons.today, Colors.orange),
      ],
    );
  }

  Widget _buildCarDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Car Booking ID', approvalData?['id']?.toString() ?? 'N/A',
            Icons.directions_car, Colors.green),
        const SizedBox(height: 8),
        _buildInfoRow('Purpose', approvalData?['purpose'] ?? 'N/A',
            Icons.bookmark, Colors.green),
        const SizedBox(height: 8),
        _buildInfoRow(
            'Date Out',
            formatDate(approvalData?['date_out'], includeDay: true),
            Icons.calendar_today,
            Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow(
            'Date In',
            formatDate(approvalData?['date_in'], includeDay: true),
            Icons.calendar_today,
            Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Place', approvalData?['place']?.toString() ?? 'N/A',
            Icons.place, Colors.orange),
        const SizedBox(height: 8),
        _buildInfoRow('Status', approvalData?['status']?.toString() ?? 'Pending',
            Icons.stairs, Colors.red),
      ],
    );
  }

  Widget _buildMeetingDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
            'Meeting ID',
            approvalData?['meeting_id']?.toString() ?? 'N/A',
            Icons.meeting_room,
            Colors.green),
        const SizedBox(height: 8),
        _buildInfoRow('Title', approvalData?['title'] ?? 'N/A', Icons.title,
            Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow(
            'From Date',
            formatDate(approvalData?['from_date_time'], includeDay: true),
            Icons.calendar_today,
            Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow(
            'To Date',
            formatDate(approvalData?['to_date_time'], includeDay: true),
            Icons.calendar_today,
            Colors.blue),
        const SizedBox(height: 8),
        _buildInfoRow('Room Name', approvalData?['room_name']?.toString() ?? 'N/A',
            Icons.room, Colors.orange),
        const SizedBox(height: 8),
        _buildInfoRow('Status', approvalData?['status']?.toString() ?? 'Pending',
            Icons.stairs, Colors.red),
      ],
    );
  }

  Widget _buildInfoRow(
      String title, String content, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text('$title: $content',
              style: const TextStyle(fontSize: 16, color: Colors.black)),
        ),
      ],
    );
  }

  Widget _buildCommentInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Comments',
            style: TextStyle(fontSize: 16, color: Colors.black)),
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
    String denyReason =
        approvalData?['deny_reason']?.toString() ?? 'No reason provided.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Deny Reason',
            style: TextStyle(fontSize: 16, color: Colors.black)),
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
        _buildStyledButton(
            label: 'Reject',
            icon: Icons.close,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            onPressed: isFinalized ? null : () => _handleReject(context)),
        _buildStyledButton(
            label: 'Approve',
            icon: Icons.check_circle_outline,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            onPressed: isFinalized ? null : () => _handleApprove(context)),
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
      label: Text(label,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  Future<void> _handleApprove(BuildContext context) async {
    await _sendApprovalStatus('approve', context);
  }

  Future<void> _handleReject(BuildContext context) async {
    await _sendApprovalStatus('reject', context);
  }

  Future<void> _sendApprovalStatus(
      String action, BuildContext context) async {
    final String comment = _descriptionController.text.trim();

    setState(() {
      isFinalized = true;
    });

    final String baseUrl = 'https://demo-application-api.flexiflows.co';
    final String? token = await _getToken();
    if (token == null) {
      _showErrorDialog('Authentication Error',
          'Token not found. Please log in again.');
      setState(() {
        isFinalized = false;
      });
      return;
    }

    String endpoint = '';
    Map<String, dynamic> body = {};
    String method = 'POST'; // default method
    // Adjust endpoint, body and method based on type and action
    if (widget.type == 'leave') {
      method = 'PUT';
      if (action == 'approve') {
        endpoint = '$baseUrl/api/leave_approve/${widget.id}';
      } else if (action == 'reject') {
        endpoint = '$baseUrl/api/leave_reject/${widget.id}';
      }
      body = {};
      if (comment.isNotEmpty) {
        body['details'] = comment;
      }
    } else if (widget.type == 'meeting') {
      method = 'PUT';
      if (action == 'approve') {
        endpoint =
        '$baseUrl/api/office-administration/book_meeting_room/approve/${widget.id}';
      } else if (action == 'reject') {
        endpoint =
        '$baseUrl/api/office-administration/book_meeting_room/disapprove/${widget.id}';
      }
      body = {};
      if (comment.isNotEmpty) {
        body['details'] = comment;
      }
    } else if (widget.type == 'car') {
      // Existing code for car
      method = 'POST';
      endpoint = '$baseUrl/api/app/tasks/approvals/pending/${widget.id}';
      body = {
        "status": action == 'approve' ? 'Approved' : 'Rejected',
        "types": widget.type,
      };
      if (comment.isNotEmpty) {
        body['description'] = comment;
      }
    } else {
      _showErrorDialog('Error', 'Invalid request type.');
      setState(() {
        isFinalized = false;
      });
      return;
    }

    print('Sending $action request to $endpoint with body: $body');

    try {
      http.Response response;
      if (method == 'PUT') {
        response = await http.put(
          Uri.parse(endpoint),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );
      } else {
        response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );
      }

      print('Approval response status: ${response.statusCode}');
      print('Approval response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessDialog(
            'Success', 'Request has been $action successfully.');
      } else {
        final responseBody = jsonDecode(response.body);
        String errorMessage =
            responseBody['message'] ?? 'Failed to $action the request.';
        _showErrorDialog('Error', errorMessage);
      }
    } catch (e, stackTrace) {
      print('Error sending $action request: $e');
      print(stackTrace);
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