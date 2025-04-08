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
import 'package:path_provider/path_provider.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/core/widgets/connectivity_indicator.dart';
import 'package:pb_hrsystem/core/widgets/snackbar/snackbar.dart';
import 'package:pb_hrsystem/hive_helper/model/add_assignment_record.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking_page.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:pb_hrsystem/login/date.dart';
import 'package:pb_hrsystem/models/qr_profile_page.dart';
import 'package:pb_hrsystem/nav/custom_bottom_nav_bar.dart';
import 'package:pb_hrsystem/services/offline_service.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:pb_hrsystem/services/session_service.dart';
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
import 'package:pb_hrsystem/login/login_page.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:hive/hive.dart';
import 'package:pb_hrsystem/hive_helper/model/event_record.dart';
import 'package:pb_hrsystem/hive_helper/model/calendar_events_record.dart';
import 'package:pb_hrsystem/hive_helper/model/calendar_events_list_record.dart';
import 'package:pb_hrsystem/widgets/update_dialog.dart';
import 'core/utils/responsive_helper.dart';

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

  final Map<String, _CacheItem> _cache = {};
  final Duration _cacheDuration = const Duration(minutes: 15);
  static const int _maxCacheSize = 100; // Limit cache size

  void set(String key, dynamic value) {
    // Clear old entries if cache is too large
    if (_cache.length >= _maxCacheSize) {
      _cleanCache();
    }

    _cache[key] = _CacheItem(
      value: value,
      timestamp: DateTime.now(),
    );
  }

  dynamic get(String key) {
    final item = _cache[key];
    if (item == null) return null;

    if (DateTime.now().difference(item.timestamp) > _cacheDuration) {
      _cache.remove(key);
      return null;
    }

    return item.value;
  }

  void _cleanCache() {
    final now = DateTime.now();
    _cache.removeWhere(
        (_, item) => now.difference(item.timestamp) > _cacheDuration);

    // If still too large, remove oldest entries
    if (_cache.length >= _maxCacheSize) {
      final sortedEntries = _cache.entries.toList()
        ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

      for (var i = 0; i < _maxCacheSize / 2; i++) {
        _cache.remove(sortedEntries[i].key);
      }
    }
  }

  void clear() => _cache.clear();
}

class _CacheItem {
  final dynamic value;
  final DateTime timestamp;

  _CacheItem({required this.value, required this.timestamp});
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

  const platformChannelSpecifics = NotificationDetails(
    android: AndroidNotificationDetails(
      'psvb_next_notification',
      'PSBV Next',
      channelDescription: 'Notifications',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    ),
    iOS: DarwinNotificationDetails(
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
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load environment variables
  await dotenv.load(fileName: ".env.demo");

  // Initialize secure storage for iOS
  await _initializeSecureStorage();

  // Initialize Hive database
  await _initializeHiveOptimized();

  // Cache base URL after environment is loaded
  appCache.baseUrl = dotenv.env['BASE_URL'];

  // Initialize remaining services
  await _initializeServices();

  // Initialize session service for background checks
  try {
    // Use a timeout to prevent hanging if workmanager is problematic
    bool sessionInitialized = false;

    try {
      await SessionService.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint("Session service initialization timed out");
          return;
        },
      );
      sessionInitialized = true;
    } catch (e) {
      debugPrint("Error during session service initialization: $e");
    }

    // Set up a fallback for session checks if workmanager isn't available
    _setupSessionCheckFallback();

    if (sessionInitialized) {
      debugPrint("Session service initialization completed successfully");
    } else {
      debugPrint("Using fallback session check mechanism");
    }
  } catch (e) {
    debugPrint("Error initializing session service: $e");
    // Set up fallback mechanism for session checks
    _setupSessionCheckFallback();
  }

  // Try to initialize Firebase and notifications, but don't block app startup if they fail
  _initializeFirebaseAndNotifications();
}

Future<void> _initializeServices() async {
  try {
    // Initialize Dio with optimized settings
    final dio = createSecureDio();
    sl.registerSingleton<Dio>(dio);

    // Initialize remaining services
    await setupServiceLocator();

    // Initialize calendar database with proper error handling
    try {
      await sl<OfflineProvider>().initializeCalendar();
      debugPrint("Calendar database initialized successfully");
    } catch (e) {
      debugPrint("Error initializing calendar: $e");
      // Don't rethrow - allow app to continue even if calendar fails

      // If database was closed unexpectedly, try to reset connections
      if (e.toString().contains('database_closed') ||
          e.toString().contains('open_failed') ||
          e.toString().contains('create database queue')) {
        debugPrint("Attempting to reset calendar database connection...");
        await sl<OfflineProvider>().resetDatabases();
      }
    }

    // Initialize history database separately to isolate potential issues
    try {
      await sl<OfflineProvider>().initializeHistory();
      debugPrint("History database initialized successfully");
    } catch (e) {
      debugPrint("Error initializing history database: $e");
      // Don't rethrow - allow app to continue even if history database fails

      // If database was closed unexpectedly, try to reset connections
      if (e.toString().contains('database_closed') ||
          e.toString().contains('open_failed') ||
          e.toString().contains('create database queue')) {
        debugPrint("Attempting to reset history database connection...");
        await sl<OfflineProvider>().resetDatabases();
      }
    }
  } catch (e) {
    debugPrint("Error initializing services: $e");
    logger.e("Service initialization error: $e");
    // Log error but don't block app startup
  }
}

Future<void> _initializeNotifications() async {
  // Initialize local notifications but don't request permissions yet
  await _initializeLocalNotifications();

  // Initialize Firebase Messaging without requesting permissions
  await _initializeFirebaseMessagingWithoutPermissions();
}

Future<void> _initializeFirebaseMessagingWithoutPermissions() async {
  try {
    // Register handlers without requesting permissions
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
          "Firebase message received in foreground: ${message.messageId}");
      _showNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("Notification tapped: ${message.data}");
    });

    // Don't request notification permissions here - let the user decide in the permission flow
  } catch (e) {
    // Catch any errors to prevent app from crashing if Firebase is not available
    debugPrint("Error initializing Firebase Messaging: $e");
  }
}

Future<void> _initializeHiveOptimized() async {
  try {
    // Initialize Hive
    await Hive.initFlutter();

    // Get the application documents directory
    final appDocumentDir = await getApplicationDocumentsDirectory();
    final path = appDocumentDir.path;

    // Register all adapters
    Hive.registerAdapter(AttendanceRecordAdapter());
    Hive.registerAdapter(AddAssignmentRecordAdapter());
    Hive.registerAdapter(UserProfileRecordAdapter());
    Hive.registerAdapter(QRRecordAdapter());
    Hive.registerAdapter(EventRecordAdapter());
    Hive.registerAdapter(CalendarEventsRecordAdapter());
    Hive.registerAdapter(CalendarEventsListRecordAdapter());

    // Initialize boxes with proper path configuration
    await Hive.openBox('loginBox', path: '$path/login.hive');
    await Hive.openBox('attendanceBox', path: '$path/attendance.hive');
    await Hive.openBox('assignmentBox', path: '$path/assignment.hive');
    await Hive.openBox('calendarBox', path: '$path/calendar.hive');
    await Hive.openBox('historyBox', path: '$path/history.hive');

    debugPrint('Hive initialized successfully with path: $path');
  } catch (e) {
    debugPrint('Error initializing Hive: $e');
    // Implement fallback mechanism if needed
  }
}

/// Initialize secure storage with iOS-specific options
Future<void> _initializeSecureStorage() async {
  if (Platform.isIOS) {
    // Configure secure storage for iOS with accessibility options
    const secureStorage = FlutterSecureStorage(
      iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock,
          synchronizable: true,
          // Use package name as account name for better organization
          accountName: 'pb_hrsystem'),
    );

    // Test storage with proper error handling
    try {
      // First try to read existing value
      final existingValue = await secureStorage.read(key: 'test_key');
      if (existingValue != null) {
        // If exists, delete it first
        await secureStorage.delete(key: 'test_key');
      }

      // Now try to write
      try {
        await secureStorage.write(key: 'test_key', value: 'test_value');
      } catch (e) {
        if (e is PlatformException && e.code == '-25299') {
          // Item exists, try to delete and write again
          await secureStorage.delete(key: 'test_key');
          await secureStorage.write(key: 'test_key', value: 'test_value');
        } else {
          rethrow;
        }
      }

      final testValue = await secureStorage.read(key: 'test_key');
      if (testValue == 'test_value') {
        debugPrint('Secure storage initialized successfully on iOS');
      } else {
        debugPrint('Secure storage test failed on iOS');
      }
      await secureStorage.delete(key: 'test_key');
    } catch (e) {
      debugPrint('Error initializing secure storage on iOS: $e');
      // Try to reset keychain if there are persistent issues
      await _resetKeychain();
    }
  }
}

// Add helper function to reset keychain if needed
Future<void> _resetKeychain() async {
  try {
    const secureStorage = FlutterSecureStorage();
    await secureStorage.deleteAll();
    debugPrint('Keychain reset successful');
  } catch (e) {
    debugPrint('Error resetting keychain: $e');
  }
}

// Add extension method for secure storage operations
extension SecureStorageExtension on FlutterSecureStorage {
  Future<void> writeSecurely(
      {required String key, required String value}) async {
    try {
      await write(key: key, value: value);
    } catch (e) {
      if (e is PlatformException && e.code == '-25299') {
        // Item exists, delete and try again
        await delete(key: key);
        await write(key: key, value: value);
      } else {
        rethrow;
      }
    }
  }
}

Future<void> _initializeFirebaseAndNotifications() async {
  try {
    // Initialize Firebase (optional)
    await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform)
        .catchError((e) {
      debugPrint("Firebase initialization failed: $e");
      return null;
    });

    // Initialize notifications (optional)
    await _initializeNotifications();
  } catch (e) {
    // Log error but don't block app startup
    debugPrint("Error initializing Firebase and notifications: $e");
  }
}

// Fallback mechanism for session checks when workmanager isn't available
void _setupSessionCheckFallback() {
  // Check session every 15 minutes using a regular Timer
  Timer.periodic(const Duration(minutes: 15), (_) {
    try {
      SessionService.checkSessionStatus();
    } catch (e) {
      debugPrint("Error in fallback session check: $e");
    }
  });

  // Also check immediately
  Future.delayed(const Duration(seconds: 10), () {
    try {
      SessionService.checkSessionStatus();
    } catch (e) {
      debugPrint("Error in initial fallback session check: $e");
    }
  });
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

    // Handle keychain storage error
    if (error is PlatformException && error.code == '-25299') {
      logger.i(
          'Item already exists in keychain - this is expected in some cases');
      return;
    }

    // Handle location timeout specifically
    if (error is TimeoutException &&
        error.toString().contains('position update')) {
      logger.i('Location timeout detected - attempting to recover');
      // Add retry mechanism with exponential backoff
      Future.delayed(const Duration(seconds: 5), () {
        // Attempt to get location again
        // You may want to implement your location service retry logic here
      });
      return;
    }
  });
}

/// ------------------------------------------
/// 4) A private method for plugin initialization
/// ------------------------------------------
Future<void> _initializeLocalNotifications() async {
  try {
    // For Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/playstore');

    // For iOS - don't request permissions on initialization
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      onDidReceiveLocalNotification:
          (int id, String? title, String? body, String? payload) async {
        debugPrint(
            'Received iOS local notification: id=$id, title=$title, body=$body');
      },
    );

    // Combine settings
    final InitializationSettings initializationSettings =
        InitializationSettings(
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

    // Create notification channels for Android
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'psvb_next_notification',
        'PSVB Next',
        description: 'Notifications',
        importance: Importance.high,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  } catch (e) {
    // Catch any errors to prevent app from crashing if notifications are not available
    debugPrint("Error initializing local notifications: $e");
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

  // Handle session expiry notifications
  if (response.payload == 'session_expired') {
    // Navigate to login page
    navigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/login', (route) => false);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeNotifier, LanguageNotifier>(
      builder: (context, themeNotifier, languageNotifier, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          builder: (context, child) {
            ResponsiveHelper.init(context);
            child = EasyLoading.init()(context, child);
            return child!;
          },
          title: 'PSVB Next',
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
          routes: {
            '/login': (context) => const LoginPage(),
            '/workTrackingPage': (context) => const WorkTrackingPage(),
          },
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

class MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 1;
  final List<GlobalKey<NavigatorState>> _navigatorKeys =
      List.generate(4, (index) => GlobalKey<NavigatorState>());

  late final StreamSubscription<List<ConnectivityResult>>
      _connectivitySubscription;
  bool _isDisposed = false;
  bool _isShowingConnectivityMessage = false;

  // Add overlay entry for connectivity status
  OverlayEntry? _overlayEntry;
  Timer? _overlayTimer;

  // Memoize screens to prevent unnecessary rebuilds
  late final List<Widget> _screens;

  // Timer for session check
  Timer? _sessionCheckTimer;

  // Flag to prevent showing multiple account warning more than once per session
  bool _hasCheckedMultipleAccounts = false;

  @override
  void initState() {
    super.initState();
    // Add observer for app lifecycle events
    WidgetsBinding.instance.addObserver(this);
    BackButtonInterceptor.add(_routeInterceptor);
    offlineProvider.initialize();

    // Initialize screens once
    _screens = [
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
    ];

    // Initialize connectivity immediately
    _initializeConnectivity();
    _startSessionCheck();

    // Check for multiple accounts
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _checkForMultipleAccounts();
      }
    });

    // Check for updates when app starts
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkForUpdates();
      }
    });
  }

  // Add lifecycle event handler to check for updates and connectivity when app is resumed
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Check connectivity when app is resumed
      _checkAndShowConnectivity();
      _checkForUpdates();
    }
  }

  // Add method to check for available updates
  Future<void> _checkForUpdates() async {
    if (mounted) {
      await UpdateDialogService.showUpdateDialog(context);
    }
  }

  // Start periodic session check
  void _startSessionCheck() {
    // Check session every 5 minutes
    _sessionCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isDisposed) return;
      _checkSessionStatus();
    });

    // Also check immediately
    _checkSessionStatus();
  }

  // Check session status and show dialog if expired
  void _checkSessionStatus() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (mounted && userProvider.isLoggedIn) {
      if (!userProvider.isSessionValid) {
        userProvider.logout();
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
        return;
      }
      userProvider.checkSessionStatus(context);
    }
  }

  // New method to check current connectivity
  Future<void> _checkAndShowConnectivity() async {
    if (!mounted || _isDisposed) return;

    try {
      final results = await connectivityResult.checkConnectivity();
      final hasInternet = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.mobile);

      if (mounted) {
        _showConnectivityOverlay(hasInternet, results);
      }
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
    }
  }

  void _showConnectivityOverlay(
      bool hasInternet, List<ConnectivityResult> source) {
    // Remove existing overlay if any
    _overlayEntry?.remove();
    _overlayTimer?.cancel();

    if (!mounted || _isDisposed) return;

    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300), // Faster animation
            tween: Tween<double>(begin: -100, end: 0),
            curve: Curves.easeOutCubic, // Smoother curve
            builder: (context, value, child) => Transform.translate(
              offset: Offset(0, value),
              child: child,
            ),
            child: Container(
              margin: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: hasInternet
                    ? Colors.green.withOpacity(0.95)
                    : Colors.red.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (hasInternet ? Colors.green : Colors.red)
                        .withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      hasInternet
                          ? (source.contains(ConnectivityResult.wifi)
                              ? Icons.wifi_rounded
                              : Icons.signal_cellular_alt_rounded)
                          : Icons.signal_wifi_off_rounded,
                      color: Colors.white,
                      size: 24,
                      key: ValueKey(hasInternet ? 'connected' : 'disconnected'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    hasInternet
                        ? (source.contains(ConnectivityResult.wifi)
                            ? 'WiFi Connected'
                            : 'Mobile Data Connected')
                        : 'No Internet Connection',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // If overlay is null at this point, exit
    if (overlay == null) return;

    // Insert overlay
    overlay.insert(_overlayEntry!);

    // Auto-dismiss the overlay after 3 seconds
    _overlayTimer = Timer(const Duration(seconds: 3), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  Future<void> _initializeConnectivity() async {
    // Check connectivity immediately when app starts
    await _checkAndShowConnectivity();

    // Listen to connectivity changes with shorter delay
    _connectivitySubscription =
        connectivityResult.onConnectivityChanged.listen((source) async {
      if (_isDisposed) return;

      final bool hasInternet = source.contains(ConnectivityResult.wifi) ||
          source.contains(ConnectivityResult.mobile);

      if (mounted) {
        _showConnectivityOverlay(hasInternet, source);

        if (!hasInternet) {
          await offlineProvider.autoOffline(true);
        } else {
          await offlineProvider.autoOffline(false);
        }
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _overlayEntry?.remove();
    _overlayTimer?.cancel();
    // Remove the observer
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription.cancel();
    _sessionCheckTimer?.cancel();
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
        body: Stack(
          children: [
            // Main content
            IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),

            // Connectivity indicator
            const ConnectivityIndicator(),
          ],
        ),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  /// Check for multiple user accounts stored in the app
  Future<void> _checkForMultipleAccounts() async {
    // Skip if we've already checked in this session
    if (_hasCheckedMultipleAccounts) return;
    _hasCheckedMultipleAccounts = true;

    try {
      // First check Hive for multiple accounts
      final Box loginBox = await Hive.openBox('loginBox');
      final bool isLoggedIn = loginBox.get('is_logged_in') ?? false;

      if (!isLoggedIn) return; // Skip if not logged in

      // Get all available tokens from SharedPreferences
      final UserPreferences prefs = sl<UserPreferences>();
      final List<String> activeUserIds = await prefs.getActiveUserIds();

      // Let's define "multiple accounts" as having more than one active user ID
      if (activeUserIds.length > 1) {
        if (mounted) {
          // Show warning dialog
          _showMultipleAccountsWarningDialog(activeUserIds);
        }
      }
    } catch (e) {
      debugPrint('Error checking for multiple accounts: $e');
    }
  }

  /// Shows a warning dialog about multiple user accounts
  void _showMultipleAccountsWarningDialog(List<String> accounts) {
    if (!mounted) return;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Multiple Accounts Detected',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'There should not be multiple active user accounts in this app. Please clear app storage and log in again to continue using the app safely.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.red.shade900.withOpacity(0.3)
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isDarkMode ? Colors.red.shade800 : Colors.red.shade200,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'To clear storage:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Go to Settings > Apps\n2. Find this app\n3. Clear Storage/Data\n4. Reopen the app and login',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor:
                    isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
              child: const Text('I\'ll Fix Later'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDarkMode ? Colors.orange : const Color(0xFFFF9800),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                // Logout and go to login screen
                Provider.of<UserProvider>(context, listen: false).logout();
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (route) => false);
              },
              child: const Text('Logout Now'),
            ),
          ],
        );
      },
    );
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
