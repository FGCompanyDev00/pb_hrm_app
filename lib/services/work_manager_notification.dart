import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    onDidReceiveLocalNotification: (int id, String? title, String? body, String? payload) async {
      // Handle notification received on iOS
    },
  );

  InitializationSettings initializationSettings = InitializationSettings(
    android: androidInitializationSettings,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

void callbackDispatcher(int notificationID, String title, String desc) async {
  Workmanager().executeTask((task, inputData) async {
    // Initialize the FlutterLocalNotificationsPlugin
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'background_channel', // ID for the channel
      'Background Notifications', // Name for the channel
      importance: Importance.high,
      priority: Priority.high,
    );

    // Show notification
    await flutterLocalNotificationsPlugin.show(
      notificationID, // Notification ID
      title, // Title
      desc, // Body
      const NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      ),
    );
    // Return true if the task completed successfully
    return Future.value(true);
  });
}

Future<void> scheduleBackgroundTask() async {
  Workmanager().registerPeriodicTask(
    '1', // Unique task name
    'sendNotification', // Task function name
    frequency: const Duration(minutes: 15), // Minimum interval on Android
  );
}
