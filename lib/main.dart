import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:pb_hrsystem/nav/custom_bottom_nav_bar.dart';
import 'package:pb_hrsystem/user_model.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'notifications/notification_page.dart';
import 'services/notification_polling_service.dart';
import 'notifications/notification_model.dart';
import 'splash/splashscreen.dart';
import 'theme/theme.dart';
import 'home/home_calendar.dart';
import 'home/attendance_screen.dart';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

  // Initialize the FlutterLocalNotificationsPlugin
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Android initialization settings
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/playstore');

  // iOS/macOS initialization settings
  const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings();

  // Combine Android and iOS/macOS settings
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
    macOS: initializationSettingsDarwin,
  );

  // Initialize the plugin with the settings
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.payload != null && response.payload!.isNotEmpty) {
        // Navigate to NotificationPage on click
        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (context) => const NotificationPage(),
        ));
      }
    },
  );

  // Request permissions for iOS
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeNotifier()),
          ChangeNotifierProvider(create: (_) => LanguageNotifier()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeNotifier, LanguageNotifier>(
      builder: (context, themeNotifier, languageNotifier, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          builder: (context, child) {
            return EasyLoading.init()(context, child!);
          },
          title: 'PSBV Next',
          theme: ThemeData(
            primarySwatch: Colors.green,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            textTheme: GoogleFonts.oxaniumTextTheme(Theme.of(context).textTheme),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green,
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.green,
            scaffoldBackgroundColor: Colors.black,
            textTheme: GoogleFonts.oxaniumTextTheme(
              Theme.of(context).textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
            ),
          ),
          themeMode: themeNotifier.currentTheme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('lo'),
            Locale('zh'),
          ],
          locale: languageNotifier.currentLocale,
          home: const SplashScreen(),
        );
      },
    );
  }
}

class LanguageNotifier with ChangeNotifier {
  Locale _currentLocale = const Locale('en');

  Locale get currentLocale => _currentLocale;

  void changeLanguage(String languageCode) {
    switch (languageCode) {
      case 'English':
        _currentLocale = const Locale('en');
        break;
      case 'Laos':
        _currentLocale = const Locale('lo');
        break;
      case 'Chinese':
        _currentLocale = const Locale('zh');
        break;
      default:
        _currentLocale = const Locale('en');
    }
    notifyListeners();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1;
  final List<NotificationModel> _notifications = [];
  late NotificationPollingService _notificationPollingService;

  static final List<Widget> _widgetOptions = <Widget>[
    const AttendanceScreen(),
    const HomeCalendar(),
    const Dashboard(),
  ];

  @override
  void initState() {
    super.initState();
    _notificationPollingService = NotificationPollingService(
      apiUrl: 'https://demo-application-api.flexiflows.co/api/work-tracking/proj/notifications',
      onNewNotifications: (notifications) {
        setState(() {
          _notifications.addAll(notifications.map((n) => NotificationModel.fromJson(n as Map<String, dynamic>)));
        });
      },
    );
    _notificationPollingService.startPolling();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _notificationPollingService.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await _fetchAndDisplayNotifications();
    return Future.value(true);
  });
}

Future<void> _fetchAndDisplayNotifications() async {
  const String baseUrl = 'https://demo-application-api.flexiflows.co';
  const String endpoint = '$baseUrl/api/work-tracking/proj/notifications';

  try {
    final response = await http.get(Uri.parse(endpoint));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List notifications = data['results'];
      for (var notification in notifications) {
        if (notification['status'] == 0) {
          await _showNotification(notification);
        }
      }
    } else {
      if (kDebugMode) {
        print('Failed to fetch notifications');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error fetching notifications: $e');
    }
  }
}

Future<void> _showNotification(Map<String, dynamic> notification) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails(
    'psbv_next_channel', // Updated channel ID for app
    'PSBV Next Notifications', // Updated channel name
    channelDescription:
    'Notifications about assignments, project updates, and member changes in PSBV Next app.', // Updated channel description
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    icon: '@mipmap/playstore',
  );
  const NotificationDetails platformChannelSpecifics =
  NotificationDetails(android: androidPlatformChannelSpecifics);
  await FlutterLocalNotificationsPlugin().show(
    notification['id'],
    'New Notification',
    notification['message'],
    platformChannelSpecifics,
    payload: notification['id'].toString(),
  );
}
