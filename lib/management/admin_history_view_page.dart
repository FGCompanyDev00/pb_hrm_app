import 'package:flutter/material.dart';

class AdminHistoryViewPage extends StatelessWidget {
  final Map<String, dynamic> item;

  const AdminHistoryViewPage({super.key, required this.item});

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'reject':
        return Colors.red;
      case 'approved':
        return Colors.green;
      case 'processing':
        return Colors.orange;
      default:
        return Colors.amber;
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

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(item['status']);
    final textColor = Colors.white; // Text color inside the status box
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: _buildAppBar(context),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Status Highlight Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),  // External shadow
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    item['status']?.toUpperCase() ?? 'UNKNOWN',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Requestor Image and Name
              CircleAvatar(
                backgroundImage: NetworkImage(item['img_name'] ?? 'https://via.placeholder.com/150'),
                radius: 40,
              ),
              const SizedBox(height: 16),
              Text(
                item['requestor_name'] ?? 'No Name',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Submitted on ${item['submission_date'] ?? 'N/A'}',
                style: const TextStyle(color: Colors.black54, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Leave Type Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A0E3),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Center(
                  child: Text(
                    'Leave',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Title, Date, Time, and Discretion
              _buildInfoRow(Icons.title, 'Title', item['title'] ?? 'N/A'),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.calendar_today, 'Date', '${item['date_out'] ?? 'N/A'} - ${item['date_in'] ?? 'N/A'}'),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.access_time, 'Time', '09:00 AM - 12:00 PM'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    'Discretion: ${item['employee_tel'] ?? 'N/A'}',
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Approver Section
              _buildApproverSection(item),
              const SizedBox(height: 32),

              // Description Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black.withOpacity(0.1) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  item['remark'] ?? 'No Description available',
                  style: const TextStyle(color: Colors.black54, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // Status Date
              Text(
                '${item['status']} - ${item['submission_date'] ?? 'N/A'}',
                style: TextStyle(color: statusColor, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '$label: $value',
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildApproverSection(Map<String, dynamic> item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          backgroundImage: NetworkImage(item['approver_image'] ?? 'https://via.placeholder.com/150'),
          radius: 20,
        ),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward, color: Colors.orange),
        const SizedBox(width: 8),
        CircleAvatar(
          backgroundImage: NetworkImage(item['supervisor_image'] ?? 'https://via.placeholder.com/150'),
          radius: 20,
        ),
      ],
    );
  }
}
