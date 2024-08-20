import 'package:flutter/material.dart';
import 'notification_model.dart';

class NotificationWidget extends StatelessWidget {
  final NotificationModel notification;

  const NotificationWidget({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10.0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Message: ${notification.message}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16.0,
            ),
          ),
          const SizedBox(height: 8.0),
          Text('Requestor: ${notification.createdBy}'),
          Text('Date: ${notification.createdAt.toString().substring(0, 10)}'),
          Text('Time: ${notification.createdAt.toString().substring(11, 16)}'),
          Text('Employee ID: ${notification.employeeId}'),
          Text('Project ID: ${notification.projectId}'),
          const SizedBox(height: 8.0),
          Row(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(notification.imageUrl),
                radius: 30.0,
              ),
              const SizedBox(width: 16.0),
              Icon(
                Icons.circle,
                color: notification.status == 1 ? Colors.green : Colors.red,
                size: 24.0,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
