import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AdminApprovalsViewPage extends StatelessWidget {
  final Map<String, dynamic> item;

  const AdminApprovalsViewPage({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0), // Increased padding for better spacing
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildRequestorSection(),
              const SizedBox(height: 24), // Increased margin top
              _buildBlueSection(),
              const SizedBox(height: 24), // Increased spacing between sections
              _buildDetailsSection(),
              const SizedBox(height: 24), // Increased spacing between sections
              _buildWorkflowSection(),
              const SizedBox(height: 24), // Increased spacing between sections
              _buildDescriptionSection(),
              const Spacer(),
              _buildActionButtons(context), // Admin action buttons with context passed
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
      title: const Text('Approvals'),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  Widget _buildRequestorSection() {
    return Column(
      children: [
        CircleAvatar(
          backgroundImage: NetworkImage(item['img_name'] ?? 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
          radius: 40,
        ),
        const SizedBox(height: 12), // Slightly increased spacing
        Text(
          item['requestor_name'] ?? 'No Name',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          'Submitted on ${item['created_at']?.split("T")[0] ?? 'N/A'} - ${item['created_at']?.split("T")[1] ?? ''}',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildBlueSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24), // Increased padding for more emphasis
      decoration: BoxDecoration(
        color: Colors.lightBlueAccent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Leave',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center, // Center alignment for details
      children: [
        _buildInfoRow(Icons.bookmark, 'Title', item['name'] ?? 'No Title'),
        const SizedBox(height: 12), // Slightly increased spacing
        _buildInfoRow(Icons.calendar_today, 'Date', '${item['take_leave_from']} - ${item['take_leave_to']}'),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.access_time, 'Time', '09:00 AM - 12:00 PM'), // Update time details based on requirement
        const SizedBox(height: 12),
        Text(
          'Type of leave: ${item['take_leave_reason'] ?? 'No Reason'}',
          style: const TextStyle(fontSize: 16, color: Colors.orange),
        ),
      ],
    );
  }

  Widget _buildWorkflowSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildUserAvatar(item['img_name']),
        const Icon(Icons.arrow_forward, color: Colors.green),
        _buildUserAvatar('https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'), // Replace with actual image URL for manager
        const Icon(Icons.arrow_forward, color: Colors.green),
        _buildUserAvatar('https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'), // Replace with actual image URL for manager
      ],
    );
  }

  Widget _buildUserAvatar(String? imageUrl) {
    return CircleAvatar(
      backgroundImage: NetworkImage(imageUrl ?? 'https://fallback-image-url.com/default_avatar.jpg'),
      radius: 20,
      onBackgroundImageError: (_, __) {
        if (kDebugMode) {
          print('Failed to load image. Displaying fallback avatar.');
        }
      },
      backgroundColor: Colors.grey[200],
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String content) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // Centering the rows
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text('$title: $content'),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center, // Center alignment for the description section
      children: [
        const Text('Description:'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12), // Increased padding for more emphasis
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            item['take_leave_reason'] ?? 'No Description',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildButton('Reject', Colors.red, Colors.white, onPressed: () => _rejectRequest(context)),
        _buildButton('Approve', Colors.green, Colors.white, onPressed: () => _approveRequest(context)),
      ],
    );
  }

  Widget _buildButton(String label, Color color, Color textColor, {required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: textColor, backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 16)),
    );
  }

  Future<void> _approveRequest(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token is null. Please log in again.')),
      );
      return;
    }

    final responseManager = await http.put(
      Uri.parse('https://demo-application-api.flexiflows.co/api/leave_processing/${item['take_leave_request_id']}'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (responseManager.statusCode == 202) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request accepted. Processing...')),
      );
      // Optionally implement polling or wait for a webhook notification.
    } else if (responseManager.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request updated successfully')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve request: ${responseManager.reasonPhrase}')),
      );
    }
  }

  Future<void> _rejectRequest(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token is null. Please log in again.')),
      );
      return;
    }

    final response = await http.put(
      Uri.parse('https://demo-application-api.flexiflows.co/api/leave_reject/${item['take_leave_request_id']}'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 202) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request to reject accepted. Processing...')),
      );

      // Optionally: Implement a polling mechanism to check the status of the rejection
      await _pollForRejectionCompletion(context);

    } else if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request rejected successfully')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject request: ${response.reasonPhrase}')),
      );
    }
  }

  Future<void> _pollForRejectionCompletion(BuildContext context) async {
    // Polling to check the status every few seconds
    // This is a simple example, adjust according to your API capabilities
    bool isRejected = false;

    for (int i = 0; i < 5; i++) { // Poll 5 times, adjust the number of retries
      await Future.delayed(const Duration(seconds: 2)); // Wait for 2 seconds before each poll

      final response = await _checkRejectionStatus();

      if (response.statusCode == 200 && response.body.contains('rejected')) {
        isRejected = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request rejected successfully')),
        );
        Navigator.pop(context, true);
        break;
      }
    }

    if (!isRejected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request rejection is still processing. Please check back later.')),
      );
    }
  }

  Future<http.Response> _checkRejectionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    return await http.get(
      Uri.parse('https://demo-application-api.flexiflows.co/api/check_rejection_status/${item['take_leave_request_id']}'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
  }

}
