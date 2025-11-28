import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../inventory_app_bar.dart';
import '../widgets/comment_modal.dart';
import '../widgets/success_modal.dart';

/// Requestor Detail page for AdminBR users
/// Displays detailed information about a specific request and allows approval/decline actions
class RequestorDetailPage extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const RequestorDetailPage({
    super.key,
    required this.requestData,
  });

  @override
  State<RequestorDetailPage> createState() => _RequestorDetailPageState();
}

class _RequestorDetailPageState extends State<RequestorDetailPage> {
  Map<String, dynamic> _requestDetails = {};
  List<Map<String, dynamic>> _requestItems = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  bool _isProcessing = false;
  bool _isFeedbackExpanded = false;

  // Base URL for images
  final String _imageBaseUrl = 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/';

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 [RequestorDetailPage] initState called with requestData: ${widget.requestData}');
    _fetchRequestDetails();
  }

  Future<void> _fetchRequestDetails() async {
    setState(() {
      _isLoading = true;
      _isError = false;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final baseUrl = dotenv.env['BASE_URL'] ?? '';
      
      if (token == null || baseUrl.isEmpty) {
        throw Exception('Authentication or BASE_URL not configured');
      }

      final String topicUid = widget.requestData['topic_uniq_id'] ?? 
                       widget.requestData['topicid'] ?? '';
      if (topicUid.isEmpty) {
        throw Exception('No topic UID found in request data');
      }

      debugPrint('🔍 [RequestorDetailPage] Fetching details for topic: $topicUid');

      Map<String, dynamic> waitingSummary = {};
      try {
        waitingSummary = await _fetchWaitingSummary(baseUrl, token, topicUid);
        debugPrint('🔍 [RequestorDetailPage] Waiting summary: $waitingSummary');
      } catch (e) {
        debugPrint('⚠️ [RequestorDetailPage] Waiting summary fetch failed: $e');
      }

      final detailUrl = '$baseUrl/api/inventory/request_topic/$topicUid';
      debugPrint('🔍 [RequestorDetailPage] API URL: $detailUrl');

      final response = await http.get(
        Uri.parse(detailUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('🔍 [RequestorDetailPage] Response status: ${response.statusCode}');
      debugPrint('🔍 [RequestorDetailPage] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
          final result = data['results'];
        Map<String, dynamic> requestDetails = {};
        List<Map<String, dynamic>> requestItems = [];

        if (result != null) {
          final List<dynamic> details = result['details'] ?? [];
          requestItems = List<Map<String, dynamic>>.from(
            details.map((e) => Map<String, dynamic>.from(e)),
          );

          requestDetails = {
            'id': result['id'] ?? waitingSummary['id'],
            'topic_uniq_id': result['topic_uniq_id'] ?? topicUid,
            'title': result['title'] ??
                waitingSummary['title'] ??
                widget.requestData['title'] ??
                '',
            'product_priority': result['product_priority'],
            'employee_name': result['employee_name'] ??
                waitingSummary['employee_name'] ??
                widget.requestData['requestor_name'],
            'img_path': result['img_path'] ??
                waitingSummary['img_path'] ??
                widget.requestData['img_path'],
            'branch_name': result['branch_name'] ??
                waitingSummary['branch_name'] ??
                widget.requestData['branch_name'],
            'status': result['status'] ??
                waitingSummary['decide'] ??
                widget.requestData['status'],
            'created_at': result['created_at'] ??
                waitingSummary['created_at'] ??
                widget.requestData['created_at'],
          };
        } else if (waitingSummary.isNotEmpty) {
          requestDetails = {
            'id': waitingSummary['id'],
            'topic_uniq_id': waitingSummary['topic_uniq_id'] ?? topicUid,
            'title': waitingSummary['title'] ?? widget.requestData['title'] ?? '',
            'employee_name': waitingSummary['employee_name'] ??
                widget.requestData['requestor_name'],
            'img_path': waitingSummary['img_path'] ?? widget.requestData['img_path'],
            'branch_name': waitingSummary['branch_name'] ??
                widget.requestData['branch_name'],
            'status': waitingSummary['decide'] ?? widget.requestData['status'],
            'created_at': waitingSummary['created_at'] ??
                widget.requestData['created_at'],
          };
        } else {
          throw Exception('No results in API response');
        }
          
          setState(() {
            _requestDetails = requestDetails;
          _requestItems = requestItems;
            _isLoading = false;
            _isError = false;
          });
          
          debugPrint('🔍 [RequestorDetailPage] Loaded ${_requestItems.length} items');
      } else {
        throw Exception('Failed to fetch request details: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = e.toString();
      });
      debugPrint('🔍 [RequestorDetailPage] Error: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchWaitingSummary(
    String baseUrl,
    String token,
    String topicUid,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/inventory/waiting/$topicUid'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch waiting detail: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final results = data['results'];

    if (results is List && results.isNotEmpty) {
      return Map<String, dynamic>.from(results.first);
    } else if (results is Map<String, dynamic>) {
      return Map<String, dynamic>.from(results);
    }

    throw Exception('Waiting detail response empty');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        final isDarkMode = themeNotifier.isDarkMode;

        return Scaffold(
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          appBar: const InventoryAppBar(
            title: 'Requestor Detail',
            showBack: true,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isError
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading request details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode ? Colors.white70 : Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchRequestDetails,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDBB342),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Requestor Information Card
                      _buildRequestorInfoCard(isDarkMode),
                      const SizedBox(height: 20),
                      // Requested Items Section
                      _buildRequestedItemsSection(isDarkMode),
                      const SizedBox(height: 20),
                      // Feedback Section (if final status)
                      if (_isFinalStatus)
                        _buildFeedbackSectionWidget(isDarkMode),
                      const SizedBox(height: 30),
                      // Action Buttons
                      _buildActionButtons(isDarkMode),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildRequestorInfoCard(bool isDarkMode) {
    final String requestorName = _requestDetails['employee_name'] ?? 'Unknown';
    final String createdAt = _requestDetails['created_at'] ?? '';
    final String status = _requestDetails['status'] ?? 'Unknown';
    // Check both img_path and img_name
    final String imgPath = _requestDetails['img_path'] ?? '';
    final String imgName = _requestDetails['img_name'] ?? '';
    final String imageUrl = _getImageUrl(imgPath.isNotEmpty ? imgPath : imgName);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Picture
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.grey.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person,
                        color: isDarkMode ? Colors.white : Colors.grey[600],
                        size: 30,
                      ),
                    )
                  : Icon(
                      Icons.person,
                      color: isDarkMode ? Colors.white : Colors.grey[600],
                      size: 30,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // Requestor Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requestorName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Submitted on ${_formatDate(createdAt)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Status: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestedItemsSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Requested Items',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        ..._requestItems.map((item) => _buildItemCard(item, isDarkMode)).toList(),
      ],
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, bool isDarkMode) {
    final String name = item['name'] ?? 'Unknown Item';
    final dynamic quantityValue = item['quantity'];
    final int quantity = (quantityValue is String) ? int.tryParse(quantityValue) ?? 0 : (quantityValue ?? 0);
    final String imageUrl = item['img_ref'] ?? ''; // API uses img_ref for item images

    debugPrint('🔍 [RequestorDetailPage] Building item card: name="$name", img_ref="$imageUrl"');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Row(
        children: [
          // Item Image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            color: const Color(0xFFDBB342),
                          ),
                        );
                      },
                          errorBuilder: (context, error, stackTrace) {
                            // Handle image load errors gracefully (403/404 are expected for expired S3 URLs)
                            // Just return fallback icon without logging
                            return Icon(
                        Icons.inventory_2,
                        color: Colors.grey[600],
                        size: 30,
                            );
                          },
                    )
                  : Icon(
                      Icons.inventory_2,
                      color: Colors.grey[600],
                      size: 30,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // Item Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'for Office',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
            ],
          ),
          // Quantity display at bottom right (for final status)
          if (_isFinalStatus)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFDBB342).withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
            ),
            child: Text(
              quantity.toString().padLeft(2, '0'),
                  style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                    color: Color(0xFFDBB342),
                  ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDarkMode) {
    return Row(
      children: [
        // Approve Button
        Expanded(
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _handleApprove,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDBB342),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Approve',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        // Decline Button
        Expanded(
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _handleDecline,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                    ),
                  )
                : const Text(
                    'Decline',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase().trim();
    // Check for supervisor pending first (with or without dots)
    if (s.contains('supervisor pending')) {
      return Colors.orange; // Kuning/oren untuk Supervisor Pending
    }
    switch (s) {
      case 'pending':
      case 'waiting':
        return Colors.orange;
      case 'approved':
      case 'completed':
      case 'received':
        return Colors.green;
      case 'decline':
      case 'declined':
      case 'rejected':
        return Colors.red;
      case 'cancel':
      case 'canceled':
      case 'cancelled':
        return Colors.red;
      case 'exported':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  bool get _isFinalStatus {
    final s = (_requestDetails['status'] ?? '').toString().toLowerCase();
    return s.contains('approved') || s.contains('decline') || s.contains('declined') || s.contains('rejected') || s.contains('received') || s.contains('exported') || s.contains('cancel');
  }

  Widget _buildFeedbackSectionWidget(bool isDarkMode) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchFeedbackList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
        return const SizedBox.shrink();
      }
      
        final feedbackList = snapshot.data!;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with expand/collapse button
              InkWell(
                onTap: () {
                  setState(() {
                    _isFeedbackExpanded = !_isFeedbackExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Comments & Feedback',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Icon(
                        _isFeedbackExpanded ? Icons.expand_less : Icons.expand_more,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
              // Feedback items (shown when expanded)
              if (_isFeedbackExpanded) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: feedbackList.map((feedback) {
      final String comment = feedback['comment'] ?? '';
      final String createdAt = feedback['created_at'] ?? '';
      final String employeeName = feedback['employee_name'] ?? 'Unknown';
      final String employeeSurname = feedback['employee_surname'] ?? '';
      final String imgPath = feedback['img_path'] ?? '';
      final String positionName = feedback['position_name'] ?? '';
      
      final String approverName = '$employeeName $employeeSurname'.trim();
      final String approverImageUrl = _getImageUrl(imgPath);
                      // Check both img_path and img_name for requester image
                      final String requesterImgPath = _requestDetails['img_path'] ?? '';
                      final String requesterImgName = _requestDetails['img_name'] ?? '';
                      final String requesterImageUrl = _getImageUrl(requesterImgPath.isNotEmpty ? requesterImgPath : requesterImgName);

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
            ),
        ),
        child: Column(
          children: [
                            // Profile images with arrow
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                                // Requester image
                    Container(
                                  width: 40,
                                  height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                                    child: requesterImageUrl.isNotEmpty
                            ? Image.network(
                                            requesterImageUrl,
                                fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.person,
                                    color: Colors.green,
                                              size: 20,
                                            ),
                              )
                            : const Icon(
                                Icons.person,
                                color: Colors.green,
                                            size: 20,
                              ),
                      ),
                    ),
                                const SizedBox(width: 12),
                // Arrow
                Container(
                                  width: 30,
                                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBB342),
                                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                                    size: 14,
                  ),
                ),
                                const SizedBox(width: 12),
                                // Approver image
                    Container(
                                  width: 40,
                                  height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                                    child: approverImageUrl.isNotEmpty
                            ? Image.network(
                                            approverImageUrl,
                                fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.person,
                                    color: Colors.green,
                                              size: 20,
                                            ),
                              )
                            : const Icon(
                                Icons.person,
                                color: Colors.green,
                                            size: 20,
                              ),
                      ),
                    ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Employee name and position
                    Text(
                              approverName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (positionName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                positionName,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                            const SizedBox(height: 8),
            // Date and time
            Text(
              _formatDate(createdAt),
              style: TextStyle(
                                fontSize: 12,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            // Comment
            if (comment.isNotEmpty)
              Text(
                comment,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchFeedbackList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final baseUrl = dotenv.env['BASE_URL'];
      final topicUid = _requestDetails['topic_uniq_id'];
      if (token == null || baseUrl == null || topicUid == null) {
        return [];
      }
      
      debugPrint('🔍 [AdminBR RequestorDetail] Fetching feedback for topic: $topicUid');
      final response = await http.get(
        Uri.parse('$baseUrl/api/inventory/request_reply/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      debugPrint('🔍 [AdminBR RequestorDetail] Feedback response status: ${response.statusCode}');
      debugPrint('🔍 [AdminBR RequestorDetail] Feedback response body: ${response.body}');
      
      if (response.statusCode != 200) return [];
      
      final decoded = jsonDecode(response.body);
      final List<dynamic> feedbackList = (decoded is List) ? decoded : (decoded['results'] ?? []);
      
      return feedbackList.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('🔍 [AdminBR RequestorDetail] Feedback error: $e');
      return [];
    }
  }

  Color _getDecideColor(String decide) {
    switch (decide.toLowerCase()) {
      case 'checked':
      case 'approved':
      case 'received':
        return Colors.green;
      case 'edit':
        return Colors.orange;
      case 'declined':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    // If already a full URL, return as is
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    // Otherwise, prepend base URL
    return '$_imageBaseUrl$imagePath';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  void _handleApprove() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CommentModal(
          action: 'Approve',
          onConfirm: (comment) {
            Navigator.of(context).pop(); // Close comment modal
            _processApproval(comment);
          },
          onCancel: () {
            Navigator.of(context).pop(); // Close comment modal
          },
        );
      },
    );
  }

  void _handleDecline() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CommentModal(
          action: 'Decline',
          onConfirm: (comment) {
            Navigator.of(context).pop(); // Close comment modal
            _processDecline(comment);
          },
          onCancel: () {
            Navigator.of(context).pop(); // Close comment modal
          },
        );
      },
    );
  }

  Future<void> _processApproval(String comment) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final baseUrl = dotenv.env['BASE_URL'] ?? '';
      
      if (token == null || baseUrl.isEmpty) {
        throw Exception('Authentication or BASE_URL not configured');
      }

      // Get the topic ID from the request data
      String topicUid = widget.requestData['topic_uniq_id'] ?? 
                       widget.requestData['topicid'] ?? '';
      if (topicUid.isEmpty) {
        throw Exception('No topic UID found in request data');
      }

      final trimmedComment = comment.trim();
      final uri = Uri.parse('$baseUrl/api/inventory/request-waiting/$topicUid');
      debugPrint('🔍 [AdminBR] Approve URL: $uri');

      final response = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'comment': trimmedComment}),
      );

      debugPrint('🔍 [AdminBR] Approval response status: ${response.statusCode}');
      debugPrint('🔍 [AdminBR] Approval response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          // Show success modal
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return SuccessModal(
                action: 'Approved',
                onClose: () {
                  Navigator.of(context).pop(); // Close success modal
                  Navigator.of(context).pop(true); // Go back to previous page
                },
              );
            },
          );
        }
      } else {
        debugPrint('🔍 [AdminBR] Approval failed with status: ${response.statusCode}');
        debugPrint('🔍 [AdminBR] Response body: ${response.body}');
        
        // Parse API response message for better error display
        String errorMessage = 'Cannot approve request. Please contact IT department.';
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          } else if (responseData['error'] != null) {
            errorMessage = responseData['error'];
          } else if (responseData['detail'] != null) {
            errorMessage = responseData['detail'];
          }
        } catch (e) {
          // If parsing fails, show user-friendly message based on status code
          switch (response.statusCode) {
            case 404:
              errorMessage = 'Cannot approve request. Please contact IT department.';
              break;
            case 403:
              errorMessage = 'You do not have permission to approve this request.';
              break;
            case 500:
              errorMessage = 'Server error. Please contact IT department.';
              break;
            default:
              errorMessage = 'Cannot approve request. Please contact IT department.';
          }
        }
        
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processDecline(String comment) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final baseUrl = dotenv.env['BASE_URL'] ?? '';
      
      if (token == null || baseUrl.isEmpty) {
        throw Exception('Authentication or BASE_URL not configured');
      }

      // Get the topic ID from the request data
      String topicUid = widget.requestData['topic_uniq_id'] ?? 
                       widget.requestData['topicid'] ?? '';
      if (topicUid.isEmpty) {
        throw Exception('No topic UID found in request data');
      }

      final trimmedComment = comment.trim();
      final uri = Uri.parse('$baseUrl/api/inventory/decline/$topicUid');
      debugPrint('🔍 [AdminBR] Decline URL: $uri');

      final response = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'comment': trimmedComment}),
      );

      debugPrint('🔍 [AdminBR] Decline response status: ${response.statusCode}');
      debugPrint('🔍 [AdminBR] Decline response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          // Show success modal
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return SuccessModal(
                action: 'Declined',
                onClose: () {
                  Navigator.of(context).pop(); // Close success modal
                  Navigator.of(context).pop(true); // Go back to previous page
                },
              );
            },
          );
        }
      } else {
        debugPrint('🔍 [AdminBR] Decline failed with status: ${response.statusCode}');
        debugPrint('🔍 [AdminBR] Response body: ${response.body}');
        
        // Parse API response message for better error display
        String errorMessage = 'Cannot decline request. Please contact IT department.';
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          } else if (responseData['error'] != null) {
            errorMessage = responseData['error'];
          } else if (responseData['detail'] != null) {
            errorMessage = responseData['detail'];
          }
        } catch (e) {
          // If parsing fails, show user-friendly message based on status code
          switch (response.statusCode) {
            case 404:
              errorMessage = 'Cannot decline request. Please contact IT department.';
              break;
            case 403:
              errorMessage = 'You do not have permission to decline this request.';
              break;
            case 500:
              errorMessage = 'Server error. Please contact IT department.';
              break;
            default:
              errorMessage = 'Cannot decline request. Please contact IT department.';
          }
        }
        
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFDBB342),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'SUCCESS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Go back to previous page
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDBB342),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ERROR',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
