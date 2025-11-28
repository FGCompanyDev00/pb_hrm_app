import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/core/widgets/snackbar/snackbar.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:pb_hrsystem/core/utils/auth_utils.dart';

// Base URL for API endpoints
String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

/// Helper method to handle HTTP GET requests with error handling
Future<http.Response?> getRequest(String endpoint) async {
  // Add debugging for inventory endpoints
  final isInventoryEndpoint = endpoint.contains('/inventory/');
  if (isInventoryEndpoint) {
    debugPrint('🔍 [HttpService] GET Request for inventory endpoint');
    debugPrint('   - Endpoint: $endpoint');
    debugPrint('   - Full URL: $baseUrl$endpoint');
  }
  
  final token = sl<UserPreferences>().getToken();
  
  if (isInventoryEndpoint) {
    debugPrint('   - Token available: ${token != null && token.isNotEmpty}');
  }

  // Use centralized auth validation with redirect
  if (!await AuthUtils.validateTokenAndRedirect(token)) {
    if (isInventoryEndpoint) {
      debugPrint('❌ [HttpService] Token validation failed');
    }
    return null;
  }

  try {
    if (isInventoryEndpoint) {
      debugPrint('   - Sending GET request...');
    }
    
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    if (isInventoryEndpoint) {
      debugPrint('   - Response received');
      debugPrint('   - Status Code: ${response.statusCode}');
      debugPrint('   - Response Body Length: ${response.body.length}');
    }
    
    if (response.statusCode == 200) {
      if (isInventoryEndpoint) {
        debugPrint('✅ [HttpService] Request successful (200)');
      }
      return response;
    } else {
      if (isInventoryEndpoint) {
        debugPrint('❌ [HttpService] Request failed with status: ${response.statusCode}');
        debugPrint('   - Response body (first 200 chars): ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
      }
      
      // Only show snackbar for non-connection related errors
      if (response.statusCode != 503 && response.statusCode != 504) {
        showSnackBar(
            'We\'re unable to process your request at the moment. Please contact IT support for assistance.');
      }
      return null;
    }
  } catch (e, stackTrace) {
    if (isInventoryEndpoint) {
      debugPrint('❌ [HttpService] Exception occurred:');
      debugPrint('   - Error: $e');
      debugPrint('   - StackTrace: $stackTrace');
    }
    
    // Silently handle connection errors
    if (e.toString().contains('SocketException') ||
        e.toString().contains('Failed host lookup')) {
      if (isInventoryEndpoint) {
        debugPrint('   - Connection error (silently handled)');
      }
      return null;
    }

    // For other errors, show snackbar
    showSnackBar('Network error occurred. Please check your connection.');
    return null;
  }
}
