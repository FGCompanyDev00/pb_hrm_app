// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'inventory_request_form.dart';
import 'inventory_approval_page.dart';
import 'inventory_app_bar.dart';
import 'dart:async'; // Added for Timer

class InventoryManagementPage extends StatefulWidget {
  const InventoryManagementPage({super.key});

  @override
  State<InventoryManagementPage> createState() =>
      _InventoryManagementPageState();
}

class _InventoryManagementPageState extends State<InventoryManagementPage> {
  final PageController _bannerPageController = PageController();
  final ValueNotifier<int> _currentBannerPageNotifier = ValueNotifier<int>(0);
  Timer? _bannerAutoSwipeTimer;
  final List<String> _banners = [
    'assets/inventory/banner1.png',
    'assets/inventory/banner2.png',
    'assets/inventory/banner3.png',
  ];

  @override
  void initState() {
    super.initState();
    _startBannerAutoSwipe();
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

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        final isDarkMode = themeNotifier.isDarkMode;

        return Scaffold(
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          appBar: const InventoryAppBar(
            title: 'INVENTORY MANAGEMENT',
            showBack: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Carousel
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: PageView.builder(
                      controller: _bannerPageController,
                      onPageChanged: (index) {
                        _currentBannerPageNotifier.value = index;
                      },
                      itemCount: _banners.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              _banners[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Banner Indicator
                  Center(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _currentBannerPageNotifier,
                      builder: (context, currentPage, _) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _banners.length,
                            (index) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: currentPage == index
                                    ? const Color(0xFFDBB342)
                                    : (isDarkMode
                                        ? Colors.grey[700]
                                        : Colors.grey[300]),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Action Menu',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildActionGrid(context, isDarkMode),
                      ],
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

  Widget _buildActionGrid(BuildContext context, bool isDarkMode) {
    final actionItems = [
      {
        'icon': 'assets/inventory/For-Office.png',
        'label': 'For Office',
        'type': 'office'
      },
      {
        'icon': 'assets/inventory/For-Cleaner.png',
        'label': 'For Cleaner',
        'type': 'cleaner'
      },
      {
        'icon': 'assets/inventory/Marketing.png',
        'label': 'Marketing',
        'type': 'marketing'
      },
      {'icon': 'assets/inventory/RED.png', 'label': 'RED', 'type': 'red'},
      {'icon': 'assets/inventory/HRD.png', 'label': 'HRD', 'type': 'hrd'},
      {'icon': 'assets/inventory/DBD.png', 'label': 'DBD', 'type': 'dbd'},
      {'icon': 'hi_app', 'label': 'Hi app', 'type': 'hi_app'},
      {
        'icon': 'assets/inventory/Approval.png',
        'label': 'Approval',
        'type': 'approval'
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0, // Fixed aspect ratio to prevent overflow
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: actionItems.length,
      itemBuilder: (context, index) {
        final item = actionItems[index];
        return _buildActionCard(
          context,
          item['icon']!,
          item['label']!,
          item['type']!,
          isDarkMode,
          index,
        );
      },
    );
  }

  Widget _buildActionCard(BuildContext context, String iconPath, String label,
      String type, bool isDarkMode, int index) {
    Widget iconWidget;
    if (iconPath == 'hi_app') {
      // Custom Hi app logo widget with fixed height
      iconWidget = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFDBB342).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hi',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFFDBB342),
              ),
            ),
            Text(
              'app',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFFDBB342),
              ),
            ),
          ],
        ),
      );
    } else {
      // Special handling for RED icon
      if (type == 'red') {
        iconWidget = Container(
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFDBB342),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      } else {
        iconWidget = Image.asset(
          iconPath,
          height: 32,
          width: 32,
          color: const Color(0xFFDBB342),
          filterQuality: FilterQuality.high,
        );
      }
    }

    return GestureDetector(
      onTap: () {
        if (type == 'approval') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const InventoryApprovalPage(),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InventoryRequestForm(type: type),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFDBB342).withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDBB342).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: iconWidget,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
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
