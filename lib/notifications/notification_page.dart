import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_model.dart';

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
          _notifications = data.map((item) => NotificationModel.fromJson(item)).toList();
        });
      } else {
        print('Failed to load notifications');
      }
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  void _clearAllNotifications() {
    setState(() {
      _notifications.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        backgroundColor: Colors.transparent, // Transparent to only show the background image
        actions: [
          TextButton.icon(
            onPressed: _clearAllNotifications,
            label: const Text(
              'Clear All',
              style: TextStyle(color: Colors.black38),
            ),
            icon: const Icon(Icons.clear_all, color: Colors.black),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNotificationsFromBackend,
        child: Container(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: _notifications.isEmpty
                ? Center(
              child: Text(
                'No notifications',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                ),
              ),
            )
                : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(notification.imageUrl),
                    ),
                    title: Text(notification.message),
                    subtitle: Text(
                      '${notification.createdAt.toString().substring(0, 10)} - ${notification.createdAt.toString().substring(11, 16)}',
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
