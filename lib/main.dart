// lib/main.dart

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // <--- ADDED
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/core/widgets/snackbar/snackbar.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:pb_hrsystem/login/date.dart';
import 'package:pb_hrsystem/models/qr_profile_page.dart';
import 'package:pb_hrsystem/nav/custom_bottom_nav_bar.dart';
import 'package:pb_hrsystem/services/offline_service.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:pb_hrsystem/splash/splashscreen.dart';
import 'package:pb_hrsystem/user_model.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'settings/theme_notifier.dart';
import 'home/home_calendar.dart';
import 'home/attendance_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'hive_helper/model/attendance_record.dart';

/// ------------------------------------------------------------
/// 1) Global instance of FlutterLocalNotificationsPlugin
/// ------------------------------------------------------------
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await setupServiceLocator();
  } catch (e) {
    print("Error during service locator setup: $e");
  }
  await initializeHive();
  sl<OfflineProvider>().initializeCalendar();

  /// ----------------------------------------------
  /// 2) Initialize local notifications
  /// ----------------------------------------------
  await _initializeLocalNotifications();

  final ios = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      IOSFlutterLocalNotificationsPlugin>();
  await ios?.requestPermissions(alert: true, badge: true, sound: true);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => LanguageNotifier()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => DateProvider()),
        ChangeNotifierProvider(create: (_) => OfflineProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

/// ------------------------------------------
/// 3) A private method for plugin initialization
/// ------------------------------------------
Future<void> _initializeLocalNotifications() async {
  // For Android
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/playstore');

  // For iOS
  const DarwinInitializationSettings initializationSettingsIOS =
  DarwinInitializationSettings(
    onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  // Combine settings
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  // Initialize the plugin
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
  );

  // (Optional) Create an Android notification channel:
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'attendance_channel_id',
    'Attendance',
    description: 'Notifications for check-in/check-out',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

/// iOS < 10 local notification callback
void onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
    ) {
  debugPrint('iOS (<10) local notification: title=$title, body=$body');
}

/// iOS 10+ (and Android) notification tap or response callback
@pragma('vm:entry-point') // important if you want background handling
void onDidReceiveNotificationResponse(NotificationResponse response) {
  debugPrint('Notification response tapped. Payload: ${response.payload}');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeNotifier, LanguageNotifier>(
      builder: (context, themeNotifier, languageNotifier, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          builder: EasyLoading.init(),
          title: 'PSBV Next Demo',
          theme: ThemeData(
            primarySwatch: Colors.green,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            textTheme:
            GoogleFonts.oxaniumTextTheme(Theme.of(context).textTheme),
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

  LanguageNotifier() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    Locale? locale = sl<UserPreferences>().getLocalizeSupport();
    _currentLocale = locale;
    notifyListeners();
  }

  void changeLanguage(String languageCode) async {
    switch (languageCode) {
      case 'English':
        _currentLocale = const Locale('en');
        await sl<UserPreferences>().setLocalizeSupport('en');
        await sl<UserPreferences>().setDefaultLanguage('English');
        break;
      case 'Laos':
        _currentLocale = const Locale('lo');
        await sl<UserPreferences>().setLocalizeSupport('lo');
        await sl<UserPreferences>().setDefaultLanguage('Laos');
        break;
      case 'Chinese':
        _currentLocale = const Locale('zh');
        await sl<UserPreferences>().setLocalizeSupport('zh');
        await sl<UserPreferences>().setDefaultLanguage('Chinese');
        break;
      default:
        _currentLocale = const Locale('en');
        await sl<UserPreferences>().setLocalizeSupport('en');
        await sl<UserPreferences>().setDefaultLanguage('English');
    }
    notifyListeners();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1;
  bool _enableConnection = false;
  final List<GlobalKey<NavigatorState>> _navigatorKeys =
  List.generate(4, (index) => GlobalKey<NavigatorState>());

  @override
  void initState() {
    super.initState();
    offlineProvider.initialize();
    connectivityResult.onConnectivityChanged.listen((source) async {
      Future.delayed(const Duration(seconds: 20))
          .whenComplete(() => _enableConnection = true);
      if (_enableConnection) {
        if (source.contains(ConnectivityResult.none)) {
          showToast('No internet', Colors.red, Icons.mobiledata_off_rounded);
          await offlineProvider.autoOffline(true);
        }
        if (source.contains(ConnectivityResult.wifi)) {
          showToast('WiFi', Colors.green, Icons.wifi);
          await offlineProvider.autoOffline(false);
        }
        if (source.contains(ConnectivityResult.mobile)) {
          showToast('Internet', Colors.green, Icons.wifi);
          await offlineProvider.autoOffline(false);
        }
      }
    });
  }

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
      });
      if (index == 2) {}
    } else {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    }
  }

  Future<bool> _onWillPop() async {
    return !await _navigatorKeys[_selectedIndex].currentState!.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (e, result) => _onWillPop,
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            Navigator(
              key: _navigatorKeys[0],
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => const AttendanceScreen(),
              ),
            ),
            Navigator(
              key: _navigatorKeys[1],
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => const HomeCalendar(),
              ),
            ),
            Navigator(
              key: _navigatorKeys[2],
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => const Dashboard(),
              ),
            ),
          ],
        ),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}

Future<void> initializeHive() async {
  await Hive.initFlutter();
  Hive.registerAdapter(AttendanceRecordAdapter());
  Hive.registerAdapter(UserProfileRecordAdapter());
  Hive.registerAdapter(QRRecordAdapter());
  // Hive.registerAdapter(MaterialColorAdapter());

  await Hive.openBox<AttendanceRecord>('pending_attendance');
  await Hive.openBox<UserProfileRecord>('user_profile');
  await Hive.openBox<QRRecord>('qr_profile');
  await Hive.openBox<String>('userProfileBox');
  await Hive.openBox<List<String>>('bannersBox');
  await Hive.openBox('loginBox');
  // await Hive.openBox('calendarEventsRecordBox');
}
