import 'package:http/http.dart' as http;
import 'package:pb_hrsystem/core/widgets/snackbar/snackbar.dart';
import 'package:pb_hrsystem/services/navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Base URL for API endpoints
const String baseUrl = 'https://demo-application-api.flexiflows.co';

/// Retrieves the authentication token from SharedPreferences
Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('token');
}

/// Helper method to handle HTTP GET requests with error handling
Future<http.Response?> getRequest(String endpoint) async {
  final token = await getToken();
  if (token == null) {
    if (NavigationService.ctx!.mounted) showSnackBar('Authentication Error: Token is null. Please log in again.');
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
