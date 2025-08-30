import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle user role checking and authentication
class UserRoleService {
  static final String _baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';
  
  /// Get the current user's roles from the API
  static Future<List<String>> getCurrentUserRoles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      debugPrint('🔍 [UserRoleService] Checking user roles...');
      debugPrint('🔍 [UserRoleService] Token: ${token?.substring(0, 20)}...');
      debugPrint('🔍 [UserRoleService] Base URL: $_baseUrl');
      
      if (token == null) {
        debugPrint('❌ [UserRoleService] No authentication token found');
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/display/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('🔍 [UserRoleService] API Response Status: ${response.statusCode}');
      debugPrint('🔍 [UserRoleService] API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
                if (data['results'] != null && data['results'].isNotEmpty) {
          final userData = data['results'][0];
          final rolesString = userData['roles'] ?? '';
          
          debugPrint('🔍 [UserRoleService] User Data: $userData');
          debugPrint('🔍 [UserRoleService] Roles String: "$rolesString"');
          
          if (rolesString.isNotEmpty) {
            final roles = rolesString.split(',').map((role) => role.trim()).toList();
            debugPrint('🔍 [UserRoleService] Parsed Roles: $roles');
            
            // Check for AdminHQ role with case-insensitive comparison
            final hasAdminHQ = roles.any((role) => role.toLowerCase() == 'adminhq');
            debugPrint('🔍 [UserRoleService] Has AdminHQ (case-insensitive): $hasAdminHQ');
            
            // Check for exact match
            final hasAdminHQExact = roles.contains('AdminHQ');
            debugPrint('🔍 [UserRoleService] Has AdminHQ (exact): $hasAdminHQExact');
            
            // Convert List<dynamic> to List<String> to fix type casting issue
            final stringRoles = roles.cast<String>();
            debugPrint('🔍 [UserRoleService] Converted to List<String>: $stringRoles');
            
            return stringRoles;
          }
        }
        debugPrint('⚠️ [UserRoleService] No results or empty roles');
        return [];
      } else {
        debugPrint('❌ [UserRoleService] Failed to fetch user roles: ${response.statusCode}');
        throw Exception('Failed to fetch user roles: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [UserRoleService] Error fetching user roles: $e');
      throw Exception('Error fetching user roles: $e');
    }
  }

  /// Check if the current user has a specific role
  static Future<bool> hasRole(String role) async {
    try {
      final roles = await getCurrentUserRoles();
      return roles.contains(role);
    } catch (e) {
      return false;
    }
  }

  /// Check if the current user has AdminHQ role
  static Future<bool> isAdminHQ() async {
    try {
      debugPrint('🔍 [UserRoleService] Checking if user is AdminHQ...');
      final roles = await getCurrentUserRoles();
      
      // Check for AdminHQ role with case-insensitive comparison
      final isAdminHQ = roles.any((role) => role.toLowerCase() == 'adminhq');
      
      debugPrint('🔍 [UserRoleService] User roles: $roles');
      debugPrint('🔍 [UserRoleService] Is AdminHQ (case-insensitive): $isAdminHQ');
      
      return isAdminHQ;
    } catch (e) {
      debugPrint('❌ [UserRoleService] Error checking AdminHQ role: $e');
      return false;
    }
  }

  /// Get the current user's ID
  static Future<String?> getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        return null;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/display/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['id'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
