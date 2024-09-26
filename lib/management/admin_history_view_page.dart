import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminHistoryViewPage extends StatefulWidget {
  final Map<String, dynamic> item;

  const AdminHistoryViewPage({super.key, required this.item});

  @override
  _AdminHistoryViewPageState createState() => _AdminHistoryViewPageState();
}

class _AdminHistoryViewPageState extends State<AdminHistoryViewPage> {
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

  String formatDate(String? dateStr) {
    try {
      if (dateStr == null || dateStr.isEmpty) {
        return 'N/A';
      }
      final DateTime parsedDate = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(parsedDate);
    } catch (e) {
      print('Date parsing error: $e');
      return 'Invalid Date';
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

    Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'rejected':
        return Colors.red;
      case 'approved':
        return Colors.green;
      case 'processing':
        return Colors.orange;
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
     final statusColor = _getStatusColor(widget.item['status']);
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRequestorSection(statusColor),
          
              _buildBlueSection(),
              const SizedBox(height: 12),
              _buildDetailsSection(),
              const SizedBox(height: 12),
              _buildWorkflowSection(),
              const SizedBox(height: 12),
              _buildCommentInputSection(),
              const SizedBox(height: 20),
              _buildActionButtons(context,statusColor),
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

  Widget _buildApproverSection(Map<String, dynamic> item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          backgroundImage: NetworkImage(item['approver_image'] ?? 'https://via.placeholder.com/150'),
          radius: 18,
        ),
        const SizedBox(width: 6),
        const Icon(Icons.arrow_forward, color: Colors.orange, size: 20),
        const SizedBox(width: 6),
        CircleAvatar(
          backgroundImage: NetworkImage(item['supervisor_image'] ?? 'https://via.placeholder.com/150'),
          radius: 18,
        ),
      ],
    );
  }

  Widget _buildRequestorSection(Color statusColor) {
    String requestorName = widget.item['employee_name'] ?? 'No Name';
    String submittedOn = formatDate(widget.item['created_at']);

    print('Requestor Info: ${widget.item}');
    final String types = widget.item['types'] ?? 'Unknown';
    if (types == 'leave') {
      submittedOn = widget.item['created_at']?.split("T")[0] ?? 'N/A';
    } else if (types == 'meeting') {
      submittedOn = widget.item['date_create']?.split("T")[0] ?? 'N/A';
    } else if (types == 'car') {
      submittedOn = widget.item['created_date']?.split("T")[0] ?? 'N/A';
    }

   return Padding(
     padding: const EdgeInsets.only(bottom:40.0),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.center, // Align the content in the center
       children: [
      // Requestor Text
     Padding(
       padding: const EdgeInsets.only(bottom:8.0),
       child: Text(
        widget.item['status'] ?? 'UNKNOWN',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 25  ,
          color: statusColor,
        ),
           ),
     ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(widget.item['img_name'] ??
                'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
            radius: 40, // Adjust the size of the avatar
          ),
          const SizedBox(width: 12), // Space between avatar and text
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
      padding: const EdgeInsets.only(bottom:20.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.lightBlueAccent.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Meeting and Booking Meeting Room',
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    final String types = widget.item['types'] ?? 'Unknown';

    if (types == 'meeting') {
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
          // _buildInfoRow(Icons.place, 'Place', widget.item['room'] ?? 'No Place Info', Colors.orange),
          // const SizedBox(height: 8),
          // _buildInfoRow(Icons.description, 'Details', widget.item['details'] ?? 'No Details Provided', Colors.purple),
          // const SizedBox(height: 8),
          // _buildInfoRow(Icons.person, 'Employee', widget.item['employee_name'] ?? 'N/A', Colors.red),
          // const SizedBox(height: 8),
          _buildInfoRowBelow('Room',widget.item['room']?? 'N/A'),
        ],
      );
    } else if (types == 'leave') {
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
          // _buildInfoRow(Icons.place, 'Place', widget.item['room'] ?? 'No Place Info', Colors.orange),
          // const SizedBox(height: 8),
          // _buildInfoRow(Icons.description, 'Details', widget.item['details'] ?? 'No Details Provided', Colors.purple),
          // const SizedBox(height: 8),
          // _buildInfoRow(Icons.person, 'Employee', widget.item['employee_name'] ?? 'N/A', Colors.red),
          // const SizedBox(height: 8),
         
        ],
      );
    } else if (types == 'car') {
    
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
          // _buildInfoRow(Icons.place, 'Place', widget.item['room'] ?? 'No Place Info', Colors.orange),
          // const SizedBox(height: 8),
          // _buildInfoRow(Icons.description, 'Details', widget.item['details'] ?? 'No Details Provided', Colors.purple),
          // const SizedBox(height: 8),
          // _buildInfoRow(Icons.person, 'Employee', widget.item['employee_name'] ?? 'N/A', Colors.red),
          // const SizedBox(height: 8),
          _buildInfoRowBelow('Discreption',widget.item['employee_tel']?? 'N/A'),
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

// Widget _buildInfoRow(IconData icon, String title, String content, Color color) {
//   return Center(
//     child: Row(
//       mainAxisSize: MainAxisSize.min, // Shrinks the row to fit its content
//       children: [
//         Icon(icon, size: 18, color: color),
//         const SizedBox(width: 4),
//         Text(
//           '$title: $content',
//           style: const TextStyle(fontSize: 14, color: Colors.black),
//         ),
//       ],
//     ),
//   );
// }

Widget _buildInfoRow(IconData icon, String title, String content, Color color) {
  return Center(
    child: SizedBox(
      width:300.0, // Make the row take the full available width
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, // Aligns the content inside the row to the start
        crossAxisAlignment: CrossAxisAlignment.start, // Ensures content is vertically centered
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$title: $content',
              style: const TextStyle(fontSize: 14, color: Colors.black),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildInfoRowBelow(String title, String content) {
  return Center(
    child: SizedBox(
      width:180.0, // Make the row take the full available width
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, // Aligns the content inside the row to the start
        crossAxisAlignment: CrossAxisAlignment.start, // Ensures content is vertically centered
        children: [
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$title: $content',
              style: const TextStyle(fontSize: 20, color: Colors.orange),
            ),
          ),
        ],
      ),
    ),
  );
}



Widget _buildCommentInputSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start, 
    children: [
      const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Description', 
          style: TextStyle(fontSize: 14, color: Colors.black),
        ),
      ),
      const SizedBox(height: 8), // Add spacing between the label and the container
      TextField(
        controller: TextEditingController(text: widget.item['details'] ?? 'No Description available'),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          filled: true, 
          fillColor: Colors.grey[200], 
        ),
        readOnly: true, 
        maxLines: 3, 
        style: const TextStyle(color: Colors.black54, fontSize: 14),
      ),
    ],
  );
}


  Widget _buildActionButtons(BuildContext context, Color statusColor) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
     Text(
        '${widget.item['status']} - ${widget.item['status_date'] ?? 'N/A'}',
        style: TextStyle(color: statusColor, fontSize: 14),
        textAlign: TextAlign.center,
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
        borderRadius: BorderRadius.circular(30), // Rounded corners like in the Figma
      ),
    ),
    icon: Icon(
      icon,
      color: textColor,
      size: 18, // Adjust size to match the design
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
