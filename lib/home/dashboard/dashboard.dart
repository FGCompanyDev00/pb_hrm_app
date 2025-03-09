import 'dart:convert';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approvals_page/approvals_main_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/returnCar/car_return_page.dart';
import 'package:pb_hrsystem/home/dashboard/history/history_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking_page.dart';
import 'package:pb_hrsystem/home/qr_profile_page.dart';
import 'package:pb_hrsystem/notifications/notification_page.dart';
import 'package:pb_hrsystem/user_model.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:pb_hrsystem/home/settings_page.dart';
import 'package:pb_hrsystem/login/login_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  DashboardState createState() => DashboardState();
}

class DashboardState extends State<Dashboard>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  // Enhanced cache management with memory optimization
  static final Map<String, _CacheData> _pageCache = {};
  static const Duration _cacheExpiry = Duration(minutes: 15);
  static const int _maxCacheSize = 50;
  DateTime? _lastCacheUpdate;

  // Optimized state management
  bool _hasUnreadNotifications = true;
  bool _isLoading = false;
  int _currentPage = 0;
  bool _isDisposed = false;
  bool _isPaused = false;
  bool _isInitialized = false;

  // Memoized values
  late final PageController _pageController;
  Timer? _carouselTimer;

  // Cached data with lazy loading
  late Future<void> _initializationFuture;
  late Future<UserProfile> futureUserProfile;
  late Future<List<String>> futureBanners;

  // Optimized navigation
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final RouteObserver<PageRoute> _routeObserver = RouteObserver<PageRoute>();

  // Location optimization
  Position? _lastKnownPosition;
  bool _isLocationEnabled = false;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Hive boxes with nullable initialization
  Box<String>? _userProfileBox;
  Box<List<String>>? _bannersBox;

  // Memoized action items - Move initialization to didChangeDependencies
  List<Map<String, dynamic>>? _actionItems;

  // Cached screen dimensions
  late final double _screenWidth;
  late final double _screenHeight;

  // Add new field for location update control
  static const Duration _locationTimeout = Duration(seconds: 15);
  static const Duration _locationUpdateInterval = Duration(minutes: 5);
  DateTime? _lastLocationUpdate;

  @override
  bool get wantKeepAlive => true;

  String get baseUrl => dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializationFuture = _initialize();
    _initializePageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeActionItems();
  }

  void _initializeActionItems() {
    if (_actionItems != null) return; // Only initialize once

    _actionItems = [
      {
        'icon': 'assets/data-2.png',
        'label': AppLocalizations.of(context)!.history,
        'onTap': () => navigateToPage(const HistoryPage()),
      },
      {
        'icon': 'assets/people.png',
        'label': AppLocalizations.of(context)!.approvals,
        'onTap': () => navigateToPage(const ApprovalsMainPage()),
      },
      {
        'icon': 'assets/status-up.png',
        'label': AppLocalizations.of(context)!.workTracking,
        'onTap': () => navigateToPage(const WorkTrackingPage()),
      },
      {
        'icon': 'assets/car_return.png',
        'label': AppLocalizations.of(context)!.carReturn,
        'onTap': () => navigateToPage(const ReturnCarPage()),
      },
      {
        'icon': 'assets/KPI.png',
        'label': AppLocalizations.of(context)!.kpi,
        'onTap': () {},
      },
      {
        'icon': 'assets/inventory.png',
        'label': AppLocalizations.of(context)!.inventory,
        'onTap': () {},
      },
    ];
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;

    switch (state) {
      case AppLifecycleState.paused:
        _isPaused = true;
        _carouselTimer?.cancel();
        _positionStreamSubscription?.pause();
        break;
      case AppLifecycleState.resumed:
        _isPaused = false;
        if (!_isDisposed) {
          _startCarouselTimer();
          if (_shouldTrackLocation()) {
            _initializeLocation();
          }
          _refreshDataSafely();
        }
        break;
      default:
        break;
    }
  }

  // Safe refresh method
  void _refreshDataSafely() {
    if (!mounted || _isDisposed || _isPaused) return;

    try {
      setState(() {
        futureUserProfile = fetchUserProfile();
        futureBanners = fetchBanners();
      });

      if (!_isDisposed && mounted) {
        Provider.of<UserProvider>(context, listen: false).fetchAndUpdateUser();
      }
    } catch (e) {
      debugPrint('Error refreshing data: $e');
    }
  }

  // Optimized navigation methods with error handling
  Future<void> navigateToPage(Widget page) async {
    if (!mounted || _isDisposed) return;

    try {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => page,
          settings: RouteSettings(name: page.runtimeType.toString()),
        ),
      );

      if (result == true && mounted && !_isDisposed) {
        _refreshDataSafely();
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _positionStreamSubscription?.cancel();
    _pageController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  void _initializePageController() {
    _pageController = PageController(initialPage: _currentPage)
      ..addListener(_handlePageChange);
    _startCarouselTimer();
  }

  void _handlePageChange() {
    if (!_pageController.hasClients) return;
    setState(() {
      _currentPage = _pageController.page?.round() ?? 0;
    });
  }

  Future<void> _initialize() async {
    try {
      setState(() => _isLoading = true);

      // Initialize Hive boxes first
      await _initializeHiveBoxes();

      // Initialize secure storage safely
      await _initializeSecureStorage();

      // Only initialize futures after Hive boxes are ready
      futureUserProfile = fetchUserProfile();
      futureBanners = fetchBanners();

      if (!_isDisposed) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (!_isDisposed) {
        setState(() => _isLoading = false);
      }
      rethrow;
    }
  }

  Future<void> _initializeSecureStorage() async {
    try {
      final storage = const FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock,
          synchronizable: true,
        ),
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );

      // Initialize with default values if needed
      final Map<String, String> initialValues = {
        'biometricEnabled': 'false',
        // Add other secure storage keys here
      };

      // Check existing values and only write if they don't exist
      for (var entry in initialValues.entries) {
        try {
          final existingValue = await storage.read(key: entry.key);
          if (existingValue == null) {
            await storage.write(
              key: entry.key,
              value: entry.value,
            );
          }
        } catch (e) {
          debugPrint('Error handling secure storage key ${entry.key}: $e');
          // Try to recover by deleting and rewriting if there's a keychain error
          if (e.toString().contains('-25299')) {
            try {
              await storage.delete(key: entry.key);
              await storage.write(
                key: entry.key,
                value: entry.value,
              );
            } catch (retryError) {
              debugPrint(
                  'Failed to recover secure storage key ${entry.key}: $retryError');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error initializing secure storage: $e');
      // Continue initialization even if secure storage fails
    }
  }

  // Initialize Hive boxes
  Future<void> _initializeHiveBoxes() async {
    try {
      // Open 'userProfileBox' if not already open
      if (!Hive.isBoxOpen('userProfileBox')) {
        _userProfileBox = await Hive.openBox<String>('userProfileBox');
      } else {
        _userProfileBox = Hive.box<String>('userProfileBox');
      }

      // Open 'bannersBox' if not already open
      if (!Hive.isBoxOpen('bannersBox')) {
        _bannersBox = await Hive.openBox<List<String>>('bannersBox');
      } else {
        _bannersBox = Hive.box<List<String>>('bannersBox');
      }
    } catch (e) {
      debugPrint('Error initializing Hive boxes: $e');
      rethrow;
    }
  }

  // Optimized data fetching
  Future<UserProfile> fetchUserProfile() async {
    if (_isDisposed) return UserProfile.fromJson({});

    try {
      // First try to get from memory cache
      final cachedProfile = _getCachedData('userProfile');
      if (cachedProfile != null) {
        // Return cached data immediately while checking for updates
        _checkForProfileUpdates();
        return cachedProfile as UserProfile;
      }

      // Then try to get from Hive
      final cachedProfileJson = userProfileBox.get('userProfile');
      if (cachedProfileJson != null) {
        final profile = UserProfile.fromJson(jsonDecode(cachedProfileJson));
        _updateCache('userProfile', profile);
        // Return Hive data while checking for updates
        _checkForProfileUpdates();
        return profile;
      }

      // If no cache, fetch from API
      return await _fetchProfileFromApi();
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      // Try to return cached data even if error
      final cachedProfileJson = userProfileBox.get('userProfile');
      if (cachedProfileJson != null) {
        return UserProfile.fromJson(jsonDecode(cachedProfileJson));
      }
      rethrow;
    }
  }

  Future<void> _checkForProfileUpdates() async {
    try {
      final newProfile = await _fetchProfileFromApi();
      final oldProfile = _getCachedData('userProfile') as UserProfile?;

      // Compare if data has changed
      if (oldProfile == null ||
          oldProfile.toJson().toString() != newProfile.toJson().toString()) {
        if (!_isDisposed && mounted) {
          setState(() {
            _updateCache('userProfile', newProfile);
            userProfileBox.put('userProfile', jsonEncode(newProfile.toJson()));
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking for profile updates: $e');
    }
  }

  Future<UserProfile> _fetchProfileFromApi() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    if (token == null) throw Exception('No token found');

    final response = await http.get(
      Uri.parse('$baseUrl/api/display/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseJson = jsonDecode(response.body);
      final List<dynamic> results = responseJson['results'];

      if (results.isNotEmpty) {
        final userProfile = UserProfile.fromJson(results[0]);
        _updateCache('userProfile', userProfile);
        await userProfileBox.put(
            'userProfile', jsonEncode(userProfile.toJson()));
        return userProfile;
      }
    }
    throw Exception('Failed to fetch profile');
  }

  // Optimized banner fetching
  Future<List<String>> fetchBanners() async {
    if (_isDisposed) return [];

    try {
      // First try memory cache
      final cachedBanners = _getCachedData('banners');
      if (cachedBanners != null) {
        // Return cached data immediately while checking for updates
        _checkForBannerUpdates();
        return List<String>.from(cachedBanners);
      }

      // Then try Hive cache
      final hiveBanners = bannersBox.get('banners');
      if (hiveBanners != null) {
        _updateCache('banners', hiveBanners);
        // Return Hive data while checking for updates
        _checkForBannerUpdates();
        return hiveBanners;
      }

      // If no cache, fetch from API
      return await _fetchBannersFromApi();
    } catch (e) {
      debugPrint('Error fetching banners: $e');
      return bannersBox.get('banners') ?? [];
    }
  }

  Future<void> _checkForBannerUpdates() async {
    try {
      final newBanners = await _fetchBannersFromApi();
      final oldBanners = _getCachedData('banners') as List<String>?;

      // Compare if data has changed
      if (oldBanners == null || !listEquals(oldBanners, newBanners)) {
        if (!_isDisposed && mounted) {
          setState(() {
            _updateCache('banners', newBanners);
            bannersBox.put('banners', newBanners);
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking for banner updates: $e');
    }
  }

  Future<List<String>> _fetchBannersFromApi() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/api/app/promotions/files'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final results = jsonDecode(response.body)['results'];
      final banners =
          results.map<String>((file) => file['files'] as String).toList();
      _updateCache('banners', banners);
      await bannersBox.put('banners', banners);
      return banners;
    }

    throw Exception('Failed to fetch banners');
  }

  // Enhanced cache management
  void _updateCache(String key, dynamic data) {
    if (_pageCache.length >= _maxCacheSize) {
      _cleanCache();
    }

    _pageCache[key] = _CacheData(
      data: data,
      timestamp: DateTime.now(),
      accessCount: 0,
    );
    _lastCacheUpdate = DateTime.now();
  }

  void _cleanCache() {
    final now = DateTime.now();
    _pageCache.removeWhere((_, item) =>
        now.difference(item.timestamp) > _cacheExpiry ||
        item.accessCount > 100);

    if (_pageCache.length >= _maxCacheSize) {
      final sortedEntries = _pageCache.entries.toList()
        ..sort((a, b) => a.value.accessCount.compareTo(b.value.accessCount));

      for (var i = 0; i < _maxCacheSize / 2; i++) {
        _pageCache.remove(sortedEntries[i].key);
      }
    }
  }

  dynamic _getCachedData(String key) {
    final cachedItem = _pageCache[key];
    if (cachedItem == null) return null;

    if (DateTime.now().difference(cachedItem.timestamp) > _cacheExpiry) {
      _pageCache.remove(key);
      return null;
    }

    cachedItem.accessCount++;
    return cachedItem.data;
  }

  // Start the carousel auto-swipe timer
  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_pageController.hasClients) {
        int nextPage = _currentPage + 1;
        // Calculate the total number of pages
        double maxScrollExtent = _pageController.position.maxScrollExtent;
        double viewportDimension = _pageController.position.viewportDimension;
        int totalPages = (maxScrollExtent / viewportDimension).ceil();

        if (nextPage >= totalPages) {
          nextPage = 0;
        }
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeIn,
        );
        setState(() {
          _currentPage = nextPage;
        });
      }
    });
  }

  // Getters for Hive boxes with null safety
  Box<String> get userProfileBox {
    if (_userProfileBox == null) {
      throw StateError('userProfileBox has not been initialized');
    }
    return _userProfileBox!;
  }

  Box<List<String>> get bannersBox {
    if (_bannersBox == null) {
      throw StateError('bannersBox has not been initialized');
    }
    return _bannersBox!;
  }

  // Add location initialization method
  Future<void> _initializeLocation() async {
    if (_isDisposed) return;

    try {
      // Check if we need to update location based on interval
      if (_lastLocationUpdate != null &&
          DateTime.now().difference(_lastLocationUpdate!) <
              _locationUpdateInterval) {
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return;
      }

      setState(() => _isLocationEnabled = true);

      // Get initial position with improved error handling
      try {
        _lastKnownPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.reduced,
          timeLimit: _locationTimeout,
        ).catchError((error) {
          if (error is TimeoutException) {
            debugPrint(
                'Location timeout detected, this is expected behavior in some cases');
            return null;
          }
          throw error;
        });

        if (_lastKnownPosition != null) {
          _lastLocationUpdate = DateTime.now();
        }
      } catch (e) {
        debugPrint('Error getting initial position: $e');
        // Continue without initial position
      }

      // Only start location updates if we need continuous tracking
      if (_shouldTrackLocation()) {
        _startLocationUpdates();
      }
    } catch (e) {
      debugPrint('Error initializing location: $e');
    }
  }

  bool _shouldTrackLocation() {
    // Add your conditions here for when location tracking is needed
    // For example, only track location during work hours or specific features
    return false; // Default to false to save battery
  }

  void _startLocationUpdates() {
    _positionStreamSubscription?.cancel();

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.reduced,
        distanceFilter: 50,
        timeLimit: _locationTimeout,
      ),
    ).listen(
      (Position position) {
        if (mounted && !_isDisposed) {
          setState(() {
            _lastKnownPosition = position;
            _lastLocationUpdate = DateTime.now();
          });
        }
      },
      onError: (error) {
        if (error is TimeoutException) {
          debugPrint(
              'Location timeout detected, this is expected behavior in some cases');
          return;
        }
        if (mounted && !_isDisposed) {
          debugPrint('Location stream error: $error');
          _handleLocationError(error);
        }
      },
      cancelOnError: false,
    );
  }

  void _handleLocationError(dynamic error) {
    if (!mounted || _isDisposed) return;

    if (error is TimeoutException) {
      // Don't retry immediately on timeout
      return;
    } else if (error.toString().contains('location service disabled')) {
      debugPrint('Location services are disabled. Not restarting updates.');
      setState(() => _isLocationEnabled = false);
    } else {
      debugPrint('Location error: $error');
      if (_shouldTrackLocation()) {
        _restartLocationUpdatesWithDelay(1);
      }
    }
  }

  void _restartLocationUpdatesWithDelay(int seconds) {
    if (!mounted) return; // Kembali awal jika widget tidak dipasang

    debugPrint('Restarting location updates in $seconds seconds');
    _positionStreamSubscription?.cancel();
    Future.delayed(Duration(seconds: seconds), () {
      if (mounted) {
        // Periksa keadaan mounted sebelum memulakan semula
        _startLocationUpdates();
      }
    });
  }

  void _restartLocationUpdates() {
    _restartLocationUpdatesWithDelay(1);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isDisposed) return const SizedBox.shrink();

    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !_isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error initializing app: ${snapshot.error}'),
            ),
          );
        }

        final themeNotifier = Provider.of<ThemeNotifier>(context);
        final bool isDarkMode = themeNotifier.isDarkMode;

        return PopScope(
          onPopInvokedWithResult: (e, result) => false,
          child: Scaffold(
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(140.0),
              child: FutureBuilder<UserProfile>(
                future: futureUserProfile,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildAppBarPlaceholder();
                  } else if (snapshot.hasError) {
                    return _buildErrorAppBar(snapshot.error.toString());
                  } else if (snapshot.hasData) {
                    return _buildAppBar(snapshot.data!, isDarkMode);
                  } else {
                    return _buildErrorAppBar(
                      AppLocalizations.of(context)!.noDataAvailable,
                    );
                  }
                },
              ),
            ),
            body: Stack(
              children: [
                if (isDarkMode) _buildDarkBackground(),
                RefreshIndicator(
                  onRefresh: () async {
                    _refreshDataSafely();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: _buildMainContent(context, isDarkMode),
                  ),
                ),
                if (_isLoading) _buildLoadingIndicator(),
              ],
            ),
          ),
        );
      },
    );
  }

  // AppBar Placeholder while loading
  PreferredSizeWidget _buildAppBarPlaceholder() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  // AppBar with error message
  PreferredSizeWidget _buildErrorAppBar(String errorMessage) {
    return AppBar(
      title: Text(
        AppLocalizations.of(context)!.errorWithDetails(errorMessage),
        style: const TextStyle(color: Colors.red),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  // AppBar with user information
  PreferredSizeWidget _buildAppBar(UserProfile userProfile, bool isDarkMode) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                isDarkMode ? 'assets/darkbg.png' : 'assets/background.png',
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.settings,
                        color: isDarkMode ? Colors.white : Colors.black,
                        size: 32),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsPage()),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfileScreen()),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: userProfile.imgName !=
                                  'default_avatar.jpg'
                              ? NetworkImage(userProfile.imgName)
                              : const AssetImage('assets/default_avatar.jpg')
                                  as ImageProvider,
                          backgroundColor: Colors.white,
                          onBackgroundImageError: (_, __) {
                            const AssetImage('assets/default_avatar.png');
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppLocalizations.of(context)!
                              .greeting(userProfile.name),
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.power_settings_new,
                        color: isDarkMode ? Colors.white : Colors.black,
                        size: 32),
                    onPressed: () => _showLogoutDialog(context, isDarkMode),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Dark mode background
  Widget _buildDarkBackground() {
    return Container(
      color: Colors.black,
    );
  }

  Widget _buildMainContent(BuildContext context, bool isDarkMode) {
    return Container(
      constraints: BoxConstraints(minHeight: sizeScreen(context).height * 0.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBannerCarousel(isDarkMode),
          const SizedBox(height: 10),
          _buildActionMenuHeader(isDarkMode),
          const SizedBox(height: 6),
          // Use Expanded here to allow scrolling of the GridView
          _buildActionGrid(isDarkMode),
        ],
      ),
    );
  }

  // Banner Carousel
  Widget _buildBannerCarousel(bool isDarkMode) {
    return SizedBox(
      height: 175.0,
      child: FutureBuilder<List<String>>(
        future: futureBanners,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show cached banners while loading if available
            final cachedBanners = _getCachedData('banners') as List<String>?;
            if (cachedBanners != null && cachedBanners.isNotEmpty) {
              return _buildBannerPageView(cachedBanners, isDarkMode);
            }
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            // Try to show cached banners on error
            final cachedBanners = _getCachedData('banners') as List<String>?;
            if (cachedBanners != null && cachedBanners.isNotEmpty) {
              return _buildBannerPageView(cachedBanners, isDarkMode);
            }
            return Center(
                child: Text(AppLocalizations.of(context)!
                    .errorWithDetails(snapshot.error.toString())));
          } else if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.isNotEmpty) {
            return _buildBannerPageView(snapshot.data!, isDarkMode);
          } else {
            return Center(
                child: Text(AppLocalizations.of(context)!.noBannersAvailable));
          }
        },
      ),
    );
  }

  Widget _buildBannerPageView(List<String> banners, bool isDarkMode) {
    return PageView.builder(
      controller: _pageController,
      itemCount: banners.length,
      onPageChanged: _handleBannerPageChange,
      itemBuilder: (context, index) {
        final bannerUrl = banners[index];

        if (bannerUrl.isEmpty ||
            Uri.tryParse(bannerUrl)?.hasAbsolutePath != true) {
          return Center(
              child: Text(AppLocalizations.of(context)!.noBannersAvailable));
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CachedNetworkImage(
              imageUrl: bannerUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
                child: const Icon(Icons.error),
              ),
              imageBuilder: (context, imageProvider) => Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    colorFilter: isDarkMode
                        ? ColorFilter.mode(
                            Colors.white.withOpacity(0.1),
                            BlendMode.lighten,
                          )
                        : null,
                  ),
                ),
              ),
              // Enhanced caching configuration
              cacheManager: DefaultCacheManager(),
              maxHeightDiskCache: 1080, // Optimize for most phone screens
              memCacheHeight: 1080,
              fadeOutDuration: const Duration(milliseconds: 300),
              fadeInDuration: const Duration(milliseconds: 300),
            ),
          ),
        );
      },
    );
  }

  // Action Menu Header
  Widget _buildActionMenuHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        height: 43,
        child: Row(
          children: [
            Container(
              width: 4,
              height: 24,
              color: const Color(0xFFDBB342),
              margin: const EdgeInsets.only(right: 12),
            ),
            Text(
              AppLocalizations.of(context)!.actionMenu,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const Spacer(),
            Text(
              AppLocalizations.of(context)!.notification,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications,
                    color: isDarkMode ? Colors.blueAccent : Colors.orangeAccent,
                    size: 27,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NotificationPage()),
                    ).then((_) {
                      _updateNotificationState();
                    });
                  },
                ),
                if (_hasUnreadNotifications)
                  Positioned(
                    right: 11,
                    top: 11,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid(bool isDarkMode) {
    if (_actionItems == null) return const SizedBox.shrink();

    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final crossAxisCount = screenWidth < 600 ? 3 : 3;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.9,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
            ),
            itemCount: _actionItems!.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final item = _actionItems![index];
              return _buildActionCard(
                context,
                item['icon'] as String,
                item['label'] as String,
                isDarkMode,
                item['onTap'] as VoidCallback,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildActionCard(BuildContext context, String imagePath, String title,
      bool isDarkMode, VoidCallback onTap) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double iconSize = constraints.maxWidth * 0.4;
        double fontSize = constraints.maxWidth * 0.1;
        fontSize = fontSize.clamp(12.0, 16.0);

        return Card(
          color: isDarkMode ? Colors.grey[850] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFDBB342), width: 0.8),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: Colors.blue.withAlpha(50),
            splashFactory: InkRipple.splashFactory,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    imagePath,
                    height: iconSize,
                    width: iconSize,
                    fit: BoxFit.contain,
                    color: isDarkMode ? Colors.white : null,
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 60,
                    color: isDarkMode ? Colors.white : const Color(0xFF9C640C),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context)!.logoutTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color:
                          isDarkMode ? Colors.white : const Color(0xFF9C640C),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.logoutConfirmation,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.grey[300] : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode
                              ? Colors.grey[700]
                              : const Color(0xFFF5F1E0),
                          foregroundColor: isDarkMode
                              ? Colors.white
                              : const Color(0xFFDBB342),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 24,
                          ),
                        ),
                        child: Text(AppLocalizations.of(context)!.cancel),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Provider.of<UserProvider>(context, listen: false)
                              .logout();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                            (Route<dynamic> route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDBB342),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 24,
                          ),
                        ),
                        child: Text(AppLocalizations.of(context)!.yesLogout),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Loading Indicator Overlay
  Widget _buildLoadingIndicator() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
      ),
    );
  }

  // Update notification state
  void _updateNotificationState() {
    setState(() {
      _hasUnreadNotifications = false;
    });
  }

  // Banner page change handler
  void _handleBannerPageChange(int index) {
    setState(() {
      _currentPage = index;
    });
  }
}

// UserProfile Model
class UserProfile {
  final String id;
  final String name;
  final String surname;
  final String email;
  final String imgName;
  final List<String> roles;

  UserProfile({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    required this.imgName,
    required this.roles,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    List<String> rolesList = [];
    if (json['roles'] is List) {
      rolesList = List<String>.from(json['roles']);
    } else if (json['roles'] is String) {
      rolesList = (json['roles'] as String)
          .split(',')
          .map((role) => role.trim())
          .toList();
    }

    return UserProfile(
      id: json['id'].toString(),
      name: json['employee_name'],
      surname: json['employee_surname'],
      email: json['employee_email'],
      imgName: json['images'],
      roles: rolesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_name': name,
      'employee_surname': surname,
      'employee_email': email,
      'images': imgName,
      'roles': roles,
    };
  }
}

// Cache data model for better memory management
class _CacheData {
  final dynamic data;
  final DateTime timestamp;
  int accessCount;

  _CacheData({
    required this.data,
    required this.timestamp,
    this.accessCount = 0,
  });
}
