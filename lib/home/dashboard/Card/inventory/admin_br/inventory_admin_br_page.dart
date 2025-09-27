import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:pb_hrsystem/services/user_role_service.dart';

import '../inventory_app_bar.dart';
import 'my_request_page.dart';
import 'my_approval_page.dart';
import 'my_receive_page.dart';
import 'request_from_hq_page.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// AdminBR-specific inventory management page
/// Displays role-based menu items: My Request, My Approval, My Receive, Request From HQ
class InventoryAdminBRPage extends StatefulWidget {
  const InventoryAdminBRPage({super.key});

  @override
  State<InventoryAdminBRPage> createState() => _InventoryAdminBRPageState();
}

class _InventoryAdminBRPageState extends State<InventoryAdminBRPage> {
  List<String> _banners = [];
  late PageController _bannerPageController;
  late ValueNotifier<int> _currentBannerPageNotifier;
  Timer? _bannerAutoSwipeTimer;

  // User role state
  bool _isAdminBR = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 [InventoryAdminBRPage] initState called');
    _bannerPageController = PageController();
    _currentBannerPageNotifier = ValueNotifier<int>(0);
    _startBannerAutoSwipe();
    _checkUserRole();
    _loadBanners();
  }

  @override
  void dispose() {
    _bannerAutoSwipeTimer?.cancel();
    _bannerPageController.dispose();
    _currentBannerPageNotifier.dispose();
    super.dispose();
  }

  /// Check if the current user has AdminBR role
  Future<void> _checkUserRole() async {
    try {
      debugPrint('🔍 [InventoryAdminBRPage] Starting role check...');
      final isAdminBR = await UserRoleService.hasRole('AdminBR');
      debugPrint('🔍 [InventoryAdminBRPage] Role check result: isAdminBR = $isAdminBR');
      setState(() {
        _isAdminBR = isAdminBR;
        _isLoading = false;
      });
      debugPrint('🔍 [InventoryAdminBRPage] State updated: _isAdminBR = $_isAdminBR, _isLoading = $_isLoading');
    } catch (e) {
      debugPrint('❌ [InventoryAdminBRPage] Error during role check: $e');
      setState(() {
        _isAdminBR = false;
        _isLoading = false;
      });
      debugPrint('🔍 [InventoryAdminBRPage] Error state set: _isAdminBR = $_isAdminBR, _isLoading = $_isLoading');
    }
  }

  void _startBannerAutoSwipe() {
    if (_banners.length > 1) {
      _bannerAutoSwipeTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (mounted && _bannerPageController.hasClients) {
          final nextPage = (_currentBannerPageNotifier.value + 1) % _banners.length;
          _bannerPageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  /// Load banners from API with caching
  Future<void> _loadBanners() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Load cached banners first
      final cachedBanners = prefs.getStringList('inventory_cached_banners');
      if (cachedBanners != null) {
        setState(() {
          _banners = cachedBanners;
        });
        _startBannerAutoSwipe();
      }
      
      // Fetch fresh banners from API
      final token = prefs.getString('token');
      final baseUrl = dotenv.env['BASE_URL'];
      if (token == null || baseUrl == null) return;
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/app/promotions/files'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['results'] != null) {
          final banners = List<String>.from(
            responseData['results'].map((file) => file['files'] as String),
          );
          setState(() {
            _banners = banners;
          });
          await prefs.setStringList('inventory_cached_banners', banners);
          _startBannerAutoSwipe();
        }
      }
    } catch (e) {
      // Ignore errors, fallback to cache or empty
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        final isDarkMode = themeNotifier.isDarkMode;
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final horizontalPadding = screenWidth < 400 ? 12.0 : 20.0;
        final verticalPadding = screenHeight < 700 ? 10.0 : 18.0;

        debugPrint('🔍 [InventoryAdminBRPage] Build method called');
        debugPrint('🔍 [InventoryAdminBRPage] _isLoading: $_isLoading');
        debugPrint('🔍 [InventoryAdminBRPage] _isAdminBR: $_isAdminBR');

        if (_isLoading) {
          return Scaffold(
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
            appBar: const InventoryAppBar(
              title: 'INVENTORY MANAGEMENT',
              showBack: true,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!_isAdminBR) {
          return Scaffold(
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
            appBar: const InventoryAppBar(
              title: 'INVENTORY MANAGEMENT',
              showBack: true,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock,
                    size: 64,
                    color: isDarkMode ? Colors.white54 : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Access Denied',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You do not have permission to access this page.',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        debugPrint('🔍 [InventoryAdminBRPage] User is AdminBR, showing AdminBR interface');

        return Scaffold(
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          appBar: const InventoryAppBar(
            title: 'INVENTORY MANAGEMENT',
            showBack: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Carousel
                    _buildBannerCarousel(isDarkMode),
                    const SizedBox(height: 18),
                    // Approval Header
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBB342),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          margin: const EdgeInsets.only(right: 12),
                        ),
                        Text(
                          'Approval',
                          style: TextStyle(
                            fontSize: screenWidth < 400 ? 17 : 20,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // AdminBR Action Grid
                    _buildAdminBRActionGrid(context, isDarkMode, screenWidth),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBannerCarousel(bool isDarkMode) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bannerHeight = screenHeight < 700
        ? 130.0
        : screenHeight < 800
            ? 145.0
            : 170.0;
    final horizontalMargin = screenWidth < 360 ? 4.0 : 8.0;

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
              color: isDarkMode ? Colors.black26 : Colors.black.withOpacity(0.08),
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
      height: bannerHeight + 16,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _bannerPageController,
              itemCount: _banners.length,
              onPageChanged: (index) {
                _currentBannerPageNotifier.value = index;
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
                      child: Image.network(
                        bannerUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined, size: 50),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Banner Indicator
          Center(
            child: ValueListenableBuilder<int>(
              valueListenable: _currentBannerPageNotifier,
              builder: (context, currentPage, _) {
                return Row(
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
          ),
        ],
      ),
    );
  }

  Widget _buildAdminBRActionGrid(BuildContext context, bool isDarkMode, double screenWidth) {
    final List<Map<String, dynamic>> adminBRActions = [
      {
        'icon': Icons.list_alt,
        'label': 'My Request',
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MyRequestPage(),
          ),
        ),
      },
      {
        'icon': Icons.approval,
        'label': 'My Approval',
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MyApprovalPage(),
          ),
        ),
      },
      {
        'icon': Icons.shopping_bag,
        'label': 'My Receive',
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MyReceivePage(),
          ),
        ),
      },
      {
        'icon': Icons.business,
        'label': 'Request From HQ',
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const RequestFromHQPage(),
          ),
        ),
      },
    ];

    // Responsive grid config - 3 columns per row for AdminBR
    final crossAxisCount = screenWidth < 360 ? 2 : 3;
    final childAspectRatio = screenWidth < 360 ? 0.95 : 0.85;
    final spacing = screenWidth < 400 ? 10.0 : 16.0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      childAspectRatio: childAspectRatio,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      children: adminBRActions.map((action) => _buildActionCard(
        context,
        action['icon'] as IconData,
        action['label'] as String,
        action['onTap'] as VoidCallback,
        isDarkMode,
        screenWidth,
      )).toList(),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
    bool isDarkMode,
    double screenWidth,
  ) {
    final iconSize = screenWidth < 360 ? 28.0 : 36.0;
    final fontSize = screenWidth < 360 ? 11.0 : 13.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFDBB342).withOpacity(0.3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withOpacity(0.18)
                  : Colors.grey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFDBB342).withOpacity(0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: Colors.green, // Green color as specified
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                  letterSpacing: 0.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
