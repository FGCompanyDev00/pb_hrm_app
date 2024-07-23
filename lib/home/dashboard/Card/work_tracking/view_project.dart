import 'package:flutter/material.dart';

class ViewProjectPage extends StatelessWidget {
  final Map<String, dynamic> project;

  const ViewProjectPage({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Project'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Title: ${project['title']}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Deadline1: ${project['deadline1']}'),
            Text('Deadline2: ${project['deadline2']}'),
            Text('Status: ${project['status']}'),
            Text('Progress: ${(project['progress'] * 100).toStringAsFixed(0)}%'),
            Text('Author: ${project['author']}'),
          ],
        ),
      ),
    );
  }
}
