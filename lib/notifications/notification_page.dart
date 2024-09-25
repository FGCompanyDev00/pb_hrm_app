import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_model.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking_page.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  List<NotificationModel> _notifications = [];

  @override
  void initState() {
    super.initState();
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _initializeNotifications();
    _fetchNotificationsFromBackend();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _fetchNotificationsFromBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    try {
      final response = await http.get(
        Uri.parse(
            'https://demo-application-api.flexiflows.co/api/work-tracking/proj/notifications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['results'];
        setState(() {
          _notifications = data
              .map((item) => NotificationModel.fromJson(item))
              .toList();
        });
      } else {
        if (kDebugMode) {
          print('Failed to load notifications');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching notifications: $e');
      }
    }
  }

  Future<String> _fetchProfileImage(String employeeId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse(
            'https://demo-application-api.flexiflows.co/api/profile/$employeeId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['results']['images'] ?? '';
      } else {
        if (kDebugMode) {
          print('Failed to load profile image: ${response.statusCode}');
        }
        return ''; // Return empty URL to avoid crashes
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching profile image: $e');
      }
      return ''; // Return empty URL to avoid crashes
    }
  }

  void _openNotificationDetails(NotificationModel notification) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkTrackingPage(
          highlightedProjectId: notification.projectId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 2,
        toolbarHeight: 92,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Notification',
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 13),
          ],
        ),
        centerTitle: true,
      ),

      body: RefreshIndicator(
        onRefresh: _fetchNotificationsFromBackend,
        child: Container(
          color: Colors.grey.shade50,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: _notifications.isEmpty
                ? Center(
              child: Text(
                'No notifications available',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
                : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return FutureBuilder<String>(
                  future: _fetchProfileImage(notification.employeeId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final imageUrl = snapshot.data ??
                        'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';

                    return Card(
                      elevation: 5,
                      margin: const EdgeInsets.only(bottom: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16.0),
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(imageUrl),
                          radius: 28,
                        ),
                        title: Text(
                          notification.message,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          '${notification.createdAt.toString().substring(0, 10)} - ${notification.createdAt.toString().substring(11, 16)}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.notifications_active,
                          color: Colors.orange,
                        ),
                        onTap: () => _openNotificationDetails(notification),  // Redirect on tap
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
