import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Utility class for image handling throughout the app
class ImageUtils {
  /// Processes an image URL to ensure it has proper format
  /// Returns the processed URL or null if the input is invalid
  static String? processImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return null;
    }

    // If already a valid URL, return as is
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    // Try to make a valid URL using the base URL from environment
    final String baseUrl = dotenv.env['BASE_URL'] ?? '';
    if (baseUrl.isEmpty) {
      debugPrint('Base URL is empty, cannot process image URL: $url');
      return null;
    }

    // Construct proper URL
    final String separator = baseUrl.endsWith('/') ? '' : '/';
    final String processedUrl = url.startsWith('/')
        ? '$baseUrl${url.substring(1)}'
        : '$baseUrl$separator$url';

    debugPrint('Processed image URL: $url -> $processedUrl');
    return processedUrl;
  }

  /// Checks if an image URL is valid
  static bool isValidImageUrl(String? url) {
    return url != null &&
        url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'));
  }

  /// Clears the image cache
  static void clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    debugPrint('Image cache cleared');
  }
}
