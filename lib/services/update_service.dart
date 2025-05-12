import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:html/parser.dart' as html_parser;
import 'dart:math' as math;
import 'package:flutter_in_store_app_version_checker/flutter_in_store_app_version_checker.dart';

class UpdateService {
  static const String _androidPackageName = 'com.phongsavanh.pb_hrsystem';
  static const String _iosBundleId = 'com.psvsystem.next';
  static const String _iosAppId = '6742818675';

  // Store URLs
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=$_androidPackageName';
  static const String _appStoreUrl =
      'https://apps.apple.com/us/app/psvb-next/id$_iosAppId';

  // Direct app URLs for native app opening
  static const String _appStoreDirectUrl =
      'itms-apps://itunes.apple.com/app/id$_iosAppId';
  static const String _playStoreDirectUrl =
      'market://details?id=$_androidPackageName';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Accept': 'text/html,application/xhtml+xml,application/xml'},
  ));

  /// Check if app needs to be updated by comparing versions
  static Future<bool> needsUpdate() async {
    try {
      // Get current app version
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;
      debugPrint('Current app version: $currentVersion');

      // Get store version using the flutter_in_store_app_version_checker package
      final String storeVersion = await _getStoreVersionWithPackage();
      debugPrint('Store version (from package): $storeVersion');

      // If package fails, try the fallback method
      if (storeVersion.isEmpty) {
        final String fallbackVersion = await _getStoreVersion();
        debugPrint('Store version (fallback method): $fallbackVersion');

        if (fallbackVersion.isEmpty) {
          return false; // If we can't get store version, don't force update
        }

        // Compare versions (removing any build number after +)
        final cleanCurrentVersion = currentVersion.split('+')[0];
        final cleanStoreVersion = fallbackVersion.split('+')[0];

        return _isVersionHigher(cleanStoreVersion, cleanCurrentVersion);
      }

      // Compare versions (removing any build number after +)
      final cleanCurrentVersion = currentVersion.split('+')[0];
      final cleanStoreVersion = storeVersion.split('+')[0];

      return _isVersionHigher(cleanStoreVersion, cleanCurrentVersion);
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return false; // In case of error, don't force update
    }
  }

  /// Get store version using the flutter_in_store_app_version_checker package
  static Future<String> _getStoreVersionWithPackage() async {
    try {
      // Create the checker with the correct configuration
      final checker = InStoreAppVersionChecker(
        appId: Platform.isIOS ? _iosAppId : _androidPackageName,
      );

      final response = await checker.checkUpdate();

      debugPrint('App version checker response: ${response.toString()}');

      if (response.newVersion != null && response.newVersion!.isNotEmpty) {
        return response.newVersion!;
      }
    } catch (e) {
      debugPrint('Error using InStoreAppVersionChecker: $e');
    }

    return '';
  }

  /// Determine if version1 is higher than version2
  static bool _isVersionHigher(String version1, String version2) {
    try {
      // Handle empty versions
      if (version1.isEmpty) return false;
      if (version2.isEmpty) return true;

      // Clean versions - remove any non-numeric/dot characters
      final cleanV1 = version1.replaceAll(RegExp(r'[^\d.]'), '');
      final cleanV2 = version2.replaceAll(RegExp(r'[^\d.]'), '');

      // Handle invalid versions after cleaning
      if (cleanV1.isEmpty) return false;
      if (cleanV2.isEmpty) return true;

      // Split versions into parts
      List<int> v1Parts =
          cleanV1.split('.').map((part) => int.tryParse(part) ?? 0).toList();
      List<int> v2Parts =
          cleanV2.split('.').map((part) => int.tryParse(part) ?? 0).toList();

      // Make sure both lists have the same length
      final maxLength = math.max(v1Parts.length, v2Parts.length);
      while (v1Parts.length < maxLength) {
        v1Parts.add(0);
      }
      while (v2Parts.length < maxLength) {
        v2Parts.add(0);
      }

      // Compare each part
      for (int i = 0; i < maxLength; i++) {
        if (v1Parts[i] > v2Parts[i]) return true;
        if (v1Parts[i] < v2Parts[i]) return false;
      }

      // Return false if versions are identical
      return false;
    } catch (e) {
      debugPrint('Error comparing versions: $e');
      return false; // On error, don't force update
    }
  }

  /// Get the latest version from the appropriate store
  static Future<String> _getStoreVersion() async {
    if (Platform.isAndroid) {
      return await _getPlayStoreVersion();
    } else if (Platform.isIOS) {
      return await _getAppStoreVersion();
    }
    return '';
  }

  /// Get the latest version from Google Play Store
  static Future<String> _getPlayStoreVersion() async {
    try {
      // First attempt: Use the flutter_in_store_app_version_checker package
      try {
        final checker = InStoreAppVersionChecker(
          appId: _androidPackageName,
        );
        final response = await checker.checkUpdate();

        if (response.newVersion != null && response.newVersion!.isNotEmpty) {
          return response.newVersion!;
        }
      } catch (e) {
        debugPrint('Error using InStoreAppVersionChecker for Play Store: $e');
      }

      // Second attempt: Parse the Play Store HTML (original method)
      final response = await _dio.get(_playStoreUrl);

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.data);

        // Method 1: Try to find version in HTML structure
        try {
          final elements = document.querySelectorAll('div.reAt0');

          if (elements.isNotEmpty) {
            // Find the element that contains the version info
            for (var element in elements) {
              final text = element.text;
              if (text.contains('Current Version')) {
                final versionText =
                    elements[elements.indexOf(element) + 1].text;
                return versionText.trim();
              }
            }
          }
        } catch (e) {
          debugPrint('Error with first Play Store parsing method: $e');
        }

        // Method 2: Alternative approach using content description
        try {
          final versionElements =
              document.querySelectorAll('[content="android:versionName"]');
          if (versionElements.isNotEmpty) {
            final versionMeta = versionElements.first;
            final version = versionMeta.attributes['content'];
            if (version != null && version.isNotEmpty) {
              return version;
            }
          }
        } catch (e) {
          debugPrint('Error with second Play Store parsing method: $e');
        }

        // Method 3: Find using regex pattern in entire HTML
        try {
          final html = response.data.toString();
          final RegExp versionRegex =
              RegExp(r'Current Version\s*<\/span><span[^>]*>([\d\.]+)<\/span>');
          final match = versionRegex.firstMatch(html);
          if (match != null && match.groupCount >= 1) {
            return match.group(1) ?? '';
          }
        } catch (e) {
          debugPrint('Error with regex Play Store parsing method: $e');
        }
      }
    } catch (e) {
      debugPrint('Error getting Play Store version: $e');
    }

    // Fallback option: If all else fails, get version from package info
    try {
      // As a last resort, use the local version as fallback
      // (this will prevent forcing updates if we fail to detect store version)
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      debugPrint('Error getting package info: $e');
    }

    return '';
  }

  /// Get the latest version from App Store
  static Future<String> _getAppStoreVersion() async {
    try {
      // First attempt: Use the flutter_in_store_app_version_checker package
      try {
        final checker = InStoreAppVersionChecker(
          appId: _iosAppId,
        );
        final response = await checker.checkUpdate();

        if (response.newVersion != null && response.newVersion!.isNotEmpty) {
          return response.newVersion!;
        }
      } catch (e) {
        debugPrint('Error using InStoreAppVersionChecker for App Store: $e');
      }

      // Second attempt: Use iTunes API directly with app ID
      final response = await _dio.get(
        'https://itunes.apple.com/lookup?id=$_iosAppId',
      );

      if (response.statusCode == 200) {
        // Method 1: Parse as String if needed
        try {
          final data = response.data;
          if (data is String) {
            final Map<String, dynamic> parsed = jsonDecode(data);
            if (parsed['resultCount'] > 0 &&
                parsed['results'] is List &&
                parsed['results'].isNotEmpty) {
              final version = parsed['results'][0]['version'];
              if (version != null) {
                return version.toString();
              }
            }
          }
          // Method 2: Handle as Map directly
          else if (data is Map) {
            final Map<String, dynamic> parsed = Map<String, dynamic>.from(data);
            if (parsed['resultCount'] > 0 &&
                parsed['results'] is List &&
                parsed['results'].isNotEmpty) {
              final version = parsed['results'][0]['version'];
              if (version != null) {
                return version.toString();
              }
            }
          }
        } catch (e) {
          debugPrint('Error parsing iTunes API response: $e');
        }
      }

      // Method 3: Alternate URL format as fallback
      try {
        final altResponse = await _dio.get(
          'https://itunes.apple.com/us/app/psvb-next/id$_iosAppId?mt=8',
        );

        if (altResponse.statusCode == 200) {
          final html = altResponse.data.toString();
          // Look for version pattern in App Store HTML
          final RegExp versionRegex = RegExp(r'Version\s+([\d\.]+)');
          final match = versionRegex.firstMatch(html);
          if (match != null && match.groupCount >= 1) {
            return match.group(1) ?? '';
          }
        }
      } catch (e) {
        debugPrint('Error with alternate App Store lookup: $e');
      }
    } catch (e) {
      debugPrint('Error getting App Store version: $e');
    }

    // Fallback option: If all else fails, get version from package info
    try {
      // As a last resort, use the local version as fallback
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      debugPrint('Error getting package info: $e');
    }

    return '';
  }

  /// Open the store page to update the app
  static Future<void> openStore() async {
    try {
      debugPrint(
          'Attempting to open store for platform: ${Platform.operatingSystem}');

      if (Platform.isAndroid) {
        // For Android devices
        debugPrint('Android platform detected, attempting to open Play Store');

        final Uri marketUri = Uri.parse(_playStoreDirectUrl);

        try {
          // First attempt: Try using market:// protocol
          debugPrint(
              'Trying to launch with market:// URL: $_playStoreDirectUrl');
          final bool canOpen = await canLaunchUrl(marketUri);
          debugPrint('Can launch market:// URL? $canOpen');

          if (canOpen) {
            final bool success = await launchUrl(
              marketUri,
              mode: LaunchMode.externalNonBrowserApplication,
            );
            debugPrint('Launched market:// URL successfully? $success');

            if (!success) throw Exception('Failed to launch market:// URL');
          } else {
            throw Exception('Cannot launch market:// URL');
          }
        } catch (e) {
          // Second attempt: Use https:// URL as fallback
          debugPrint('Error launching market:// URL: $e');
          debugPrint('Trying fallback to https:// URL: $_playStoreUrl');

          final Uri webUri = Uri.parse(_playStoreUrl);
          final bool success = await launchUrl(
            webUri,
            mode: LaunchMode.externalApplication,
          );

          debugPrint('Launched https:// URL successfully? $success');
          if (!success) throw Exception('Failed to launch https:// URL');
        }
      } else if (Platform.isIOS) {
        // For iOS devices
        debugPrint('iOS platform detected, attempting to open App Store');

        // First try the direct iTunes URL scheme
        final Uri appStoreUri = Uri.parse(_appStoreDirectUrl);

        try {
          debugPrint(
              'Trying to launch with itms-apps:// URL: $_appStoreDirectUrl');
          final bool canOpen = await canLaunchUrl(appStoreUri);
          debugPrint('Can launch itms-apps:// URL? $canOpen');

          if (canOpen) {
            final bool success = await launchUrl(
              appStoreUri,
              mode: LaunchMode.externalNonBrowserApplication,
            );
            debugPrint('Launched itms-apps:// URL successfully? $success');

            if (!success) throw Exception('Failed to launch itms-apps:// URL');
          } else {
            throw Exception('Cannot launch itms-apps:// URL');
          }
        } catch (e) {
          // Try alternate URL format
          debugPrint('Error launching itms-apps:// URL: $e');
          debugPrint('Trying alternate URL format');

          // Try other URL formats
          final List<String> urlFormats = [
            'itms-apps://itunes.apple.com/app/id$_iosAppId', // Format without app name
            'itms://itunes.apple.com/app/id$_iosAppId', // Legacy format
            _appStoreUrl, // Web URL
          ];

          bool launched = false;
          for (final url in urlFormats) {
            try {
              debugPrint('Trying URL: $url');
              final Uri uri = Uri.parse(url);

              if (await canLaunchUrl(uri)) {
                final bool success = await launchUrl(
                  uri,
                  mode: url.startsWith('itms')
                      ? LaunchMode.externalNonBrowserApplication
                      : LaunchMode.externalApplication,
                );

                debugPrint('Launch success for $url: $success');

                if (success) {
                  launched = true;
                  break;
                }
              }
            } catch (e) {
              debugPrint('Error trying URL $url: $e');
            }
          }

          if (!launched) {
            throw Exception('Failed to launch any App Store URL');
          }
        }
      } else {
        // For other platforms, just try the web URL
        debugPrint('Non-mobile platform detected, using web URL');

        final Uri webUri =
            Uri.parse(Platform.isAndroid ? _playStoreUrl : _appStoreUrl);

        final bool success = await launchUrl(
          webUri,
          mode: LaunchMode.platformDefault,
        );

        debugPrint('Launched web URL successfully? $success');
      }
    } catch (e) {
      debugPrint('Error opening store: $e');
    }
  }
}
