// import 'dart:async';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:pb_hrsystem/notifications/notification_model.dart';

// class NotificationPollingService {
//   final String apiUrl;
//   final Function(List<NotificationModel>) onNewNotifications;
//   Timer? _timer;

//   NotificationPollingService({
//     required this.apiUrl,
//     required this.onNewNotifications,
//   });

//   void startPolling() {
//     _timer = Timer.periodic(const Duration(minutes: 1), (timer) async {
//       await _fetchNotifications();
//     });
//   }

//   Future<void> _fetchNotifications() async {
//     try {
//       final response = await http.get(Uri.parse(apiUrl));

//       if (response.statusCode == 200) {
//         final contentType = response.headers['content-type'];
//         if (contentType != null && contentType.contains('application/json')) {
//           final List<dynamic> data = json.decode(response.body)['results'];
//           final List<NotificationModel> notifications = data.map((item) {
//             return NotificationModel.fromJson(item);
//           }).toList();

//           onNewNotifications(notifications);
//         } else {
//           // Handle case where response is not JSON
//           debugPrint('Error: Expected JSON response but got $contentType');
//         }
//       } else {
//         debugPrint('Error: ${response.statusCode} - ${response.reasonPhrase}');
//       }
//     } catch (e) {
//       // Handle any other exceptions, such as network errors
//       debugPrint('Error fetching notifications: $e');
//     }
//   }

//   void stopPolling() {
//     _timer?.cancel();
//   }
// }

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pb_hrsystem/notifications/notification_model.dart';
import 'dart:convert';

class NotificationPollingService {
  final String apiUrl;
  final Function(List<NotificationModel>) onNewNotifications;
  Timer? _timer;

  NotificationPollingService({
    required this.apiUrl,
    required this.onNewNotifications,
  });

  void startPolling() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      await _fetchNotifications();
    });
  }

  Future<void> _fetchNotifications() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'];
        if (contentType != null && contentType.contains('application/json')) {
          final List<dynamic> data = json.decode(response.body)['results'];
          final List<NotificationModel> notifications = data.map((item) {
            return NotificationModel.fromJson(item);
          }).toList();

          onNewNotifications(notifications);
        } else {
          // Handle case where response is not JSON
          debugPrint('Error: Expected JSON response but got $contentType');
        }
      } else {
        debugPrint('Error: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      // Handle any other exceptions, such as network errors
      debugPrint('Error fetching notifications: $e');
    }
  }

  void stopPolling() {
    _timer?.cancel();
  }
}

Future<void> insertNotification(Map<String, dynamic> data) async {
  final url = Uri.parse('https://your-api-url.com/api/notifications');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(data),
  );

  if (response.statusCode == 200) {
    debugPrint('Notification inserted successfully.');
  } else {
    debugPrint('Failed to insert notification. Status: ${response.statusCode}');
  }
}
