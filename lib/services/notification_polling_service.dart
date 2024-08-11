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
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'];
        if (contentType != null && contentType.contains('application/json')) {
          final List<dynamic> data = json.decode(response.body)['results'];
          final List<NotificationModel> notifications = data.map((item) {
            return NotificationModel(
              id: item['id'],
              type: item['message'],
              requestor: item['created_by'],
              date: item['created_at'].substring(0, 10),
              time: item['created_at'].substring(11, 16),
              status: item['status'] == 0 ? 'Pending' : 'Read',
              imageUrl: item['images'] ?? 'https://your-image-url.com',
            );
          }).toList();

          onNewNotifications(notifications);
        } else {
          // Handle case where response is not JSON
          print('Error: Expected JSON response but got $contentType');
        }
      } else {
        print('Error: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      // Handle any other exceptions, such as network errors
      print('Error fetching notifications: $e');
    }
  }

  void stopPolling() {
    _timer?.cancel();
  }
}
