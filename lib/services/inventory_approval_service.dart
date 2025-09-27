import 'dart:convert';
import 'package:pb_hrsystem/services/http_service.dart';

/// Inventory approvals API helper
class InventoryApprovalService {
  /// Fetch supervisor waiting approvals
  static Future<List<Map<String, dynamic>>> fetchSupervisorWaitings() async {
    return _fetchApprovals('/api/inventory/supervisor/waitings');
  }

  /// Fetch approvals (in branch / from branch)
  static Future<List<Map<String, dynamic>>> fetchWaitings() async {
    return _fetchApprovals('/api/inventory/waitings');
  }

  /// Internal fetch helper that normalizes response parsing
  static Future<List<Map<String, dynamic>>> _fetchApprovals(String endpoint) async {
    final response = await getRequest(endpoint);
    if (response == null) {
      return [];
    }

    try {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> results = (data['results'] as List?) ?? <dynamic>[];
      return List<Map<String, dynamic>>.from(
        results.map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } catch (_) {
      return [];
    }
  }
}




