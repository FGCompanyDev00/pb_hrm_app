import 'package:flutter/material.dart';
import 'package:pb_hrsystem/notifications/notification_model.dart';

extension NotificationStyle on NotificationModel {
  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
