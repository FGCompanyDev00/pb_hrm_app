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
  final List<int> _selectedNotifications = [];
  bool _isDeleting = false;

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
        _notifications = data.map((item) {
          return NotificationModel.fromJson(item);
        }).toList();
      });
    } else {
      // Handle error response
      print('Failed to load notifications');
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedNotifications.contains(id)) {
        _selectedNotifications.remove(id);
      } else {
        _selectedNotifications.add(id);
      }
    });
  }

  void _deleteSelectedNotifications() {
    setState(() {
      _notifications.removeWhere(
              (notification) => _selectedNotifications.contains(notification.id));
      _selectedNotifications.clear();
      _isDeleting = false;
    });
  }

  void _startDeleting() {
    setState(() {
      _isDeleting = true;
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
          if (_isDeleting)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _deleteSelectedNotifications,
            ),
          if (!_isDeleting)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _startDeleting,
            ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    final isSelected =
                    _selectedNotifications.contains(notification.id);
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
                        subtitle: Text('${notification.createdAt.toString().substring(0, 10)} - ${notification.createdAt.toString().substring(11, 16)}'),
                        trailing: _isDeleting
                            ? (isSelected
                            ? const Icon(Icons.check_box)
                            : const Icon(Icons.check_box_outline_blank))
                            : null,
                        onTap: _isDeleting
                            ? () => _toggleSelection(notification.id)
                            : null,
                        onLongPress: () => _toggleSelection(notification.id),
                      ),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: _fetchNotificationsFromBackend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Text('Refresh', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
