import 'package:http/http.dart' as http;
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/core/widgets/snackbar/snackbar.dart';
import 'package:pb_hrsystem/services/services_locator.dart';

// Base URL for API endpoints
const String baseUrl = 'https://demo-application-api.flexiflows.co';

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
      showSnackBar('Failed to load data. Status Code: ${response.statusCode}. Message: ${response.body}');
      return null;
    }
  } catch (e) {
    showSnackBar('Network Error: $e');
    return null;
  }
}
