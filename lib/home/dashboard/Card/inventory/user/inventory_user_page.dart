import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../inventory_app_bar.dart';
import 'my_request_page.dart';
import 'my_approval_page.dart';
import 'my_receive_page.dart';

/// Main Inventory Management page for User role
/// Displays banner carousel and action grid for inventory management
class InventoryUserPage extends StatefulWidget {
  const InventoryUserPage({super.key});

  @override
  State<InventoryUserPage> createState() => _InventoryUserPageState();
}

class _InventoryUserPageState extends State<InventoryUserPage> {
  // Banner state
  List<String> _banners = [];
  late PageController _bannerPageController;
  late ValueNotifier<int> _currentBannerPageNotifier;
  Timer? _bannerAutoSwipeTimer;

  @override
  void initState() {
    super.initState();
    _bannerPageController = PageController();
    _currentBannerPageNotifier = ValueNotifier<int>(0);
    _startBannerAutoSwipe();
    _loadBanners();
  }

  @override
  void dispose() {
    _bannerAutoSwipeTimer?.cancel();
    _bannerPageController.dispose();
    _currentBannerPageNotifier.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        final isDarkMode = themeNotifier.isDarkMode;
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
          appBar: InventoryAppBar(
            title: 'INVENTORY MANAGEMENT',
            showBack: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner Carousel
                _buildBannerCarousel(screenWidth, screenHeight, isDarkMode),
                const SizedBox(height: 24),
                
                // Action Grid Section
                _buildActionGridSection(isDarkMode, screenWidth),
                
                // Back to Action Menu button
                const SizedBox(height: 24),
                _buildBackToActionMenuButton(isDarkMode),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBannerCarousel(double screenWidth, double screenHeight, bool isDarkMode) {
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
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[200],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_outlined,
                size: 50,
                color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'No banners available',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                  fontSize: 14,
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
              builder: (context, currentIndex, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _banners.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: currentIndex == index
                            ? const Color(0xFFDBB342)
                            : (isDarkMode ? Colors.grey[600] : Colors.grey[300]),
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

  Widget _buildBackToActionMenuButton(bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
      },
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
              Icons.swipe_up,
              color: const Color(0xFFDBB342),
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              'Click this button to switch to Action Menu',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Back to requesting functionality',
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

  Widget _buildActionGridSection(bool isDarkMode, double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Inventory Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Action Grid
        _buildUserActionGrid(isDarkMode, screenWidth),
      ],
    );
  }

  Widget _buildUserActionGrid(bool isDarkMode, double screenWidth) {
    // Responsive grid config - 3 columns per row for User
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
      children: [
        _buildActionCard(
          title: 'My Request',
          icon: Icons.assignment,
          color: const Color(0xFF9C27B0),
          onTap: () => _navigateToPage(const MyRequestPage()),
        ),
        _buildActionCard(
          title: 'My Approval',
          icon: Icons.approval,
          color: const Color(0xFF4CAF50),
          onTap: () => _navigateToPage(const MyApprovalPage()),
        ),
        _buildActionCard(
          title: 'My Receive',
          icon: Icons.shopping_bag,
          color: const Color(0xFFFF9800),
          onTap: () => _navigateToPage(const MyReceivePage()),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        final isDarkMode = themeNotifier.isDarkMode;
        
        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: color,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }
}
