// lib/main.dart

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/core/widgets/snackbar/snackbar.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:pb_hrsystem/login/date.dart';
import 'package:pb_hrsystem/hive_helper/model/calendar_events_list_record.dart';
import 'package:pb_hrsystem/hive_helper/model/event_record.dart';
import 'package:pb_hrsystem/hive_helper/model/material_color.dart';
import 'package:pb_hrsystem/nav/custom_bottom_nav_bar.dart';
import 'package:pb_hrsystem/services/offline_service.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:pb_hrsystem/services/work_manager_notification.dart';
import 'package:pb_hrsystem/splash/splashscreen.dart';
import 'package:pb_hrsystem/user_model.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'theme/theme.dart';
import 'home/home_calendar.dart';
import 'home/attendance_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'hive_helper/model/attendance_record.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setupServiceLocator();
  await initializeHive();
  // await initializeService();
  // Initialize notifications
  // await initializeNotifications();
  // await scheduleBackgroundTask();
  await cancelBackgroundTask();
  sl<OfflineProvider>().initializeCalendar();

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
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1;
  bool _enableConnection = false;
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(4, (index) => GlobalKey<NavigatorState>());

  @override
  void initState() {
    super.initState();
    offlineProvider.initialize();
    connectivityResult.onConnectivityChanged.listen((source) {
      Future.delayed(const Duration(seconds: 20)).whenComplete(() => _enableConnection = true);
      if (_enableConnection) {
        if (source.contains(ConnectivityResult.none)) showToast('No internet', Colors.red, Icons.mobiledata_off_rounded);
        if (source.contains(ConnectivityResult.wifi)) showToast('WiFi', Colors.green, Icons.wifi);
        if (source.contains(ConnectivityResult.mobile)) showToast('Internet', Colors.green, Icons.wifi);
      }
    });
  }

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
    return !await _navigatorKeys[_selectedIndex].currentState!.maybePop();
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
              onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const AttendanceScreen()),
            ),
            Navigator(
              key: _navigatorKeys[1],
              onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const HomeCalendar()),
            ),
            Navigator(
              key: _navigatorKeys[2],
              onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const Dashboard()),
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
  // Hive.registerAdapter(CalendarEventsListRecordAdapter());
  // Hive.registerAdapter(EventRecordAdapter());
  // Hive.registerAdapter(MaterialColorAdapter());

  await Hive.openBox<AttendanceRecord>('pending_attendance');
  // await Hive.openBox<CalendarEventsListRecord>('store_events_calendar');
  await Hive.openBox<String>('userProfileBox');
  await Hive.openBox<List<String>>('bannersBox');
  await Hive.openBox('loginBox');
  // await Hive.openBox('calendarEventsRecordBox');
  await Hive.openBox('UserProfileRecordBox');
}
