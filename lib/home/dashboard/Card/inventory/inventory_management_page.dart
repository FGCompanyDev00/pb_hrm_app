// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'inventory_request_form.dart';
import 'inventory_approval_page.dart';
import 'inventory_app_bar.dart';
import 'dart:async'; // Added for Timer
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pb_hrsystem/services/user_role_service.dart';
import 'admin_hq/inventory_admin_hq_page.dart';
import 'admin_br/inventory_admin_br_page.dart';
import 'branch_manager/inventory_branch_manager_page.dart';
import 'user/inventory_user_page.dart';

class InventoryManagementPage extends StatefulWidget {
  const InventoryManagementPage({super.key});

  @override
  State<InventoryManagementPage> createState() =>
      _InventoryManagementPageState();
}

class _InventoryManagementPageState extends State<InventoryManagementPage> {
  // Banner state
  List<String> _banners = [];
  late PageController _bannerPageController;
  late ValueNotifier<int> _currentBannerPageNotifier;
  Timer? _bannerAutoSwipeTimer;

  // Inventory categories fetched from API
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';

  // User role state
  bool _isAdminHQ = false;
  bool _isAdminBR = false;
  bool _isBranchManager = false;
  bool _isUser = false;
  bool _isRoleLoading = true;

  @override
  void initState() {
    super.initState();
    _bannerPageController = PageController();
    _currentBannerPageNotifier = ValueNotifier<int>(0);
    _startBannerAutoSwipe();
    _checkUserRole();
    _fetchCategories();
    _loadBanners();
  }

  @override
  void dispose() {
    _bannerAutoSwipeTimer?.cancel();
    _bannerPageController.dispose();
    _currentBannerPageNotifier.dispose();
    super.dispose();
  }

  /// Check if the current user has AdminHQ, AdminBR, Branch_manager, or User role
  Future<void> _checkUserRole() async {
    try {
      debugPrint('🔍 [InventoryManagementPage] Starting role check...');
      final isAdminHQ = await UserRoleService.isAdminHQ();
      final isAdminBR = await UserRoleService.hasRole('AdminBR');
      final isBranchManager = await UserRoleService.hasRole('Branch_manager');
      final isUser = await UserRoleService.hasRole('User');
      debugPrint('🔍 [InventoryManagementPage] Role check result: isAdminHQ = $isAdminHQ, isAdminBR = $isAdminBR, isBranchManager = $isBranchManager, isUser = $isUser');
      setState(() {
        _isAdminHQ = isAdminHQ;
        _isAdminBR = isAdminBR;
        _isBranchManager = isBranchManager;
        _isUser = isUser;
        _isRoleLoading = false;
      });
      debugPrint('🔍 [InventoryManagementPage] State updated: _isAdminHQ = $_isAdminHQ, _isAdminBR = $_isAdminBR, _isBranchManager = $_isBranchManager, _isUser = $_isUser, _isRoleLoading = $_isRoleLoading');
    } catch (e) {
      debugPrint('❌ [InventoryManagementPage] Error during role check: $e');
      setState(() {
        _isAdminHQ = false;
        _isAdminBR = false;
        _isBranchManager = false;
        _isUser = false;
        _isRoleLoading = false;
      });
      debugPrint('🔍 [InventoryManagementPage] Error state set: _isAdminHQ = $_isAdminHQ, _isAdminBR = $_isAdminBR, _isBranchManager = $_isBranchManager, _isUser = $_isUser, _isRoleLoading = $_isRoleLoading');
    }
  }

  void _startBannerAutoSwipe() {
    _bannerAutoSwipeTimer?.cancel();
    if (_banners.length > 1) {
      _bannerAutoSwipeTimer =
          Timer.periodic(const Duration(seconds: 4), (timer) {
        if (mounted && _bannerPageController.hasClients) {
          final currentPage = _currentBannerPageNotifier.value;
          final nextPage = (currentPage + 1) % _banners.length;
          
          // Smooth animation with optimized duration and curve
          _bannerPageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    }
  }

  // Banner API fetch and cache (same as dashboard.dart)
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

  // Fetch categories from API with caching
  Future<void> _fetchCategories() async {
    setState(() {
      _isLoading = true;
      _isError = false;
      _errorMessage = '';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final baseUrl = dotenv.env['BASE_URL'] ?? '';
      if (token == null || baseUrl.isEmpty) {
        throw Exception('Authentication or BASE_URL not configured');
      }
      // Try loading from cache first
      final cached = prefs.getString('inventory_categories');
      if (cached != null) {
        final List<dynamic> cachedList = jsonDecode(cached);
        setState(() {
          _categories = List<Map<String, dynamic>>.from(
              cachedList.map((e) => Map<String, dynamic>.from(e)));
          _isLoading = false;
        });
      }
      // Fetch fresh data
      final response = await http.get(
        Uri.parse('$baseUrl/api/inventory/categories'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null) {
          final List<dynamic> results = data['results'];
          setState(() {
            _categories = List<Map<String, dynamic>>.from(
                results.map((e) => Map<String, dynamic>.from(e)));
            _isLoading = false;
            _isError = false;
          });
          // Cache the results
          await prefs.setString('inventory_categories', jsonEncode(results));
        } else {
          throw Exception('No results in API response');
        }
      } else {
        throw Exception('Failed to fetch categories: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        final isDarkMode = themeNotifier.isDarkMode;

        debugPrint('🔍 [InventoryManagementPage] Build method called');
        debugPrint('🔍 [InventoryManagementPage] _isRoleLoading: $_isRoleLoading');
        debugPrint('🔍 [InventoryManagementPage] _isAdminHQ: $_isAdminHQ');
        debugPrint('🔍 [InventoryManagementPage] _isAdminBR: $_isAdminBR');

        // Always show loading state while checking roles
        if (_isRoleLoading) {
          debugPrint('🔍 [InventoryManagementPage] Showing loading state');
          return Scaffold(
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
            appBar: const InventoryAppBar(
              title: 'INVENTORY MANAGEMENT',
              showBack: true,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        debugPrint('🔍 [InventoryManagementPage] Showing default requesting interface for all users');
        debugPrint('🔍 [InventoryManagementPage] Role info - AdminHQ: $_isAdminHQ, AdminBR: $_isAdminBR, BranchManager: $_isBranchManager, User: $_isUser');

        // Default inventory management page for ALL users (requesting functionality)
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final horizontalPadding = screenWidth < 400 ? 12.0 : 20.0;
        final verticalPadding = screenHeight < 700 ? 10.0 : 18.0;
        
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
                    // Action Menu Header
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
                          'Action Menu',
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
                    // Action Grid
                    _buildActionGrid(context, isDarkMode, screenWidth),
                    
                    // Swipe down indicator for role-specific approval pages
                    if (_isAdminHQ || _isAdminBR || _isBranchManager || _isUser) ...[
                      const SizedBox(height: 24),
                      _buildSwipeDownIndicator(isDarkMode),
                    ],
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
                                  color:
                                      const Color(0xFFDBB342).withOpacity(0.4),
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

  Widget _buildSwipeDownIndicator(bool isDarkMode) {
    return GestureDetector(
      onTap: _navigateToRoleSpecificPage,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFDBB342).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.swipe_down,
              color: const Color(0xFFDBB342),
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              'Click this button to switch to ${_getRoleSpecificTitle()}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Access your approval management',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleSpecificTitle() {
    if (_isAdminHQ) return 'AdminHQ Approvals';
    if (_isAdminBR) return 'AdminBR Approvals';
    if (_isBranchManager) return 'Branch Manager Approvals';
    if (_isUser) return 'User Approvals';
    return 'Approvals';
  }

  void _navigateToRoleSpecificPage() {
    if (_isAdminHQ) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const InventoryAdminHQPage()),
      );
    } else if (_isAdminBR) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const InventoryAdminBRPage()),
      );
    } else if (_isBranchManager) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const InventoryBranchManagerPage()),
      );
    } else if (_isUser) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const InventoryUserPage()),
      );
    }
  }

  Widget _buildActionGrid(
      BuildContext context, bool isDarkMode, double screenWidth) {
    // API categories first, then Approval button last
    final List<Widget> buttons = [];
    // API categories
    for (int i = 0; i < _categories.length; i++) {
      final cat = _categories[i];
      buttons.add(_buildCategoryCard(context, cat, isDarkMode, i, screenWidth));
    }
    // Approval button LAST
    buttons.add(_buildActionCard(
      context,
      'assets/inventory/Approval.png',
      'Approval',
      'approval',
      isDarkMode,
      _categories.length,
      screenWidth,
    ));
    // Responsive grid config
    final crossAxisCount = screenWidth < 360 ? 2 : 3;
    final childAspectRatio = screenWidth < 360
        ? 0.95
        : screenWidth < 400
            ? 0.9
            : 1.0;
    final spacing = screenWidth < 400 ? 10.0 : 16.0;
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _isError
            ? Center(
                child: Column(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(height: 8),
                    Text(_errorMessage,
                        style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _fetchCategories,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                children: buttons,
              );
  }

  Widget _buildActionCard(BuildContext context, String iconPath, String label,
      String type, bool isDarkMode, int index, double screenWidth) {
    final iconSize = screenWidth < 360 ? 28.0 : 36.0;
    final fontSize = screenWidth < 360 ? 11.0 : 13.0;
    return GestureDetector(
      onTap: () {
        if (type == 'approval') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const InventoryApprovalPage(),
            ),
          );
        }
      },
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
              child: Image.asset(
                iconPath,
                height: iconSize,
                width: iconSize,
                fit: BoxFit.contain,
                color: isDarkMode ? Colors.white : null,
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

  Widget _buildCategoryCard(BuildContext context, Map<String, dynamic> cat,
      bool isDarkMode, int index, double screenWidth) {
    final String imgUrl = cat['img_name'] ?? '';
    final String label = cat['name'] ?? '';
    final String uid = cat['uid'] ?? '';
    final iconSize = screenWidth < 360 ? 28.0 : 36.0;
    final fontSize = screenWidth < 360 ? 11.0 : 13.0;
    return GestureDetector(
      onTap: () {
        // Navigate to request form with category UID
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InventoryRequestForm(categoryUid: uid, categoryName: label),
          ),
        );
      },
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
              child: imgUrl.isNotEmpty
                  ? Image.network(
                      imgUrl,
                      height: iconSize,
                      width: iconSize,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, color: Colors.grey),
                    )
                  : const Icon(Icons.image, size: 32, color: Colors.grey),
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
