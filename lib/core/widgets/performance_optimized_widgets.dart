import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

/// High-performance optimized widgets for consistent UI and better performance
class PerformanceOptimizedWidgets {
  /// Optimized header widget with caching and reduced rebuilds
  static Widget buildOptimizedHeader({
    required String title,
    required bool isDarkMode,
    required Size screenSize,
    VoidCallback? onBackPressed,
    List<Widget>? actions,
    String? backgroundImage,
  }) {
    return Container(
      height: screenSize.height * 0.17,
      width: double.infinity,
      decoration: BoxDecoration(
        image: backgroundImage != null
            ? DecorationImage(
                image: AssetImage(backgroundImage),
                fit: BoxFit.cover,
              )
            : DecorationImage(
                image: AssetImage(
                  isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png',
                ),
                fit: BoxFit.cover,
              ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.04,
            vertical: screenSize.height * 0.015,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (onBackPressed != null)
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: screenSize.width * 0.07,
                  ),
                  onPressed: onBackPressed,
                )
              else
                SizedBox(width: screenSize.width * 0.12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontSize: screenSize.width * 0.06,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (actions != null && actions.isNotEmpty)
                Row(children: actions)
              else
                SizedBox(width: screenSize.width * 0.12),
            ],
          ),
        ),
      ),
    );
  }

  /// Optimized tab bar widget with reduced rebuilds
  static Widget buildOptimizedTabBar({
    required bool firstTabSelected,
    required VoidCallback onFirstTabPressed,
    required VoidCallback onSecondTabPressed,
    required String firstTabLabel,
    required String secondTabLabel,
    required IconData firstTabIcon,
    required IconData secondTabIcon,
    required Size screenSize,
    required bool isDarkMode,
    String? firstTabAsset,
    String? secondTabAsset,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.03,
        vertical: screenSize.height * 0.003,
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabBarButton(
              isSelected: firstTabSelected,
              onPressed: onFirstTabPressed,
              label: firstTabLabel,
              icon: firstTabIcon,
              assetPath: firstTabAsset,
              screenSize: screenSize,
              isDarkMode: isDarkMode,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20.0),
                bottomLeft: Radius.circular(20.0),
              ),
            ),
          ),
          SizedBox(width: screenSize.width * 0.002),
          Expanded(
            child: _TabBarButton(
              isSelected: !firstTabSelected,
              onPressed: onSecondTabPressed,
              label: secondTabLabel,
              icon: secondTabIcon,
              assetPath: secondTabAsset,
              screenSize: screenSize,
              isDarkMode: isDarkMode,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(20.0),
                bottomRight: Radius.circular(20.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Optimized list item card with minimal rebuilds
  static Widget buildOptimizedItemCard({
    required Map<String, dynamic> item,
    required VoidCallback onTap,
    required Size screenSize,
    required bool isDarkMode,
    String? displayTypeOverride,
    bool showStatus = true,
    bool showEmployeeImage = true,
    Color? borderColor,
    Widget? customTrailing,
  }) {
    return _OptimizedItemCard(
      item: item,
      onTap: onTap,
      screenSize: screenSize,
      isDarkMode: isDarkMode,
      displayTypeOverride: displayTypeOverride,
      showStatus: showStatus,
      showEmployeeImage: showEmployeeImage,
      borderColor: borderColor,
      customTrailing: customTrailing,
    );
  }

  /// Optimized empty state widget
  static Widget buildOptimizedEmptyState({
    required String message,
    required IconData icon,
    required Size screenSize,
    required bool isDarkMode,
    String? subtitle,
    VoidCallback? onRetry,
    String? retryLabel,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(screenSize.width * 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: screenSize.width * 0.15,
              color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            SizedBox(height: screenSize.height * 0.02),
            Text(
              message,
              style: TextStyle(
                fontSize: screenSize.width * 0.045,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: screenSize.height * 0.01),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: screenSize.width * 0.035,
                  color:
                      isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              SizedBox(height: screenSize.height * 0.03),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  retryLabel ?? 'Retry',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenSize.width * 0.06,
                    vertical: screenSize.height * 0.015,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Optimized loading state widget
  static Widget buildOptimizedLoadingState({
    required String message,
    required Size screenSize,
    required bool isDarkMode,
    IconData? icon,
  }) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(screenSize.width * 0.08),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(
                icon,
                size: screenSize.width * 0.16,
                color: isDarkMode ? Colors.amber[700] : Colors.blue[600],
              ),
            SizedBox(height: screenSize.height * 0.024),
            Text(
              message,
              style: TextStyle(
                fontSize: screenSize.width * 0.05,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenSize.height * 0.01),
            Text(
              'Please wait...',
              style: TextStyle(
                fontSize: screenSize.width * 0.035,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Optimized cached image widget
  static Widget buildOptimizedCachedImage({
    required String imageUrl,
    required double radius,
    Color? backgroundColor,
    Widget? errorWidget,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey.shade300,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: radius * 2,
            height: radius * 2,
            color: Colors.grey.shade200,
            child: Icon(
              Icons.person,
              color: Colors.grey.shade600,
              size: radius,
            ),
          ),
          errorWidget: (context, url, error) =>
              errorWidget ??
              Icon(
                Icons.person,
                color: Colors.grey.shade600,
                size: radius,
              ),
        ),
      ),
    );
  }

  /// Optimized view more button
  static Widget buildOptimizedViewMoreButton({
    required VoidCallback onPressed,
    required Size screenSize,
    required bool isDarkMode,
    String? label,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: screenSize.width * 0.4,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: screenSize.height * 0.012,
                  horizontal: screenSize.width * 0.03,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(screenSize.width * 0.05),
                  side: const BorderSide(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                elevation: 5,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label ?? 'View More',
                    style: TextStyle(
                      fontSize: screenSize.width * 0.035,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: screenSize.width * 0.02),
                  Icon(
                    Icons.arrow_downward,
                    size: screenSize.width * 0.04,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Private optimized tab bar button widget
class _TabBarButton extends StatelessWidget {
  const _TabBarButton({
    required this.isSelected,
    required this.onPressed,
    required this.label,
    required this.icon,
    required this.screenSize,
    required this.isDarkMode,
    required this.borderRadius,
    this.assetPath,
  });

  final bool isSelected;
  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  final String? assetPath;
  final Size screenSize;
  final bool isDarkMode;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: screenSize.height * 0.008,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? Colors.amber.shade700 : Colors.amber)
              : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300),
          borderRadius: borderRadius,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (assetPath != null)
              Image.asset(
                assetPath!,
                width: screenSize.width * 0.07,
                height: screenSize.width * 0.07,
                color: isSelected
                    ? Colors.white
                    : (isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600),
              )
            else
              Icon(
                icon,
                size: screenSize.width * 0.07,
                color: isSelected
                    ? Colors.white
                    : (isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600),
              ),
            SizedBox(width: screenSize.width * 0.02),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600),
                fontWeight: FontWeight.bold,
                fontSize: screenSize.width * 0.04,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Private optimized item card widget
class _OptimizedItemCard extends StatelessWidget {
  const _OptimizedItemCard({
    required this.item,
    required this.onTap,
    required this.screenSize,
    required this.isDarkMode,
    this.displayTypeOverride,
    this.showStatus = true,
    this.showEmployeeImage = true,
    this.borderColor,
    this.customTrailing,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final Size screenSize;
  final bool isDarkMode;
  final String? displayTypeOverride;
  final bool showStatus;
  final bool showEmployeeImage;
  final Color? borderColor;
  final Widget? customTrailing;

  @override
  Widget build(BuildContext context) {
    final type = item['type']?.toString().toLowerCase() ?? 'unknown';
    final status = item['status']?.toString() ?? 'pending';
    final title = item['title']?.toString() ?? 'No Title';
    final startDate = item['startDate']?.toString() ?? '';
    final endDate = item['endDate']?.toString() ?? '';
    final employeeName = item['employee_name']?.toString() ?? 'N/A';
    final imageUrl =
        item['img_name']?.toString() ?? 'https://via.placeholder.com/150';

    final typeColor = _getTypeColor(type);
    final statusColor = _getStatusColor(status);
    final typeIcon = _getIconForType(type);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenSize.width * 0.04),
          side: BorderSide(
            color: borderColor ?? typeColor,
            width: screenSize.width * 0.004,
          ),
        ),
        margin: EdgeInsets.symmetric(vertical: screenSize.height * 0.005),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: screenSize.height * 0.008,
            horizontal: screenSize.width * 0.02,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon section
              SizedBox(
                width: screenSize.width * 0.14,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      typeIcon,
                      color: typeColor,
                      size: screenSize.width * 0.08,
                    ),
                    SizedBox(height: screenSize.height * 0.002),
                    Text(
                      displayTypeOverride ?? _getDisplayType(type),
                      style: TextStyle(
                        color: typeColor,
                        fontSize: screenSize.width * 0.025,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: screenSize.width * 0.02),

              // Information column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: screenSize.width * 0.033,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenSize.height * 0.003),
                    if (startDate.isNotEmpty && endDate.isNotEmpty)
                      Text(
                        '${_formatDate(startDate)} → ${_formatDate(endDate)}',
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.white70
                              : Colors.grey.shade700,
                          fontSize: screenSize.width * 0.028,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(height: screenSize.height * 0.002),
                    Text(
                      'Employee: $employeeName',
                      style: TextStyle(
                        color:
                            isDarkMode ? Colors.white70 : Colors.grey.shade700,
                        fontSize: screenSize.width * 0.028,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showStatus) ...[
                      SizedBox(height: screenSize.height * 0.005),
                      Row(
                        children: [
                          Text(
                            'Status: ',
                            style: TextStyle(
                              fontSize: screenSize.width * 0.028,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenSize.width * 0.012,
                              vertical: screenSize.height * 0.002,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(
                                  screenSize.width * 0.015),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: screenSize.width * 0.028,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Trailing section
              if (customTrailing != null)
                customTrailing!
              else if (showEmployeeImage) ...[
                SizedBox(width: screenSize.width * 0.015),
                PerformanceOptimizedWidgets.buildOptimizedCachedImage(
                  imageUrl: imageUrl,
                  radius: screenSize.width * 0.05,
                  backgroundColor:
                      isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final DateTime parsedDate = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy').format(parsedDate);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  String _getDisplayType(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return 'Meeting Room';
      case 'leave':
        return 'Leave';
      case 'car':
        return 'Car Booking';
      case 'minutes of meeting':
        return 'Meeting Minutes';
      default:
        return type;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return Colors.green;
      case 'leave':
        return Colors.orange;
      case 'car':
        return Colors.blue;
      case 'minutes of meeting':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'public':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'disapproved':
      case 'rejected':
      case 'cancel':
        return Colors.red;
      case 'pending':
      case 'waiting':
        return Colors.amber;
      case 'processing':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return Icons.meeting_room;
      case 'leave':
        return Icons.event;
      case 'car':
        return Icons.directions_car;
      case 'minutes of meeting':
        return Icons.event_available;
      default:
        return Icons.info;
    }
  }
}
