import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/core/widgets/snackbar/snackbar.dart';
import 'package:pb_hrsystem/services/services_locator.dart';

// Base URL for API endpoints
String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

/// Helper method to handle HTTP GET requests with error handling
Future<http.Response?> getRequest(String endpoint) async {
  final token = sl<UserPreferences>().getToken();
  if (token == null) {
    showSnackBar('Authentication Error: Token is null. Please log in again.');
    return null;
  }

  try {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return response;
    } else {
      // Only show snackbar for non-connection related errors
      if (response.statusCode != 503 && response.statusCode != 504) {
        showSnackBar(
            'We\'re unable to process your request at the moment. Please contact IT support for assistance.');
      }
      return null;
    }
  } catch (e) {
    // Silently handle connection errors
    if (e.toString().contains('SocketException') ||
        e.toString().contains('Failed host lookup')) {
      return null;
    }

    // For other errors, show snackbar
    showSnackBar('Network error occurred. Please check your connection.');
    return null;
  }
}
