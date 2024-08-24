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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Leave',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.0,
                  ),
                ),
                const SizedBox(height: 10),
                Text('Requestor: ${notification.createdBy}'),
                Text(
                  'Date: ${notification.createdAt.toString().substring(0, 10)} - ${notification.createdAt.toString().substring(0, 10)}',
                ),
                Text(
                  'Time: ${notification.createdAt.toString().substring(11, 16)} Am - 12:00 Pm', // Adjust the time display logic as needed
                ),
              ],
            ),
          ),
          CircleAvatar(
            backgroundImage: NetworkImage(notification.imageUrl),
            radius: 30.0,
          ),
        ],
      ),
    );
  }
}