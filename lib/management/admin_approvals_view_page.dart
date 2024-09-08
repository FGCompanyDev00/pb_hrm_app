import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AdminApprovalsViewPage extends StatefulWidget {
  final Map<String, dynamic> item;

  const AdminApprovalsViewPage({super.key, required this.item});

  @override
  _AdminApprovalsViewPageState createState() => _AdminApprovalsViewPageState();
}

class _AdminApprovalsViewPageState extends State<AdminApprovalsViewPage> {
  final TextEditingController _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0), // More compact padding
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
              const SizedBox(height: 16), // Compact padding at bottom
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
        const SizedBox(height: 8), // Reduced spacing
        Text(
          widget.item['requestor_name'] ?? 'No Name',
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4), // Reduced spacing
        Text(
          'Submitted on ${widget.item['created_at']?.split("T")[0] ?? 'N/A'} - ${widget.item['created_at']?.split("T")[1] ?? ''}',
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildBlueSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.lightBlueAccent.withOpacity(0.8), // Slight transparency
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
        _buildInfoRow(Icons.bookmark, 'Title', widget.item['name'] ?? 'No Title'),
        const SizedBox(height: 8),
        _buildInfoRow(Icons.calendar_today, 'Date',
            '${widget.item['take_leave_from']} - ${widget.item['take_leave_to']}'),
        const SizedBox(height: 8),
        _buildInfoRow(Icons.access_time, 'Time', '09:00 AM - 12:00 PM'),
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
        _buildUserAvatar(widget.item['img_name']),
        const Icon(Icons.arrow_forward, color: Colors.green),
        _buildUserAvatar(
            'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
        const Icon(Icons.arrow_forward, color: Colors.green),
        _buildUserAvatar(
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
        Icon(icon, size: 18), // Smaller icon
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
        _buildButton('Reject', Colors.grey.shade300, Colors.black,
            onPressed: () => _submitDecision(context, 'Reject')),
        _buildButton('Approve', Colors.green, Colors.white,
            onPressed: () => _submitDecision(context, 'Approve')),
      ],
    );
  }

  Widget _buildButton(String label, Color color, Color textColor,
      {required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: textColor,
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), // Compact padding
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10), // Modern rounded corners
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }

  Future<void> _submitDecision(BuildContext context, String decision) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final comment = _descriptionController.text;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token is null. Please log in again.')),
      );
      return;
    }

    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a comment.')),
      );
      return;
    }

    final response = await http.post(
      Uri.parse('https://demo-application-api.flexiflows.co/api/leave_replies'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: '{"leave_reply_id": "1", "leave_request_id": "${widget.item['take_leave_request_id']}", "decide": "$decision", "details": "$comment"}',
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request $decision successfully')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to $decision request: ${response.reasonPhrase}')),
      );
    }
  }
}
