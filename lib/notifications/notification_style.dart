import 'package:flutter/material.dart';
import 'notification_model.dart';

extension NotificationStyle on NotificationModel {
  Color get statusColor {
    switch (status) {
      case 1:
        return Colors.green;
      case 0:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color get backgroundColor {
    switch (status) {
      case 1:
        return Colors.green[100]!;
      case 0:
        return Colors.red[100]!;
      default:
        return Colors.grey[100]!;
    }
  }

  Color get textColor {
    switch (status) {
      case 1:
        return Colors.green[900]!;
      case 0:
        return Colors.red[900]!;
      default:
        return Colors.grey[900]!;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 1:
        return Icons.check_circle;
      case 0:
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }
}
