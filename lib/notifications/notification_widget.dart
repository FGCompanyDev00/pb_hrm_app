import 'package:flutter/material.dart';
import 'notification_model.dart';
import 'notification_style.dart';

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
          CircleAvatar(
            backgroundImage: NetworkImage(notification.imageUrl),
            radius: 30.0,
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.type,
                  style: TextStyle(
                    color: notification.statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Requestor: ${notification.requestor}',
                  style: const TextStyle(fontSize: 14.0),
                ),
                Text(
                  'Date: ${notification.date}',
                  style: const TextStyle(fontSize: 14.0),
                ),
                Text(
                  'Time: ${notification.time}',
                  style: const TextStyle(fontSize: 14.0),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16.0),
        ],
      ),
    );
  }
}
