// staff_approvals_view_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approval/edit_section/car_booking_edit_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approval/edit_section/leave_request_edit_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approval/edit_section/meeting_edit_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approval/edit_section/meeting_room_booking_edit_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApprovalsViewPage extends StatefulWidget {
  final String type;
  final String id;

  const ApprovalsViewPage({
    super.key,
    required this.type,
    required this.id,
  });

  @override
  _ApprovalsViewPageState createState() => _ApprovalsViewPageState();
}

class _ApprovalsViewPageState extends State<ApprovalsViewPage> {
  Map<String, dynamic>? data;
  bool isFinalized = false;
  bool isLoading = true;
  String? imageUrl;
  String? label;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final String type = widget.type.toLowerCase();
    final String id = widget.id;
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    String endpoint = '';

    switch (type) {
      case 'leave':
        endpoint = '$baseUrl/api/leave_request/$id';
        break;
      case 'car':
        endpoint = '$baseUrl/api/office-administration/car_permit/me/$id';
        break;
      case 'meeting room':
        endpoint = '$baseUrl/api/office-administration/book_meeting_room/my-request/$id';
        break;
      case 'meeting':
        endpoint = '$baseUrl/api/work-tracking/meeting/get-meeting/$id';
        break;
      default:
        _showErrorDialog('Error', 'Unknown request type.');
        setState(() {
          isLoading = false;
        });
        return;
    }

    try {
      final String? tokenValue = await token;
      if (tokenValue == null) {
        _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
        setState(() {
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $tokenValue',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (type == 'leave') {
          data = decoded['results'] != null && decoded['results'].isNotEmpty
              ? decoded['results'][0]
              : null;
        } else if (type == 'car') {
          data = decoded['results'];
        } else if (type == 'meeting room') {
          data = decoded['results'];
        } else if (type == 'meeting') {
          data = decoded['result'] != null && decoded['result'].isNotEmpty
              ? decoded['result'][0]
              : null;
        }
        setState(() {
          imageUrl = data?['img_path'] ??
              'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
          isLoading = false;
        });
      } else {
        _showErrorDialog('Error', 'Failed to fetch data: ${response.reasonPhrase}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
      _showErrorDialog('Error', 'An unexpected error occurred while fetching data.');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<String?> get token async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      print('Error retrieving token: $e');
      return null;
    }
  }

  String formatDate(String? dateStr, {bool includeTime = false}) {
    try {
      if (dateStr == null || dateStr.isEmpty) {
        return 'N/A';
      }
      final DateTime parsedDate = DateTime.parse(dateStr);
      return includeTime
          ? DateFormat('dd-MM-yyyy, HH:mm').format(parsedDate)
          : DateFormat('dd-MM-yyyy').format(parsedDate);
    } catch (e) {
      print('Date parsing error: $e');
      return 'Invalid Date';
    }
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
    String requestorName = data?['requestor_name'] ?? data?['employee_name'] ?? 'No Name';
    String submittedOn = '';
    switch (widget.type.toLowerCase()) {
      case 'leave':
        submittedOn = formatDate(data?['created_at']);
        break;
      case 'car':
        submittedOn = formatDate(data?['created_date']);
        break;
      case 'meeting room':
        submittedOn = formatDate(data?['date_create']);
        break;
      case 'meeting':
        submittedOn = formatDate(data?['created_at']);
        break;
      default:
        submittedOn = 'N/A';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Requestor',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(imageUrl!),
                radius: 30,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requestorName,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                    ),
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
      case 'meeting room':
        return 'Meeting Room Booking';
      default:
        return 'Approval Details';
    }
  }

  Widget _buildDetailsSection() {
    final String type = widget.type.toLowerCase();

    switch (type) {
      case 'meeting':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildInfoRow(Icons.bookmark, 'Title', data?['title'] ?? 'No Title', Colors.green),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              'Date',
              '${formatDate(data?['from_date_time'])} - ${formatDate(data?['to_date_time'])}',
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.room, 'Room', data?['room_name'] ?? 'No Room Info', Colors.orange),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.description, 'Details', data?['description'] ?? 'No Details Provided', Colors.purple),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.person, 'Employee', data?['employee_name'] ?? 'N/A', Colors.red),
          ],
        );
      case 'leave':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildInfoRow(Icons.bookmark, 'Title', data?['name'] ?? 'No Title', Colors.green),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              'Date',
              '${data?['take_leave_from'] ?? 'N/A'} - ${data?['take_leave_to'] ?? 'N/A'}',
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.time_to_leave, 'Reason', data?['take_leave_reason'] ?? 'No Reason Provided', Colors.purple),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.person, 'Employee', data?['requestor_name'] ?? 'N/A', Colors.red),
          ],
        );
      case 'car':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildInfoRow(Icons.bookmark, 'Purpose', data?['purpose'] ?? 'No Purpose', Colors.green),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.place, 'Place', data?['place'] ?? 'N/A', Colors.blue),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.directions_car, 'Vehicle ID', data?['vehicle_id'] ?? 'N/A', Colors.orange),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_today, 'Date Out', data?['date_out'] ?? 'N/A', Colors.blue),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_today, 'Date In', data?['date_in'] ?? 'N/A', Colors.blue),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.access_time, 'Time Out', data?['time_out'] ?? 'N/A', Colors.purple),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.access_time, 'Time In', data?['time_in'] ?? 'N/A', Colors.purple),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.person, 'Driver Name', data?['driver_name'] ?? 'N/A', Colors.red),
          ],
        );
      case 'meeting room':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildInfoRow(Icons.bookmark, 'Title', data?['title'] ?? 'No Title', Colors.green),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              'Date',
              '${formatDate(data?['from_date_time'])} - ${formatDate(data?['to_date_time'])}',
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.room, 'Room', data?['room_name'] ?? 'No Room Info', Colors.orange),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.description, 'Remark', data?['remark'] ?? 'No Remarks', Colors.purple),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.person, 'Employee', data?['employee_name'] ?? 'N/A', Colors.red),
          ],
        );
      default:
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
        _buildUserAvatar(imageUrl!, label: 'Requester'),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward, color: Colors.green),
        const SizedBox(width: 8),
        _buildUserAvatar(data?['line_manager_img'] ??
            'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg',
            label: 'Line Manager'),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward, color: Colors.green),
        const SizedBox(width: 8),
        _buildUserAvatar(data?['hr_img'] ??
            'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg',
            label: 'HR'),
      ],
    );
  }

  Widget _buildUserAvatar(String imageUrl, {String label = ''}) {
    return Column(
      children: [
        CircleAvatar(
          backgroundImage: NetworkImage(imageUrl),
          radius: 20,
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

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStyledButton(
          label: 'Delete',
          icon: Icons.delete,
          backgroundColor: Colors.red.shade300,
          textColor: Colors.white,
          onPressed: isFinalized ? null : () => _handleDelete(),
        ),
        _buildStyledButton(
          label: 'Edit',
          icon: Icons.edit,
          backgroundColor: Colors.blue,
          textColor: Colors.white,
          onPressed: isFinalized ? null : () => _handleEdit(),
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

  Future<void> _handleEdit() async {
    setState(() {
      isFinalized = true;
    });

    final String type = widget.type.toLowerCase();

    switch (type) {
      case 'meeting':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MeetingEditPage(item: data!),
          ),
        );
        break;
      case 'leave':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LeaveRequestEditPage(item: data!),
          ),
        );
        break;
      case 'car':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CarBookingEditPage(item: data!),
          ),
        );
        break;
      case 'meeting room':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MeetingRoomBookingEditPage(item: data!),
          ),
        );
        break;
      default:
        _showErrorDialog('Error', 'Unknown request type.');
    }

    setState(() {
      isFinalized = false;
    });
  }

  Future<void> _handleDelete() async {
    final String type = widget.type.toLowerCase();
    final String id = widget.id;
    const String baseUrl = 'https://demo-application-api.flexiflows.co';

    if (id.isEmpty) {
      _showErrorDialog('Invalid Data', 'Request ID is missing.');
      return;
    }

    final String? tokenValue = await token;
    if (tokenValue == null) {
      _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
      return;
    }

    setState(() {
      isFinalized = true;
    });

    try {
      http.Response response;

      switch (type) {
        case 'leave':
          response = await http.put(
            Uri.parse('$baseUrl/api/leave_cancel/$id'),
            headers: {
              'Authorization': 'Bearer $tokenValue',
              'Content-Type': 'application/json',
            },
          );
          if (response.statusCode == 200 || response.statusCode == 201) {
            _showSuccessDialog('Success', 'Leave request deleted successfully.');
          } else {
            _showErrorDialog('Error', 'Failed to delete leave request: ${response.reasonPhrase}');
          }
          break;

        case 'car':
          response = await http.delete(
            Uri.parse('$baseUrl/api/office-administration/car_permit/$id'),
            headers: {
              'Authorization': 'Bearer $tokenValue',
              'Content-Type': 'application/json',
            },
          );
          if (response.statusCode == 200 || response.statusCode == 204) {
            _showSuccessDialog('Success', 'Car permit deleted successfully.');
          } else {
            _showErrorDialog('Error', 'Failed to delete car permit: ${response.reasonPhrase}');
          }
          break;

        case 'meeting room':
          response = await http.delete(
            Uri.parse('$baseUrl/api/office-administration/book_meeting_room/$id'),
            headers: {
              'Authorization': 'Bearer $tokenValue',
              'Content-Type': 'application/json',
            },
          );
          if (response.statusCode == 200 || response.statusCode == 204) {
            _showSuccessDialog('Success', 'Meeting room booking deleted successfully.');
          } else {
            _showErrorDialog('Error', 'Failed to delete meeting room booking: ${response.reasonPhrase}');
          }
          break;

        case 'meeting':
          response = await http.put(
            Uri.parse('$baseUrl/api/work-tracking/meeting/delete/$id'),
            headers: {
              'Authorization': 'Bearer $tokenValue',
              'Content-Type': 'application/json',
            },
          );
          if (response.statusCode == 200 || response.statusCode == 201) {
            _showSuccessDialog('Success', 'Meeting deleted successfully.');
          } else {
            _showErrorDialog('Error', 'Failed to delete meeting: ${response.reasonPhrase}');
          }
          break;

        default:
          _showErrorDialog('Error', 'Unknown request type.');
      }
    } catch (e) {
      print('Error deleting request: $e');
      _showErrorDialog('Error', 'An unexpected error occurred while deleting the request.');
    }

    setState(() {
      isFinalized = false;
    });
  }

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
            },
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
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : data == null
          ? const Center(
        child: Text(
          'No Data Available',
          style: TextStyle(fontSize: 16, color: Colors.red),
        ),
      )
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildRequestorSection(),
              _buildBlueSection(),
              const SizedBox(height: 12),
              _buildDetailsSection(),
              const SizedBox(height: 12),
              _buildWorkflowSection(),
              const SizedBox(height: 20),
              _buildActionButtons(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
