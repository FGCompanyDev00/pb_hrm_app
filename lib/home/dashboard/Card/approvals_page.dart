import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';

class StaffApprovalsPage extends StatefulWidget {
  const StaffApprovalsPage({super.key});

  @override
  _StaffApprovalsPageState createState() => _StaffApprovalsPageState();
}

class _StaffApprovalsPageState extends State<StaffApprovalsPage> {
  bool _isApprovalSelected = true;

  final List<Map<String, dynamic>> _items = [
    {
      'title': 'Meeting and Booking meeting room',
      'date': 'Date: 01-05-2024\n8:30 To 12:00',
      'room': 'Room: Back can yon 2F',
      'status': 'Approved',
      'icon': Icons.meeting_room,
      'type': 'Meeting Room Booking',
      'description': 'Booking for meeting room at Back Canyon 2F.',
    },
    {
      'title': 'Phoutthalom',
      'date': 'Date: 01-05-2024\n8:30 To 12:00',
      'room': 'Tel: 02078656511',
      'status': 'Pending',
      'icon': Icons.directions_car,
      'type': 'Company Car Reservation',
      'description': 'Reservation of company car for official use.',
    },
    {
      'title': 'Phoutthalom Douangphila',
      'date': 'Date: 01-05-2024\n8:30 To 12:00',
      'room': 'Type: sick leave',
      'status': 'Pending',
      'icon': Icons.event,
      'type': 'Leave Request',
      'description': 'Request for sick leave.',
    },
    {
      'title': 'Phoutthalom',
      'date': 'Date: 01-05-2024\n8:30 To 12:00',
      'room': 'Tel: 02078656511',
      'status': 'Rejected',
      'icon': Icons.directions_car,
      'type': 'Company Car Reservation',
      'description': 'Reservation of company car for official use.',
    },
    {
      'title': 'Meeting and Booking meeting room',
      'date': 'Date: 01-05-2024\n8:30 To 12:00',
      'room': 'Room: Back can yon 2F',
      'status': 'Approved',
      'icon': Icons.meeting_room,
      'type': 'Meeting Room Booking',
      'description': 'Booking for meeting room at Back Canyon 2F.',
    },
  ];

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.amber;
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  void _showApprovalDetail(BuildContext context, Map<String, dynamic> item, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ApprovalDetailPopup(
              item: item,
              isDarkMode: isDarkMode,
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _getHistoryItems() {
    final List<Map<String, dynamic>> historyItems =
    _items.where((item) => item['status'] != 'Pending').toList();

    if (historyItems.length > 100) {
      historyItems.sort((a, b) => a['date'].compareTo(b['date']));
      historyItems.removeRange(0, historyItems.length - 100);
    }

    return historyItems;
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    final List<Map<String, dynamic>> approvalItems =
    _items.where((item) => item['status'] == 'Pending').toList();
    final List<Map<String, dynamic>> historyItems = _getHistoryItems();

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.1,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
                fit: BoxFit.cover,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 25,
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, size: 30, color: Colors.black),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Text(
                      'Approvals',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isApprovalSelected = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      decoration: BoxDecoration(
                        color: _isApprovalSelected ? Colors.amber : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Center(
                        child: Text(
                          'Approval',
                          style: TextStyle(
                            color: _isApprovalSelected ? Colors.black : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isApprovalSelected = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      decoration: BoxDecoration(
                        color: _isApprovalSelected ? Colors.grey[300] : Colors.amber,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Center(
                        child: Text(
                          'History',
                          style: TextStyle(
                            color: _isApprovalSelected ? Colors.black : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: _isApprovalSelected
                  ? approvalItems.map((item) => _buildApprovalCard(context, item, isDarkMode)).toList()
                  : historyItems.map((item) => _buildApprovalCard(context, item, isDarkMode)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalCard(BuildContext context, Map<String, dynamic> item, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        _showApprovalDetail(context, item, isDarkMode);
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: BorderSide(color: _getStatusColor(item['status'])),
        ),
        elevation: 5,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                item['icon'],
                color: _getStatusColor(item['status']),
                size: 40,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'],
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['date'],
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['room'],
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Status: ',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: _getStatusColor(item['status']),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Text(
                            item['status'],
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const CircleAvatar(
                backgroundImage: AssetImage('assets/avatar_placeholder.png'),
                radius: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ApprovalDetailPopup extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDarkMode;

  const ApprovalDetailPopup({
    super.key,
    required this.item,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    // Splitting the date string safely
    final dateParts = item['date']?.split('\n') ?? [''];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Requestor',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const CircleAvatar(
              backgroundImage: AssetImage('assets/avatar_placeholder.png'),
              radius: 30,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ms. Zhao Lusi',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Submitted on 26 Feb 2024 - 11:30:00',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          item['title'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 8),
            Text(
              dateParts[0],
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.access_time, size: 20),
            const SizedBox(width: 8),
            Text(
              dateParts.length > 1 ? dateParts[1] : '',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.location_on, size: 20),
            const SizedBox(width: 8),
            Text(
              item['room'],
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (item['status'] == 'Pending')
          const Text(
            'Your request is pending and being processed.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.amber,
            ),
          )
        else
          Text(
            'This request has been ${item['status'].toLowerCase()}.',
            style: TextStyle(
              fontSize: 16,
              color: _getStatusColor(item['status']),
            ),
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.amber;
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.black;
    }
  }
}
