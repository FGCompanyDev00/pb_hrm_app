// notification_detail_page.dart

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

class _NotificationDetailPageState extends State<NotificationDetailPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _descriptionController = TextEditingController();
  bool isLoading = true;
  bool isFinalized = false;
  Map<String, dynamic>? approvalData;
  String? requestorImage;
  String? userResponse;
  late AnimationController _animationController;
  late Animation<double> _animation;

  final String _imageBaseUrl =
      'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/';

  @override
  void initState() {
    super.initState();
    _fetchApprovalDetails();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
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

      if (widget.type == 'leave') {
        apiUrl = '$baseUrl/api/leave_request/all/${widget.id}';
      } else if (widget.type == 'car') {
        apiUrl = '$baseUrl/api/office-administration/car_permit/${widget.id}';
      } else if (widget.type == 'meeting') {
        apiUrl = '$baseUrl/api/office-administration/book_meeting_room/${widget.id}';
      } else {
        throw Exception('Unknown type: ${widget.type}');
      }

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if ((data['statusCode'] == 200 || data['statusCode'] == 201) &&
            data['results'] != null) {
          setState(() {
            approvalData = widget.type == 'leave'
                ? Map<String, dynamic>.from(data['results'][0])
                : Map<String, dynamic>.from(data['results']);

            if (widget.type == 'leave') {
              String? imgPath =
              approvalData!['img_path']?.toString().trim();
              if (imgPath != null && imgPath.isNotEmpty) {
                requestorImage = imgPath;
              } else {
                requestorImage =
                'https://via.placeholder.com/150';
              }
            } else {
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

            if (widget.type == 'meeting') {
              userResponse =
                  approvalData!['user_response']?.toString().toLowerCase();
            }

            isLoading = false;
          });
        } else {
          throw Exception(
              data['message'] ?? 'Failed to load approval details.');
        }
      } else {
        throw Exception(
            'Failed to load approval details: ${response.statusCode}');
      }
    } catch (e) {
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
    } catch (e) {
      return 'Invalid Date';
    }
  }

  Future<String?> _getToken() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
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
            if (widget.type == 'meeting') ...[
              _buildMeetingActionButtons(),
            ] else ...[
              if (isPendingStatus(status)) ...[
                _buildCommentInputSection(),
                const SizedBox(height: 22),
                _buildActionButtons(),
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
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(profileImage),
              radius: 35,
              backgroundColor: Colors.grey[300],
              onBackgroundImageError: (error, stackTrace) {},
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(requestorName,
                    style: const TextStyle(
                        color: Colors.black, fontSize: 18)),
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
        _buildInfoRow('Leave Request ID',
            approvalData?['take_leave_request_id']?.toString() ?? 'N/A',
            Icons.assignment, Colors.green),
        const SizedBox(height: 8),
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
        _buildInfoRow('Car Booking ID',
            approvalData?['id']?.toString() ?? 'N/A', Icons.directions_car,
            Colors.green),
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
        _buildInfoRow('Place',
            approvalData?['place']?.toString() ?? 'N/A', Icons.place,
            Colors.orange),
        const SizedBox(height: 8),
        _buildInfoRow('Status',
            approvalData?['status']?.toString() ?? 'Pending', Icons.stairs,
            Colors.red),
      ],
    );
  }

  Widget _buildMeetingDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Meeting ID',
            approvalData?['meeting_id']?.toString() ?? 'N/A',
            Icons.meeting_room, Colors.green),
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
        _buildInfoRow('Room Name',
            approvalData?['room_name']?.toString() ?? 'N/A', Icons.room,
            Colors.orange),
        const SizedBox(height: 8),
        _buildInfoRow('Status',
            approvalData?['status']?.toString() ?? 'Pending', Icons.stairs,
            Colors.red),
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
              style:
              const TextStyle(fontSize: 16, color: Colors.black)),
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
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20)),
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

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStyledButton(
            label: 'Reject',
            icon: Icons.close,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            onPressed: isFinalized ? null : () => _handleReject()),
        _buildStyledButton(
            label: 'Approve',
            icon: Icons.check_circle_outline,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            onPressed: isFinalized ? null : () => _handleApprove()),
      ],
    );
  }

  Widget _buildMeetingActionButtons() {
    bool alreadyResponded = userResponse != null;
    String responseLabel = '';
    Color buttonColor = Colors.grey;
    IconData buttonIcon = Icons.check;

    if (userResponse == 'join') {
      responseLabel = 'Joined';
      buttonColor = Colors.blue;
      buttonIcon = Icons.check;
    } else if (userResponse == 'decline') {
      responseLabel = 'Declined';
      buttonColor = Colors.red;
      buttonIcon = Icons.close;
    } else if (userResponse == 'undecided') {
      responseLabel = 'Undecided';
      buttonColor = Colors.orange;
      buttonIcon = Icons.help_outline;
    }

    return Column(
      children: [
        alreadyResponded
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                backgroundColor: buttonColor,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              icon:
              Icon(buttonIcon, color: Colors.white, size: 20),
              label: Text(responseLabel,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ],
        )
            : Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            _buildResponsiveButton(
              label: 'Join',
              icon: Icons.person_add,
              backgroundColor: Colors.blue,
              textColor: Colors.white,
              onPressed: () => _handleMeetingAction('join'),
            ),
            _buildResponsiveButton(
              label: 'Decline',
              icon: Icons.close,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              onPressed: () => _handleMeetingAction('decline'),
            ),
            _buildResponsiveButton(
              label: 'Undecided',
              icon: Icons.help_outline,
              backgroundColor: Colors.orange,
              textColor: Colors.white,
              onPressed: () => _handleMeetingAction('undecided'),
            ),
          ],
        ),
        if (_animationController.isAnimating)
          ScaleTransition(
            scale: _animation,
            child: const Icon(
              Icons.celebration,
              color: Colors.pink,
              size: 50,
            ),
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
        const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30)),
      ),
      icon: Icon(icon, color: textColor, size: 20),
      label: Text(label,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor)),
    );
  }

  Widget _buildResponsiveButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.28,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30)),
        ),
        icon: Icon(icon, color: textColor, size: 20),
        label: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor)),
      ),
    );
  }

  Future<void> _handleApprove() async {
    await _sendApprovalStatus('approve');
  }

  Future<void> _handleReject() async {
    await _sendApprovalStatus('reject');
  }

  Future<void> _handleMeetingAction(String action) async {
    final String uid = widget.id;
    final String baseUrl = 'https://demo-application-api.flexiflows.co';

    String endpoint;

    if (action == 'join') {
      endpoint = '$baseUrl/api/office-administration/book_meeting_room/yes/$uid';
    } else if (action == 'decline' || action == 'undecided') {
      endpoint = '$baseUrl/api/office-administration/book_meeting_room/no/$uid';
    } else {
      _showErrorDialog('Error', 'Invalid action.');
      return;
    }

    setState(() {
      isFinalized = true;
    });

    try {
      final String? token = await _getToken();
      if (token == null) {
        _showErrorDialog(
            'Authentication Error', 'Token not found. Please log in again.');
        setState(() {
          isFinalized = false;
        });
        return;
      }

      final response = await http.put(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          userResponse = action;
        });
        _animationController.forward().then((_) {
          _animationController.reset();
        });
        _showSuccessDialog(
            'Success',
            'You have successfully ${action == 'join' ? 'joined' : 'responded to'} the meeting invite.');
        Navigator.of(context).pop(true);
      } else {
        final responseBody = jsonDecode(response.body);
        String errorMessage =
            responseBody['message'] ?? 'Failed to $action the meeting invite.';
        _showErrorDialog('Error', errorMessage);
        setState(() {
          isFinalized = false;
        });
      }
    } catch (e) {
      _showErrorDialog('Error', 'An unexpected error occurred.');
      setState(() {
        isFinalized = false;
      });
    }
  }

  Future<void> _sendApprovalStatus(String action) async {
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
    String method = 'POST';

    if (widget.type == 'leave') {
      method = 'PUT';
      if (action == 'approve') {
        endpoint = '$baseUrl/api/leave_approve/${widget.id}';
      } else if (action == 'reject') {
        endpoint = '$baseUrl/api/leave_reject/${widget.id}';
      }
      body = {};
    } else if (widget.type == 'car') {
      method = 'POST';
      endpoint = '$baseUrl/api/app/tasks/approvals/pending/${widget.id}';
      body = {
        "status": action == 'approve' ? 'Approved' : 'Rejected',
        "types": widget.type,
      };
    } else {
      _showErrorDialog('Error', 'Invalid request type.');
      setState(() {
        isFinalized = false;
      });
      return;
    }

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

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessDialog(
            'Success', 'Request has been $action successfully.');
        await _fetchApprovalDetails();
        Navigator.of(context).pop(true);
      } else {
        final responseBody = jsonDecode(response.body);
        String errorMessage =
            responseBody['message'] ?? 'Failed to $action the request.';
        _showErrorDialog('Error', errorMessage);
        setState(() {
          isFinalized = false;
        });
      }
    } catch (e) {
      _showErrorDialog('Error', 'An unexpected error occurred.');
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
              Navigator.of(ctx).pop();
              if (widget.type == 'meeting') {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
