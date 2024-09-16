import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approval/edit_request.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ApprovalsViewPage extends StatelessWidget {
  final Map<String, dynamic> item;

  const ApprovalsViewPage({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.symmetric(
      horizontal: MediaQuery.of(context).size.width * 0.03, // Compact horizontal padding
    );

    return Scaffold(
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 60), // Extra top margin
            _buildRequestorSection(),
            const SizedBox(height: 30), // Extra top margin between sections
            _buildBlueSection(),
            const SizedBox(height: 20), // Extra top margin between sections
            _buildDetailsSection(),
            const SizedBox(height: 10), // Extra top margin between sections
            _buildWorkflowSection(),
            const SizedBox(height: 10), // Extra top margin between sections
            _buildDescriptionSection(),
            const SizedBox(height: 30), // Extra top margin before buttons
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
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Approvals',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 70,
    );
  }

  Widget _buildRequestorSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          backgroundImage: NetworkImage(
            item['img_name'] ??
                'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg',
          ),
          radius: 35, // Reduced size for compactness
        ),
        const SizedBox(width: 16), // Reduced space between avatar and text
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['requestor_name'] ?? 'No Name',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18, // Reduced font size for compact design
              ),
            ),
            const SizedBox(height: 6), // Reduced vertical spacing
            Text(
              'Submitted on ${item['created_at']?.split("T")[0] ?? 'N/A'}',
              style: const TextStyle(fontSize: 13, color: Colors.black), // Smaller text
            ),
            const SizedBox(height: 6), // Reduced vertical spacing
            Text(
              'Status: ${item['is_approve'] ?? 'N/A'}',
              style: const TextStyle(
                  fontSize: 15, color: Colors.orange, fontWeight: FontWeight.bold), // Slightly smaller text
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBlueSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.lightBlueAccent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        item['types'] ?? 'No Data',
        style: const TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), // Slightly reduced font size
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          item['take_leave_type_id'] ?? 'No Title',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), // Reduced font size
        ),
        const SizedBox(height: 10), // Reduced vertical spacing
        _buildInfoRow(Icons.calendar_today, 'Date', '${item['take_leave_from']} - ${item['take_leave_to']}'),
        const SizedBox(height: 10), // Reduced vertical spacing
        Text(
          'Type of leave: ${item['take_leave_reason'] ?? 'No Reason'}',
          style: const TextStyle(fontSize: 15, color: Colors.orange, fontWeight: FontWeight.bold), // Reduced font size
        ),
      ],
    );
  }

  Widget _buildWorkflowSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildUserAvatar(item['img_name']),
        const SizedBox(width: 12), // Reduced space between avatars
        const Icon(Icons.arrow_forward, color: Colors.green, size: 24), // Slightly smaller icon
        const SizedBox(width: 12),
        _buildUserAvatar('https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
        const SizedBox(width: 12),
        const Icon(Icons.arrow_forward, color: Colors.green, size: 24),
        const SizedBox(width: 12),
        _buildUserAvatar('https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
      ],
    );
  }

  Widget _buildUserAvatar(String? imageUrl) {
    return CircleAvatar(
      backgroundImage: NetworkImage(imageUrl ??
          'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
      radius: 22, // Reduced avatar size
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String content) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: Colors.black54),
        const SizedBox(width: 6),
        Text(
          '$title: ',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), // Slightly smaller font
        ),
        Text(
          content,
          style: const TextStyle(fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Description:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12), // Reduced padding
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Text(
            item['take_leave_reason'] ?? 'No Description',
            style: const TextStyle(fontSize: 15, color: Colors.black54), // Slightly smaller font
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildButton('Delete', Colors.redAccent, Colors.white, onPressed: () => _deleteRequest(context)),
        _buildButton('Edit', Colors.lightBlueAccent, Colors.white, onPressed: () => _editRequest(context)),
      ],
    );
  }

  Widget _buildButton(String label, Color color, Color textColor, {required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: textColor, backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)), // Slightly smaller font size
    );
  }

  Future<void> _deleteRequest(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token is null. Please log in again.')),
      );
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('https://demo-application-api.flexiflows.co/api/leave_cancel/${item['take_leave_request_id']}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request cancelled successfully')),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to cancel request: ${response.reasonPhrase}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  void _editRequest(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditRequestPage(item: item),
      ),
    );
  }
}
