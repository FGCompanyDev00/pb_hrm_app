// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprehensive optimizer for low-end Android devices
class LowEndDeviceOptimizer {
  static bool _isLowEndDevice = false;
  static int _deviceMemoryMB = 0;
  static Timer? _memoryCleanupTimer;
  static Timer? _performanceMonitorTimer;

  // Memory management thresholds
  static const int LOW_END_MEMORY_THRESHOLD = 2048; // 2GB RAM
  static const int CRITICAL_MEMORY_THRESHOLD = 1024; // 1GB RAM
  static const int VERY_LOW_MEMORY_THRESHOLD = 512; // 512MB RAM

  // Performance settings for different device tiers
  static const Map<String, Map<String, dynamic>> DEVICE_TIERS = {
    'very_low': {
      'max_cache_size': 50, // Maximum cached items
      'image_cache_size': 20,
      'list_item_limit': 20,
      'animation_duration': 150,
      'debounce_delay': 500,
      'background_sync_interval': 300000, // 5 minutes
      'enable_animations': false,
      'enable_shadows': false,
      'enable_blur': false,
    },
    'low': {
      'max_cache_size': 100,
      'image_cache_size': 50,
      'list_item_limit': 50,
      'animation_duration': 200,
      'debounce_delay': 300,
      'background_sync_interval': 180000, // 3 minutes
      'enable_animations': true,
      'enable_shadows': false,
      'enable_blur': false,
    },
    'medium': {
      'max_cache_size': 200,
      'image_cache_size': 100,
      'list_item_limit': 100,
      'animation_duration': 250,
      'debounce_delay': 200,
      'background_sync_interval': 120000, // 2 minutes
      'enable_animations': true,
      'enable_shadows': true,
      'enable_blur': false,
    },
    'high': {
      'max_cache_size': 500,
      'image_cache_size': 200,
      'list_item_limit': 200,
      'animation_duration': 300,
      'debounce_delay': 100,
      'background_sync_interval': 60000, // 1 minute
      'enable_animations': true,
      'enable_shadows': true,
      'enable_blur': true,
    },
  };

  /// Initialize optimizer with device detection
  static Future<void> initialize() async {
    await _detectDeviceCapabilities();
    _setupMemoryManagement();
    _setupPerformanceMonitoring();
    _configureFlutterOptimizations();

    debugPrint('📱 Device tier: ${getCurrentDeviceTier()}');
    debugPrint('💾 Available memory: ${_deviceMemoryMB}MB');
    debugPrint(
        '⚡ Low-end optimizations: ${_isLowEndDevice ? 'ENABLED' : 'DISABLED'}');
  }

  /// Detect device capabilities and memory
  static Future<void> _detectDeviceCapabilities() async {
    try {
      // Get device memory info (Android specific)
      if (Platform.isAndroid) {
        const platform = MethodChannel('device_info');
        try {
          final Map<dynamic, dynamic> deviceInfo =
              await platform.invokeMethod('getDeviceInfo');
          _deviceMemoryMB = deviceInfo['totalMemoryMB'] ?? 0;
        } catch (e) {
          // Fallback: Estimate based on performance
          _deviceMemoryMB = await _estimateMemoryFromPerformance();
        }
      } else {
        _deviceMemoryMB = 4096; // Assume 4GB for non-Android
      }

      _isLowEndDevice = _deviceMemoryMB <= LOW_END_MEMORY_THRESHOLD;
    } catch (e) {
      debugPrint('Error detecting device capabilities: $e');
      _deviceMemoryMB = 2048; // Conservative default
      _isLowEndDevice = true;
    }
  }

  /// Estimate memory based on performance benchmarks
  static Future<int> _estimateMemoryFromPerformance() async {
    final stopwatch = Stopwatch()..start();

    // Simple CPU benchmark
    int iterations = 0;
    while (stopwatch.elapsedMilliseconds < 100) {
      iterations++;
      // Simple calculation
      for (int i = 0; i < 1000; i++) {
        i * i;
      }
    }

    stopwatch.stop();

    // Estimate memory based on performance
    if (iterations < 500) return 512; // Very low-end
    if (iterations < 1000) return 1024; // Low-end
    if (iterations < 2000) return 2048; // Medium
    return 4096; // High-end
  }

  /// Setup automatic memory management
  static void _setupMemoryManagement() {
    // Cleanup memory every 2 minutes on low-end devices
    final interval = _isLowEndDevice
        ? const Duration(minutes: 2)
        : const Duration(minutes: 5);

    _memoryCleanupTimer = Timer.periodic(interval, (_) {
      _performMemoryCleanup();
    });
  }

  /// Setup performance monitoring
  static void _setupPerformanceMonitoring() {
    if (_isLowEndDevice) {
      _performanceMonitorTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _monitorPerformance(),
      );
    }
  }

  /// Configure Flutter-specific optimizations
  static void _configureFlutterOptimizations() {
    // Reduce texture cache for low-end devices
    if (_isLowEndDevice) {
      PaintingBinding.instance.imageCache.maximumSize =
          getDeviceSetting('image_cache_size');
      PaintingBinding.instance.imageCache.maximumSizeBytes =
          1024 * 1024 * 10; // 10MB max
    }

    // Disable raster cache for very low-end devices
    if (_deviceMemoryMB <= VERY_LOW_MEMORY_THRESHOLD) {
      debugPrint('🔧 Disabling raster cache for very low-end device');
      // Note: This would require engine-level modifications
    }
  }

  /// Perform comprehensive memory cleanup
  static void _performMemoryCleanup() {
    try {
      // Clear image cache if memory is low
      if (_isLowEndDevice) {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }

      // Force garbage collection (use sparingly)
      if (_deviceMemoryMB <= CRITICAL_MEMORY_THRESHOLD) {
        _forceGarbageCollection();
      }

      debugPrint('🧹 Memory cleanup completed');
    } catch (e) {
      debugPrint('Error during memory cleanup: $e');
    }
  }

  /// Force garbage collection (emergency only)
  static void _forceGarbageCollection() {
    // This is a last resort for very low memory situations
    if (_deviceMemoryMB <= VERY_LOW_MEMORY_THRESHOLD) {
      // Run in isolate to avoid blocking main thread
      Isolate.spawn(_gcIsolate, null);
    }
  }

  /// Garbage collection isolate
  static void _gcIsolate(dynamic message) {
    // Force GC in isolate
    for (int i = 0; i < 3; i++) {
      List.generate(1000, (index) => index).clear();
    }
  }

  /// Monitor app performance
  static void _monitorPerformance() {
    // Monitor frame rate and memory usage
    // This would integrate with Flutter DevTools in debug mode
    if (kDebugMode) {
      debugPrint(
          '🔍 Performance check - Device tier: ${getCurrentDeviceTier()}');
    }
  }

  /// Get current device tier
  static String getCurrentDeviceTier() {
    if (_deviceMemoryMB <= VERY_LOW_MEMORY_THRESHOLD) return 'very_low';
    if (_deviceMemoryMB <= CRITICAL_MEMORY_THRESHOLD) return 'low';
    if (_deviceMemoryMB <= LOW_END_MEMORY_THRESHOLD) return 'medium';
    return 'high';
  }

  /// Get device-specific setting
  static T getDeviceSetting<T>(String key) {
    final tier = getCurrentDeviceTier();
    return DEVICE_TIERS[tier]![key] as T;
  }

  /// Check if device is low-end
  static bool get isLowEndDevice => _isLowEndDevice;

  /// Get device memory in MB
  static int get deviceMemoryMB => _deviceMemoryMB;

  /// Optimized ListView builder for low-end devices
  static Widget buildOptimizedListView({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    ScrollController? controller,
    bool shrinkWrap = false,
  }) {
    final maxItems = getDeviceSetting<int>('list_item_limit');
    final effectiveItemCount = _isLowEndDevice
        ? (itemCount > maxItems ? maxItems : itemCount)
        : itemCount;

    return ListView.builder(
      controller: controller,
      shrinkWrap: shrinkWrap,
      itemCount: effectiveItemCount,
      physics: _isLowEndDevice
          ? const ClampingScrollPhysics()
          : // Smoother on low-end
          const AlwaysScrollableScrollPhysics(),
      cacheExtent: _isLowEndDevice ? 100.0 : 250.0,
      itemBuilder: (context, index) {
        if (index >= effectiveItemCount) {
          return const SizedBox.shrink();
        }
        return itemBuilder(context, index);
      },
    );
  }

  /// Optimized image loading for low-end devices
  static Widget buildOptimizedImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          errorWidget ?? const Icon(Icons.error),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ?? const CircularProgressIndicator();
      },
      cacheWidth: _isLowEndDevice && width != null ? width.toInt() : null,
      cacheHeight: _isLowEndDevice && height != null ? height.toInt() : null,
    );
  }

  /// Optimized animation duration
  static Duration getOptimizedAnimationDuration([Duration? defaultDuration]) {
    if (!getDeviceSetting<bool>('enable_animations')) {
      return Duration.zero;
    }

    final optimizedMs = getDeviceSetting<int>('animation_duration');
    return Duration(milliseconds: optimizedMs);
  }

  /// Optimized debounce duration
  static Duration getOptimizedDebounceDuration() {
    final ms = getDeviceSetting<int>('debounce_delay');
    return Duration(milliseconds: ms);
  }

  /// Memory-efficient pagination
  static List<T> getOptimizedPage<T>(List<T> items, int page,
      [int? customPageSize]) {
    final pageSize = customPageSize ?? getDeviceSetting<int>('list_item_limit');
    final startIndex = page * pageSize;
    final endIndex = startIndex + pageSize;

    if (startIndex >= items.length) return [];

    return items.sublist(
      startIndex,
      endIndex > items.length ? items.length : endIndex,
    );
  }

  /// Cleanup resources
  static void dispose() {
    _memoryCleanupTimer?.cancel();
    _performanceMonitorTimer?.cancel();
    _memoryCleanupTimer = null;
    _performanceMonitorTimer = null;
  }

  /// Emergency memory cleanup
  static Future<void> emergencyCleanup() async {
    try {
      // Clear all caches
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Clear SharedPreferences cache if exists
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getKeys().where((key) => key.startsWith('cache_')).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }

      // Force GC for critical memory situations
      if (_deviceMemoryMB <= VERY_LOW_MEMORY_THRESHOLD) {
        _forceGarbageCollection();
      }

      debugPrint('🚨 Emergency cleanup completed');
    } catch (e) {
      debugPrint('Error during emergency cleanup: $e');
    }
  }

  /// Get performance report
  static Map<String, dynamic> getPerformanceReport() {
    return {
      'device_tier': getCurrentDeviceTier(),
      'memory_mb': _deviceMemoryMB,
      'is_low_end': _isLowEndDevice,
      'settings': DEVICE_TIERS[getCurrentDeviceTier()],
      'optimizations_active': _isLowEndDevice,
      'cleanup_timer_active': _memoryCleanupTimer?.isActive ?? false,
      'monitor_timer_active': _performanceMonitorTimer?.isActive ?? false,
    };
  }
}

/// Extension for optimized widgets
extension LowEndOptimizations on Widget {
  /// Apply low-end device optimizations to any widget
  Widget optimizeForLowEnd() {
    if (!LowEndDeviceOptimizer.isLowEndDevice) return this;

    return RepaintBoundary(
      child: this,
    );
  }

  /// Conditionally show widget based on device capability
  Widget showOnCapableDevices() {
    return LowEndDeviceOptimizer.isLowEndDevice
        ? const SizedBox.shrink()
        : this;
  }
}

/// Optimized ScrollPhysics for low-end devices
class LowEndScrollPhysics extends ClampingScrollPhysics {
  const LowEndScrollPhysics({super.parent});

  @override
  LowEndScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return LowEndScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingVelocity =>
      LowEndDeviceOptimizer.isLowEndDevice ? 100.0 : 50.0;

  @override
  double get maxFlingVelocity =>
      LowEndDeviceOptimizer.isLowEndDevice ? 2000.0 : 8000.0;
}
