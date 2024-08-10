import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pb_hrsystem/notifications/notification_model.dart';

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
    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['results'];
      final List<NotificationModel> notifications = data.map((item) {
        return NotificationModel(
          id: item['id'],  // Ensure the id is correctly fetched from the API response
          type: item['message'],
          requestor: item['created_by'],
          date: item['created_at'].substring(0, 10),
          time: item['created_at'].substring(11, 16),
          status: item['status'] == 0 ? 'Pending' : 'Read',
          imageUrl: item['images'] ?? 'https://your-image-url.com', // Replace with actual image URL or use fallback
        );
      }).toList();

      onNewNotifications(notifications);
    } else {
      // Handle error response
    }
  }

  void stopPolling() {
    _timer?.cancel();
  }
}