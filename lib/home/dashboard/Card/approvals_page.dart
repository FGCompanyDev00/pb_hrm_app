import 'package:flutter/material.dart';

class ApprovalsPage extends StatelessWidget {
  const ApprovalsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              padding: const EdgeInsets.all(5.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TabBar(
                labelColor: Colors.black,
                indicator: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(25),
                ),
                indicatorPadding: EdgeInsets.zero,
                indicatorSize: TabBarIndicatorSize.tab,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: 'Approval'),
                  Tab(text: 'History'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildApprovalSection(context, isDarkMode),
                  _buildHistorySection(context, isDarkMode),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalSection(BuildContext context, bool isDarkMode) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildApprovalCard(context, 'Meeting and Booking meeting room', 'Room', 'assets/Vector.png', 'Room: Back can yon 2F', 'Pending', isDarkMode),
        _buildApprovalCard(context, 'Phoutthalom', 'Car', 'assets/Vector-1.png', 'Tel: 02078656511', 'Pending', isDarkMode),
        _buildApprovalCard(context, 'Phoutthalom Douangphila', 'Leave', 'assets/Vector-2.png', 'Type: sick leave', 'Pending', isDarkMode),
      ],
    );
  }

  Widget _buildHistorySection(BuildContext context, bool isDarkMode) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildApprovalCard(context, 'Meeting and Booking meeting room', 'Room', 'assets/Vector.png', 'Room: Back can yon 2F', 'Approved', isDarkMode),
        _buildApprovalCard(context, 'Phoutthalom', 'Car', 'assets/Vector-1.png', 'Tel: 02078656511', 'Rejected', isDarkMode),
        _buildApprovalCard(context, 'Phoutthalom Douangphila', 'Leave', 'assets/Vector-2.png', 'Type: sick leave', 'Rejected', isDarkMode),
      ],
    );
  }

  Widget _buildApprovalCard(BuildContext context, String title, String type, String imagePath, String detail, String status, bool isDarkMode) {
    Color statusColor;
    if (status == 'Pending') {
      statusColor = Colors.amber;
    } else if (status == 'Approved') {
      statusColor = Colors.green;
    } else {
      statusColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(imagePath, height: 48, width: 48),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Date: 01-05-2024, 8:30 To 01-05-2024, 12:00',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Status:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
