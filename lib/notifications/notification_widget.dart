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
        color: notification.backgroundColor,
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
          Row(
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
                      notification.message,
                      style: TextStyle(
                        color: notification.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Requestor: ${notification.createdBy}',
                      style: TextStyle(fontSize: 14.0, color: notification.textColor),
                    ),
                    Text(
                      'Date: ${notification.createdAt.toString().substring(0, 10)}',
                      style: TextStyle(fontSize: 14.0, color: notification.textColor),
                    ),
                    Text(
                      'Time: ${notification.createdAt.toString().substring(11, 16)}',
                      style: TextStyle(fontSize: 14.0, color: notification.textColor),
                    ),
                  ],
                ),
              ),
              Icon(
                notification.statusIcon,
                color: notification.statusColor,
                size: 24.0,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
