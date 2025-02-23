// lib/main.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Initialize Logger with a custom filter for production
final Logger logger =
    Logger(printer: PrettyPrinter(), filter: ProductionFilter());

const FlutterSecureStorage secureStorage = FlutterSecureStorage();

/// Cache for frequently accessed data
class AppCache {
  static final AppCache _instance = AppCache._internal();
  factory AppCache() => _instance;
  AppCache._internal();

  String? baseUrl;
  String? deviceToken;
  Map<String, dynamic> userSettings = {};

  // Add cache for commonly used values
  final Map<String, dynamic> _cache = {};
  final Duration _cacheDuration = const Duration(minutes: 15);

  void set(String key, dynamic value) {
    _cache[key] = {
      'value': value,
      'timestamp': DateTime.now(),
    };
  }

  dynamic get(String key) {
    final item = _cache[key];
    if (item == null) return null;

    final timestamp = item['timestamp'] as DateTime;
    if (DateTime.now().difference(timestamp) > _cacheDuration) {
      _cache.remove(key);
      return null;
    }

    return item['value'];
  }

  void clear() => _cache.clear();
}

final appCache = AppCache();

/// ------------------------------------------------------------
/// 2) Firebase Messaging background handler
/// ------------------------------------------------------------
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Firebase message received in background: ${message.messageId}");
  _showNotification(message);
}

/// ------------------------------------------------------------
/// 3) Show notification function for push notifications
/// ------------------------------------------------------------
Future<void> _showNotification(RemoteMessage message) async {
  if (!Platform.isIOS && !Platform.isAndroid)
    return; // Early return for unsupported platforms

  debugPrint("Notification received: ${message.notification?.title}");
  final notification = message.notification;
  if (notification == null) {
    debugPrint("No notification data found in message");
    return;
  }

  final platformChannelSpecifics = NotificationDetails(
    android: const AndroidNotificationDetails(
      'psbv_next_notification',
      'PSBV Next',
      channelDescription: 'Notifications',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  await flutterLocalNotificationsPlugin.show(
    notification.hashCode,
    notification.title,
    notification.body,
    platformChannelSpecifics,
    payload: message.data.toString(),
  );
}

Future<void> _initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create a list to hold all initialization futures
  final List<Future> initializationTasks = [
    // Firebase initialization with error handling
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .catchError((e) {
      debugPrint("Firebase initialization failed: $e");
      return null;
    }),

    // Environment loading with error handling
    dotenv.load(fileName: ".env.demo").catchError((e) { // change it to .env.production for production mode
      debugPrint("Error loading .env file: $e");
      return null;
    }),

    // Hive initialization
    _initializeHiveOptimized(),

    // System orientation
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  ];

  // Wait for all initialization tasks to complete concurrently
  await Future.wait(initializationTasks, eagerError: false)
      .catchError((e) => debugPrint("Initialization error: $e"));

  // Cache base URL after environment is loaded
  appCache.baseUrl = dotenv.env['BASE_URL'];

  // Initialize remaining services concurrently
  await Future.wait([
    _initializeServices(),
    _initializeNotifications(),
  ], eagerError: false);
}

Future<void> _initializeServices() async {
  // Initialize Dio with optimized settings
  final dio = createSecureDio();
  sl.registerSingleton<Dio>(dio);

  // Initialize remaining services
  await setupServiceLocator();
  await sl<OfflineProvider>().initializeCalendar();
}

Future<void> _initializeNotifications() async {
  await Future.wait([
    _initializeLocalNotifications(),
    _initializeFirebaseMessaging(),
  ], eagerError: false);
}

Future<void> _initializeFirebaseMessaging() async {
  // Request permissions
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    debugPrint('User granted permission');

    // Register handlers
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
          "Firebase message received in foreground: ${message.messageId}");
      _showNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("Notification tapped: ${message.data}");
    });
  }
}

Future<void> _initializeHiveOptimized() async {
  await Hive.initFlutter();

  // Register adapters sequentially to avoid type issues
  Hive.registerAdapter(AttendanceRecordAdapter());
  Hive.registerAdapter(AddAssignmentRecordAdapter());
  Hive.registerAdapter(UserProfileRecordAdapter());
  Hive.registerAdapter(QRRecordAdapter());

  // Get encryption key
  final storedKey = await secureStorage.read(key: 'hive_encryption_key');
  final encryptionKey = storedKey != null
      ? base64Url.decode(storedKey)
      : encrypt.Key.fromSecureRandom(32).bytes;

  if (storedKey == null) {
    await secureStorage.write(
      key: 'hive_encryption_key',
      value: base64UrlEncode(encryptionKey),
    );
  }

  final cipher = HiveAesCipher(encryptionKey);

  // Open boxes concurrently with error handling
  try {
    await Future.wait<void>([
      Hive.openBox<AttendanceRecord>('pending_attendance',
          encryptionCipher: cipher),
      Hive.openBox<AddAssignmentRecord>('add_assignment',
          encryptionCipher: cipher),
      Hive.openBox<UserProfileRecord>('user_profile', encryptionCipher: cipher),
      Hive.openBox<QRRecord>('qr_profile', encryptionCipher: cipher),
      Hive.openBox<String>('userProfileBox', encryptionCipher: cipher),
      Hive.openBox<List<String>>('bannersBox', encryptionCipher: cipher),
      Hive.openBox('loginBox', encryptionCipher: cipher),
    ], eagerError: false);
  } catch (e) {
    debugPrint('Error opening Hive boxes: $e');
  }
}

void main() {
  runZonedGuarded(() async {
    await _initializeApp();

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
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/playstore');

  // For iOS
  final DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    onDidReceiveLocalNotification:
        (int id, String? title, String? body, String? payload) async {
      debugPrint(
          'Received iOS local notification: id=$id, title=$title, body=$body');
    },
  );

  // Combine settings
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  // Initialize the plugin
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint('Notification response received: ${response.payload}');
    },
  );

  // Create notification channels for both platforms
  if (Platform.isAndroid) {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'psbv_next_notification',
      'PSBV Next',
      description: 'Notifications',
      importance: Importance.high,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
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
  final List<GlobalKey<NavigatorState>> _navigatorKeys =
      List.generate(4, (index) => GlobalKey<NavigatorState>());

  // Add StreamSubscription for proper cleanup
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(_routeInterceptor);
    offlineProvider.initialize();

    // Optimize connectivity listener
    _initializeConnectivity();
  }

  Future<void> _initializeConnectivity() async {
    // Delay enabling connection check
    Future.delayed(const Duration(seconds: 20))
        .then((_) => _enableConnection = true);

    _connectivitySubscription =
        connectivityResult.onConnectivityChanged.listen((source) async {
      if (!_enableConnection) return;

      if (!mounted) return;

      if (source.contains(ConnectivityResult.none)) {
        showToast('No internet', Colors.red, Icons.mobiledata_off_rounded);
        await offlineProvider.autoOffline(true);
      } else if (source.contains(ConnectivityResult.wifi) ||
          source.contains(ConnectivityResult.mobile)) {
        showToast(
            source.contains(ConnectivityResult.wifi) ? 'WiFi' : 'Internet',
            Colors.green,
            Icons.wifi);
        await offlineProvider.autoOffline(false);
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    BackButtonInterceptor.remove(_routeInterceptor);
    super.dispose();
  }

  // Optimize route interceptor
  bool _routeInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    if (!mounted) return false;

    final currentContext = _navigatorKeys[_selectedIndex].currentContext;
    if (currentContext == null) return false;

    // Check for keyboard first
    if (MediaQuery.of(currentContext).viewInsets.bottom > 0) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      return true;
    }

    final navigationState = Navigator.of(currentContext);
    if (navigationState.canPop()) {
      navigationState.pop();
      return true;
    }
    return false;
  }

  Future<bool> _onWillPop() async {
    final navState = _navigatorKeys[_selectedIndex].currentState;
    if (navState == null) return true;
    return !await navState.maybePop();
  }

  // Optimize item tap handler
  void _onItemTapped(int index) {
    if (!mounted) return;

    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
      if (index == 1) {
        final homeCalendarState = HomeCalendarState();
        if (homeCalendarState is Refreshable) {
          homeCalendarState.refresh();
        }
      }
    } else {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: List.generate(
            3,
            (index) => Navigator(
              key: _navigatorKeys[index],
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => _buildScreen(index),
              ),
            ),
          ),
        ),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const AttendanceScreen();
      case 1:
        return const HomeCalendar();
      case 2:
        return const Dashboard();
      default:
        return const SizedBox.shrink();
    }
  }
}

Dio createSecureDio() {
  final Dio dio = Dio();

  // Optimize timeout settings and headers
  dio.options = BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    headers: const {
      HttpHeaders.contentTypeHeader: 'application/json',
      'Accept': 'application/json',
    },
    responseType: ResponseType.json,
    validateStatus: (status) => status != null && status < 500,
    followRedirects: true,
    maxRedirects: 5,
  );

  // Add optimized interceptors
  dio.interceptors.addAll([
    _createRetryInterceptor(),
    if (!kDebugMode) _createCacheInterceptor(),
    _createSecurityInterceptor(),
  ]);

  return dio;
}

Interceptor _createRetryInterceptor() {
  return InterceptorsWrapper(
    onError: (DioException error, handler) async {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        if ((error.requestOptions.extra['retryCount'] ?? 0) < 3) {
          error.requestOptions.extra['retryCount'] =
              (error.requestOptions.extra['retryCount'] ?? 0) + 1;

          // Add exponential backoff
          await Future.delayed(
            Duration(
                milliseconds:
                    pow(2, error.requestOptions.extra['retryCount']).toInt() *
                        1000),
          );

          return handler.resolve(await Dio().fetch(error.requestOptions));
        }
      }
      return handler.next(error);
    },
  );
}

Interceptor _createCacheInterceptor() {
  return InterceptorsWrapper(
    onResponse: (response, handler) {
      final headers = response.headers;
      if (!headers.map.containsKey(HttpHeaders.cacheControlHeader)) {
        headers.set(HttpHeaders.cacheControlHeader, 'public, max-age=300');
      }
      return handler.next(response);
    },
  );
}

Interceptor _createSecurityInterceptor() {
  return InterceptorsWrapper(
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
  );
}
