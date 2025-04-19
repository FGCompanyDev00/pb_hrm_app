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
    with
        AutomaticKeepAliveClientMixin,
        WidgetsBindingObserver,
        TickerProviderStateMixin {
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

  String standardErrorMessage =
      'We\'re unable to process your request at the moment. Please contact IT support for assistance.';

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

  // Animasi baru
  late AnimationController _bellAnimationController;
  late Animation<double> _bellAnimation;

  late AnimationController _settingsRotationController;
  late Animation<double> _settingsRotationAnimation;

  late AnimationController _logoutGradientController;
  late Animation<double> _logoutGradientAnimation;

  late AnimationController _waveHandController;
  late Animation<double> _waveHandAnimation;

  // Create a dedicated CacheManager for profile images
  static final profileImageCacheManager = CacheManager(
    Config(
      'profileImageCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 20,
      repo: JsonCacheInfoRepository(databaseName: 'profileImageCache'),
      fileService: HttpFileService(),
    ),
  );

  // Create a dedicated CacheManager for banner images
  static final bannerImageCacheManager = CacheManager(
    Config(
      'bannerImageCache',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 50,
      repo: JsonCacheInfoRepository(databaseName: 'bannerImageCache'),
      fileService: HttpFileService(),
    ),
  );

  @override
  bool get wantKeepAlive => true;

  String get baseUrl => dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializationFuture = _initialize();
    _initializePageController();

    // Inisialisasi animasi-animasi baru
    _initAnimations();
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
        'onTap': () =>
            navigatorKey.currentState?.pushNamed('/workTrackingPage'),
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

          // Instead of full refresh, use cached data first then update in background
          _quickLoadThenRefresh();
        }
        break;
      case AppLifecycleState.inactive:
        // Save current state to make resuming faster
        _persistCurrentState();
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

  // Optimized navigation methods with better caching
  Future<void> navigateToPage(Widget page) async {
    if (!mounted || _isDisposed) return;

    try {
      // Save current state before navigation for faster return
      _persistCurrentState();

      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => page,
          settings: RouteSettings(name: page.runtimeType.toString()),
        ),
      );

      if (result == true && mounted && !_isDisposed) {
        _quickLoadThenRefresh();
      } else {
        // Just ensure cached data is used on return
        if (mounted && !_isDisposed) {
          setState(() {
            // Trigger rebuild with cached data
          });
        }
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

    // Dispose animasi-animasi baru
    _bellAnimationController.dispose();
    _settingsRotationController.dispose();
    _logoutGradientController.dispose();
    _waveHandController.dispose();

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

      // Check if we have cached data for immediate display
      bool hasCachedProfile = false;
      bool hasCachedBanners = false;

      try {
        // Try memory cache first (fastest)
        final cachedProfile = _getCachedData('userProfile');
        final cachedBanners = _getCachedData('banners');

        hasCachedProfile = cachedProfile != null;
        hasCachedBanners =
            cachedBanners != null && (cachedBanners as List).isNotEmpty;

        // If no memory cache, check Hive
        if (!hasCachedProfile) {
          final profileJson = _userProfileBox?.get('userProfile');
          hasCachedProfile = profileJson != null;

          // Preload profile to memory cache if available
          if (hasCachedProfile) {
            final profile = UserProfile.fromJson(jsonDecode(profileJson!));
            _updateCache('userProfile', profile);
          }
        }

        if (!hasCachedBanners) {
          final banners = _bannersBox?.get('banners');
          hasCachedBanners = banners != null && banners.isNotEmpty;

          // Preload banners to memory cache if available
          if (hasCachedBanners) {
            _updateCache('banners', banners);
          }
        }
      } catch (cacheError) {
        debugPrint('Error checking cache during initialization: $cacheError');
      }

      // Initialize futures based on cache status
      futureUserProfile = hasCachedProfile
          ? Future.value(_getCachedData('userProfile') as UserProfile)
          : fetchUserProfile();

      futureBanners = hasCachedBanners
          ? Future.value(_getCachedData('banners') as List<String>)
          : fetchBanners();

      if (!_isDisposed) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });

        // If we used cached data, refresh in background after UI is displayed
        if (hasCachedProfile || hasCachedBanners) {
          Future.microtask(() {
            if (hasCachedProfile) _checkForProfileUpdates(forceUpdate: false);
            if (hasCachedBanners)
              _fetchBannersFromApiAndUpdate(forceUpdate: false);
          });
        }
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

  // Optimized data fetching with improved caching strategy
  Future<UserProfile> fetchUserProfile() async {
    if (_isDisposed) return UserProfile.fromJson({});

    try {
      // Use memory cache for fastest retrieval - immediate display without any delay
      final cachedProfile = _getCachedData('userProfile');
      if (cachedProfile != null) {
        // Start async update check without waiting for UI
        Future.microtask(() => _checkForProfileUpdates(forceUpdate: false));
        return cachedProfile as UserProfile;
      }

      // Fall back to Hive for persistence between app launches
      final cachedProfileJson = userProfileBox.get('userProfile');
      if (cachedProfileJson != null) {
        try {
          final profile = UserProfile.fromJson(jsonDecode(cachedProfileJson));
          _updateCache('userProfile', profile);

          // Prefetch the profile image immediately for faster display
          if (profile.imgName.isNotEmpty &&
              profile.imgName != 'avatar_placeholder.png') {
            _prefetchImage(profile.imgName);
          }

          // Start async update check in background
          Future.microtask(() => _checkForProfileUpdates(forceUpdate: false));
          return profile;
        } catch (parseError) {
          debugPrint('Error parsing cached profile: $parseError');
        }
      }

      // No cache available - fetch from API immediately
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
    if (_isDisposed) return;

    try {
      // Skip update check if we have a recent profile (unless forced)
      final cachedProfile = _getCachedData('userProfile') as UserProfile?;
      final cacheTimestamp = _getCacheTimestamp('userProfile');

      // Only check for updates if the cache is old or forced
      if (!forceUpdate && cachedProfile != null && cacheTimestamp != null) {
        final cacheAge = DateTime.now().difference(cacheTimestamp);
        if (cacheAge < const Duration(minutes: 5)) {
          return; // Cache is fresh enough, skip update
        }
      }

      final newProfile = await _fetchProfileFromApi();
      final oldProfile = _getCachedData('userProfile') as UserProfile?;

      // Check specifically for profile image changes
      final hasImageChanged =
          oldProfile != null && oldProfile.imgName != newProfile.imgName;

      // Compare if data has changed
      if (oldProfile == null ||
          oldProfile.toJson().toString() != newProfile.toJson().toString()) {
        if (!_isDisposed && mounted) {
          // If profile image changed, clear the old image from cache
          if (hasImageChanged && oldProfile?.imgName != null) {
            _clearImageFromCache(oldProfile!.imgName);
          }

          // Prefetch new image before updating state
          if (newProfile.imgName.isNotEmpty &&
              newProfile.imgName != 'avatar_placeholder.png') {
            _prefetchImage(newProfile.imgName);
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
      if (imageUrl.isNotEmpty &&
          Uri.tryParse(imageUrl)?.hasAbsolutePath == true) {
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

  // Optimized banner fetching with improved caching
  Future<List<String>> fetchBanners() async {
    if (_isDisposed) return [];

    try {
      // Memory cache check - immediate display
      final cachedBanners = _getCachedData('banners');
      if (cachedBanners != null) {
        // Prefetch banner images in background for faster display
        Future.microtask(() {
          final banners = List<String>.from(cachedBanners);
          if (banners.isNotEmpty) {
            // Prefetch current banner and next one
            _prefetchImage(banners[_currentPage]);
            if (_currentPage + 1 < banners.length) {
              _prefetchImage(banners[_currentPage + 1]);
            }
          }

          // Check for updates in background without blocking UI
          _checkForBannerUpdates(forceUpdate: false);
        });

        return List<String>.from(cachedBanners);
      }

      // Hive persistent cache check
      final hiveBanners = bannersBox.get('banners');
      if (hiveBanners != null && hiveBanners.isNotEmpty) {
        _updateCache('banners', hiveBanners);

        // Prefetch banner images in background
        Future.microtask(() {
          if (hiveBanners.isNotEmpty) {
            _prefetchImage(hiveBanners[0]);
            if (hiveBanners.length > 1) {
              _prefetchImage(hiveBanners[1]);
            }
          }

          // Check for updates in background
          _checkForBannerUpdates(forceUpdate: false);
        });

        return hiveBanners;
      }

      // No cache - fetch from API
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
      // Skip update check if we already have banners (unless forced)
      final cachedBanners = _getCachedData('banners') as List<String>?;
      if (!forceUpdate && cachedBanners != null && cachedBanners.isNotEmpty) {
        return; // Use cached banners, no need to refresh
      }

      final newBanners = await _fetchBannersFromApi();
      final oldBanners = _getCachedData('banners') as List<String>?;

      // Compare if data has changed
      if (oldBanners == null || !listEquals(oldBanners, newBanners)) {
        if (!_isDisposed && mounted) {
          // Clear old banner images from cache if they're no longer used
          if (oldBanners != null) {
            final removedBanners = oldBanners
                .where((oldUrl) => !newBanners.contains(oldUrl))
                .toList();
            for (final bannerUrl in removedBanners) {
              _clearImageFromCache(bannerUrl);
            }

            // Prefetch new images that weren't in the old list
            final newImages = newBanners
                .where((newUrl) => !oldBanners.contains(newUrl))
                .toList();
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
  void _prefetchImage(String imageUrl, {bool highPriority = false}) {
    if (imageUrl.isEmpty || Uri.tryParse(imageUrl)?.hasAbsolutePath != true)
      return;

    try {
      // Create a unique cache key for better control
      final cacheKey = 'img_${imageUrl.hashCode}';

      // Use CachedNetworkImageProvider with precacheImage for efficient caching
      final provider = CachedNetworkImageProvider(
        imageUrl,
        cacheKey: cacheKey,
        maxWidth: 1080, // Limit max size for memory efficiency
        maxHeight: 1080,
      );

      // Precache with higher priority for important images
      precacheImage(provider, context, onError: (exception, stackTrace) {
        debugPrint('Error precaching image: $exception');
      });

      // Also ensure it's in the disk cache for persistence
      DefaultCacheManager().getSingleFile(imageUrl).then((file) {
        // debugPrint('Image cached to disk: ${file.path}');
      }).catchError((e) {
        debugPrint('Error caching image to disk: $e');
      });
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

    // Pre-cache profile image if this is a user profile update
    if (key == 'userProfile' &&
        data is UserProfile &&
        data.imgName.isNotEmpty &&
        data.imgName != 'avatar_placeholder.png') {
      _prefetchImage(data.imgName);
    }
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

  // Start the carousel auto-swipe timer with modern sliding effect
  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 12), (Timer timer) {
      if (_pageController.hasClients) {
        int nextPage = _currentPage + 1;
        // Calculate the total number of pages
        double maxScrollExtent = _pageController.position.maxScrollExtent;
        double viewportDimension = _pageController.position.viewportDimension;
        int totalPages = (maxScrollExtent / viewportDimension).ceil() + 1;

        if (nextPage >= totalPages) {
          nextPage = 0;
        }

        // Prefetch the next image if it's already in the cache
        if (nextPage < totalPages) {
          final banners = _getCachedData('banners') as List<String>?;
          if (banners != null &&
              banners.isNotEmpty &&
              nextPage < banners.length) {
            // Prefetch next image for smoother transitions
            final imageUrl = banners[nextPage];
            if (imageUrl.isNotEmpty) {
              _prefetchImage(imageUrl);

              // Also prefetch the image after the next one
              if (nextPage + 1 < banners.length) {
                _prefetchImage(banners[nextPage + 1]);
              }
            }
          }
        }

        // Modern sliding animation with smoother curve
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 900),
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
          timeLimit:
              Duration(seconds: 10), // Shorter timeout to prevent hanging
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
          _restartLocationUpdatesWithDelay(
              3); // Wait 3 seconds for other errors
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

  // New method to quickly show cached data then refresh in background
  void _quickLoadThenRefresh() {
    if (!mounted || _isDisposed || _isPaused) return;

    try {
      // First use cached data for immediate display
      final cachedProfile = _getCachedData('userProfile') as UserProfile?;
      final cachedBanners = _getCachedData('banners') as List<String>?;

      // If we have cached data, use it immediately
      if (cachedProfile != null &&
          cachedBanners != null &&
          cachedBanners.isNotEmpty) {
        setState(() {
          // Use cached data for immediate UI update
        });

        // Then refresh in background
        Future.microtask(() {
          _checkForProfileUpdates(forceUpdate: false);
          _fetchBannersFromApiAndUpdate(forceUpdate: false);
        });
      } else {
        // If no cache, do a regular refresh
        _refreshDataSafely();
      }
    } catch (e) {
      debugPrint('Error in quick load: $e');
    }
  }

  // New method to save current state for faster resume
  void _persistCurrentState() {
    try {
      // Save any important state that needs to persist
      final cachedProfile = _getCachedData('userProfile') as UserProfile?;
      if (cachedProfile != null) {
        userProfileBox.put('userProfile', jsonEncode(cachedProfile.toJson()));
      }

      final cachedBanners = _getCachedData('banners') as List<String>?;
      if (cachedBanners != null) {
        bannersBox.put('banners', cachedBanners);
      }
    } catch (e) {
      debugPrint('Error persisting state: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isDisposed) return const SizedBox.shrink();

    // Preload profile picture when dashboard is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && _getCachedData('userProfile') != null) {
        final profile = _getCachedData('userProfile') as UserProfile?;
        if (profile != null &&
            profile.imgName.isNotEmpty &&
            profile.imgName != 'avatar_placeholder.png') {
          _prefetchImage(profile.imgName);
        }
      }
    });

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
              child: Text('Error initializing app: $standardErrorMessage'),
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
                      standardErrorMessage,
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
        standardErrorMessage,
        style: const TextStyle(color: Colors.red),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  // AppBar with user information
  Widget _buildAppBar(UserProfile userProfile, bool isDarkMode) {
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
                  // Settings Icon with rotation animation
                  AnimatedBuilder(
                    animation: _settingsRotationAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _settingsRotationAnimation.value,
                        child: IconButton(
                          icon: Icon(Icons.settings,
                              color: isDarkMode ? Colors.white : Colors.black,
                              size: 32),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SettingsPage()),
                          ),
                        ),
                      );
                    },
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
                        ProfileAvatar(
                          userProfile: userProfile,
                          isDarkMode: isDarkMode,
                          cacheManager: profileImageCacheManager,
                        ),
                        const SizedBox(height: 6),
                        // Greeting text with waving hand emoji
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppLocalizations.of(context)!
                                  .greeting(userProfile.name),
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontSize: 22,
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _waveHandAnimation,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _waveHandAnimation.value,
                                  child: const Text(
                                    " 👋",
                                    style: TextStyle(
                                      fontSize: 22,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Logout Icon with gradient animation
                  AnimatedBuilder(
                    animation: _logoutGradientAnimation,
                    builder: (context, child) {
                      return ShaderMask(
                        shaderCallback: (bounds) {
                          return SweepGradient(
                            colors: isDarkMode
                                ? const [
                                    Colors.white,
                                    Color(0xFFFF8A80),
                                    Colors.white,
                                    Color(0xFFEF5350)
                                  ]
                                : const [
                                    Colors.black,
                                    Colors.red,
                                    Colors.black,
                                    Color(0xFFB71C1C)
                                  ],
                            stops: const [0.0, 0.25, 0.5, 0.75],
                            startAngle: 0.0,
                            endAngle: 3.14159 * 2,
                            transform: GradientRotation(
                                _logoutGradientAnimation.value * 2 * 3.14159),
                          ).createShader(bounds);
                        },
                        child: IconButton(
                          icon: Icon(Icons.power_settings_new,
                              color: Colors.white, size: 32),
                          onPressed: () =>
                              _showLogoutDialog(context, isDarkMode),
                        ),
                      );
                    },
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
    return BannerCarousel(
      futurebanners: futureBanners,
      cachedBanners: _getCachedData('banners') as List<String>?,
      cacheManager: bannerImageCacheManager,
      pageController: _pageController,
      currentPage: _currentPage,
      onPageChanged: _handleBannerPageChange,
      isDarkMode: isDarkMode,
      height: 175.0,
      standardErrorMessage: standardErrorMessage,
      onPreloadImage: _prefetchImage,
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
            // Bell icon dengan animasi - tanpa gradient
            AnimatedBuilder(
              animation: _bellAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _bellAnimation.value,
                  child: Stack(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.notifications,
                          color: isDarkMode ? Colors.white : Colors.black87,
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
                );
              },
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

  // Custom page transition when user manually changes page
  void _handleBannerPageChange(int index) {
    setState(() {
      _currentPage = index;
    });

    // Prefetch adjacent images when user manually changes page
    final banners = _getCachedData('banners') as List<String>?;
    if (banners != null && banners.isNotEmpty) {
      // Prefetch current image if not already loaded
      if (index < banners.length) {
        _prefetchImage(banners[index]);
      }

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

  // Inisialisasi semua animasi
  void _initAnimations() {
    // Bell icon animation
    _bellAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _bellAnimation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(
        parent: _bellAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Settings rotation animation
    _settingsRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _settingsRotationAnimation =
        Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(
        parent: _settingsRotationController,
        curve: Curves.linear,
      ),
    );

    // Logout gradient animation - lebih smooth dan natural
    _logoutGradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5), // Durasi lebih panjang
    )..repeat();

    _logoutGradientAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoutGradientController,
        curve: Curves.easeInOut, // Perubahan kurva animasi
      ),
    );

    // Wave hand animation - lebih lambat
    _waveHandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Durasi lebih panjang
    )..repeat(reverse: true);

    _waveHandAnimation = Tween<double>(begin: -0.15, end: 0.15).animate(
      // Jangkauan sedikit dikurangi
      CurvedAnimation(
        parent: _waveHandController,
        curve: Curves.easeInOut,
      ),
    );
  }

  // Check network connectivity status
  Future<bool> _hasNetworkConnection() async {
    try {
      final result = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return result.statusCode == 200;
    } catch (e) {
      return false;
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

// Dedicated widget for profile avatar with improved image handling
class ProfileAvatar extends StatefulWidget {
  final UserProfile userProfile;
  final bool isDarkMode;
  final CacheManager cacheManager;

  const ProfileAvatar({
    Key? key,
    required this.userProfile,
    required this.isDarkMode,
    required this.cacheManager,
  }) : super(key: key);

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  late final String imageUrl;
  late final String cacheKey;
  bool _isOnline = true;
  bool _isLoading = true;
  FileInfo? _cachedFileInfo;

  @override
  void initState() {
    super.initState();
    imageUrl = widget.userProfile.imgName;
    cacheKey = 'profile_${widget.userProfile.id}_${imageUrl.hashCode}';
    _checkConnectivity();
    _loadFromCache();
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _isOnline = result.statusCode == 200;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOnline = false;
        });
      }
    }
  }

  Future<void> _loadFromCache() async {
    try {
      if (imageUrl.isEmpty || imageUrl == 'avatar_placeholder.png') {
        _finishLoading();
        return;
      }

      // Try to get the file from cache first
      _cachedFileInfo = await widget.cacheManager.getFileFromCache(cacheKey);

      if (_cachedFileInfo != null) {
        // We have a cached file, use it and trigger rebuild
        if (mounted) setState(() {});
      }

      if (_isOnline) {
        // If online, fetch the latest version in background
        _updateCacheFromNetwork();
      } else {
        // If offline, just use the cache
        _finishLoading();
      }
    } catch (e) {
      debugPrint('Error loading profile image from cache: $e');
      _finishLoading();
    }
  }

  Future<void> _updateCacheFromNetwork() async {
    try {
      if (imageUrl.isEmpty || imageUrl == 'avatar_placeholder.png') {
        _finishLoading();
        return;
      }

      // Download the image and update cache
      final fileInfo = await widget.cacheManager.downloadFile(
        imageUrl,
        key: cacheKey,
        force: true, // Force update to get fresh image
      );

      if (mounted) {
        setState(() {
          _cachedFileInfo = fileInfo;
        });
      }
    } catch (e) {
      debugPrint('Error updating profile image from network: $e');
    } finally {
      _finishLoading();
    }
  }

  void _finishLoading() {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.white,
      child: imageUrl.isEmpty || imageUrl == 'avatar_placeholder.png'
          ? Image.asset(
              'assets/avatar_placeholder.png',
              fit: BoxFit.cover,
              width: 56,
              height: 56,
            )
          : _buildProfileImage(),
    );
  }

  Widget _buildProfileImage() {
    // If we have a cached file and not forcing online refresh, use it directly
    if (_cachedFileInfo != null && (!_isOnline || !_isLoading)) {
      return ClipOval(
        child: Image.file(
          _cachedFileInfo!.file,
          fit: BoxFit.cover,
          width: 56,
          height: 56,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/avatar_placeholder.png',
              fit: BoxFit.cover,
              width: 56,
              height: 56,
            );
          },
        ),
      );
    }

    // If we're online or don't have cache yet, use CachedNetworkImage
    return ClipOval(
      child: CachedNetworkImage(
        cacheManager: widget.cacheManager,
        cacheKey: cacheKey,
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: 56,
        height: 56,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        progressIndicatorBuilder: (context, url, progress) => Center(
          child: CircularProgressIndicator(
            value: progress.progress,
            strokeWidth: 2.0,
            color: widget.isDarkMode ? Colors.white70 : Colors.black45,
          ),
        ),
        errorWidget: (context, url, error) => Image.asset(
          'assets/avatar_placeholder.png',
          fit: BoxFit.cover,
          width: 56,
          height: 56,
        ),
      ),
    );
  }
}

class BannerCarousel extends StatefulWidget {
  final Future<List<String>> futurebanners;
  final List<String>? cachedBanners;
  final CacheManager cacheManager;
  final PageController pageController;
  final int currentPage;
  final Function(int) onPageChanged;
  final bool isDarkMode;
  final double height;
  final String standardErrorMessage;
  final Function(String, {bool highPriority}) onPreloadImage;

  const BannerCarousel({
    Key? key,
    required this.futurebanners,
    this.cachedBanners,
    required this.cacheManager,
    required this.pageController,
    required this.currentPage,
    required this.onPageChanged,
    required this.isDarkMode,
    required this.height,
    required this.standardErrorMessage,
    required this.onPreloadImage,
  }) : super(key: key);

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel>
    with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  List<String> _banners = [];
  Map<String, FileInfo?> _cachedBannerFiles = {};
  late AnimationController _loadingController;
  late Animation<double> _loadingAnimation;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _loadingController, curve: Curves.easeInOutCubic));

    _checkConnectivity();
    _initializeBanners();
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _isOnline = result.statusCode == 200;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOnline = false;
        });
      }
    }
  }

  Future<void> _initializeBanners() async {
    // First use cached banners if available
    if (widget.cachedBanners != null && widget.cachedBanners!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _banners = List.from(widget.cachedBanners!);
        });
      }

      // Load cached files for faster display
      _loadCachedBannerFiles(widget.cachedBanners!);
    }

    // Then wait for actual data from API if online
    if (_isOnline) {
      try {
        final apiBanners = await widget.futurebanners;
        if (mounted && apiBanners.isNotEmpty) {
          setState(() {
            _banners = apiBanners;
          });

          // Preload all banner images for smooth experience
          _preloadAllBannerImages(apiBanners);
        }
      } catch (e) {
        debugPrint('Error loading banners from API: $e');
      }
    }
  }

  Future<void> _loadCachedBannerFiles(List<String> banners) async {
    for (final url in banners) {
      if (url.isEmpty) continue;

      try {
        final cacheKey = 'banner_${url.hashCode}';
        final cachedFile = await widget.cacheManager.getFileFromCache(cacheKey);

        if (cachedFile != null && mounted) {
          setState(() {
            _cachedBannerFiles[url] = cachedFile;
          });
        }
      } catch (e) {
        debugPrint('Error loading cached banner file: $e');
      }
    }
  }

  void _preloadAllBannerImages(List<String> banners) {
    for (final url in banners) {
      if (url.isEmpty) continue;

      try {
        final cacheKey = 'banner_${url.hashCode}';

        // Preload current, previous, and next banner
        final currentIndex = _banners.indexOf(url);
        if (currentIndex == widget.currentPage ||
            currentIndex == widget.currentPage - 1 ||
            currentIndex == widget.currentPage + 1) {
          // Immediate preload for visible banners
          widget.onPreloadImage(url, highPriority: true);

          // Also ensure it's in disk cache
          widget.cacheManager.getSingleFile(url, key: cacheKey).then((file) {
            if (mounted) {
              setState(() {
                _cachedBannerFiles[url] = FileInfo(
                  file,
                  FileSource.Cache,
                  DateTime.now().add(const Duration(days: 7)),
                  url,
                );
              });
            }
          });
        } else {
          // Lower priority for other banners
          widget.onPreloadImage(url);
        }
      } catch (e) {
        debugPrint('Error preloading banner image: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: _banners.isEmpty
          ? _buildLoadingPlaceholder()
          : Column(
              children: [
                Expanded(
                  child: _buildBannerPageView(),
                ),
                const SizedBox(height: 8),
                _buildPageIndicator(_banners.length, widget.currentPage),
              ],
            ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Center(
      child: AnimatedBuilder(
        animation: _loadingAnimation,
        builder: (context, child) {
          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: SweepGradient(
                colors: widget.isDarkMode
                    ? [
                        Colors.blue.shade900,
                        Colors.blue.shade200,
                        Colors.blue.shade900
                      ]
                    : [
                        Colors.amber.shade800,
                        Colors.amber.shade300,
                        Colors.amber.shade800
                      ],
                stops: [0.0, _loadingAnimation.value, 1.0],
                transform:
                    GradientRotation(_loadingAnimation.value * 2 * 3.14159),
              ),
            ),
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.image,
                  size: 24,
                  color: widget.isDarkMode
                      ? Colors.blue.shade200
                      : Colors.amber.shade800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBannerPageView() {
    return PageView.builder(
      controller: widget.pageController,
      itemCount: _banners.length,
      onPageChanged: widget.onPageChanged,
      physics: const BouncingScrollPhysics(),
      pageSnapping: true,
      padEnds: false,
      itemBuilder: (context, index) {
        final bannerUrl = _banners[index];

        if (bannerUrl.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.noBannersAvailable,
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          );
        }

        // Create a unique cache key for this banner
        final cacheKey = 'banner_${bannerUrl.hashCode}';

        // Preload adjacent banners for smooth scrolling
        if (index > 0) {
          widget.onPreloadImage(_banners[index - 1]);
        }
        if (index < _banners.length - 1) {
          widget.onPreloadImage(_banners[index + 1]);
        }

        return Hero(
          tag: 'banner_$index',
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.isDarkMode ? Colors.black54 : Colors.black12,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _buildBannerImage(bannerUrl, cacheKey),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBannerImage(String imageUrl, String cacheKey) {
    // If we have the file cached and we're offline or prioritizing performance
    if (_cachedBannerFiles.containsKey(imageUrl) &&
        (!_isOnline || _cachedBannerFiles[imageUrl] != null)) {
      final cachedFile = _cachedBannerFiles[imageUrl];
      if (cachedFile != null) {
        return Image.file(
          cachedFile.file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorWidget();
          },
        );
      }
    }

    // Otherwise use CachedNetworkImage with our custom cache manager
    return CachedNetworkImage(
      cacheManager: widget.cacheManager,
      cacheKey: cacheKey,
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      fadeOutDuration: Duration.zero,
      fadeInDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      errorWidget: (context, url, error) => _buildErrorWidget(),
      progressIndicatorBuilder: (context, url, progress) => Container(
        color: widget.isDarkMode ? Colors.grey[850] : Colors.grey[200],
        child: Center(
          child: CircularProgressIndicator(
            value: progress.progress,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.isDarkMode ? Colors.blueAccent : Colors.amber,
            ),
            strokeWidth: 3,
          ),
        ),
      ),
      imageBuilder: (context, imageProvider) => Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: imageProvider,
            fit: BoxFit.cover,
            colorFilter: widget.isDarkMode
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
                Colors.black.withOpacity(0.3),
              ],
              stops: const [0.7, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: widget.isDarkMode ? Colors.grey[850] : Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined,
              size: 40,
              color: widget.isDarkMode ? Colors.redAccent : Colors.red),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Image failed to load',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int count, int currentIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: index == currentIndex ? 12.0 : 8.0,
          height: index == currentIndex ? 12.0 : 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == currentIndex
                ? (widget.isDarkMode
                    ? Colors.blueAccent
                    : const Color(0xFFDBB342))
                : (widget.isDarkMode
                    ? Colors.grey.shade700
                    : Colors.grey.shade300),
          ),
        ),
      ),
    );
  }
}
