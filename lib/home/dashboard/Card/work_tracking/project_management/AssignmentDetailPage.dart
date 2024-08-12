import 'package:flutter/material.dart';

class AssignmentDetailPage extends StatelessWidget {
  final Map<String, dynamic> assignmentDetail;

  const AssignmentDetailPage({super.key, required this.assignmentDetail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(assignmentDetail['title']),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${assignmentDetail['s_name']}'),
            Text('Description: ${assignmentDetail['description']}'),
            Text('Created By: ${assignmentDetail['create_by']}'),
            Text('Updated By: ${assignmentDetail['update_by']}'),
            // Add more fields based on what you want to display
          ],
        ),
      ),
    );
  }
}
