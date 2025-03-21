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
          // Force a refresh of data when app is resumed
          _refreshDataSafely();
          
          // Schedule another refresh after a short delay to ensure images are loaded
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!_isDisposed && mounted) {
              _fetchBannersFromApiAndUpdate(forceUpdate: true);
            }
          });
        }
        break;
      default:
        break;
    }
  }

  // Safe refresh method
  // Improved refresh method that forces updates from API
  void _refreshDataSafely() {
    if (!mounted || _isDisposed || _isPaused) return;

    try {
      // Force update checks when user returns to app
      _checkForProfileUpdates(forceUpdate: true);
      
      // Clear the image cache to ensure fresh images
      DefaultCacheManager().emptyCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      
      // Fetch new data from API
      _fetchBannersFromApiAndUpdate(forceUpdate: true);
      
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
      const storage = FlutterSecureStorage(
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

  // Optimized data fetching with fast cache check and immediate API fallback
  Future<UserProfile> fetchUserProfile() async {
    if (_isDisposed) return UserProfile.fromJson({});

    try {
      // Quick memory cache check - fastest retrieval
      final cachedProfile = _getCachedData('userProfile');
      if (cachedProfile != null) {
        // Start async update check without waiting
        _checkForProfileUpdates(forceUpdate: false);
        return cachedProfile as UserProfile;
      }

      // Quick Hive check - second fastest retrieval
      final cachedProfileJson = userProfileBox.get('userProfile');
      if (cachedProfileJson != null) {
        try {
          final profile = UserProfile.fromJson(jsonDecode(cachedProfileJson));
          _updateCache('userProfile', profile);
          // Start async update check without waiting
          _checkForProfileUpdates(forceUpdate: false);
          return profile;
        } catch (parseError) {
          debugPrint('Error parsing cached profile: $parseError');
          // Continue to API fetch if parse error
        }
      }

      // No cache or cache error - fetch from API immediately
      return await _fetchProfileFromApi();
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      // Try to return cached data even if error
      try {
        final cachedProfileJson = userProfileBox.get('userProfile');
        if (cachedProfileJson != null) {
          return UserProfile.fromJson(jsonDecode(cachedProfileJson));
        }
      } catch (cacheError) {
        debugPrint('Error retrieving from cache: $cacheError');
      }
      rethrow;
    }
  }

  Future<void> _checkForProfileUpdates({bool forceUpdate = false}) async {
    try {
      // Skip update check if we recently checked (unless forced)
      final now = DateTime.now();
      final lastUpdate = _getCacheTimestamp('userProfile');
      if (!forceUpdate && lastUpdate != null && 
          now.difference(lastUpdate) < const Duration(minutes: 5)) {
        return; // Skip frequent updates unless forced
      }
      
      final newProfile = await _fetchProfileFromApi();
      final oldProfile = _getCachedData('userProfile') as UserProfile?;

      // Check specifically for profile image changes
      final hasImageChanged = oldProfile != null && 
          oldProfile.imgName != newProfile.imgName;

      // Compare if data has changed
      if (oldProfile == null ||
          oldProfile.toJson().toString() != newProfile.toJson().toString()) {
        if (!_isDisposed && mounted) {
          // If profile image changed, clear the old image from cache
          if (hasImageChanged && oldProfile?.imgName != null) {
            _clearImageFromCache(oldProfile!.imgName);
          }
          
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

  // Clear a specific image from the cache
  Future<void> _clearImageFromCache(String imageUrl) async {
    try {
      if (imageUrl.isNotEmpty && Uri.tryParse(imageUrl)?.hasAbsolutePath == true) {
        // Clear both the disk cache and the memory cache
        await DefaultCacheManager().removeFile(imageUrl);
        
        // Also clear from Flutter's image cache
        final provider = NetworkImage(imageUrl);
        PaintingBinding.instance.imageCache.evict(provider);
        
        // Clear from CachedNetworkImage's cache
        final cachedProvider = CachedNetworkImageProvider(imageUrl);
        PaintingBinding.instance.imageCache.evict(cachedProvider);
        
        debugPrint('Cleared old image from all caches: $imageUrl');
      }
    } catch (e) {
      debugPrint('Error clearing image from cache: $e');
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

  // Optimized banner fetching with fast cache check and immediate API fallback
  Future<List<String>> fetchBanners() async {
    if (_isDisposed) return [];

    try {
      // Always start an API fetch in the background to ensure fresh data
      // This ensures we always have the latest data when reopening the app
      _fetchBannersFromApiAndUpdate(forceUpdate: true);
      
      // Quick memory cache check - fastest retrieval for immediate display
      final cachedBanners = _getCachedData('banners');
      if (cachedBanners != null) {
        return List<String>.from(cachedBanners);
      }

      // Quick Hive check - second fastest retrieval
      final hiveBanners = bannersBox.get('banners');
      if (hiveBanners != null && hiveBanners.isNotEmpty) {
        _updateCache('banners', hiveBanners);
        return hiveBanners;
      }

      // No cache or empty cache - wait for API fetch to complete
      return await _fetchBannersFromApi();
    } catch (e) {
      debugPrint('Error fetching banners: $e');
      try {
        return bannersBox.get('banners') ?? [];
      } catch (cacheError) {
        debugPrint('Error retrieving banners from cache: $cacheError');
        return [];
      }
    }
  }

  // New method to fetch banners from API and update state
  Future<void> _fetchBannersFromApiAndUpdate({bool forceUpdate = false}) async {
    try {
      // Skip update check if we recently checked (unless forced)
      final now = DateTime.now();
      final lastUpdate = _getCacheTimestamp('banners');
      if (!forceUpdate && lastUpdate != null && 
          now.difference(lastUpdate) < const Duration(minutes: 2)) { // Reduced time to 2 minutes
        return; // Skip frequent updates unless forced
      }
      
      final newBanners = await _fetchBannersFromApi();
      final oldBanners = _getCachedData('banners') as List<String>?;

      // Compare if data has changed
      if (oldBanners == null || !listEquals(oldBanners, newBanners)) {
        if (!_isDisposed && mounted) {
          // Clear old banner images from cache if they're no longer used
          if (oldBanners != null) {
            final removedBanners = oldBanners.where(
                (oldUrl) => !newBanners.contains(oldUrl)).toList();
            for (final bannerUrl in removedBanners) {
              _clearImageFromCache(bannerUrl);
            }
            
            // Prefetch new images that weren't in the old list
            final newImages = newBanners.where(
                (newUrl) => !oldBanners.contains(newUrl)).toList();
            for (final bannerUrl in newImages) {
              _prefetchImage(bannerUrl);
            }
          } else {
            // Prefetch all images if we had no old banners
            for (final bannerUrl in newBanners) {
              _prefetchImage(bannerUrl);
            }
          }
          
          setState(() {
            _updateCache('banners', newBanners);
            bannersBox.put('banners', newBanners);
            // Update the future to trigger UI refresh with new data
            futureBanners = Future.value(newBanners);
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking for banner updates: $e');
    }
  }
  
  // Helper method to prefetch images
  void _prefetchImage(String imageUrl) {
    if (imageUrl.isEmpty || Uri.tryParse(imageUrl)?.hasAbsolutePath != true) return;
    
    try {
      final provider = CachedNetworkImageProvider(imageUrl);
      precacheImage(provider, context);
    } catch (e) {
      debugPrint('Error prefetching image: $e');
    }
  }
  
  Future<void> _checkForBannerUpdates({bool forceUpdate = false}) async {
    return _fetchBannersFromApiAndUpdate(forceUpdate: forceUpdate);
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

  // Enhanced cache management with timestamp tracking
  void _updateCache(String key, dynamic data) {
    if (_pageCache.length >= _maxCacheSize) {
      _cleanCache();
    }

    final now = DateTime.now();
    _pageCache[key] = _CacheData(
      data: data,
      timestamp: now,
      accessCount: 0,
    );
    _lastCacheUpdate = now;
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

  // Get cached data with improved timestamp tracking
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

  // Get the timestamp of when an item was cached
  DateTime? _getCacheTimestamp(String key) {
    final cachedItem = _pageCache[key];
    return cachedItem?.timestamp;
  }

  // Start the carousel auto-swipe timer with improved animation
  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_pageController.hasClients) {
        int nextPage = _currentPage + 1;
        // Calculate the total number of pages
        double maxScrollExtent = _pageController.position.maxScrollExtent;
        double viewportDimension = _pageController.position.viewportDimension;
        int totalPages = (maxScrollExtent / viewportDimension).ceil() + 1;

        if (nextPage >= totalPages) {
          nextPage = 0;
        }
        
        // Prefetch the next image before animation starts
        if (nextPage < totalPages) {
          final banners = _getCachedData('banners') as List<String>?;
          if (banners != null && banners.isNotEmpty && nextPage < banners.length) {
            _prefetchImage(banners[nextPage]);
          }
        }
        
        // Improved animation curve for smoother transitions
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
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

  // Add location initialization method with improved timeout handling
  Future<void> _initializeLocation() async {
    if (_isDisposed) return;

    try {
      // Check if we need to update location based on interval
      if (_lastLocationUpdate != null &&
          DateTime.now().difference(_lastLocationUpdate!) <
              _locationUpdateInterval) {
        return;
      }

      // Wrap in a try-catch to prevent any location errors from crashing the app
      try {
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

        // Get initial position with improved error handling and shorter timeout
        try {
          // Use a completer with a timeout to avoid hanging
          final completer = Completer<Position?>();
          
          // Set up a timeout that completes with null after 10 seconds
          Timer(const Duration(seconds: 10), () {
            if (!completer.isCompleted) {
              debugPrint('💡 Location timeout detected - completing with null');
              completer.complete(null);
            }
          });
          
          // Start the actual location request
          Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.reduced,
            timeLimit: const Duration(seconds: 10),
          ).then((position) {
            if (!completer.isCompleted) {
              completer.complete(position);
            }
          }).catchError((error) {
            if (!completer.isCompleted) {
              if (error is TimeoutException) {
                debugPrint('Location timeout caught and handled gracefully');
                completer.complete(null);
              } else {
                completer.completeError(error);
              }
            }
          });
          
          // Wait for either the position or the timeout
          _lastKnownPosition = await completer.future.catchError((error) {
            debugPrint('Error getting position, handled gracefully: $error');
            return null;
          });

          if (_lastKnownPosition != null) {
            _lastLocationUpdate = DateTime.now();
          }
        } catch (e) {
          debugPrint('Error getting initial position (handled): $e');
          // Continue without initial position
        }

        // Only start location updates if we need continuous tracking
        if (_shouldTrackLocation()) {
          _startLocationUpdates();
        }
      } catch (e) {
        // Catch any location service errors
        debugPrint('Location service error (handled): $e');
      }
    } catch (e) {
      // Final fallback to ensure app doesn't crash
      debugPrint('Error initializing location (handled at root): $e');
    }
  }

  bool _shouldTrackLocation() {
    
    return false; // Default to false to save battery
  }

  void _startLocationUpdates() {
    // Cancel any existing subscription first
    _positionStreamSubscription?.cancel();

    try {
      // Create a new position stream with more resilient error handling
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.reduced,
          distanceFilter: 50,
          timeLimit: Duration(seconds: 10), // Shorter timeout to prevent hanging
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
          // Handle all errors gracefully without propagating
          if (error is TimeoutException) {
            debugPrint('💡 Location timeout detected - attempting to recover');
            // Don't propagate timeout errors, just log them
            return;
          }
          
          if (mounted && !_isDisposed) {
            // Log but don't crash on location errors
            debugPrint('Location stream error (handled): $error');
            _handleLocationError(error);
          }
        },
        cancelOnError: false, // Never cancel on error to maintain the stream
      );
    } catch (e) {
      // Catch any errors during stream setup
      debugPrint('Error setting up location stream (handled): $e');
    }
  }

  void _handleLocationError(dynamic error) {
    if (!mounted || _isDisposed) return;

    try {
      if (error is TimeoutException) {
        // For timeouts, wait longer before retrying to avoid rapid retries
        debugPrint('Location timeout - waiting before retry');
        if (_shouldTrackLocation()) {
          _restartLocationUpdatesWithDelay(5); // Wait 5 seconds before retry
        }
        return;
      } else if (error.toString().contains('location service disabled')) {
        debugPrint('Location services are disabled. Not restarting updates.');
        setState(() => _isLocationEnabled = false);
      } else {
        debugPrint('Location error (handled): $error');
        if (_shouldTrackLocation()) {
          _restartLocationUpdatesWithDelay(3); // Wait 3 seconds for other errors
        }
      }
    } catch (e) {
      // Final safety net to prevent any crashes in the error handler itself
      debugPrint('Error in location error handler (handled): $e');
    }
  }

  void _restartLocationUpdatesWithDelay(int seconds) {
    if (!mounted) return; // Return early if widget is not mounted

    debugPrint('Restarting location updates in $seconds seconds');
    // Cancel existing subscription
    _positionStreamSubscription?.cancel();
    
    // Use a try-catch to prevent any errors during the delayed restart
    try {
      Future.delayed(Duration(seconds: seconds), () {
        // Verify the widget is still mounted before restarting
        if (mounted && !_isDisposed) {
          _startLocationUpdates();
        }
      });
    } catch (e) {
      debugPrint('Error scheduling location restart (handled): $e');
    }
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
                          backgroundColor: Colors.white,
                          child: userProfile.imgName != 'avatar_placeholder.png'
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: userProfile.imgName,
                                    fit: BoxFit.cover,
                                    width: 56,
                                    height: 56,
                                    progressIndicatorBuilder: (context, url, progress) => Center(
                                      child: CircularProgressIndicator(
                                        value: progress.progress,
                                        strokeWidth: 2.0,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Image.asset(
                                      'assets/avatar_placeholder.png',
                                      fit: BoxFit.cover,
                                      width: 56,
                                      height: 56,
                                    ),
                                    // Optimized caching for profile images
                                    memCacheWidth: 112, // 2x for high DPI displays
                                    memCacheHeight: 112,
                                    useOldImageOnUrlChange: true,
                                  ),
                                )
                              : Image.asset(
                                  'assets/avatar_placeholder.png',
                                  fit: BoxFit.cover,
                                  width: 56,
                                  height: 56,
                                ),
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

  // Banner Carousel with improved loading and animation
  Widget _buildBannerCarousel(bool isDarkMode) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 175.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: FutureBuilder<List<String>>(
        future: futureBanners,
        builder: (context, snapshot) {
          // Always try to show cached banners first for immediate display
          final cachedBanners = _getCachedData('banners') as List<String>?;
          
          if (cachedBanners != null && cachedBanners.isNotEmpty) {
            // If we have cached data, show it immediately while fetching new data in background
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Start a background refresh if we're waiting for new data
              Future.microtask(() => _fetchBannersFromApiAndUpdate(forceUpdate: true));
            }
            return _buildBannerPageView(cachedBanners, isDarkMode);
          }
          
          // Handle other states when no cached data is available
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDarkMode ? Colors.blueAccent : Colors.orangeAccent,
                ),
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: isDarkMode ? Colors.redAccent : Colors.red,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.errorWithDetails(snapshot.error.toString()),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.isNotEmpty) {
            // If we have new data from API, update cache and show it
            if (!listEquals(snapshot.data!, cachedBanners ?? [])) {
              _updateCache('banners', snapshot.data!);
              bannersBox.put('banners', snapshot.data!);
            }
            return _buildBannerPageView(snapshot.data!, isDarkMode);
          } else {
            return Center(
              child: Text(
                AppLocalizations.of(context)!.noBannersAvailable,
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                  fontSize: 16,
                ),
              ),
            );
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

        // Prefetch next image for smoother swiping
        if (index < banners.length - 1) {
          _prefetchImage(banners[index + 1]);
        }

        return Hero(
          tag: 'banner_$index',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuint,
            margin: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode ? Colors.black54 : Colors.black12,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                key: ValueKey('banner_image_$bannerUrl'),
                imageUrl: bannerUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 40, color: Colors.red),
                      const SizedBox(height: 8),
                      Text(
                        'Image failed to load',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
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
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.2),
                        ],
                        stops: const [0.7, 1.0],
                      ),
                    ),
                  ),
                ),
                // Enhanced caching configuration with optimized settings
                cacheManager: DefaultCacheManager(),
                maxHeightDiskCache: 1080, // Optimize for most phone screens
                memCacheHeight: 1080,
                fadeOutDuration: const Duration(milliseconds: 150), // Faster transitions
                fadeInDuration: const Duration(milliseconds: 250),
                // Improved caching behavior
                useOldImageOnUrlChange: false, // Don't use old image, always fetch fresh
                placeholderFadeInDuration: const Duration(milliseconds: 200),
                progressIndicatorBuilder: (context, url, progress) => Container(
                  color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: progress.progress,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDarkMode ? Colors.blueAccent : Colors.orangeAccent,
                      ),
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
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
    
    // Prefetch the next image when user manually changes page
    final banners = _getCachedData('banners') as List<String>?;
    if (banners != null && banners.isNotEmpty) {
      // Prefetch next image
      if (index < banners.length - 1) {
        _prefetchImage(banners[index + 1]);
      }
      // Also prefetch previous image for backward swiping
      if (index > 0) {
        _prefetchImage(banners[index - 1]);
      }
    }
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
