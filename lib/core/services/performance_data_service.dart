import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/core/services/performance_cache_service.dart';
import 'package:pb_hrsystem/core/utils/auth_utils.dart';

/// High-performance data service with optimized API calls and background processing
class PerformanceDataService {
  static final String _baseUrl =
      dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  // Connection timeout and retry configuration
  static const Duration _timeout = Duration(seconds: 15);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // Throttling configuration to prevent API overload
  static final Map<String, DateTime> _lastRequestTimes = {};
  static const Duration _minRequestInterval = Duration(milliseconds: 500);

  /// Optimized HTTP client with connection pooling
  static late http.Client _httpClient;

  static void initialize() {
    _httpClient = http.Client();
  }

  static void dispose() {
    _httpClient.close();
  }

  /// Enhanced HTTP request with retry logic and throttling
  static Future<http.Response?> _makeRequest(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    try {
      // Request throttling
      final now = DateTime.now();
      final lastRequest = _lastRequestTimes[endpoint];
      if (lastRequest != null &&
          now.difference(lastRequest) < _minRequestInterval) {
        await Future.delayed(_minRequestInterval - now.difference(lastRequest));
      }
      _lastRequestTimes[endpoint] = DateTime.now();

      // Get authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (!await AuthUtils.validateTokenAndRedirect(token)) {
        throw Exception('Authentication failed');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

      final url = Uri.parse('$_baseUrl$endpoint');

      // Retry logic with exponential backoff
      for (int attempt = 0; attempt < _maxRetries; attempt++) {
        try {
          http.Response response;

          switch (method.toUpperCase()) {
            case 'GET':
              response = await _httpClient
                  .get(url, headers: headers)
                  .timeout(_timeout);
              break;
            case 'POST':
              response = await _httpClient
                  .post(
                    url,
                    headers: headers,
                    body: body != null ? jsonEncode(body) : null,
                  )
                  .timeout(_timeout);
              break;
            default:
              throw UnsupportedError('HTTP method $method not supported');
          }

          if (response.statusCode >= 200 && response.statusCode < 300) {
            return response;
          } else if (response.statusCode == 401) {
            // Token expired, don't retry
            throw Exception('Authentication failed');
          } else if (attempt == _maxRetries - 1) {
            throw Exception(
                'HTTP ${response.statusCode}: ${response.reasonPhrase}');
          }
        } catch (e) {
          if (attempt == _maxRetries - 1) rethrow;

          // Exponential backoff
          final delay = Duration(
            milliseconds: _retryDelay.inMilliseconds * (1 << attempt),
          );
          await Future.delayed(delay);
        }
      }

      return null;
    } catch (e) {
      debugPrint('Request error for $endpoint: $e');
      rethrow;
    }
  }

  /// Batch API requests for better performance
  static Future<List<http.Response?>> batchRequests(
      List<String> endpoints) async {
    final futures = endpoints.map((endpoint) => _makeRequest(endpoint));
    return await Future.wait(futures);
  }

  /// Process large data sets in isolate to avoid blocking UI
  static Future<List<Map<String, dynamic>>> processDataInBackground(
    List<dynamic> rawData,
    Map<String, dynamic> processingParams,
  ) async {
    return await compute(_processDataIsolate, {
      'data': rawData,
      'params': processingParams,
    });
  }

  /// Isolate function for data processing
  static List<Map<String, dynamic>> _processDataIsolate(
      Map<String, dynamic> input) {
    final rawData = input['data'] as List<dynamic>;
    final params = input['params'] as Map<String, dynamic>;
    final currentUserId = params['currentUserId'] as String?;
    final filterType = params['filterType'] as String?;

    final processedData = <Map<String, dynamic>>[];

    for (final item in rawData) {
      if (item is Map<String, dynamic>) {
        // Apply filtering logic
        if (filterType == 'current_user' && currentUserId != null) {
          final itemUserId =
              _extractUserId(item, params['itemType'] as String?);
          if (itemUserId != currentUserId) continue;
        }

        // Process and format item
        final processedItem = _formatItem(item, params);
        if (processedItem.isNotEmpty) {
          processedData.add(processedItem);
        }
      }
    }

    // Sort by updated_at if available
    processedData.sort((a, b) {
      final aDate = DateTime.tryParse(a['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(b['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return processedData;
  }

  /// Extract user ID based on item type
  static String _extractUserId(Map<String, dynamic> item, String? itemType) {
    switch (itemType?.toLowerCase()) {
      case 'car':
        return item['requestor_id']?.toString() ?? '';
      case 'minutes of meeting':
        return item['created_by']?.toString() ?? '';
      default:
        return item['employee_id']?.toString() ?? '';
    }
  }

  /// Format item for consistent structure
  static Map<String, dynamic> _formatItem(
      Map<String, dynamic> item, Map<String, dynamic> params) {
    final itemType = item['types']?.toString().toLowerCase() ?? 'unknown';
    final leaveTypes = params['leaveTypes'] as Map<int, String>? ?? {};

    final formattedItem = <String, dynamic>{
      'id': item['uid']?.toString() ?? item['outmeeting_uid']?.toString() ?? '',
      'type': itemType,
      'status': (item['status']?.toString() ?? 'pending').toLowerCase(),
      'updated_at': item['updated_at']?.toString() ?? '',
      'img_name':
          item['img_name']?.toString() ?? 'https://via.placeholder.com/150',
      'img_path': item['img_path']?.toString() ?? '',
    };

    // Type-specific formatting
    switch (itemType) {
      case 'meeting':
        formattedItem.addAll({
          'title': item['title']?.toString() ?? 'No Title',
          'startDate': item['from_date_time']?.toString() ?? '',
          'endDate': item['to_date_time']?.toString() ?? '',
          'room': item['room_name']?.toString() ?? 'No Room',
          'employee_name': item['employee_name']?.toString() ?? 'N/A',
          'remark': item['remark']?.toString() ?? '',
        });
        break;

      case 'leave':
        final leaveTypeId = item['leave_type_id'] as int? ?? 0;
        formattedItem.addAll({
          'title': item['name']?.toString() ?? 'No Title',
          'startDate': item['take_leave_from']?.toString() ?? '',
          'endDate': item['take_leave_to']?.toString() ?? '',
          'leave_type': leaveTypes[leaveTypeId] ?? 'Unknown',
        });
        break;

      case 'car':
        formattedItem.addAll({
          'title': item['purpose']?.toString() ?? 'No Purpose',
          'startDate': _combineDatetime(item['date_out'], item['time_out']),
          'endDate': _combineDatetime(item['date_in'], item['time_in']),
          'place': item['place']?.toString() ?? 'N/A',
          'employee_name': item['requestor_name']?.toString() ?? 'N/A',
        });
        break;

      case 'minutes of meeting':
        formattedItem.addAll({
          'title': item['title']?.toString() ?? 'No Title',
          'startDate': item['fromdate']?.toString() ?? '',
          'endDate': item['todate']?.toString() ?? '',
          'location': item['location']?.toString() ?? 'No Location',
          'employee_name': item['created_by_name']?.toString() ?? 'N/A',
          'guests': item['guests'] ?? [],
        });
        break;
    }

    return formattedItem;
  }

  /// Combine date and time strings
  static String _combineDatetime(dynamic date, dynamic time) {
    if (date == null || time == null) return '';
    return '${date}T$time:00';
  }

  /// Calendar Events API with smart caching
  static Future<List<Map<String, dynamic>>> fetchCalendarEvents({
    bool forceRefresh = false,
  }) async {
    // Check cache first
    if (!forceRefresh) {
      final cached = await PerformanceCacheService.getCachedCalendarEvents();
      if (cached != null) {
        return List<Map<String, dynamic>>.from(cached);
      }
    }

    try {
      final endpoints = [
        '/api/work-tracking/out-meeting/out-meeting',
        '/api/leave_requests',
        '/api/office-administration/book_meeting_room/my-requests',
        '/api/office-administration/book_meeting_room/invites-meeting',
        '/api/office-administration/car_permits/me',
        '/api/office-administration/car_permits/invites-car-member',
        '/api/work-tracking/meeting/get-all-meeting',
        '/api/work-tracking/out-meeting/outmeeting/my-members',
      ];

      final responses = await batchRequests(endpoints);
      final allEvents = <Map<String, dynamic>>[];

      // Process each response
      for (int i = 0; i < responses.length; i++) {
        final response = responses[i];
        if (response?.statusCode == 200) {
          final data = jsonDecode(response!.body);
          if (data['results'] != null) {
            final events = List<Map<String, dynamic>>.from(data['results']);
            allEvents.addAll(events);
          }
        }
      }

      // Process in background
      final processedEvents = await processDataInBackground(allEvents, {
        'filterType': 'none',
        'itemType': 'calendar',
      });

      // Cache the results
      await PerformanceCacheService.cacheCalendarEvents(processedEvents);

      return processedEvents;
    } catch (e) {
      debugPrint('Error fetching calendar events: $e');
      rethrow;
    }
  }

  /// Notification Data API with smart caching
  static Future<Map<String, dynamic>> fetchNotificationData({
    bool forceRefresh = false,
  }) async {
    // Check cache first
    if (!forceRefresh) {
      final cached = await PerformanceCacheService.getCachedNotificationData();
      if (cached != null) {
        return cached;
      }
    }

    try {
      final endpoints = [
        '/api/office-administration/book_meeting_room/invites-meeting',
        '/api/office-administration/car_permits/invites-car-member',
        '/api/work-tracking/out-meeting/outmeeting/my-members',
        '/api/leave-types',
      ];

      final responses = await batchRequests(endpoints);
      final result = <String, dynamic>{
        'meetingInvites': [],
        'pendingItems': [],
        'historyItems': [],
        'leaveTypes': <int, String>{},
      };

      // Process responses
      for (int i = 0; i < responses.length; i++) {
        final response = responses[i];
        if (response?.statusCode == 200) {
          final data = jsonDecode(response!.body);

          if (endpoints[i].contains('leave-types') && data['results'] != null) {
            final leaveTypesData = data['results'] as List<dynamic>;
            final leaveTypes = <int, String>{};
            for (var item in leaveTypesData) {
              leaveTypes[item['leave_type_id'] as int] =
                  item['name'].toString();
            }
            result['leaveTypes'] = leaveTypes;
          } else if (data['results'] != null) {
            final items = List<Map<String, dynamic>>.from(data['results']);

            if (endpoints[i].contains('invites-meeting')) {
              result['meetingInvites'].addAll(items);
              result['pendingItems'].addAll(items);
            } else if (endpoints[i].contains('invites-car-member')) {
              result['pendingItems'].addAll(items);
            } else if (endpoints[i].contains('my-members')) {
              result['meetingInvites'].addAll(items);
            }
          }
        }
      }

      // Process data in background
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('employee_id');

      final processingParams = {
        'currentUserId': currentUserId,
        'filterType': 'invitations_only',
        'leaveTypes': result['leaveTypes'],
      };

      if (result['meetingInvites'].isNotEmpty) {
        result['meetingInvites'] = await processDataInBackground(
          result['meetingInvites'],
          processingParams,
        );
      }

      if (result['pendingItems'].isNotEmpty) {
        result['pendingItems'] = await processDataInBackground(
          result['pendingItems'],
          processingParams,
        );
      }

      // Cache the results
      await PerformanceCacheService.cacheNotificationData(result);

      return result;
    } catch (e) {
      debugPrint('Error fetching notification data: $e');
      rethrow;
    }
  }

  /// History Data API with smart caching
  static Future<Map<String, dynamic>> fetchHistoryData({
    bool forceRefresh = false,
  }) async {
    // Check cache first
    if (!forceRefresh) {
      final cached = await PerformanceCacheService.getCachedHistoryData();
      if (cached != null) {
        return cached;
      }
    }

    try {
      final endpoints = [
        '/api/app/users/history/pending',
        '/api/app/users/history',
        '/api/leave-types',
      ];

      final responses = await batchRequests(endpoints);
      final result = <String, dynamic>{
        'pendingItems': [],
        'historyItems': [],
        'leaveTypes': <int, String>{},
      };

      // Process responses
      for (int i = 0; i < responses.length; i++) {
        final response = responses[i];
        if (response?.statusCode == 200) {
          final data = jsonDecode(response!.body);

          if (endpoints[i].contains('leave-types') && data['results'] != null) {
            final leaveTypesData = data['results'] as List<dynamic>;
            final leaveTypes = <int, String>{};
            for (var item in leaveTypesData) {
              leaveTypes[item['leave_type_id'] as int] =
                  item['name'].toString();
            }
            result['leaveTypes'] = leaveTypes;
          } else if (data['results'] != null) {
            final items = List<Map<String, dynamic>>.from(data['results']);

            if (endpoints[i].contains('pending')) {
              result['pendingItems'] = items;
            } else if (endpoints[i].contains('history')) {
              result['historyItems'] = items;
            }
          }
        }
      }

      // Process data in background
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('employee_id');

      final processingParams = {
        'currentUserId': currentUserId,
        'filterType': 'current_user',
        'leaveTypes': result['leaveTypes'],
      };

      if (result['pendingItems'].isNotEmpty) {
        result['pendingItems'] = await processDataInBackground(
          result['pendingItems'],
          processingParams,
        );
      }

      if (result['historyItems'].isNotEmpty) {
        result['historyItems'] = await processDataInBackground(
          result['historyItems'],
          processingParams,
        );
      }

      // Cache the results
      await PerformanceCacheService.cacheHistoryData(result);

      return result;
    } catch (e) {
      debugPrint('Error fetching history data: $e');
      rethrow;
    }
  }

  /// Approvals Data API with smart caching
  static Future<Map<String, dynamic>> fetchApprovalsData({
    bool forceRefresh = false,
  }) async {
    // Check cache first
    if (!forceRefresh) {
      final cached = await PerformanceCacheService.getCachedApprovalsData();
      if (cached != null) {
        return cached;
      }
    }

    // Reuse history data fetching as they use same endpoints
    return await fetchHistoryData(forceRefresh: forceRefresh);
  }

  /// Leave Types API with smart caching
  static Future<Map<int, String>> fetchLeaveTypes({
    bool forceRefresh = false,
  }) async {
    // Check cache first
    if (!forceRefresh) {
      final cached = await PerformanceCacheService.getCachedLeaveTypes();
      if (cached != null) {
        return cached;
      }
    }

    try {
      final response = await _makeRequest('/api/leave-types');

      if (response?.statusCode == 200) {
        final data = jsonDecode(response!.body);
        if (data['results'] != null) {
          final leaveTypesData = data['results'] as List<dynamic>;
          final leaveTypes = <int, String>{};

          for (var item in leaveTypesData) {
            leaveTypes[item['leave_type_id'] as int] = item['name'].toString();
          }

          // Cache the results
          await PerformanceCacheService.cacheLeaveTypes(leaveTypes);

          return leaveTypes;
        }
      }

      return {};
    } catch (e) {
      debugPrint('Error fetching leave types: $e');
      return {};
    }
  }

  /// Cleanup expired cache and optimize memory
  static Future<void> performMaintenanceTasks() async {
    try {
      PerformanceCacheService.clearExpiredMemoryCache();

      // Clear old request timestamps
      final now = DateTime.now();
      _lastRequestTimes.removeWhere(
          (key, value) => now.difference(value) > const Duration(hours: 1));
    } catch (e) {
      debugPrint('Error performing maintenance tasks: $e');
    }
  }
}
