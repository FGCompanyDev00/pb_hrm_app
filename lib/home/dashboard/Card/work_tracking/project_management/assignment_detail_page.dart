import 'package:flutter/material.dart';

class AssignmentDetailPage extends StatelessWidget {
  final Map<String, dynamic> assignmentDetail;

  const AssignmentDetailPage({super.key, required this.assignmentDetail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(assignmentDetail['title'] ?? 'No Title'),  // Handle null case
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${assignmentDetail['s_name'] ?? 'No Status'}'),  // Handle null case
            Text('Description: ${assignmentDetail['description'] ?? 'No Description'}'),  // Handle null case
            Text('Created By: ${assignmentDetail['create_by'] ?? 'Unknown'}'),  // Handle null case
            Text('Updated By: ${assignmentDetail['update_by'] ?? 'Unknown'}'),  // Handle null case

          ],
        ),
      ),
    );
  }
}
