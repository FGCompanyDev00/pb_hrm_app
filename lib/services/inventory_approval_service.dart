import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pb_hrsystem/services/http_service.dart';

/// Inventory approvals API helper
class InventoryApprovalService {
  /// Fetch supervisor waiting approvals
  static Future<List<Map<String, dynamic>>> fetchSupervisorWaitings() async {
    return _fetchApprovals('/api/inventory/supervisor/waitings');
  }

  /// Fetch branch manager waiting approvals
  static Future<List<Map<String, dynamic>>> fetchBranchManagerWaitings() async {
    return _fetchApprovals('/api/inventory/branches_manager/waitings');
  }

  /// Fetch approvals (in branch / from branch)
  static Future<List<Map<String, dynamic>>> fetchWaitings() async {
    return _fetchApprovals('/api/inventory/waitings');
  }

  /// Internal fetch helper that normalizes response parsing
  static Future<List<Map<String, dynamic>>> _fetchApprovals(String endpoint) async {
    debugPrint('🔍 [InventoryApprovalService] Fetching from endpoint: $endpoint');
    
    final response = await getRequest(endpoint);
    
    if (response == null) {
      debugPrint('⚠️ [InventoryApprovalService] Response is null for endpoint: $endpoint');
      return [];
    }

    debugPrint('🔍 [InventoryApprovalService] Response received:');
    debugPrint('   - Status Code: ${response.statusCode}');
    debugPrint('   - Response Body Length: ${response.body.length}');
    
    try {
      final Map<String, dynamic> data = jsonDecode(response.body);
      debugPrint('🔍 [InventoryApprovalService] JSON decoded successfully');
      debugPrint('   - Data keys: ${data.keys.toList()}');
      debugPrint('   - Status Code (from response): ${data['statusCode']}');
      debugPrint('   - Message: ${data['message']}');
      
      final List<dynamic> results = (data['results'] as List?) ?? <dynamic>[];
      debugPrint('   - Results count: ${results.length}');
      
      if (results.isNotEmpty) {
        debugPrint('   - First result keys: ${(results[0] as Map).keys.toList()}');
      }
      
      final parsedResults = List<Map<String, dynamic>>.from(
        results.map((e) => Map<String, dynamic>.from(e as Map)),
      );
      
      debugPrint('✅ [InventoryApprovalService] Successfully parsed ${parsedResults.length} results');
      return parsedResults;
    } catch (e, stackTrace) {
      debugPrint('❌ [InventoryApprovalService] Error parsing response:');
      debugPrint('   - Error: $e');
      debugPrint('   - StackTrace: $stackTrace');
      debugPrint('   - Response body (first 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
      return [];
    }
  }
}




