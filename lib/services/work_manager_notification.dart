import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(android: androidInitializationSettings);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Initialize the FlutterLocalNotificationsPlugin
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'background_channel', // ID for the channel
      'Background Notifications', // Name for the channel
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    // Show notification
    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      'Hello from WorkManager', // Title
      'This is a notification triggered by WorkManager.', // Body
      platformDetails,
    );

    // Return true if the task completed successfully
    return Future.value(true);
  });
}

Future<void> scheduleBackgroundTask() async {
  Workmanager().registerPeriodicTask(
    'task_id', // Unique task name
    'sendNotification', // Task function name
    frequency: const Duration(minutes: 15), // Minimum interval on Android
    inputData: {'message': 'Hello from WorkManager!'}, // Optional input data
  );
}
