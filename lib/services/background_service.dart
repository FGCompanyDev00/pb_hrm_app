import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/hive_helper/model/attendance_record.dart';
import 'package:http/http.dart' as http;
import 'package:pb_hrsystem/services/offline_service.dart';
import 'package:pb_hrsystem/services/services_locator.dart';

final service = FlutterBackgroundService();

Future<void> initializeService() async {
  /// OPTIONAL, using custom notification channel id
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', // id
    'Check In', // title
    description: 'Check In', // description
    importance: Importance.high, // importance must be at low or higher level
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  if (Platform.isIOS || Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        iOS: DarwinInitializationSettings(),
        android: AndroidInitializationSettings('ic_bg_service_small'),
      ),
    );
  }

  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // this will be executed when app is in foreground or background in separated isolate
      onStart: onStart,

      // auto start service
      autoStart: true,
      isForegroundMode: true,

      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'Check In',
      initialNotificationContent: 'Check In',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.systemExempted],
    ),
    iosConfiguration: IosConfiguration(
      // auto start service
      autoStart: true,

      // this will be executed when app is in foreground in separated isolate
      onForeground: onStart,

      // you have to enable background fetch capability on xcode project
      onBackground: onIosBackground,
    ),
  );
}

Future<void> stopBackgroundService() async {
  service.invoke("stopService");
}

// to ensure this is executed
// run app from xcode, then from xcode menu, select Simulate Background Fetch

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // sl<UserPreferences>().reload();
  // sl<UserPreferences>().log();

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  DartPluginRegistrant.ensureInitialized();

  // For flutter prior to version 3.0.0
  // We have to register the plugin manually

  // sl<UserPreferences>().onStartBackground('my_foreground');

  /// OPTIONAL when use custom notification
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // bring to foreground
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        /// OPTIONAL for use custom notification
        /// the notification id must be equals with AndroidConfiguration when you call configure() method.
        flutterLocalNotificationsPlugin.show(
          888,
          'COOL SERVICE',
          'Awesome ${DateTime.now()}',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'my_foreground',
              'MY FOREGROUND SERVICE',
              icon: 'ic_bg_service_small',
              ongoing: true,
            ),
          ),
        );

        // if you don't using custom notification, uncomment this
        service.setForegroundNotificationInfo(
          title: "Check In",
          content: "Check-inn at ${DateTime.now()}",
        );
        Duration? currentDuration = sl<UserPreferences>().getWorkingHours();

        if ((currentDuration?.inHours ?? 0) > 6) {
          // Create AttendanceRecord
          AttendanceRecord record = AttendanceRecord(
            deviceId: sl<UserPreferences>().getDevice() ?? '',
            latitude: '',
            // Will be filled below
            longitude: '',
            // Will be filled below
            section: '',
            type: 'checkOut',
            timestamp: DateTime.now(),
          );
          sendCheckInOutRequest(record);
          service.invoke("stopService");
        }
      }
    }

    /// you can see this log in logcat
    // debugPrint('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');

    // test using external plugin
    final deviceInfo = DeviceInfoPlugin();
    String? device;
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      device = androidInfo.model;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      device = iosInfo.model;
    }

    service.invoke(
      'update',
      {
        "current_date": DateTime.now().toIso8601String(),
        "device": device,
      },
    );
  });
}

const String officeApiUrl = 'https://demo-application-api.flexiflows.co/api/attendance/checkin-checkout/office';
const String offsiteApiUrl = 'https://demo-application-api.flexiflows.co/api/attendance/checkin-checkout/offsite';

Future<void> sendCheckInOutRequest(AttendanceRecord record) async {
  if (sl<OfflineProvider>().isOfflineService.value) return;

  String url;
  if (record.section == 'Home' || record.section == 'Office') {
    url = officeApiUrl;
  } else {
    url = offsiteApiUrl;
  }

  String? token = sl<UserPreferences>().getToken();

  final response = await http.post(
    Uri.parse(url),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      "device_id": record.deviceId,
      "latitude": record.latitude,
      "longitude": record.longitude,
    }),
  );

  if (response.statusCode == 201 || response.statusCode == 202) {
    final Map<String, dynamic> responseData = jsonDecode(response.body);
    debugPrint(responseData.toString());
  } else {
    throw Exception('Failed with status code ${response.statusCode}');
  }
}
