// import 'package:flutter/material.dart';
// import 'package:pb_hrsystem/theme/theme.dart';
// import 'package:provider/provider.dart';

// class ApprovalsViewPage extends StatelessWidget {
//   final Map<String, dynamic> item;

//   const ApprovalsViewPage({
//     super.key,
//     required this.item,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final themeNotifier = Provider.of<ThemeNotifier>(context);
//     final bool isDarkMode = themeNotifier.isDarkMode;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Approval Details'),
//         backgroundColor: isDarkMode ? Colors.black : Colors.amber,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Requestor',
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 20,
//                 color: isDarkMode ? Colors.white : Colors.black,
//               ),
//             ),
//             const SizedBox(height: 16),
//             Row(
//               children: [
//                 CircleAvatar(
//                   backgroundImage: NetworkImage(item['img_path'] ?? 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
//                   radius: 30,
//                 ),
//                 const SizedBox(width: 16),
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       item['requestor_name'] ?? 'No Name',
//                       style: TextStyle(
//                         fontSize: 16,
//                         color: isDarkMode ? Colors.white : Colors.black,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       'Submitted on ${item['created_at']}',
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: isDarkMode ? Colors.white70 : Colors.black54,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             Text(
//               item['name'] ?? 'No Title',
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 18,
//                 color: isDarkMode ? Colors.white : Colors.black,
//               ),
//             ),
//             const SizedBox(height: 16),
//             Row(
//               children: [
//                 const Icon(Icons.calendar_today, size: 20),
//                 const SizedBox(width: 8),
//                 Text(
//                   'From: ${item['take_leave_from']} To: ${item['take_leave_to']}',
//                   style: TextStyle(
//                     fontSize: 16,
//                     color: isDarkMode ? Colors.white70 : Colors.black54,
//                   ),
//                 ),
//               ],
//             ),
//             Row(
//               children: [
//                 const Icon(Icons.access_time, size: 20),
//                 const SizedBox(width: 8),
//                 Text(
//                   'Days: ${item['days']}',
//                   style: TextStyle(
//                     fontSize: 16,
//                     color: isDarkMode ? Colors.white70 : Colors.black54,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             Row(
//               children: [
//                 const Icon(Icons.book, size: 20),
//                 const SizedBox(width: 8),
//                 Text(
//                   item['take_leave_reason'] ?? 'No Reason',
//                   style: TextStyle(
//                     fontSize: 16,
//                     color: isDarkMode ? Colors.white70 : Colors.black54,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'Status: ${item['is_approve']}',
//               style: TextStyle(
//                 fontSize: 16,
//                 color: isDarkMode ? Colors.white : Colors.black,
//               ),
//             ),
//             const SizedBox(height: 24),
//             if (item['is_approve'] == 'Waiting')
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   ElevatedButton(
//                     onPressed: () {
//                       // Implement the approve functionality
//                     },
//                     style: ElevatedButton.styleFrom(
//                       foregroundColor: Colors.white, backgroundColor: Colors.green,
//                     ),
//                     child: const Text('Approve'),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       // Implement the reject functionality
//                     },
//                     style: ElevatedButton.styleFrom(
//                       foregroundColor: Colors.white, backgroundColor: Colors.red,
//                     ),
//                     child: const Text('Reject'),
//                   ),
//                 ],
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApprovalsViewPage extends StatelessWidget {
  final Map<String, dynamic> item;

  const ApprovalsViewPage({
    super.key,
    required this.item,
  });

  Future<void> _approveRequest(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _showErrorDialog(context, 'Authorization Error', 'Token is null. Please log in again.');
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('https://demo-application-api.flexiflows.co/api/leave_approve/${item['id']}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showSuccessDialog(context, 'Approved Successfully');
      } else {
        _showErrorDialog(context, 'Failed to Approve', response.reasonPhrase ?? 'Unknown error occurred');
      }
    } catch (e) {
      _showErrorDialog(context, 'Error', 'An unexpected error occurred: $e');
    }
  }

  Future<void> _rejectRequest(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _showErrorDialog(context, 'Authorization Error', 'Token is null. Please log in again.');
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('https://demo-application-api.flexiflows.co/api/leave_reject/${item['id']}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showSuccessDialog(context, 'Rejected Successfully');
      } else {
        _showErrorDialog(context, 'Failed to Reject', response.reasonPhrase ?? 'Unknown error occurred');
      }
    } catch (e) {
      _showErrorDialog(context, 'Error', 'An unexpected error occurred: $e');
    }
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Close dialog and navigate back
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((_) => Navigator.of(context).pop()); // Go back to the previous page
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approval Details'),
        backgroundColor: isDarkMode ? Colors.black : Colors.amber,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                CircleAvatar(
                  backgroundImage: NetworkImage(item['img_path'] ??
                      'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
                  radius: 30,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['requestor_name'] ?? 'No Name',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submitted on ${item['created_at']}',
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
              item['name'] ?? 'No Title',
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
                  'From: ${item['take_leave_from']} To: ${item['take_leave_to']}',
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
                  'Days: ${item['days']}',
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
                const Icon(Icons.book, size: 20),
                const SizedBox(width: 8),
                Text(
                  item['take_leave_reason'] ?? 'No Reason',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Status: ${item['is_approve']}',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            if (item['is_approve'] == 'Waiting')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _approveRequest(context),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Approve'),
                  ),
                  ElevatedButton(
                    onPressed: () => _rejectRequest(context),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Reject'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
