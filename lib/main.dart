// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:pb_hrsystem/login/date.dart';
import 'package:pb_hrsystem/nav/custom_bottom_nav_bar.dart';
import 'package:pb_hrsystem/services/offline_service.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:pb_hrsystem/user_model.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'splash/splashscreen.dart';
import 'theme/theme.dart';
import 'home/home_calendar.dart';
import 'home/attendance_screen.dart';
import 'login/notification_permission_page.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/attendance_record.dart';
import 'package:flutter/services.dart';
import 'package:flutter_offline/flutter_offline.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(AttendanceRecordAdapter());

  await Hive.openBox<AttendanceRecord>('pending_attendance');
  await Hive.openBox<String>('userProfileBox');
  await Hive.openBox<List<String>>('bannersBox');

  // Initialize Service Locator
  await setupServiceLocator();

  // Initialize the FlutterLocalNotificationsPlugin
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Android initialization settings
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/playstore');

  // iOS/macOS initialization settings
  DarwinInitializationSettings initializationSettingsDarwin =
  DarwinInitializationSettings(
    requestAlertPermission: false, // Do not request permissions here
    requestBadgePermission: false,
    requestSoundPermission: false,
    onDidReceiveLocalNotification:
        (int id, String? title, String? body, String? payload) async {
      // Handle notification received in foreground
      if (kDebugMode) {
        print("iOS Local Notification received: $title $body $payload");
      }
    },
  );

  // Combine Android and iOS/macOS settings
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
    macOS: initializationSettingsDarwin,
  );

  // Initialize the plugin with the settings
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.payload != null && response.payload!.isNotEmpty) {
        // Navigate to NotificationPermissionPage on click
        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (context) => const NotificationPermissionPage(),
        ));
      }
    },
  );

  // Initialize Offline Service
  final OfflineService offlineService = sl<OfflineService>();
  offlineService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => LanguageNotifier()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => DateProvider()),
        Provider.value(value: offlineService),
      ],
      child: const MyApp(),
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
    Locale? locale = await sl<UserPreferences>().getLocalizeSupport();
    if (locale != null) {
      _currentLocale = locale;
      notifyListeners();
    }
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
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
      });
    } else {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    }
  }

  Future<bool> _onWillPop() async {
    final isFirstRouteInCurrentTab =
    !await _navigatorKeys[_selectedIndex].currentState!.maybePop();
    if (isFirstRouteInCurrentTab) {
      return true;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            Navigator(
              key: _navigatorKeys[0],
              onGenerateRoute: (routeSettings) {
                return MaterialPageRoute(
                    builder: (context) => const AttendanceScreen());
              },
            ),
            Navigator(
              key: _navigatorKeys[1],
              onGenerateRoute: (routeSettings) {
                return MaterialPageRoute(builder: (context) => const HomeCalendar());
              },
            ),
            Navigator(
              key: _navigatorKeys[2],
              onGenerateRoute: (routeSettings) {
                return MaterialPageRoute(builder: (context) => const Dashboard());
              },
            ),
            // Navigator(
            //   key: _navigatorKeys[3],
            //   onGenerateRoute: (routeSettings) {
            //     return MaterialPageRoute(builder: (context) => const HistoryPage());
            //   },
            // ),
          ],
        ),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }
}


