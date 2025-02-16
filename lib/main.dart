// lib/main.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logger/logger.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/core/widgets/snackbar/snackbar.dart';
import 'package:pb_hrsystem/hive_helper/model/add_assignment_record.dart';
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
import 'package:encrypt/encrypt.dart' as encrypt;
import 'firebase_options.dart';

/// ------------------------------------------------------------
/// 1) Global instance of FlutterLocalNotificationsPlugin
/// ------------------------------------------------------------
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Initialize Logger with a custom filter for production
final Logger logger = Logger(
  printer: PrettyPrinter(),
  filter: ProductionFilter(),
);

const FlutterSecureStorage secureStorage = FlutterSecureStorage();

/// ------------------------------------------------------------
/// 2) Firebase Messaging background handler
/// ------------------------------------------------------------
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  _showNotification(message);
}

/// ------------------------------------------------------------
/// 3) Show notification function for push notifications
/// ------------------------------------------------------------
Future<void> _showNotification(RemoteMessage message) async {
  RemoteNotification? notification = message.notification;
  if (notification != null) {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'psbv_next_notification', // Must match the channel id created below
      'PSBV Next',
      channelDescription: 'Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );
    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformChannelSpecifics,
      payload: message.data.toString(),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  // Run entire app inside runZonedGuarded:
  runZonedGuarded(() async {
    try {
      await dotenv.load(fileName: ".env.demo"); // Please change to ".env.production" for release
    } catch (e) {
      debugPrint("Error loading .env file: $e");
    }

    debugPrint("BASE_URL Loaded: ${dotenv.env['BASE_URL']}");

    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // Initialize secure HTTP client
    final Dio dio = createSecureDio();
    sl.registerSingleton<Dio>(dio);

    // Setup service locator
    try {
      await setupServiceLocator();
    } catch (e) {
      if (kDebugMode) {
        logger.e("Error during service locator setup: $e");
      }
    }
    await initializeHive();
    sl<OfflineProvider>().initializeCalendar();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Register Firebase Messaging background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Listen for foreground messages and display notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotification(message);
    });

    // Listen for notification tap (when app is in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("Notification tapped: ${message.data}");
    });

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
  }, (error, stack) {
    // Catch all global asynchronous errors here
    if (kDebugMode) {
      logger.e("Uncaught error: $error");
      logger.e(stack);
    }
  });
}

/// ------------------------------------------
/// 4) A private method for plugin initialization
/// ------------------------------------------
Future<void> _initializeLocalNotifications() async {
  // For Android
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/playstore');

  // For iOS
  const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  // Combine settings
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  // Initialize the plugin without deprecated callbacks
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
  );

  // (Optional) Create an Android notification channel:
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'psbv_next_notification',
    'PSBV Next',
    description: 'Notifications',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
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
@pragma('vm:entry-point')
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

// Logger Production Filter
class ProductionFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // Disable logging in release mode
    return !kReleaseMode;
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
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(4, (index) => GlobalKey<NavigatorState>());

  @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(_routeInterceptor);
    offlineProvider.initialize();
    connectivityResult.onConnectivityChanged.listen((source) async {
      Future.delayed(const Duration(seconds: 20)).whenComplete(() => _enableConnection = true);
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

  @override
  void dispose() {
    // Unregister the back button interceptor
    BackButtonInterceptor.remove(_routeInterceptor);
    super.dispose();
  }

  bool _routeInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    // Access the current context based on the selected navigator
    BuildContext currentContext = _navigatorKeys[_selectedIndex].currentContext!;

    // Get the NavigatorState from the current context
    var navigationState = Navigator.of(currentContext);

    // If the keyboard is open, close it
    if (MediaQuery.of(currentContext).viewInsets.bottom > 0) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      return true; // Prevent default back button action
    }

    if (navigationState.canPop()) {
      navigationState.pop();
      return true; // Prevent default back button action
    }

    // If at the root route, allow the default back button behavior (e.g., exit app)
    return false;
  }

  void _onItemTapped(int index) async {
    if (index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
      });
      if (index == 1) {
        (HomeCalendarState() as Refreshable).refresh.call();
      }
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
  Hive.registerAdapter(AddAssignmentRecordAdapter());
  Hive.registerAdapter(UserProfileRecordAdapter());
  Hive.registerAdapter(QRRecordAdapter());

  final String? storedKey = await secureStorage.read(key: 'hive_encryption_key');
  final List<int> encryptionKey = storedKey != null ? base64Url.decode(storedKey) : encrypt.Key.fromSecureRandom(32).bytes;
  if (storedKey == null) {
    final String encodedKey = base64UrlEncode(encryptionKey);
    await secureStorage.write(key: 'hive_encryption_key', value: encodedKey);
  }

  final HiveAesCipher cipher = HiveAesCipher(encryptionKey);

  await Future.wait([
    Hive.openBox<AttendanceRecord>('pending_attendance', encryptionCipher: cipher),
    Hive.openBox<AddAssignmentRecord>('add_assignment', encryptionCipher: cipher),
    Hive.openBox<UserProfileRecord>('user_profile', encryptionCipher: cipher),
    Hive.openBox<QRRecord>('qr_profile', encryptionCipher: cipher),
    Hive.openBox<String>('userProfileBox', encryptionCipher: cipher),
    Hive.openBox<List<String>>('bannersBox', encryptionCipher: cipher),
    Hive.openBox('loginBox', encryptionCipher: cipher),
  ]);
}

Dio createSecureDio() {
  final Dio dio = Dio();

  dio.options = BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
    headers: {
      HttpHeaders.contentTypeHeader: 'application/json',
    },
    responseType: ResponseType.json,
  );

  // Interceptor to enforce HTTPS
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (!options.uri.isScheme('https')) {
          return handler.reject(
            DioException(
              requestOptions: options,
              error: 'HTTPS is required',
              type: DioExceptionType.badResponse,
            ),
          );
        }
        return handler.next(options);
      },
    ),
  );

  return dio;
}
