import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/core/utils/low_end_device_optimizer.dart';

/// Ultra-optimized cache service for low-end Android devices
class OptimizedPerformanceCacheService {
  static const String _calendarCacheKey = 'opt_calendar_cache';
  static const String _notificationCacheKey = 'opt_notification_cache';
  static const String _historyCacheKey = 'opt_history_cache';
  static const String _approvalsCacheKey = 'opt_approvals_cache';

  // Adaptive cache settings based on device capability
  static int get _maxMemoryCacheItems {
    return LowEndDeviceOptimizer.getDeviceSetting<int>('max_cache_size');
  }

  static int get _maxMemoryCacheBytes {
    final deviceTier = LowEndDeviceOptimizer.getCurrentDeviceTier();
    switch (deviceTier) {
      case 'very_low':
        return 2 * 1024 * 1024; // 2MB
      case 'low':
        return 5 * 1024 * 1024; // 5MB
      case 'medium':
        return 10 * 1024 * 1024; // 10MB
      default:
        return 20 * 1024 * 1024; // 20MB
    }
  }

  // Ultra-lightweight memory cache
  static final Map<String, _UltraLightCacheEntry> _memoryCache = {};
  static int _currentMemoryUsage = 0;

  /// Set cache data with aggressive optimization for low-end devices
  static Future<void> setCacheData(String key, dynamic data,
      {Duration? expiry}) async {
    try {
      final deviceExpiry = _getOptimizedExpiry(expiry);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Compress data for low-end devices
      final compressedData = await _compressData(data);
      final entry = _UltraLightCacheEntry(
        data: compressedData,
        timestamp: timestamp,
        expiry: deviceExpiry.inMilliseconds,
        isCompressed: LowEndDeviceOptimizer.isLowEndDevice,
      );

      // Check memory limits before adding
      await _enforceMemoryLimits();

      // Add to memory cache
      _memoryCache[key] = entry;
      _currentMemoryUsage += entry.sizeInBytes;

      // Persist to storage (async, non-blocking)
      _persistToStorage(key, entry);
    } catch (e) {
      debugPrint('Error setting optimized cache for $key: $e');
    }
  }

  /// Get cache data with fast access patterns
  static Future<T?> getCacheData<T>(String key) async {
    try {
      // Check memory cache first (fastest)
      if (_memoryCache.containsKey(key)) {
        final entry = _memoryCache[key]!;
        if (_isCacheValid(entry)) {
          return await _decompressData<T>(entry);
        } else {
          // Remove expired entry
          _removeFromMemoryCache(key);
        }
      }

      // Fallback to storage (slower)
      return await _loadFromStorage<T>(key);
    } catch (e) {
      debugPrint('Error getting optimized cache for $key: $e');
      return null;
    }
  }

  /// Compress data based on device capability
  static Future<dynamic> _compressData(dynamic data) async {
    if (!LowEndDeviceOptimizer.isLowEndDevice) {
      return data; // No compression for high-end devices
    }

    try {
      // Simple JSON compression for low-end devices
      if (data is List || data is Map) {
        final jsonString = jsonEncode(data);
        if (jsonString.length > 1024) {
          // Only compress if > 1KB
          // Simple compression: remove whitespace and use shorter keys
          final compressed = jsonString
              .replaceAll(' ', '')
              .replaceAll('\n', '')
              .replaceAll('\t', '');
          return compressed;
        }
      }
      return data;
    } catch (e) {
      debugPrint('Compression failed: $e');
      return data;
    }
  }

  /// Decompress data
  static Future<T?> _decompressData<T>(_UltraLightCacheEntry entry) async {
    try {
      if (!entry.isCompressed) {
        return entry.data as T?;
      }

      // Decompress if needed
      if (entry.data is String) {
        final decompressed = jsonDecode(entry.data);
        return decompressed as T?;
      }

      return entry.data as T?;
    } catch (e) {
      debugPrint('Decompression failed: $e');
      return null;
    }
  }

  /// Get optimized expiry time based on device tier
  static Duration _getOptimizedExpiry(Duration? requested) {
    final deviceTier = LowEndDeviceOptimizer.getCurrentDeviceTier();
    final defaultExpiry = requested ?? const Duration(minutes: 15);

    switch (deviceTier) {
      case 'very_low':
        // Very short cache for very low-end devices
        return Duration(minutes: (defaultExpiry.inMinutes * 0.3).round());
      case 'low':
        return Duration(minutes: (defaultExpiry.inMinutes * 0.5).round());
      case 'medium':
        return Duration(minutes: (defaultExpiry.inMinutes * 0.8).round());
      default:
        return defaultExpiry;
    }
  }

  /// Enforce memory limits with aggressive cleanup
  static Future<void> _enforceMemoryLimits() async {
    if (_currentMemoryUsage <= _maxMemoryCacheBytes &&
        _memoryCache.length <= _maxMemoryCacheItems) {
      return;
    }

    debugPrint('🧹 Memory limit exceeded, cleaning cache...');

    // Sort by last access time (LRU)
    final sortedEntries = _memoryCache.entries.toList()
      ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

    // Remove oldest entries until within limits
    final targetSize = (_maxMemoryCacheBytes * 0.7).round(); // 70% of max
    final targetCount = (_maxMemoryCacheItems * 0.7).round();

    while ((_currentMemoryUsage > targetSize ||
            _memoryCache.length > targetCount) &&
        sortedEntries.isNotEmpty) {
      final entry = sortedEntries.removeAt(0);
      _removeFromMemoryCache(entry.key);
    }

    debugPrint(
        '🧹 Cache cleaned: ${_memoryCache.length} items, ${(_currentMemoryUsage / 1024).round()}KB');
  }

  /// Remove entry from memory cache
  static void _removeFromMemoryCache(String key) {
    final entry = _memoryCache.remove(key);
    if (entry != null) {
      _currentMemoryUsage -= entry.sizeInBytes;
    }
  }

  /// Check if cache entry is valid
  static bool _isCacheValid(_UltraLightCacheEntry entry) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - entry.timestamp) < entry.expiry;
  }

  /// Persist to storage (non-blocking)
  static void _persistToStorage(String key, _UltraLightCacheEntry entry) {
    // Use compute for heavy operations on low-end devices
    if (LowEndDeviceOptimizer.isLowEndDevice) {
      compute(_persistInIsolate, {
        'key': key,
        'entry': entry.toJson(),
      }).catchError((e) {
        debugPrint('Storage persistence failed: $e');
      });
    } else {
      // Direct persistence for high-end devices
      _persistDirectly(key, entry);
    }
  }

  /// Persist data in isolate (for low-end devices)
  static Future<void> _persistInIsolate(Map<String, dynamic> params) async {
    try {
      final key = params['key'] as String;
      final entryJson = params['entry'] as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('opt_$key', jsonEncode(entryJson));
    } catch (e) {
      debugPrint('Isolate persistence error: $e');
    }
  }

  /// Direct persistence for high-end devices
  static Future<void> _persistDirectly(
      String key, _UltraLightCacheEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('opt_$key', jsonEncode(entry.toJson()));
    } catch (e) {
      debugPrint('Direct persistence error: $e');
    }
  }

  /// Load from storage
  static Future<T?> _loadFromStorage<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedData = prefs.getString('opt_$key');

      if (storedData != null) {
        final entryJson = jsonDecode(storedData);
        final entry = _UltraLightCacheEntry.fromJson(entryJson);

        if (_isCacheValid(entry)) {
          // Add back to memory cache
          _memoryCache[key] = entry;
          _currentMemoryUsage += entry.sizeInBytes;

          return await _decompressData<T>(entry);
        } else {
          // Remove expired storage entry
          await prefs.remove('opt_$key');
        }
      }

      return null;
    } catch (e) {
      debugPrint('Storage load error for $key: $e');
      return null;
    }
  }

  /// Calendar-specific optimized methods
  static Future<void> cacheCalendarEvents(List<dynamic> events) async {
    await setCacheData(_calendarCacheKey, events,
        expiry: Duration(
            minutes: LowEndDeviceOptimizer.getDeviceSetting<int>(
                    'background_sync_interval') ~/
                60000));
  }

  static Future<List<dynamic>?> getCachedCalendarEvents() async {
    return await getCacheData<List<dynamic>>(_calendarCacheKey);
  }

  /// Notification-specific optimized methods
  static Future<void> cacheNotificationData(Map<String, dynamic> data) async {
    await setCacheData(_notificationCacheKey, data,
        expiry: const Duration(minutes: 10));
  }

  static Future<Map<String, dynamic>?> getCachedNotificationData() async {
    return await getCacheData<Map<String, dynamic>>(_notificationCacheKey);
  }

  /// History-specific optimized methods
  static Future<void> cacheHistoryData(Map<String, dynamic> data) async {
    await setCacheData(_historyCacheKey, data,
        expiry: const Duration(minutes: 20));
  }

  static Future<Map<String, dynamic>?> getCachedHistoryData() async {
    return await getCacheData<Map<String, dynamic>>(_historyCacheKey);
  }

  /// Approvals-specific optimized methods
  static Future<void> cacheApprovalsData(Map<String, dynamic> data) async {
    await setCacheData(_approvalsCacheKey, data,
        expiry: const Duration(minutes: 15));
  }

  static Future<Map<String, dynamic>?> getCachedApprovalsData() async {
    return await getCacheData<Map<String, dynamic>>(_approvalsCacheKey);
  }

  /// Emergency cleanup for low memory situations
  static Future<void> emergencyCleanup() async {
    try {
      // Clear all memory cache
      _memoryCache.clear();
      _currentMemoryUsage = 0;

      // Clear storage cache for low-end devices
      if (LowEndDeviceOptimizer.isLowEndDevice) {
        final prefs = await SharedPreferences.getInstance();
        final keys =
            prefs.getKeys().where((key) => key.startsWith('opt_')).toList();
        for (final key in keys) {
          await prefs.remove(key);
        }
      }

      debugPrint('🚨 Emergency cache cleanup completed');
    } catch (e) {
      debugPrint('Emergency cleanup error: $e');
    }
  }

  /// Clear all caches
  static Future<void> clearAllCaches() async {
    await emergencyCleanup();
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'memory_items': _memoryCache.length,
      'memory_usage_kb': (_currentMemoryUsage / 1024).round(),
      'memory_limit_kb': (_maxMemoryCacheBytes / 1024).round(),
      'device_tier': LowEndDeviceOptimizer.getCurrentDeviceTier(),
      'compression_enabled': LowEndDeviceOptimizer.isLowEndDevice,
      'utilization_percent':
          ((_currentMemoryUsage / _maxMemoryCacheBytes) * 100).round(),
    };
  }
}

/// Ultra-lightweight cache entry optimized for memory usage
class _UltraLightCacheEntry {
  final dynamic data;
  final int timestamp;
  final int expiry;
  final bool isCompressed;

  _UltraLightCacheEntry({
    required this.data,
    required this.timestamp,
    required this.expiry,
    required this.isCompressed,
  });

  /// Estimate size in bytes
  int get sizeInBytes {
    try {
      if (data is String) {
        return (data as String).length * 2; // Rough estimate for UTF-16
      } else if (data is List) {
        return (data as List).length * 50; // Rough estimate
      } else if (data is Map) {
        return (data as Map).length * 100; // Rough estimate
      }
      return 100; // Default estimate
    } catch (e) {
      return 100;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'timestamp': timestamp,
      'expiry': expiry,
      'isCompressed': isCompressed,
    };
  }

  factory _UltraLightCacheEntry.fromJson(Map<String, dynamic> json) {
    return _UltraLightCacheEntry(
      data: json['data'],
      timestamp: json['timestamp'],
      expiry: json['expiry'],
      isCompressed: json['isCompressed'] ?? false,
    );
  }
}
