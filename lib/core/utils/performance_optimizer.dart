import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Performance optimization utilities for existing pages
class PerformanceOptimizer {
  /// Debounce timer for API calls to prevent excessive requests
  static Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  /// Memory cache for frequently accessed data
  static final Map<String, dynamic> _memoryCache = {};
  static final Map<String, int> _cacheTimestamps = {};

  /// Throttle function calls to prevent excessive executions
  static void throttle(String key, VoidCallback callback, [Duration? delay]) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastCall = _cacheTimestamps[key] ?? 0;
    final throttleDelay = delay ?? const Duration(milliseconds: 500);

    if (now - lastCall >= throttleDelay.inMilliseconds) {
      _cacheTimestamps[key] = now;
      callback();
    }
  }

  /// Debounce function calls to delay execution until after calls have stopped
  static void debounce(String key, VoidCallback callback) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, callback);
  }

  /// Checks if a State object is mounted - use this before calling setState manually
  /// Usage: if (PerformanceOptimizer.isMounted(this)) { setState(() { /* changes */ }); }
  static bool isMounted(State state) {
    return state.mounted;
  }

  /// Batch async operations to improve performance
  static Future<List<T>> batchAsyncOperations<T>(
    List<Future<T> Function()> operations, {
    int? batchSize,
  }) async {
    final effectiveBatchSize = batchSize ?? 5;
    final results = <T>[];

    for (int i = 0; i < operations.length; i += effectiveBatchSize) {
      final end = (i + effectiveBatchSize > operations.length)
          ? operations.length
          : i + effectiveBatchSize;

      final batch = operations.sublist(i, end);
      final batchResults = await Future.wait(
        batch.map((operation) => operation()),
      );

      results.addAll(batchResults);
    }

    return results;
  }

  /// Optimized list processing using isolates for large datasets
  static Future<List<T>> processLargeList<T>(
    List<dynamic> data,
    T Function(dynamic) processor, {
    int threshold = 1000,
  }) async {
    if (data.length < threshold) {
      // Process on main thread for small lists
      return data.map(processor).toList();
    } else {
      // Use isolate for large lists
      return await compute(_processListInIsolate, {
        'data': data,
        'processor': processor,
      });
    }
  }

  /// Isolate function for list processing
  static List<T> _processListInIsolate<T>(Map<String, dynamic> params) {
    final List<dynamic> data = params['data'];
    final T Function(dynamic) processor = params['processor'];
    return data.map(processor).toList();
  }

  /// Memory-efficient pagination helper
  static List<T> paginateList<T>(
    List<T> list,
    int page,
    int itemsPerPage,
  ) {
    final startIndex = (page - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;

    if (startIndex >= list.length) return [];

    return list.sublist(
      startIndex,
      endIndex > list.length ? list.length : endIndex,
    );
  }

  /// Efficient search with caching
  static List<T> searchWithCache<T>(
    String cacheKey,
    List<T> items,
    String query,
    List<String> Function(T) getSearchFields, {
    Duration cacheDuration = const Duration(minutes: 5),
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cacheTimestamp = _cacheTimestamps[cacheKey] ?? 0;

    // Check cache validity
    if (now - cacheTimestamp < cacheDuration.inMilliseconds &&
        _memoryCache.containsKey(cacheKey)) {
      final cachedResults = _memoryCache[cacheKey] as List<T>?;
      if (cachedResults != null) return cachedResults;
    }

    // Perform search
    final lowercaseQuery = query.toLowerCase();
    final results = items.where((item) {
      final searchFields = getSearchFields(item);
      return searchFields
          .any((field) => field.toLowerCase().contains(lowercaseQuery));
    }).toList();

    // Cache results
    _memoryCache[cacheKey] = results;
    _cacheTimestamps[cacheKey] = now;

    return results;
  }

  /// Optimized JSON operations with error handling
  static Map<String, dynamic>? safeJsonDecode(String jsonString) {
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('JSON decode error: $e');
      return null;
    }
  }

  static String? safeJsonEncode(dynamic object) {
    try {
      return jsonEncode(object);
    } catch (e) {
      debugPrint('JSON encode error: $e');
      return null;
    }
  }

  /// Smart cache management with automatic cleanup
  static Future<void> setCache(
    String key,
    dynamic data, {
    Duration? expiry,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryTime = expiry ?? const Duration(hours: 1);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final cacheData = {
        'data': data,
        'timestamp': timestamp,
        'expiry': expiryTime.inMilliseconds,
      };

      // Store in memory cache
      _memoryCache[key] = cacheData;

      // Store in SharedPreferences
      final encoded = safeJsonEncode(cacheData);
      if (encoded != null) {
        await prefs.setString('cache_$key', encoded);
      }
    } catch (e) {
      debugPrint('Cache set error for $key: $e');
    }
  }

  static Future<T?> getCache<T>(String key) async {
    try {
      // Check memory cache first
      if (_memoryCache.containsKey(key)) {
        final cacheData = _memoryCache[key] as Map<String, dynamic>;
        if (_isCacheValid(cacheData)) {
          return cacheData['data'] as T?;
        } else {
          _memoryCache.remove(key);
        }
      }

      // Check SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cache_$key');

      if (cached != null) {
        final cacheData = safeJsonDecode(cached);
        if (cacheData != null && _isCacheValid(cacheData)) {
          // Restore to memory cache
          _memoryCache[key] = cacheData;
          return cacheData['data'] as T?;
        } else {
          // Remove expired cache
          await prefs.remove('cache_$key');
        }
      }

      return null;
    } catch (e) {
      debugPrint('Cache get error for $key: $e');
      return null;
    }
  }

  /// Check if cache is still valid
  static bool _isCacheValid(Map<String, dynamic> cacheData) {
    final timestamp = cacheData['timestamp'] as int? ?? 0;
    final expiry = cacheData['expiry'] as int? ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    return (now - timestamp) < expiry;
  }

  /// Memory cleanup utilities
  static void clearMemoryCache([String? specificKey]) {
    if (specificKey != null) {
      _memoryCache.remove(specificKey);
      _cacheTimestamps.remove(specificKey);
    } else {
      _memoryCache.clear();
      _cacheTimestamps.clear();
    }
  }

  static void cleanupExpiredCache() {
    final expiredKeys = <String>[];

    for (final entry in _memoryCache.entries) {
      if (entry.value is Map<String, dynamic>) {
        final cacheData = entry.value as Map<String, dynamic>;
        if (!_isCacheValid(cacheData)) {
          expiredKeys.add(entry.key);
        }
      }
    }

    for (final key in expiredKeys) {
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  /// Performance monitoring utilities
  static final Map<String, Stopwatch> _performanceTimers = {};

  static void startTimer(String operation) {
    _performanceTimers[operation] = Stopwatch()..start();
  }

  static int stopTimer(String operation) {
    final timer = _performanceTimers[operation];
    if (timer != null) {
      timer.stop();
      final elapsed = timer.elapsedMilliseconds;
      _performanceTimers.remove(operation);
      debugPrint('⏱️ $operation took ${elapsed}ms');
      return elapsed;
    }
    return 0;
  }

  /// Image caching optimization
  static final Map<String, String> _imageUrlCache = {};

  static String optimizeImageUrl(String? url, {String? fallback}) {
    if (url == null || url.isEmpty) {
      return fallback ?? 'https://via.placeholder.com/150';
    }

    // Cache optimized URLs
    if (_imageUrlCache.containsKey(url)) {
      return _imageUrlCache[url]!;
    }

    String optimizedUrl = url;

    // Add optimization parameters for better performance
    if (!url.contains('placeholder')) {
      optimizedUrl = '$url?w=150&h=150&fit=crop';
    }

    _imageUrlCache[url] = optimizedUrl;
    return optimizedUrl;
  }

  /// Widget key optimization for better rebuild performance
  static const String _keyPrefix = 'perf_';
  static int _keyCounter = 0;

  static Key generateOptimizedKey(String identifier) {
    return Key('$_keyPrefix${identifier}_${++_keyCounter}');
  }

  /// Network request optimization
  static final Map<String, Completer<dynamic>> _pendingRequests = {};

  static Future<T> deduplicateRequest<T>(
    String key,
    Future<T> Function() requestFunction,
  ) async {
    // If same request is already pending, wait for it
    if (_pendingRequests.containsKey(key)) {
      return await _pendingRequests[key]!.future as T;
    }

    // Create new request
    final completer = Completer<T>();
    _pendingRequests[key] = completer as Completer<dynamic>;

    try {
      final result = await requestFunction();
      completer.complete(result);
      return result;
    } catch (error) {
      completer.completeError(error);
      rethrow;
    } finally {
      _pendingRequests.remove(key);
    }
  }

  /// Dispose resources and cleanup
  static void dispose() {
    _debounceTimer?.cancel();
    _memoryCache.clear();
    _cacheTimestamps.clear();
    _performanceTimers.clear();
    _imageUrlCache.clear();
    _pendingRequests.clear();
  }
}
