// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pb_hrsystem/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/core/widgets/linear_loading_indicator.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approvals_page/approvals_main_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/returnCar/car_return_page.dart';
import 'package:pb_hrsystem/home/dashboard/history/history_page.dart';
import 'package:pb_hrsystem/home/qr_profile_page.dart';
import 'package:pb_hrsystem/notifications/notification_page.dart';
import 'package:pb_hrsystem/user_model.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:pb_hrsystem/home/settings_page.dart';
import 'package:pb_hrsystem/login/login_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/inventory_page.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  // Basic state management
  bool _isLoading = false;
  bool _hasUnreadNotifications = true;

  // Banner state - isolated from main widget to prevent profile refresh
  late ValueNotifier<int> _currentBannerPageNotifier;

  // Data holders
  UserProfile? _userProfile;
  List<String> _banners = [];

  // Controllers
  late PageController _bannerPageController;
  Timer? _bannerAutoSwipeTimer;

  // Database
  Database? _database;

  // Animation controllers
  late AnimationController _bellAnimationController;
  late Animation<double> _bellAnimation;
  late AnimationController _waveAnimationController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _currentBannerPageNotifier = ValueNotifier<int>(0);
    _initializeDatabase();
    _initializeAnimations();
    _initializePageController();
    _loadData();
  }

  List<Map<String, dynamic>> _getActionItems(BuildContext context) {
    return [
      {
        'icon': 'assets/data-2.png',
        'label': AppLocalizations.of(context)!.history,
        'onTap': () => _navigateToPage(const HistoryPage()),
      },
      {
        'icon': 'assets/people.png',
        'label': AppLocalizations.of(context)!.approvals,
        'onTap': () => _navigateToPage(const ApprovalsMainPage()),
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
        'onTap': () => _navigateToPage(const ReturnCarPage()),
      },
      {
        'icon': 'assets/KPI.png',
        'label': AppLocalizations.of(context)!.kpi,
        'onTap': () {},
      },
      {
        'icon': 'assets/inventory.png',
        'label': AppLocalizations.of(context)!.inventory,
        'onTap': () => _navigateToPage(const InventoryPage()),
      },
    ];
  }

  void _initializeAnimations() {
    // Bell animation
    _bellAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _bellAnimation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(
          parent: _bellAnimationController, curve: Curves.easeInOut),
    );

    // Wave animation
    _waveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _waveAnimation = Tween<double>(begin: -0.15, end: 0.15).animate(
      CurvedAnimation(
          parent: _waveAnimationController, curve: Curves.easeInOut),
    );
  }

  void _initializePageController() {
    _bannerPageController = PageController(initialPage: 0);
  }

  void _startBannerAutoSwipe() {
    _bannerAutoSwipeTimer?.cancel();
    if (_banners.length > 1) {
      _bannerAutoSwipeTimer =
          Timer.periodic(const Duration(seconds: 4), (timer) {
        if (mounted && _bannerPageController.hasClients) {
          final nextPage =
              (_currentBannerPageNotifier.value + 1) % _banners.length;
          _bannerPageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _stopBannerAutoSwipe() {
    _bannerAutoSwipeTimer?.cancel();
  }

  Future<void> _initializeDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final dbPath = path.join(databasesPath, 'dashboard_images.db');

      _database = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (Database db, int version) async {
          // Create table for storing images
          await db.execute('''
            CREATE TABLE images (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              url TEXT UNIQUE,
              data BLOB,
              created_at INTEGER
            )
          ''');
        },
      );

      debugPrint('Database initialized successfully');
    } catch (e) {
      debugPrint('Error initializing database: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load from cache first for immediate display
      await _loadFromCache();

      // Then fetch fresh data from API
      await _fetchFromAPI();
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load cached profile
      final cachedProfile = prefs.getString('cached_profile');
      if (cachedProfile != null) {
        final profileJson = jsonDecode(cachedProfile);
        setState(() {
          _userProfile = UserProfile.fromJson(profileJson);
        });
        debugPrint('Loaded cached profile: ${_userProfile?.name}');
      }

      // Load cached banners
      final cachedBanners = prefs.getStringList('cached_banners');
      if (cachedBanners != null) {
        setState(() {
          _banners = cachedBanners;
        });
        // Start auto-swipe for cached banners too
        _startBannerAutoSwipe();
        debugPrint('Loaded cached banners: ${_banners.length} items');
      }
    } catch (e) {
      debugPrint('Error loading from cache: $e');
    }
  }

  Future<void> _fetchFromAPI() async {
    try {
      // Fetch profile and banners in parallel
      final results = await Future.wait([
        _fetchUserProfile(),
        _fetchBanners(),
      ]);

      final profile = results[0] as UserProfile?;
      final banners = results[1] as List<String>;

      if (profile != null) {
        setState(() => _userProfile = profile);

        // Cache profile data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_profile', jsonEncode(profile.toJson()));

        // Download and cache profile image
        if (profile.imgName.isNotEmpty &&
            profile.imgName != 'avatar_placeholder.png') {
          _downloadAndCacheImage(profile.imgName);
        }
      }

      if (banners.isNotEmpty) {
        setState(() => _banners = banners);

        // Cache banners data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('cached_banners', banners);

        // Start auto-swipe after banners are loaded
        _startBannerAutoSwipe();

        // Download and cache banner images
        for (final banner in banners) {
          if (banner.isNotEmpty) {
            _downloadAndCacheImage(banner);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching from API: $e');
      rethrow;
    }
  }

  Future<UserProfile?> _fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('No authentication token');
    }

    final baseUrl = dotenv.env['BASE_URL'];
    if (baseUrl == null) {
      throw Exception('BASE_URL not configured');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/display/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData['results'] != null &&
          responseData['results'].isNotEmpty) {
        final profile = UserProfile.fromJson(responseData['results'][0]);
        debugPrint('Profile fetched successfully: ${profile.name}');
        return profile;
      } else {
        debugPrint('No profile results in API response');
      }
    } else if (response.statusCode == 401) {
      // Token expired
      debugPrint('Profile API - Token expired');
      await prefs.remove('token');
      throw Exception('Authentication expired');
    } else {
      debugPrint(
          'Profile API error: ${response.statusCode} - ${response.body}');
    }

    throw Exception('Failed to fetch profile');
  }

  Future<List<String>> _fetchBanners() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        debugPrint('No authentication token for banners');
        throw Exception('No authentication token');
      }

      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null) {
        debugPrint('BASE_URL not configured for banners');
        throw Exception('BASE_URL not configured');
      }

      debugPrint('Fetching banners from: $baseUrl/api/app/promotions/files');

      final response = await http.get(
        Uri.parse('$baseUrl/api/app/promotions/files'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      debugPrint('Banners API response status: ${response.statusCode}');
      debugPrint('Banners API response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['results'] != null) {
          final banners = List<String>.from(
            responseData['results'].map((file) => file['files'] as String),
          );
          debugPrint('Fetched ${banners.length} banners successfully');
          return banners;
        } else {
          debugPrint('No results field in banner response');
        }
      } else {
        debugPrint(
            'Banner API error: ${response.statusCode} - ${response.body}');
      }

      return [];
    } catch (e) {
      debugPrint('Error fetching banners: $e');
      return [];
    }
  }

  Future<void> _downloadAndCacheImage(String imageUrl) async {
    if (_database == null || imageUrl.isEmpty) return;

    try {
      // Check if image already exists in cache
      final existing = await _database!.query(
        'images',
        where: 'url = ?',
        whereArgs: [imageUrl],
      );

      if (existing.isNotEmpty) {
        debugPrint('Image already cached: $imageUrl');
        return;
      }

      // Download image
      final response = await http.get(Uri.parse(imageUrl)).timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode == 200) {
        // Store in database
        await _database!.insert(
          'images',
          {
            'url': imageUrl,
            'data': response.bodyBytes,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        debugPrint('Image cached successfully: $imageUrl');
      }
    } catch (e) {
      debugPrint('Error downloading image: $e');
    }
  }

  Future<Uint8List?> _getCachedImage(String imageUrl) async {
    if (_database == null || imageUrl.isEmpty) return null;

    try {
      final result = await _database!.query(
        'images',
        columns: ['data'],
        where: 'url = ?',
        whereArgs: [imageUrl],
      );

      if (result.isNotEmpty) {
        return result.first['data'] as Uint8List;
      }
    } catch (e) {
      debugPrint('Error getting cached image: $e');
    }

    return null;
  }

  Future<void> _navigateToPage(Widget page) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => page),
    );
  }

  Future<void> _refreshData() async {
    await _fetchFromAPI();
  }

  @override
  void dispose() {
    _stopBannerAutoSwipe();
    _currentBannerPageNotifier.dispose();
    _bellAnimationController.dispose();
    _waveAnimationController.dispose();
    _bannerPageController.dispose();
    _database?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        final isDarkMode = themeNotifier.isDarkMode;

        return PopScope(
          onPopInvokedWithResult: (didPop, result) => false,
          child: Scaffold(
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
            appBar: _buildAppBar(isDarkMode),
            body: Column(
              children: [
                // Linear loading indicator at the top
                LinearLoadingIndicator(
                  isLoading: _isLoading,
                  color: const Color(0xFFDBB342),
                  height: 3.0,
                ),
                // Main content
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshData,
                    child: _buildBody(isDarkMode),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDarkMode) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: kToolbarHeight +
          70, // Increased height to show greeting text properly
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
                  // Settings Icon
                  IconButton(
                    icon: Icon(
                      Icons.settings,
                      color: isDarkMode ? Colors.white : Colors.black,
                      size: 28,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsPage()),
                    ),
                  ),

                  // Profile Section
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ProfileScreen()),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Get screen dimensions for responsive design
                          final screenWidth = MediaQuery.of(context).size.width;
                          final availableHeight = constraints.maxHeight;

                          // Calculate responsive sizes - optimized for better text visibility
                          final avatarRadius = screenWidth < 360
                              ? 22.0 // Small screens (iPhone SE)
                              : screenWidth < 390
                                  ? 24.0 // Medium screens (iPhone 12/13)
                                  : screenWidth < 430
                                      ? 25.0 // Large screens (iPhone 14 Plus)
                                      : 26.0; // Extra large screens

                          final greetingFontSize = screenWidth < 360
                              ? 15.0 // Small screens
                              : screenWidth < 390
                                  ? 16.0 // Medium screens
                                  : screenWidth < 430
                                      ? 17.0 // Large screens
                                      : 18.0; // Extra large screens

                          final avatarSize = avatarRadius * 2;
                          final spacing = availableHeight > 85 ? 8.0 : 6.0;

                          return Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Profile Avatar - Responsive size, bigger but safe
                              CircleAvatar(
                                radius: avatarRadius,
                                backgroundColor: Colors.white,
                                child: _userProfile?.imgName != null &&
                                        _userProfile!.imgName.isNotEmpty &&
                                        _userProfile!.imgName !=
                                            'avatar_placeholder.png'
                                    ? FutureBuilder<Uint8List?>(
                                        future: _getCachedImage(
                                            _userProfile!.imgName),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData &&
                                              snapshot.data != null) {
                                            return ClipOval(
                                              child: Image.memory(
                                                snapshot.data!,
                                                fit: BoxFit.cover,
                                                width: avatarSize,
                                                height: avatarSize,
                                              ),
                                            );
                                          } else {
                                            return ClipOval(
                                              child: Image.network(
                                                _userProfile!.imgName,
                                                fit: BoxFit.cover,
                                                width: avatarSize,
                                                height: avatarSize,
                                                loadingBuilder: (context, child,
                                                    loadingProgress) {
                                                  if (loadingProgress == null) {
                                                    return child;
                                                  }
                                                  return Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[200],
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.person,
                                                      size: avatarRadius,
                                                      color: Colors.grey[400],
                                                    ),
                                                  );
                                                },
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Image.asset(
                                                    'assets/avatar_placeholder.png',
                                                    fit: BoxFit.cover,
                                                    width: avatarSize,
                                                    height: avatarSize,
                                                  );
                                                },
                                              ),
                                            );
                                          }
                                        },
                                      )
                                    : Image.asset(
                                        'assets/avatar_placeholder.png',
                                        fit: BoxFit.cover,
                                        width: avatarSize,
                                        height: avatarSize,
                                      ),
                              ),
                              SizedBox(height: spacing),

                              // Greeting Text - Responsive and bigger
                              Flexible(
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: screenWidth * 0.65,
                                  ),
                                  child: _userProfile != null
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                AppLocalizations.of(context)!
                                                    .greeting(
                                                        _userProfile!.name),
                                                style: TextStyle(
                                                  color: isDarkMode
                                                      ? Colors.white
                                                      : Colors.black,
                                                  fontSize: greetingFontSize,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.2,
                                                  height: 1.2,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            AnimatedBuilder(
                                              animation: _waveAnimation,
                                              builder: (context, child) {
                                                return Transform.rotate(
                                                  angle: _waveAnimation.value,
                                                  child: Text(
                                                    " 👋",
                                                    style: TextStyle(
                                                      fontSize:
                                                          greetingFontSize,
                                                      height: 1.2,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        )
                                      : Text(
                                          'Loading...',
                                          style: TextStyle(
                                            color: isDarkMode
                                                ? Colors.white70
                                                : Colors.black54,
                                            fontSize: greetingFontSize - 2,
                                            height: 1.2,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  // Logout Icon
                  IconButton(
                    icon: const Icon(
                      Icons.power_settings_new,
                      color: Colors.red,
                      size: 28,
                    ),
                    onPressed: () => _showLogoutDialog(isDarkMode),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive padding based on screen size
    final topPadding = screenHeight < 700 ? 12.0 : 18.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(), // More fluid iOS-like scrolling
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, topPadding, 0, 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Carousel with fade-in animation
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 800),
              child: _buildBannerCarousel(isDarkMode),
            ),
            SizedBox(height: screenHeight < 700 ? 4 : 8),

            // Action Menu Header with slide animation
            AnimatedSlide(
              offset: const Offset(0, 0),
              duration: const Duration(milliseconds: 600),
              child: _buildActionMenuHeader(isDarkMode),
            ),
            SizedBox(height: screenHeight < 700 ? 12 : 16),

            // Action Grid with staggered animation
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 1000),
              child: _buildActionGrid(isDarkMode),
            ),
            SizedBox(height: screenHeight < 700 ? 20 : 28),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerCarousel(bool isDarkMode) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive banner height - made smaller and more compact
    final bannerHeight = screenHeight < 700
        ? 130.0
        : screenHeight < 800
            ? 145.0
            : 155.0;

    // Responsive margins
    final horizontalMargin = screenWidth < 360 ? 10.0 : 16.0;

    if (_isLoading && _banners.isEmpty) {
      return Container(
        height: bannerHeight,
        margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: isDarkMode
              ? LinearGradient(
                  colors: [Colors.grey[850]!, Colors.grey[800]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.grey[100]!, Colors.grey[200]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          boxShadow: [
            BoxShadow(
              color:
                  isDarkMode ? Colors.black26 : Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image,
              size: 48,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Loading banners...',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            // Linear loading indicator for banner loading
            const SizedBox(
              width: 120,
              child: LinearLoadingIndicator(
                isLoading: true,
                color: Color(0xFFDBB342),
                height: 2.0,
              ),
            ),
          ],
        ),
      );
    }

    if (_banners.isEmpty) {
      return Container(
        height: bannerHeight,
        margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: isDarkMode
              ? LinearGradient(
                  colors: [Colors.grey[850]!, Colors.grey[800]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.grey[100]!, Colors.grey[200]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          boxShadow: [
            BoxShadow(
              color:
                  isDarkMode ? Colors.black26 : Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: 45,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
              const SizedBox(height: 12),
              Text(
                'No banners available',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: bannerHeight + 16, // Extra space for indicator - more compact
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _bannerPageController,
              itemCount: _banners.length,
              onPageChanged: (index) {
                // Update only the banner page notifier - no setState to prevent profile refresh
                _currentBannerPageNotifier.value = index;
                // Reset auto-swipe timer when user manually swipes
                _startBannerAutoSwipe();
              },
              itemBuilder: (context, index) {
                final bannerUrl = _banners[index];

                return Container(
                  margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black54
                            : Colors.black.withOpacity(0.15),
                        blurRadius: 15,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Hero(
                    tag: 'banner_$index',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _buildBannerImage(bannerUrl),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          _buildPageIndicator(),
        ],
      ),
    );
  }

  Widget _buildBannerImage(String imageUrl) {
    return FutureBuilder<Uint8List?>(
      future: _getCachedImage(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
          );
        } else {
          // Try loading from network
          return Image.network(
            imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.grey.withOpacity(0.1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image,
                      size: 40,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    // Linear loading indicator for individual image loading
                    const SizedBox(
                      width: 100,
                      child: LinearLoadingIndicator(
                        isLoading: true,
                        color: Color(0xFFDBB342),
                        height: 2.0,
                      ),
                    ),
                  ],
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.broken_image_outlined, size: 50),
                ),
              );
            },
          );
        }
      },
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withOpacity(0.1),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: _currentBannerPageNotifier,
        builder: (context, currentPage, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _banners.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                width: index == currentPage ? 24.0 : 8.0,
                height: 8.0,
                margin: const EdgeInsets.symmetric(horizontal: 3.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: index == currentPage
                      ? const Color(0xFFDBB342)
                      : Colors.white.withOpacity(0.5),
                  boxShadow: index == currentPage
                      ? [
                          BoxShadow(
                            color: const Color(0xFFDBB342).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

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
                              builder: (context) => const NotificationPage(),
                            ),
                          ).then((_) {
                            setState(() => _hasUnreadNotifications = false);
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
    final actionItems = _getActionItems(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive grid configuration - more compact design
    final crossAxisCount = screenWidth < 360 ? 2 : 3;
    final childAspectRatio = screenWidth < 360
        ? 0.9 // Slightly taller for 2-column layout
        : screenWidth < 400
            ? 0.85 // More compact for 3-column
            : screenHeight < 700
                ? 0.9 // Compact for smaller screens
                : 0.95; // Slightly taller for larger screens

    final horizontalPadding = screenWidth < 360 ? 14.0 : 18.0;
    final spacing = screenWidth < 360 ? 8.0 : 10.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing * 0.8,
        ),
        itemCount: actionItems.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final item = actionItems[index];
          return AnimatedContainer(
            duration: Duration(milliseconds: 200 + (index * 50)),
            curve: Curves.easeOutBack,
            child: _buildActionCard(
              item['icon'] as String,
              item['label'] as String,
              isDarkMode,
              item['onTap'] as VoidCallback,
              index,
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionCard(String imagePath, String title, bool isDarkMode,
      VoidCallback onTap, int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight;
        final cardWidth = constraints.maxWidth;
        final iconSize =
            cardHeight * 0.28; // Slightly smaller for more compact look
        final screenWidth = MediaQuery.of(context).size.width;

        // Responsive font size - improved for compact design
        final fontSize = screenWidth < 360 ? 10.5 : 11.5;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
                14), // Slightly smaller radius for compact look
            gradient: isDarkMode
                ? LinearGradient(
                    colors: [
                      Colors.grey[850]!,
                      Colors.grey[800]!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.white,
                      Colors.grey[50]!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            border: Border.all(
              color: const Color(0xFFDBB342)
                  .withOpacity(0.4), // Slightly more visible border
              width: 1.0, // Thinner border for cleaner look
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.25)
                    : const Color(0xFFDBB342).withOpacity(0.08),
                blurRadius: 6, // Reduced shadow for more compact feel
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              splashColor: const Color(0xFFDBB342).withOpacity(0.15),
              highlightColor: const Color(0xFFDBB342).withOpacity(0.08),
              child: Container(
                padding: EdgeInsets.all(
                    screenWidth < 360 ? 4.0 : 6.0), // More compact padding
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon with subtle animation effect
                    TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 400 + (index * 100)),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 0.5 + (value * 0.5),
                          child: Opacity(
                            opacity: value,
                            child: Container(
                              padding: const EdgeInsets.all(
                                  6), // More compact icon padding
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFFDBB342).withOpacity(0.12),
                                borderRadius:
                                    BorderRadius.circular(10), // Smaller radius
                              ),
                              child: Image.asset(
                                imagePath,
                                height: iconSize.clamp(
                                    24.0, 36.0), // Smaller icon size range
                                width: iconSize.clamp(24.0, 36.0),
                                fit: BoxFit.contain,
                                color: isDarkMode ? Colors.white : null,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(
                        height:
                            screenWidth < 360 ? 4 : 6), // More compact spacing

                    // Title with better typography
                    Flexible(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: cardWidth * 0.9),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                            letterSpacing: 0.2,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
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
                    color: isDarkMode ? Colors.white : const Color(0xFF9C640C),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode
                            ? Colors.grey[700]
                            : const Color(0xFFF5F1E0),
                        foregroundColor:
                            isDarkMode ? Colors.white : const Color(0xFFDBB342),
                      ),
                      child: Text(AppLocalizations.of(context)!.cancel),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Provider.of<UserProvider>(context, listen: false)
                            .logout();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (context) => const LoginPage()),
                          (Route<dynamic> route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDBB342),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(AppLocalizations.of(context)!.yesLogout),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Simple UserProfile model
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
      id: json['id']?.toString() ?? '',
      name: json['employee_name'] ?? '',
      surname: json['employee_surname'] ?? '',
      email: json['employee_email'] ?? '',
      imgName: json['images'] ?? '',
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
