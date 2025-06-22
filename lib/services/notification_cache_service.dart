// notification_cache_service.dart
// Smart caching service for notifications with immediate display and background updates

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationCacheService {
  static const String _meetingInvitesKey = 'cached_meeting_invites';
  static const String _pendingItemsKey = 'cached_pending_items';
  static const String _historyItemsKey = 'cached_history_items';
  static const String _leaveTypesKey = 'cached_leave_types';

  // Cache expiry durations
  static const Duration _shortCacheExpiry = Duration(minutes: 5);
  static const Duration _longCacheExpiry = Duration(hours: 24);

  /// Get cached data with timestamp checking
  static Future<T?> getCachedData<T>(
      String key, T Function(Map<String, dynamic>) fromJson,
      {Duration? maxAge}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDataString = prefs.getString(key);

      if (cachedDataString == null) return null;

      final cachedData = jsonDecode(cachedDataString);
      final timestamp = DateTime.parse(cachedData['timestamp']);
      final maxAgeToUse = maxAge ?? _shortCacheExpiry;

      // Check if cache is still valid
      if (DateTime.now().difference(timestamp) > maxAgeToUse) {
        if (kDebugMode) {
          debugPrint('Cache expired for key: $key');
        }
        return null;
      }

      if (kDebugMode) {
        debugPrint('Cache hit for key: $key');
      }

      return fromJson(cachedData['data']);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error retrieving cached data for $key: $e');
      }
      return null;
    }
  }

  /// Cache data with timestamp
  static Future<void> cacheData(String key, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheObject = {
        'timestamp': DateTime.now().toIso8601String(),
        'data': data,
      };

      await prefs.setString(key, jsonEncode(cacheObject));

      if (kDebugMode) {
        debugPrint('Data cached successfully for key: $key');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error caching data for $key: $e');
      }
    }
  }

  /// Get cached meeting invites
  static Future<List<Map<String, dynamic>>?> getCachedMeetingInvites() async {
    return await getCachedData<List<Map<String, dynamic>>>(
      _meetingInvitesKey,
      (data) => List<Map<String, dynamic>>.from(data['meetings'] ?? []),
    );
  }

  /// Cache meeting invites
  static Future<void> cacheMeetingInvites(
      List<Map<String, dynamic>> meetings) async {
    await cacheData(_meetingInvitesKey, {'meetings': meetings});
  }

  /// Get cached pending items
  static Future<List<Map<String, dynamic>>?> getCachedPendingItems() async {
    return await getCachedData<List<Map<String, dynamic>>>(
      _pendingItemsKey,
      (data) => List<Map<String, dynamic>>.from(data['pending'] ?? []),
    );
  }

  /// Cache pending items
  static Future<void> cachePendingItems(
      List<Map<String, dynamic>> pending) async {
    await cacheData(_pendingItemsKey, {'pending': pending});
  }

  /// Get cached history items
  static Future<List<Map<String, dynamic>>?> getCachedHistoryItems() async {
    return await getCachedData<List<Map<String, dynamic>>>(
      _historyItemsKey,
      (data) => List<Map<String, dynamic>>.from(data['history'] ?? []),
    );
  }

  /// Cache history items
  static Future<void> cacheHistoryItems(
      List<Map<String, dynamic>> history) async {
    await cacheData(_historyItemsKey, {'history': history});
  }

  /// Get cached leave types with longer expiry
  static Future<Map<int, String>?> getCachedLeaveTypes() async {
    final result = await getCachedData<Map<int, String>>(
      _leaveTypesKey,
      (data) {
        final Map<String, dynamic> rawMap =
            Map<String, dynamic>.from(data['leaveTypes'] ?? {});
        return rawMap
            .map((key, value) => MapEntry(int.parse(key), value.toString()));
      },
      maxAge: _longCacheExpiry, // Leave types change less frequently
    );
    return result;
  }

  /// Cache leave types
  static Future<void> cacheLeaveTypes(Map<int, String> leaveTypes) async {
    final serializable =
        leaveTypes.map((key, value) => MapEntry(key.toString(), value));
    await cacheData(_leaveTypesKey, {'leaveTypes': serializable});
  }

  /// Clear all cached data
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_meetingInvitesKey),
        prefs.remove(_pendingItemsKey),
        prefs.remove(_historyItemsKey),
        prefs.remove(_leaveTypesKey),
      ]);

      if (kDebugMode) {
        debugPrint('All notification cache cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error clearing cache: $e');
      }
    }
  }

  /// Check if any cached data exists
  static Future<bool> hasCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_meetingInvitesKey) ||
          prefs.containsKey(_pendingItemsKey) ||
          prefs.containsKey(_historyItemsKey);
    } catch (e) {
      return false;
    }
  }
}
