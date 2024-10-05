import 'package:flutter/material.dart';

class FinishStaffApprovalsPage extends StatelessWidget {
  final Map<String, dynamic> item;

  const FinishStaffApprovalsPage({super.key, required this.item});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Approved':
        return Icons.check_circle;
      case 'Rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = item['is_approve'] ?? 'Unknown';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          'Request Approval Result',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Status Box with Increased Spacing Below AppBar
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20.0),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    statusIcon, // Status icon
                    color: statusColor,
                    size: 40,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Leave Button with Increased Spacing Below Status Box
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A0E3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    'Leave',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Leave Details with Increased Spacing
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.title, color: Colors.black54),
                    const SizedBox(width: 8),
                    const Text(
                      'Title : ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      item['title'] ?? 'No Title',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.black54),
                    const SizedBox(width: 8),
                    const Text(
                      'Date : ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${item['take_leave_from']} - ${item['take_leave_to']}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.access_time, color: Colors.black54),
                    const SizedBox(width: 8),
                    const Text(
                      'Time : ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${item['time_from']} - ${item['time_to']}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.phone, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text(
                      'Discretion : ',
                      style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      item['discretion'] ?? 'N/A',
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Approver Details with Increased Spacing
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(item['approver_image'] ??
                      'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
                  radius: 30,
                ),
                const SizedBox(width: 16),
                const Icon(Icons.arrow_forward, color: Colors.orange, size: 30),
                const SizedBox(width: 16),
                CircleAvatar(
                  backgroundImage: NetworkImage(item['supervisor_image'] ??
                      'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
                  radius: 30,
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Description Section with Increased Spacing
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Description:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  item['description'] ?? 'No Description available',
                  style: const TextStyle(color: Colors.black54, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (status == 'Rejected')
                  Text(
                    'Rejected - ${item['rejection_date'] ?? 'N/A'}',
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                if (status == 'Approved')
                  Text(
                    'Approved - ${item['approval_date'] ?? 'N/A'}',
                    style: const TextStyle(color: Colors.green, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
