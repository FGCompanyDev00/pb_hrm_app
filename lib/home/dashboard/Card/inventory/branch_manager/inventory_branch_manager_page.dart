import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import '../inventory_app_bar.dart';
import 'my_request_page.dart';
import 'my_approval_page.dart';
import 'my_receive_page.dart';

/// Main Inventory Management page for Branch_manager role
/// Displays banner carousel and action grid for inventory management
class InventoryBranchManagerPage extends StatefulWidget {
  const InventoryBranchManagerPage({super.key});

  @override
  State<InventoryBranchManagerPage> createState() => _InventoryBranchManagerPageState();
}

class _InventoryBranchManagerPageState extends State<InventoryBranchManagerPage> {
  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;

  // Mock banner data
  final List<Map<String, dynamic>> _banners = [
    {
      'title': 'Inventory Management',
      'subtitle': 'Manage your branch inventory efficiently',
      'image': 'assets/inventory.png',
      'color': const Color(0xFF4CAF50),
    },
    {
      'title': 'Request Tracking',
      'subtitle': 'Track requests and approvals',
      'image': 'assets/task.png',
      'color': const Color(0xFF2196F3),
    },
    {
      'title': 'Item Management',
      'subtitle': 'Manage your inventory items',
      'image': 'assets/box-time.png',
      'color': const Color(0xFFFF9800),
    },
  ];

  @override
  void initState() {
    super.initState();
    // Auto-scroll banners
    _startBannerAutoScroll();
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  void _startBannerAutoScroll() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _currentBannerIndex = (_currentBannerIndex + 1) % _banners.length;
        _bannerController.animateToPage(
          _currentBannerIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _startBannerAutoScroll();
      }
    });
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
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBannerCarousel(double screenWidth, double screenHeight, bool isDarkMode) {
    return SizedBox(
      height: screenHeight * 0.25,
      child: PageView.builder(
        controller: _bannerController,
        onPageChanged: (index) {
          setState(() {
            _currentBannerIndex = index;
          });
        },
        itemCount: _banners.length,
        itemBuilder: (context, index) {
          final banner = _banners[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  banner['color'],
                  banner['color'].withOpacity(0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: banner['color'].withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          banner['title'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          banner['subtitle'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.inventory_2,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
              'Approval',
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
        _buildBranchManagerActionGrid(isDarkMode, screenWidth),
      ],
    );
  }

  Widget _buildBranchManagerActionGrid(bool isDarkMode, double screenWidth) {
    // Responsive grid config - 3 columns per row for Branch_manager
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
          color: const Color(0xFF9C27B0), // Pink for icons
          onTap: () => _navigateToPage(const MyRequestPage()),
        ),
        _buildActionCard(
          title: 'My Approval',
          icon: Icons.approval,
          color: const Color(0xFF4CAF50), // Green for approval
          onTap: () => _navigateToPage(const MyApprovalPage()),
        ),
        _buildActionCard(
          title: 'My Receive',
          icon: Icons.shopping_bag,
          color: const Color(0xFFFF9800), // Orange for receive
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
