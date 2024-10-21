import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminHistoryViewPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final String type;
  final String id;

  const AdminHistoryViewPage({
    super.key,
    required this.item,
    required this.type,
    required this.id,
  });

  @override
  _AdminHistoryViewPageState createState() => _AdminHistoryViewPageState();
}

class _AdminHistoryViewPageState extends State<AdminHistoryViewPage> {
  String? lineManagerImage;
  String? hrImage;
  bool isLoading = true;
  String? status;

  @override
  void initState() {
    super.initState();
    _initializeHistory();
  }

  Future<void> _initializeHistory() async {
    await _fetchImages();
    _setStatus();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _fetchImages() async {
    setState(() {
      lineManagerImage = widget.item['line_manager_img'] ??
          'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
      hrImage = widget.item['hr_img'] ??
          'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
    });
  }

  void _setStatus() {
    final String type = widget.type.toLowerCase();
    switch (type) {
      case 'leave':
        bool? isApprove = widget.item['is_approve'];
        status = isApprove == true ? 'Approved' : 'Rejected';
        break;
      case 'meeting':
        status = widget.item['s_name'] ?? 'Unknown';
        break;
      case 'car':
      case 'meeting room':
        status = widget.item['status'] ?? 'Unknown';
        break;
      default:
        status = 'Unknown';
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
    return Scaffold(
      appBar: _buildAppBar(context),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildRequestorSection(),
              _buildBlueSection(),
              const SizedBox(height: 16),
              _buildDetailsSection(),
              const SizedBox(height: 16),
              _buildWorkflowSection(),
              const SizedBox(height: 16),
              _buildOverallStatusIndicator(),
              const SizedBox(height: 16),
              _buildCommentsSection(),
              const SizedBox(height: 20),
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
        'History Detail',
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
                backgroundImage: NetworkImage(widget.item['img_name'] ??
                    'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
                radius: 30,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requestorName,
                    style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
              Icons.bookmark,
              'Title',
              widget.item['title'] ?? 'No Title',
              Colors.green),
          const SizedBox(height: 8),
          _buildInfoRow(
              Icons.calendar_today,
              'Date',
              '${widget.item['startDate'] ?? 'N/A'} - ${widget.item['endDate'] ?? 'N/A'}',
              Colors.blue),
          const SizedBox(height: 8),
          _buildInfoRow(
              Icons.meeting_room,
              'Room',
              widget.item['room'] ?? 'No Room Info',
              Colors.orange),
          const SizedBox(height: 8),
          _buildInfoRow(
              Icons.description,
              'Details',
              widget.item['details'] ?? 'No Details Provided',
              Colors.purple),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.person, 'Employee',
              widget.item['employee_name'] ?? 'N/A', Colors.red),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.info, 'Status', status ?? 'Unknown', Colors.blue),
        ],
      );
    } else if (type == 'leave') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
              Icons.bookmark,
              'Title',
              widget.item['title'] ?? 'No Title',
              Colors.green),
          const SizedBox(height: 8),
          _buildInfoRow(
              Icons.calendar_today,
              'Date',
              '${widget.item['startDate'] ?? 'N/A'} - ${widget.item['endDate'] ?? 'N/A'}',
              Colors.blue),
          const SizedBox(height: 8),
          _buildInfoRow(
              Icons.time_to_leave,
              'Reason',
              widget.item['details'] ?? 'No Reason Provided',
              Colors.purple),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.person, 'Employee',
              widget.item['employee_name'] ?? 'N/A', Colors.red),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.info, 'Status', status ?? 'Unknown', Colors.blue),
        ],
      );
    } else if (type == 'car') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
              Icons.bookmark,
              'Title',
              widget.item['title'] ?? 'No Title',
              Colors.green),
          const SizedBox(height: 8),
          _buildInfoRow(
              Icons.calendar_today,
              'Date',
              '${widget.item['startDate'] ?? 'N/A'} - ${widget.item['endDate'] ?? 'N/A'}',
              Colors.blue),
          const SizedBox(height: 8),
          _buildInfoRow(
              Icons.access_time_rounded,
              'Time',
              '${widget.item['time'] ?? 'N/A'} - ${widget.item['time_end'] ?? 'N/A'}',
              Colors.blue),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.place, 'Room',
              widget.item['room'] ?? 'N/A', Colors.orange),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.info, 'Status', status ?? 'Unknown', Colors.blue),
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
        _buildUserAvatar(widget.item['img_name'],
            radius: 20, label: 'Requester', status: 'N/A'),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward, color: Colors.green),
        const SizedBox(width: 8),
        _buildUserAvatar(lineManagerImage,
            radius: 20, label: 'Line Manager', status: status ?? 'Unknown'),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward, color: Colors.green),
        const SizedBox(width: 8),
        _buildUserAvatar(hrImage,
            radius: 20, label: 'HR', status: 'N/A'),
      ],
    );
  }

  Widget _buildUserAvatar(String? imageUrl,
      {double radius = 20, String label = '', String status = 'N/A'}) {
    Color? statusColor;
    if (status == 'Approved') {
      statusColor = Colors.green;
    } else if (status == 'Rejected') {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.grey;
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
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        ),
        if (status != 'N/A' && status != 'Unknown')
          Text(
            status,
            style: TextStyle(fontSize: 10, color: statusColor),
          ),
      ],
    );
  }

  Widget _buildOverallStatusIndicator() {
    return Column(
      children: [
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
    if (status == 'Approved') {
      return 'Approved';
    } else if (status == 'Rejected') {
      return 'Rejected';
    } else {
      return 'Unknown';
    }
  }

  Color _getOverallStatusColor() {
    String currentStatus = _determineOverallStatus();
    switch (currentStatus.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInfoRow(
      IconData icon, String title, String content, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$title: $content',
              style: const TextStyle(fontSize: 16, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Comments',
            style: TextStyle(
                fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.item['comments'] ?? 'No comments available.',
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
