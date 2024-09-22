import 'package:flutter/material.dart';

class AdminHistoryViewPage extends StatelessWidget {
  final Map<String, dynamic> item;

  const AdminHistoryViewPage({super.key, required this.item});

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
        'Approvals History Detail',
        style: TextStyle(
          color: Colors.black,
          fontSize: 22,
          fontWeight: FontWeight.w500,
        ),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.black,
          size: 20,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      toolbarHeight: 80,
      elevation: 0,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(item['status']);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: _buildAppBar(context),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Status Box with Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle, color: statusColor, size: 24),
                  const SizedBox(width: 6),
                  Text(
                    item['status']?.toUpperCase() ?? 'UNKNOWN',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 30  ,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Requestor Image and Name
              CircleAvatar(
                backgroundImage: NetworkImage(item['img_name'] ?? 'https://via.placeholder.com/150'),
                radius: 36,
              ),
              const SizedBox(height: 12),
              Text(
                item['requestor_name'] ?? 'No Name',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Submitted on ${item['submission_date'] ?? 'N/A'}',
                style: const TextStyle(color: Colors.black54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Leave Type Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                decoration: BoxDecoration(
                  color: Colors.lightBlueAccent,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: const Center(
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
              const SizedBox(height: 12),

              // Title, Date, Time, and Discretion
              _buildInfoRow(Icons.title, 'Title', item['title'] ?? 'N/A'),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.calendar_today, 'Date', '${item['date_out'] ?? 'N/A'} - ${item['date_in'] ?? 'N/A'}'),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.access_time, 'Time', '09:00 AM - 12:00 PM'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone, color: Colors.red, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Discretion: ${item['employee_tel'] ?? 'N/A'}',
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Approver Section
              _buildApproverSection(item),
              const SizedBox(height: 12),

              // Description Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black.withOpacity(0.1) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Text(
                  item['remark'] ?? 'No Description available',
                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),

              // Status Date
              Text(
                '${item['status']} - ${item['status_date'] ?? 'N/A'}',
                style: TextStyle(color: statusColor, fontSize: 14),
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
        Icon(icon, color: Colors.blue, size: 20),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$label: $value',
            style: const TextStyle(fontSize: 14, color: Colors.black),
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
}
