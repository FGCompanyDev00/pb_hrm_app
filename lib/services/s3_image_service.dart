import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

/// A custom HTTP file service that adds necessary headers for S3 authentication
class S3HttpFileService implements FileService {
  final http.Client _httpClient;

  S3HttpFileService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  @override
  int get concurrentFetches => 10; // Default value for concurrent downloads

  @override
  set concurrentFetches(int value) {
    // This is a no-op as we're using standard http client
    // If needed, we could implement a queue system here
  }

  @override
  Future<FileServiceResponse> get(String url,
      {Map<String, String>? headers}) async {
    try {
      // Check if this is an S3 URL (handle both demo and production buckets)
      if (url.contains('s3.ap-southeast-1.amazonaws.com')) {
        // Create custom headers with S3 specific requirements
        final s3Headers = {
          'Accept': '*/*',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
          'Pragma': 'no-cache',
          // Add any additional headers needed for S3 auth
        };

        // Merge with any existing headers
        if (headers != null) {
          s3Headers.addAll(headers);
        }

        // Use the merged headers for the request
        final response =
            await _httpClient.get(Uri.parse(url), headers: s3Headers);
        return _handleResponse(response, url);
      }

      // For non-S3 URLs, use a standard implementation
      final response = await _httpClient.get(Uri.parse(url), headers: headers);
      return _handleResponse(response, url);
    } catch (e) {
      debugPrint('S3HttpFileService error: $e for URL: $url');
      rethrow;
    }
  }

  FileServiceResponse _handleResponse(http.Response response, String url) {
    if (response.statusCode == 200) {
      return HttpGetResponse(response);
    }

    // Log error for better debugging
    debugPrint('S3 image request failed: ${response.statusCode} for $url');
    debugPrint('Response body: ${response.body}');
    debugPrint('Response headers: ${response.headers}');

    // Handle common S3 errors
    switch (response.statusCode) {
      case 403:
        throw HttpExceptionWithStatus(
          403,
          'Access denied to S3 image. Authentication failed. URL: $url',
          uri: Uri.parse(url),
        );
      case 404:
        throw HttpExceptionWithStatus(
          404,
          'S3 image not found',
          uri: Uri.parse(url),
        );
      default:
        throw HttpExceptionWithStatus(
          response.statusCode,
          'Failed to download S3 image',
          uri: Uri.parse(url),
        );
    }
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
    return DateTime.now().add(const Duration(days: 7));
  }

  @override
  String? get eTag => _response.headers['etag'];

  @override
  int get statusCode => _response.statusCode;
}

/// Creates a cache manager specifically optimized for S3 images
CacheManager createS3CacheManager({
  required String key,
  Duration stalePeriod = const Duration(days: 7),
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
