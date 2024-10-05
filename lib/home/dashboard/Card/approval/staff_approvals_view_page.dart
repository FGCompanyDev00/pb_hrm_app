import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approval/staff_edit_request.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ApprovalsViewPage extends StatefulWidget {
  final Map<String, dynamic> item;

  const ApprovalsViewPage({super.key, required this.item});

  @override
  _ApprovalsViewPageState createState() => _ApprovalsViewPageState();
}

class _ApprovalsViewPageState extends State<ApprovalsViewPage> {
  late Map<String, dynamic> item;

  @override
  void initState() {
    super.initState();
    item = widget.item;
  }

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.symmetric(
      horizontal: MediaQuery.of(context).size.width * 0.03,
    );

    return Scaffold(
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            _buildRequestorSection(),
            const SizedBox(height: 30),
            _buildBlueSection(),
            const SizedBox(height: 20),
            _buildDetailsSection(),
            const SizedBox(height: 10),
            _buildWorkflowSection(),
            const SizedBox(height: 10),
            _buildDescriptionSection(),
            const SizedBox(height: 30),
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
        onPressed: () => Navigator.of(context).pop(true),
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
          radius: 35,
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['requestor_name'] ?? 'No Name',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Submitted on ${item['created_at']?.split("T")[0] ?? 'N/A'}',
              style: const TextStyle(fontSize: 13, color: Colors.black),
            ),
            const SizedBox(height: 6),
            Text(
              'Status: ${item['is_approve'] ?? 'N/A'}',
              style: const TextStyle(
                  fontSize: 15, color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBlueSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.lightBlueAccent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        item['types'] ?? 'No Data',
        style: const TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          item['take_leave_type_id'] ?? 'No Title',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        _buildInfoRow(Icons.calendar_today, 'Date', '${item['take_leave_from']} - ${item['take_leave_to']}'),
        const SizedBox(height: 10),
        Text(
          'Type of leave: ${item['take_leave_reason'] ?? 'No Reason'}',
          style: const TextStyle(fontSize: 15, color: Colors.orange, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildWorkflowSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildUserAvatar(item['img_name']),
        const SizedBox(width: 12),
        const Icon(Icons.arrow_forward, color: Colors.green, size: 24),
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
      radius: 22,
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
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Text(
            item['take_leave_reason'] ?? 'No Description',
            style: const TextStyle(fontSize: 15, color: Colors.black54),
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
      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

      if (response.statusCode == 200 || response.statusCode == 201) {
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

  Future<void> _refreshData(BuildContext context) async {
    setState(() {});
  }

  void _editRequest(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditRequestPage(item: item),
      ),
    );

    if (result == true) {
      _refreshData(context);  // Refresh the page to reflect updated data
    }
  }
}
