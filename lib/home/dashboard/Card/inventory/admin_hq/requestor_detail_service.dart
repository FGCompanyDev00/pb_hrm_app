import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'requestor_detail_constants.dart';

/// Service class for Requestor Detail API calls
/// Handles all HTTP requests with timeout, retry logic, and error handling
class RequestorDetailService {
  static final String _baseUrl = dotenv.env['BASE_URL'] ?? '';
  static final http.Client _httpClient = http.Client();

  /// Get authentication headers
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Make HTTP request with timeout and retry logic
  static Future<http.Response> _makeRequest(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    int retryCount = 0,
  }) async {
    try {
      http.Response response;
      
      // Use appropriate HTTP method
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _httpClient
              .get(uri, headers: headers)
              .timeout(RequestorDetailConstants.requestTimeout);
          break;
        case 'PUT':
          response = await _httpClient
              .put(uri, headers: headers, body: body)
              .timeout(RequestorDetailConstants.requestTimeout);
          break;
        case 'POST':
          response = await _httpClient
              .post(uri, headers: headers, body: body)
              .timeout(RequestorDetailConstants.requestTimeout);
          break;
        default:
          throw UnsupportedError('HTTP method $method not supported');
      }

      // Retry on 5xx errors
      if (response.statusCode >= 500 &&
          retryCount < RequestorDetailConstants.maxRetries) {
        debugPrint(
            '⚠️ [RequestorDetailService] Server error ${response.statusCode}, retrying... (${retryCount + 1}/${RequestorDetailConstants.maxRetries})');
        await Future.delayed(RequestorDetailConstants.retryDelay);
        return _makeRequest(method, uri,
            headers: headers, body: body, retryCount: retryCount + 1);
      }

      return response;
    } on TimeoutException {
      if (retryCount < RequestorDetailConstants.maxRetries) {
        debugPrint(
            '⚠️ [RequestorDetailService] Request timeout, retrying... (${retryCount + 1}/${RequestorDetailConstants.maxRetries})');
        await Future.delayed(RequestorDetailConstants.retryDelay);
        return _makeRequest(method, uri,
            headers: headers, body: body, retryCount: retryCount + 1);
      }
      rethrow;
    } catch (e) {
      debugPrint('❌ [RequestorDetailService] Request failed: $e');
      rethrow;
    }
  }

  /// Fetch waiting summary for approval source
  static Future<Map<String, dynamic>> fetchWaitingSummary(
      String topicUid) async {
    if (_baseUrl.isEmpty) {
      throw Exception('BASE_URL not configured');
    }

    final headers = await _getHeaders();
    final uri = Uri.parse(
        '$_baseUrl${RequestorDetailConstants.endpointWaiting}/$topicUid');

    debugPrint(
        '🔍 [RequestorDetailService] Fetching waiting summary for topic: $topicUid');

    final response = await _makeRequest('GET', uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to fetch waiting summary: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final results = data['results'];

    if (results is List && results.isNotEmpty) {
      return Map<String, dynamic>.from(results.first);
    } else if (results is Map<String, dynamic>) {
      return Map<String, dynamic>.from(results);
    }

    throw Exception('Waiting summary response empty');
  }

  /// Fetch request details
  static Future<Map<String, dynamic>> fetchRequestDetails(
    String topicUid,
    bool isApprovalSource,
  ) async {
    if (_baseUrl.isEmpty) {
      throw Exception('BASE_URL not configured');
    }

    final headers = await _getHeaders();
    final endpoint = isApprovalSource
        ? '$_baseUrl${RequestorDetailConstants.endpointRequestTopic}/$topicUid'
        : '$_baseUrl${RequestorDetailConstants.endpointMyRequestTopicDetail}/$topicUid';
    final uri = Uri.parse(endpoint);

    debugPrint(
        '🔍 [RequestorDetailService] Fetching request details for topic: $topicUid (approval: $isApprovalSource)');

    final response = await _makeRequest('GET', uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch request details: ${response.statusCode}');
    }

    return jsonDecode(response.body);
  }

  /// Receive item
  static Future<void> receiveItem(String topicUid) async {
    if (_baseUrl.isEmpty) {
      throw Exception('BASE_URL not configured');
    }

    final headers = await _getHeaders();
    final uri = Uri.parse(
        '$_baseUrl${RequestorDetailConstants.endpointReceived}/$topicUid');

    debugPrint(
        '🔍 [RequestorDetailService] Receiving item for topic: $topicUid');

    final response = await _makeRequest('PUT', uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to receive item: ${response.statusCode}');
    }
  }

  /// Approve request
  static Future<void> approveRequest(String topicUid, String comment) async {
    if (_baseUrl.isEmpty) {
      throw Exception('BASE_URL not configured');
    }

    final headers = await _getHeaders();
    final uri = Uri.parse(
        '$_baseUrl${RequestorDetailConstants.endpointRequestWaiting}/$topicUid');

    debugPrint(
        '🔍 [RequestorDetailService] Approving request for topic: $topicUid');

    final body = jsonEncode({'comment': comment.trim()});
    final response =
        await _makeRequest('PUT', uri, headers: headers, body: body);

    if (response.statusCode != 200 && response.statusCode != 201) {
      // Parse error message from response
      String errorMessage =
          'Cannot approve request. Please contact IT department.';
      try {
        final responseData = jsonDecode(response.body);
        errorMessage = responseData['message'] ??
            responseData['error'] ??
            responseData['detail'] ??
            errorMessage;
      } catch (e) {
        // Use default message
      }
      throw Exception(errorMessage);
    }
  }

  /// Decline request
  static Future<void> declineRequest(String topicUid, String comment) async {
    if (_baseUrl.isEmpty) {
      throw Exception('BASE_URL not configured');
    }

    final headers = await _getHeaders();
    final uri = Uri.parse(
        '$_baseUrl${RequestorDetailConstants.endpointDecline}/$topicUid');

    debugPrint(
        '🔍 [RequestorDetailService] Declining request for topic: $topicUid');

    final body = jsonEncode({'comment': comment.trim()});
    final response =
        await _makeRequest('PUT', uri, headers: headers, body: body);

    if (response.statusCode != 200 && response.statusCode != 201) {
      // Parse error message from response
      String errorMessage =
          'Cannot decline request. Please contact IT department.';
      try {
        final responseData = jsonDecode(response.body);
        errorMessage = responseData['message'] ??
            responseData['error'] ??
            responseData['detail'] ??
            errorMessage;
      } catch (e) {
        // Use default message
      }
      throw Exception(errorMessage);
    }
  }

  /// Update request
  static Future<void> updateRequest(
    String topicUid,
    String title,
    List<Map<String, dynamic>> details,
  ) async {
    if (_baseUrl.isEmpty) {
      throw Exception('BASE_URL not configured');
    }

    final headers = await _getHeaders();
    final uri = Uri.parse(
        '$_baseUrl${RequestorDetailConstants.endpointRequestTopic}/$topicUid');

    debugPrint(
        '🔍 [RequestorDetailService] Updating request for topic: $topicUid');

    final body = jsonEncode({
      'title': title.trim(),
      'details': details,
      'confirmed': 0,
    });

    final response =
        await _makeRequest('PUT', uri, headers: headers, body: body);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to update request: ${response.statusCode}');
    }
  }

  /// Cancel request
  static Future<void> cancelRequest(String topicUid, String comment) async {
    if (_baseUrl.isEmpty) {
      throw Exception('BASE_URL not configured');
    }

    final headers = await _getHeaders();
    final uri = Uri.parse(
        '$_baseUrl${RequestorDetailConstants.endpointRequestCancel}/$topicUid');

    debugPrint(
        '🔍 [RequestorDetailService] Cancelling request for topic: $topicUid');

    final body = jsonEncode({'comment': comment.trim()});
    final response =
        await _makeRequest('PUT', uri, headers: headers, body: body);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to cancel request: ${response.statusCode}');
    }
  }

  /// Fetch feedback list
  static Future<List<Map<String, dynamic>>> fetchFeedbackList(
      String topicUid) async {
    if (_baseUrl.isEmpty) {
      return [];
    }

    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(
          '$_baseUrl${RequestorDetailConstants.endpointRequestReply}/$topicUid');

      debugPrint(
          '🔍 [RequestorDetailService] Fetching feedback for topic: $topicUid');

      final response = await _makeRequest('GET', uri, headers: headers);

      if (response.statusCode != 200) {
        return [];
      }

      final decoded = jsonDecode(response.body);
      final List<dynamic> feedbackList =
          (decoded is List) ? decoded : (decoded['results'] ?? []);

      return feedbackList
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('❌ [RequestorDetailService] Feedback fetch error: $e');
      return [];
    }
  }

  /// Dispose HTTP client (call when app closes)
  static void dispose() {
    _httpClient.close();
  }
}
