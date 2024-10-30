import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pb_hrsystem/core/widgets/snackbar/snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Base URL for API endpoints
const String baseUrl = 'https://demo-application-api.flexiflows.co';

/// Retrieves the authentication token from SharedPreferences
Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('token');
}

/// Helper method to handle HTTP GET requests with error handling
Future<http.Response?> getRequest(BuildContext context, String endpoint) async {
  final token = await getToken();
  if (token == null) {
    if (context.mounted) showSnackBar(context, 'Authentication Error: Token is null. Please log in again.');
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
      if (context.mounted) showSnackBar(context, 'Failed to load data. Status Code: ${response.statusCode}. Message: ${response.reasonPhrase}');
      return null;
    }
  } catch (e) {
    if (context.mounted) showSnackBar(context, 'Network Error: $e');
    return null;
  }
}
