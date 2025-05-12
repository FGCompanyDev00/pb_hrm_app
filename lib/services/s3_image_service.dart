import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

// Helper class for queued requests
class _PendingRequest {
  final String url;
  final Map<String, String>? headers;
  final Completer<FileServiceResponse> completer;

  _PendingRequest(this.url, this.headers, this.completer);
}

/// A custom HTTP file service that adds necessary headers for S3 authentication
class S3HttpFileService implements FileService {
  final http.Client _httpClient;
  final int _maxConcurrentFetches = 4; // Limit concurrent downloads
  final Map<String, Completer<FileServiceResponse>> _activeRequests = {};
  int _activeRequestCount = 0;
  final List<_PendingRequest> _requestQueue = [];

  // Cache of recently checked URLs to prevent redundant expiry checks
  final Map<String, DateTime> _expiryCheckCache = {};
  final Duration _expiryCheckCacheDuration = Duration(minutes: 5);

  // Silence all console logs for this service
  final bool _enableLogging = false;

  S3HttpFileService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  @override
  int get concurrentFetches => _maxConcurrentFetches;

  @override
  set concurrentFetches(int value) {
    // Allow call but don't change our fixed limit
  }

  // Log only if logging is enabled
  void _log(String message) {
    if (_enableLogging) {
      debugPrint(message);
    }
  }

  // Process next request from the queue if possible
  void _processQueue() {
    if (_activeRequestCount >= _maxConcurrentFetches || _requestQueue.isEmpty) {
      return;
    }

    final request = _requestQueue.removeAt(0);
    _activeRequests[request.url] = request.completer;
    _activeRequestCount++;

    _executeRequest(request.url, request.headers).then((response) {
      request.completer.complete(response);
      _activeRequestCount--;
      _activeRequests.remove(request.url);
      _processQueue(); // Process next request
    }).catchError((error) {
      request.completer.completeError(error);
      _activeRequestCount--;
      _activeRequests.remove(request.url);
      _processQueue(); // Process next request even on error
    });
  }

  // Check if an S3 URL is expired or will expire soon
  bool _isUrlExpiredOrExpiringSoon(Uri uri) {
    try {
      final url = uri.toString();

      // Check the cache first to avoid redundant expiry checks
      final cachedCheck = _expiryCheckCache[url];
      if (cachedCheck != null &&
          DateTime.now().difference(cachedCheck) < _expiryCheckCacheDuration) {
        // We recently checked this URL and it was valid
        return false;
      }

      // Check if the URL is a pre-signed AWS S3 URL
      // It should have the X-Amz-Date and X-Amz-Expires parameters
      final dateParam = uri.queryParameters['X-Amz-Date'];
      final expiresParam = uri.queryParameters['X-Amz-Expires'];

      if (dateParam != null && expiresParam != null) {
        try {
          // Parse the AWS date format (YYYYMMDDTHHMMSSZ)
          // Format example: 20250501T164815Z
          final year = dateParam.substring(0, 4);
          final month = dateParam.substring(4, 6);
          final day = dateParam.substring(6, 8);
          final hour = dateParam.substring(9, 11);
          final minute = dateParam.substring(11, 13);
          final second = dateParam.substring(13, 15);

          final reqDate =
              DateTime.parse('$year-$month-${day}T$hour:$minute:${second}Z');

          final expiresSeconds = int.parse(expiresParam);
          final expiryTime = reqDate.add(Duration(seconds: expiresSeconds));

          // Get current time in UTC to match AWS timestamps
          final now = DateTime.now().toUtc();

          // Check if already expired
          if (now.isAfter(expiryTime)) {
            _log('S3 URL expired at ${expiryTime.toIso8601String()}');
            return true;
          }

          // Check if will expire soon (within 15 minutes)
          // This gives us a buffer to refresh before it actually expires
          if (now.add(const Duration(minutes: 15)).isAfter(expiryTime)) {
            _log('S3 URL will expire soon at ${expiryTime.toIso8601String()}');
            return true;
          }

          // URL is valid and not expiring soon, cache this result
          _expiryCheckCache[url] = DateTime.now();
          return false;
        } catch (parseError) {
          // If we can't parse the date or expires, assume it might be expired
          _log('Error parsing S3 pre-signed URL date parameters: $parseError');
          return true;
        }
      }

      // If there are no AWS parameters, it's either not a pre-signed URL
      // or it's an S3 URL without auth parameters which will likely fail
      if (url.contains('s3.ap-southeast-1.amazonaws.com') &&
          (dateParam == null || expiresParam == null)) {
        _log('S3 URL missing required auth parameters');
        return true;
      }

      return false;
    } catch (e) {
      _log('Error checking URL expiry: $e');
      // On error, assume it might be expired to be safe
      return true;
    }
  }

  // Internal method to execute the actual request
  Future<FileServiceResponse> _executeRequest(
      String url, Map<String, String>? headers) async {
    try {
      // Check for basic URL validity
      final uri = Uri.tryParse(url);
      if (uri == null) {
        throw HttpExceptionWithStatus(
          400,
          'Invalid URL format',
          uri: Uri.parse('https://invalid.url'),
        );
      }

      // Check if this is an S3 URL (handle both demo and production buckets)
      if (url.contains('s3.ap-southeast-1.amazonaws.com')) {
        // Check if URL has expired or will expire soon
        bool isLikelyExpired = _isUrlExpiredOrExpiringSoon(uri);

        // Create custom headers with S3 specific requirements
        final s3Headers = {
          'Accept': '*/*',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
          'Pragma': 'no-cache',
          // Important: AWS pre-signed URLs must have their Authorization header preserved
          // DO NOT add a custom Authorization header as it will override the signed URL
        };

        // Merge with any existing headers
        if (headers != null) {
          s3Headers.addAll(headers);
        }

        // If the URL is likely expired, we should not attempt the request
        if (isLikelyExpired) {
          // Instead of making a request that will fail, return a failed response directly
          throw HttpExceptionWithStatus(
            403,
            'S3 pre-signed URL has expired and needs to be refreshed',
            uri: uri,
          );
        }

        // For S3 URLs, add a timeout to prevent hanging
        try {
          final response = await _httpClient
              .get(uri, headers: s3Headers)
              .timeout(const Duration(seconds: 15));
          return _handleResponse(response);
        } on TimeoutException {
          throw HttpExceptionWithStatus(
            408, // Request Timeout
            'Request to S3 timed out',
            uri: uri,
          );
        }
      }

      // For non-S3 URLs, use a standard implementation
      final response = await _httpClient.get(Uri.parse(url), headers: headers);
      return _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  // Helper to create a shorter URL for logging purposes
  String _getShortUrlForLogging(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      // Just return the filename part for logging
      final fileName = path.split('/').last;
      return 'S3 image: $fileName';
    } catch (_) {
      return 'S3 image URL';
    }
  }

  @override
  Future<FileServiceResponse> get(String url,
      {Map<String, String>? headers}) async {
    // Check if this request is already in progress
    if (_activeRequests.containsKey(url)) {
      return _activeRequests[url]!.future;
    }

    // Create a new completer for this request
    final completer = Completer<FileServiceResponse>();

    // Check if we can execute immediately or need to queue
    if (_activeRequestCount < _maxConcurrentFetches) {
      _activeRequests[url] = completer;
      _activeRequestCount++;

      _executeRequest(url, headers).then((response) {
        completer.complete(response);
        _activeRequestCount--;
        _activeRequests.remove(url);
        _processQueue(); // Process next request if any
      }).catchError((error) {
        completer.completeError(error);
        _activeRequestCount--;
        _activeRequests.remove(url);
        _processQueue(); // Process next request even on error
      });
    } else {
      // Queue the request for later processing
      _requestQueue.add(_PendingRequest(url, headers, completer));
    }

    return completer.future;
  }

  FileServiceResponse _handleResponse(http.Response response) {
    if (response.statusCode == 200) {
      return HttpGetResponse(response);
    }

    // Handle common S3 errors
    switch (response.statusCode) {
      case 403:
        throw HttpExceptionWithStatus(
          403,
          'Access denied to S3 image. Authentication failed or URL expired.',
          uri: response.request?.url,
        );
      case 404:
        throw HttpExceptionWithStatus(
          404,
          'S3 image not found',
          uri: response.request?.url,
        );
      default:
        throw HttpExceptionWithStatus(
          response.statusCode,
          'Failed to download S3 image',
          uri: response.request?.url,
        );
    }
  }

  // Properly dispose resources on app shutdown
  void dispose() {
    _httpClient.close();
    _requestQueue.clear();
    _activeRequests.clear();
    _expiryCheckCache.clear();
  }

  // Clean expired entries from the expiry check cache
  void _cleanExpiryCheckCache() {
    final now = DateTime.now();
    _expiryCheckCache.removeWhere((url, timestamp) =>
        now.difference(timestamp) > _expiryCheckCacheDuration);
  }
}

/// A simple response implementation for HTTP responses
class HttpGetResponse implements FileServiceResponse {
  final http.Response _response;

  HttpGetResponse(this._response);

  @override
  Stream<List<int>> get content => Stream.value(_response.bodyBytes);

  @override
  int? get contentLength => _response.contentLength;

  @override
  String get fileExtension {
    final contentType = _response.headers['content-type'];
    if (contentType == null) return ''; // Return empty string instead of null

    // Extract extension from content type
    switch (contentType.split('/').last) {
      case 'jpeg':
      case 'jpg':
        return 'jpg';
      case 'png':
        return 'png';
      case 'gif':
        return 'gif';
      case 'webp':
        return 'webp';
      default:
        return ''; // Return empty string if unknown
    }
  }

  @override
  DateTime get validTill {
    // For S3 pre-signed URLs, we use a shorter validTill time
    // to ensure cache is refreshed more frequently
    final uri = Uri.tryParse(_response.request?.url.toString() ?? '');
    if (uri != null &&
        uri.toString().contains('s3.ap-southeast-1.amazonaws.com')) {
      // For S3 URLs, set a shorter validity period to force refresh
      return DateTime.now().add(const Duration(hours: 12));
    }

    // For regular URLs, use cache-control header if available
    final cacheControl = _response.headers['cache-control'];
    if (cacheControl != null && cacheControl.contains('max-age=')) {
      try {
        final maxAge = int.parse(
          RegExp(r'max-age=(\d+)').firstMatch(cacheControl)?.group(1) ??
              '86400',
        );
        return DateTime.now().add(Duration(seconds: maxAge));
      } catch (_) {
        // Default to one day if parsing fails
        return DateTime.now().add(const Duration(days: 1));
      }
    }

    // Default expiration if no cache control header
    return DateTime.now().add(const Duration(days: 2));
  }

  @override
  String? get eTag => _response.headers['etag'];

  @override
  int get statusCode => _response.statusCode;
}

/// Creates a cache manager specifically optimized for S3 images
CacheManager createS3CacheManager({
  required String key,
  Duration stalePeriod =
      const Duration(hours: 24), // Reduced from 7 days to 24 hours
  int maxNrOfCacheObjects = 50,
}) {
  return CacheManager(
    Config(
      key,
      stalePeriod: stalePeriod,
      maxNrOfCacheObjects: maxNrOfCacheObjects,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: S3HttpFileService(),
    ),
  );
}
