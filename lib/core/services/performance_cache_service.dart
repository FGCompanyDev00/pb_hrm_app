import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// High-performance centralized cache service with memory optimization
class PerformanceCacheService {
  static const String _calendarCacheKey = 'perf_calendar_cache';
  static const String _notificationCacheKey = 'perf_notification_cache';
  static const String _historyCacheKey = 'perf_history_cache';
  static const String _approvalsCacheKey = 'perf_approvals_cache';
  static const String _leaveTypesCacheKey = 'perf_leave_types_cache';

  // Cache expiry times (in milliseconds)
  static const int _shortCacheExpiry = 5 * 60 * 1000; // 5 minutes
  static const int _mediumCacheExpiry = 15 * 60 * 1000; // 15 minutes
  static const int _longCacheExpiry = 60 * 60 * 1000; // 1 hour

  // In-memory cache for frequently accessed data
  static final Map<String, dynamic> _memoryCache = {};
  static final Map<String, int> _cacheTimestamps = {};

  /// Optimized cache write operation using isolate for large data
  static Future<void> setCacheData(String key, dynamic data,
      {int? customExpiry}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final expiry = customExpiry ?? _mediumCacheExpiry;

      final cacheEntry = {
        'data': data,
        'timestamp': timestamp,
        'expiry': expiry,
      };

      // Store in memory cache for quick access
      _memoryCache[key] = cacheEntry;
      _cacheTimestamps[key] = timestamp;

      // Asynchronously persist to SharedPreferences
      _persistCacheData(key, cacheEntry);
    } catch (e) {
      debugPrint('Error setting cache data for $key: $e');
    }
  }

  /// Optimized cache read operation with fallback strategies
  static Future<T?> getCacheData<T>(String key) async {
    try {
      // First check memory cache
      if (_memoryCache.containsKey(key)) {
        final cacheEntry = _memoryCache[key];
        if (_isCacheValid(cacheEntry)) {
          return cacheEntry['data'] as T?;
        } else {
          // Remove expired memory cache
          _memoryCache.remove(key);
          _cacheTimestamps.remove(key);
        }
      }

      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(key);

      if (cachedString != null) {
        final cacheEntry = jsonDecode(cachedString);
        if (_isCacheValid(cacheEntry)) {
          // Restore to memory cache
          _memoryCache[key] = cacheEntry;
          _cacheTimestamps[key] = cacheEntry['timestamp'];
          return cacheEntry['data'] as T?;
        } else {
          // Remove expired cache
          await prefs.remove(key);
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error getting cache data for $key: $e');
      return null;
    }
  }

  /// Background persistence without blocking UI
  static void _persistCacheData(String key, Map<String, dynamic> cacheEntry) {
    // Use compute for heavy serialization to avoid blocking UI
    compute(_serializeAndPersist, {
      'key': key,
      'data': cacheEntry,
    }).catchError((e) {
      debugPrint('Error persisting cache data: $e');
    });
  }

  /// Isolate function for serialization
  static Future<void> _serializeAndPersist(Map<String, dynamic> params) async {
    try {
      final key = params['key'] as String;
      final data = params['data'];
      final serialized = jsonEncode(data);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, serialized);
    } catch (e) {
      debugPrint('Error in isolate serialization: $e');
    }
  }

  /// Check if cache entry is still valid
  static bool _isCacheValid(Map<String, dynamic> cacheEntry) {
    final timestamp = cacheEntry['timestamp'] as int;
    final expiry = cacheEntry['expiry'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;

    return (now - timestamp) < expiry;
  }

  /// Calendar-specific cache methods
  static Future<void> cacheCalendarEvents(List<dynamic> events) async {
    await setCacheData(_calendarCacheKey, events,
        customExpiry: _shortCacheExpiry);
  }

  static Future<List<dynamic>?> getCachedCalendarEvents() async {
    return await getCacheData<List<dynamic>>(_calendarCacheKey);
  }

  /// Notification-specific cache methods
  static Future<void> cacheNotificationData(Map<String, dynamic> data) async {
    await setCacheData(_notificationCacheKey, data,
        customExpiry: _mediumCacheExpiry);
  }

  static Future<Map<String, dynamic>?> getCachedNotificationData() async {
    return await getCacheData<Map<String, dynamic>>(_notificationCacheKey);
  }

  /// History-specific cache methods
  static Future<void> cacheHistoryData(Map<String, dynamic> data) async {
    await setCacheData(_historyCacheKey, data,
        customExpiry: _mediumCacheExpiry);
  }

  static Future<Map<String, dynamic>?> getCachedHistoryData() async {
    return await getCacheData<Map<String, dynamic>>(_historyCacheKey);
  }

  /// Approvals-specific cache methods
  static Future<void> cacheApprovalsData(Map<String, dynamic> data) async {
    await setCacheData(_approvalsCacheKey, data,
        customExpiry: _mediumCacheExpiry);
  }

  static Future<Map<String, dynamic>?> getCachedApprovalsData() async {
    return await getCacheData<Map<String, dynamic>>(_approvalsCacheKey);
  }

  /// Leave types cache methods
  static Future<void> cacheLeaveTypes(Map<int, String> leaveTypes) async {
    await setCacheData(_leaveTypesCacheKey, leaveTypes,
        customExpiry: _longCacheExpiry);
  }

  static Future<Map<int, String>?> getCachedLeaveTypes() async {
    final cached =
        await getCacheData<Map<String, dynamic>>(_leaveTypesCacheKey);
    if (cached != null) {
      return cached
          .map((key, value) => MapEntry(int.parse(key), value.toString()));
    }
    return null;
  }

  /// Memory management methods
  static void clearMemoryCache() {
    _memoryCache.clear();
    _cacheTimestamps.clear();
  }

  static void clearExpiredMemoryCache() {
    final expiredKeys = <String>[];

    for (final entry in _memoryCache.entries) {
      final cacheEntry = entry.value as Map<String, dynamic>;
      if (!_isCacheValid(cacheEntry)) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  /// Preload critical cache data
  static Future<void> preloadCriticalData() async {
    try {
      await Future.wait([
        getCachedLeaveTypes(),
        getCachedCalendarEvents(),
      ]);
    } catch (e) {
      debugPrint('Error preloading critical data: $e');
    }
  }

  /// Clear all caches
  static Future<void> clearAllCaches() async {
    try {
      clearMemoryCache();
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_calendarCacheKey),
        prefs.remove(_notificationCacheKey),
        prefs.remove(_historyCacheKey),
        prefs.remove(_approvalsCacheKey),
        prefs.remove(_leaveTypesCacheKey),
      ]);
    } catch (e) {
      debugPrint('Error clearing all caches: $e');
    }
  }

  /// Get cache statistics for debugging
  static Map<String, dynamic> getCacheStats() {
    return {
      'memory_cache_size': _memoryCache.length,
      'memory_cache_keys': _memoryCache.keys.toList(),
      'cache_timestamps': _cacheTimestamps,
    };
  }
}
