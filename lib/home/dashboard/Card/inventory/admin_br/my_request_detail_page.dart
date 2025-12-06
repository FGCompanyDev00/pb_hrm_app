import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/comment_modal.dart';
import '../inventory_app_bar.dart';

/// My Request Detail page for AdminBR users
/// View-only page showing request details, status, and approval history
class MyRequestDetailPage extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const MyRequestDetailPage({
    super.key,
    required this.requestData,
  });

  @override
  State<MyRequestDetailPage> createState() => _MyRequestDetailPageState();
}

class _MyRequestDetailPageState extends State<MyRequestDetailPage> {
  Map<String, dynamic> _requestDetails = {};
  List<Map<String, dynamic>> _requestItems = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  bool _isSubmitting = false;
  final TextEditingController _titleController = TextEditingController();

  // Base URL for images
  final String _imageBaseUrl = 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/';

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 [MyRequestDetailPage] initState called with requestData: ${widget.requestData}');
    _loadRequestDetails();
  }

  Future<void> _loadRequestDetails() async {
    setState(() {
      _isLoading = true;
      _isError = false;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final baseUrl = dotenv.env['BASE_URL'];

      if (token == null || baseUrl == null) {
        throw Exception('Authentication token or base URL not found');
      }

      // Get the topic ID from the request data - check both possible field names
      String topicUid = widget.requestData['topic_uniq_id'] ?? 
                       widget.requestData['topicid'] ?? '';
      if (topicUid.isEmpty) {
        throw Exception('No topic UID found in request data');
      }

      debugPrint('🔍 [MyRequestDetailPage] Fetching details for topic: $topicUid');
      debugPrint('🔍 [MyRequestDetailPage] API URL: $baseUrl/api/inventory/my-request-topic-detail/$topicUid');

      final response = await http.get(
        Uri.parse('$baseUrl/api/inventory/my-request-topic-detail/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('🔍 [MyRequestDetailPage] Response status: ${response.statusCode}');
      debugPrint('🔍 [MyRequestDetailPage] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null) {
          final result = data['results'];
          
          // Extract request details and items
          debugPrint('🔍 [MyRequestDetailPage] API result img_path: ${result['img_path']}');
          debugPrint('🔍 [MyRequestDetailPage] API result img_name: ${result['img_name']}');
          debugPrint('🔍 [MyRequestDetailPage] API result employee_name: ${result['employee_name']}');
          
          final requestDetails = {
            'id': result['id'],
            'topic_uniq_id': result['topic_uniq_id'],
            'title': result['title'],
            'product_priority': result['product_priority'],
            'employee_name': result['employee_name'],
            'img_path': result['img_path'],
            'img_name': result['img_name'],
            'branch_name': result['branch_name'],
            'status': result['status'],
            'request_stock': result['request_stock'],
            'department_name': result['department_name'],
            'created_at': result['created_at'],
          };
          
          debugPrint('🔍 [MyRequestDetailPage] Saved requestDetails img_path: ${requestDetails['img_path']}');
          debugPrint('🔍 [MyRequestDetailPage] Saved requestDetails img_name: ${requestDetails['img_name']}');
          
          final List<dynamic> details = result['details'] ?? [];
          
          debugPrint('🔍 [MyRequestDetailPage] Raw details: $details');
          
          setState(() {
            _requestDetails = requestDetails;
            _requestItems = List<Map<String, dynamic>>.from(
                details.map((e) => Map<String, dynamic>.from(e)));
            _titleController.text = _requestDetails['title'] ?? '';
            _isLoading = false;
            _isError = false;
          });
          debugPrint('✅ [MyRequestDetailPage] Request details loaded successfully');
        } else {
          throw Exception('No results in API response');
        }
      } else {
        throw Exception('Failed to fetch request details: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = e.toString();
      });
      debugPrint('❌ [MyRequestDetailPage] Error loading request details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        final isDarkMode = themeNotifier.isDarkMode;
        
        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
          appBar: InventoryAppBar(
            title: 'My Request',
            showBack: true,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isError
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading request details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _loadRequestDetails,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDBB342),
                              foregroundColor: Colors.white,
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
                          _buildRequestorInfoCard(isDarkMode),
                          const SizedBox(height: 16),
                          // Title field (editable if Supervisor Pending)
                          if (_canEditItems) _buildTitleField(isDarkMode),
                          if (_canEditItems) const SizedBox(height: 16),
                          _buildRequestedItemsSection(isDarkMode),
                          const SizedBox(height: 16),
                          if (_isFinalStatus)
                            FutureBuilder<Widget>(
                              future: _buildFeedbackSection(isDarkMode),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                return snapshot.data ?? const SizedBox.shrink();
                              },
                            )
                          else
                            _buildUpdateCancelRow(isDarkMode),
                          const SizedBox(height: 16),
                          // if (_isFinalStatus) _buildApprovalHistorySection(isDarkMode), // Commented out - not in use yet
                        ],
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildRequestorInfoCard(bool isDarkMode) {
    final String requestorName = _requestDetails['employee_name'] ?? 'Unknown';
    final String submittedAt = _formatDate(_requestDetails['created_at']);
    final String status = _requestDetails['status'] ?? 'Unknown';
    final String imgPath = _requestDetails['img_path'] ?? '';
    final String imgName = _requestDetails['img_name'] ?? '';
    final String imageUrl = _getImageUrl(imgPath, imgName);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          // Profile Picture
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFDBB342),
                width: 2,
              ),
            ),
            child: ClipOval(
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
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person,
                        color: Colors.grey[600],
                        size: 30,
                      ),
                    )
                  : Icon(
                      Icons.person,
                      color: Colors.grey[600],
                      size: 30,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // Requestor Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requestorName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Submitted on $submittedAt',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Status: $status',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request Title',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: 'Enter request title...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: const Color(0xFFDBB342).withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDBB342), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(_requestItems.length, (index) => _buildRequestedItemCard(_requestItems[index], isDarkMode, index)),
      ],
    );
  }

  Widget _buildRequestedItemCard(Map<String, dynamic> item, bool isDarkMode, int index) {
    final String name = item['name'] ?? 'Unknown Item';
    final int quantity = (item['quantity'] is String)
        ? int.tryParse(item['quantity']) ?? 0
        : (item['quantity'] ?? 0);
    final String category = item['category'] ?? 'for Office';
    final String imageUrl = _getItemImageUrl(item['img_ref']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          // Item Image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.withOpacity(0.3),
                width: 1,
              ),
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
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.computer,
                        color: Colors.grey[600],
                        size: 24,
                      ),
                    )
                  : Icon(
                      Icons.computer,
                      color: Colors.grey[600],
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Item Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Quantity or controls
          _isFinalStatus
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBB342).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    quantity.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDBB342),
                    ),
                  ),
                )
              : Row(
                  children: [
                    IconButton(
                      onPressed: () => _decrementQuantity(index),
                      icon: const Icon(Icons.remove_circle_outline),
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBB342).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        quantity.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDBB342),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _incrementQuantity(index),
                      icon: const Icon(Icons.add_circle_outline),
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _removeItem(index),
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red[400],
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  // Final vs editable status
  bool get _isFinalStatus {
    final statusStr = (_requestDetails['status'] ?? '').toString();
    final s = statusStr.toLowerCase().trim().replaceAll(RegExp(r'[.\s]+'), ' ');
    // Supervisor Pending is NOT a final status - user can still edit
    if (s.contains('supervisor pending')) {
      debugPrint('🔍 [AdminBR] Status "$statusStr" is Supervisor Pending - NOT final status');
      return false;
    }
    final isFinal = s.contains('approved') || s.contains('decline') || s.contains('declined') || s.contains('rejected') || s.contains('received') || s.contains('exported') || s.contains('cancel');
    debugPrint('🔍 [AdminBR] Status "$statusStr" isFinalStatus: $isFinal');
    return isFinal;
  }

  bool get _canEditItems {
    final statusStr = (_requestDetails['status'] ?? '').toString();
    final s = statusStr.toLowerCase().trim().replaceAll(RegExp(r'[.\s]+'), ' ');
    // Check for supervisor pending status (with or without dots, case insensitive)
    final canEdit = s.contains('supervisor pending');
    debugPrint('🔍 [AdminBR] Status: "$statusStr", Normalized: "$s", CanEditItems: $canEdit');
    return canEdit;
  }

  // Quantity controls for editable mode
  void _incrementQuantity(int index) {
    setState(() {
      final current = (_requestItems[index]['quantity'] is String)
          ? int.tryParse(_requestItems[index]['quantity']) ?? 0
          : (_requestItems[index]['quantity'] ?? 0);
      _requestItems[index]['quantity'] = current + 1;
    });
  }

  void _decrementQuantity(int index) {
    setState(() {
      final current = (_requestItems[index]['quantity'] is String)
          ? int.tryParse(_requestItems[index]['quantity']) ?? 0
          : (_requestItems[index]['quantity'] ?? 0);
      if (current > 1) {
        _requestItems[index]['quantity'] = current - 1;
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _requestItems.removeAt(index);
    });
  }

  Widget _buildUpdateCancelRow(bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDBB342),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(_isSubmitting ? 'Updating...' : 'Update'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: _isSubmitting
                ? null
                : () async {
                    String? comment;
                    await showDialog(
                      context: context,
                      builder: (context) => CommentModal(
                        action: 'Submit',
                        onConfirm: (c) {
                          comment = c;
                          Navigator.of(context).pop();
                        },
                        onCancel: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                    final hasComment = (comment ?? '').trim().isNotEmpty;
                    if (hasComment) {
                      await _submitCancel((comment ?? '').trim());
                    }
                  },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFDBB342), width: 2),
              foregroundColor: const Color(0xFFDBB342),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(_isSubmitting ? 'Cancelling...' : 'Cancel'),
          ),
        ),
      ],
    );
  }

  Future<void> _submitUpdate() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final baseUrl = dotenv.env['BASE_URL'];
      final topicUid = _requestDetails['topic_uniq_id'];
      if (token == null || baseUrl == null || topicUid == null) {
        throw Exception('Missing auth or topic id');
      }

      // Validate quantities before sending
      final details = <Map<String, dynamic>>[];
      for (var item in _requestItems) {
        final barcode = item['barcode'] ?? item['bar_code'] ?? '';
        final qty = (item['quantity'] is String) ? int.tryParse(item['quantity']) ?? 0 : (item['quantity'] ?? 0);
        if (barcode.isEmpty) {
          throw Exception('Barcode is required for all items');
        }
        if (qty <= 0) {
          throw Exception('Quantity must be greater than 0 for all items');
        }
        details.add({
          'barcode': barcode,
          'quantity': qty,
        });
      }

      if (details.isEmpty) {
        throw Exception('At least one item is required');
      }

      final body = {
        'title': _titleController.text.trim().isEmpty ? (_requestDetails['title'] ?? '') : _titleController.text.trim(),
        'details': details,
        'confirmed': 0,
      };

      debugPrint('🔍 [AdminBR] Update body: ${jsonEncode(body)}');

      final response = await http.put(
        Uri.parse('$baseUrl/api/inventory/request_topic/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint('🔍 [AdminBR] Update response status: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request updated successfully')),
        );
        // Navigate back to refresh the list
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to update (${response.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getUserFriendlyErrorMessage(e)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitCancel(String comment) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final baseUrl = dotenv.env['BASE_URL'];
      if (token == null || baseUrl == null) {
        throw Exception('Missing auth');
      }
      final topicUid = _requestDetails['topic_uniq_id'];
      if (topicUid == null) throw Exception('Missing topic id');
      
      final body = {'comment': comment};
      debugPrint('🔍 [AdminBR] Cancel body: ${jsonEncode(body)}');

      final response = await http.put(
        Uri.parse('$baseUrl/api/inventory/request-cancel/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint('🔍 [AdminBR] Cancel response status: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request cancelled')),
        );
        // Navigate back to refresh the list
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to cancel (${response.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getUserFriendlyErrorMessage(e)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<Widget> _buildFeedbackSection(bool isDarkMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final baseUrl = dotenv.env['BASE_URL'];
      final topicUid = _requestDetails['topic_uniq_id'];
      if (token == null || baseUrl == null || topicUid == null) {
        return const SizedBox.shrink();
      }
      
      debugPrint('🔍 [AdminBR] Fetching feedback for topic: $topicUid');
      final response = await http.get(
        Uri.parse('$baseUrl/api/inventory/request_reply/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      debugPrint('🔍 [AdminBR] Feedback response status: ${response.statusCode}');
      debugPrint('🔍 [AdminBR] Feedback response body: ${response.body}');
      
      if (response.statusCode != 200) return const SizedBox.shrink();
      
      final decoded = jsonDecode(response.body);
      final List<dynamic> feedbackList = (decoded is List) ? decoded : (decoded['results'] ?? []);
      
      if (feedbackList.isEmpty) return const SizedBox.shrink();

      // Get the latest feedback (first item in the list)
      final feedback = feedbackList.first;
      final String comment = feedback['comment'] ?? '';
      final String decide = feedback['decide'] ?? '';
      final String createdAt = feedback['created_at'] ?? '';
      final String employeeName = feedback['employee_name'] ?? 'Unknown';
      final String employeeSurname = feedback['employee_surname'] ?? '';
      final String imgPath = feedback['img_path'] ?? '';
      final String positionName = feedback['position_name'] ?? '';
      
      final String approverName = '$employeeName $employeeSurname'.trim();
      // Check both img_path and img_name for approver image
      final String imgName = feedback['img_name'] ?? '';
      final String approverImageUrl = _getImageUrl(imgPath, imgName);
      debugPrint('🔍 [MyRequestDetailPage] Approver image - img_path: $imgPath, img_name: $imgName, final URL: $approverImageUrl');
      
      // Get requester name and image
      // Use original request data for name to avoid double name issue
      final String requesterName = widget.requestData['employee_name'] ?? 
                                   widget.requestData['full_name'] ?? 
                                   _requestDetails['employee_name'] ?? 
                                   'Unknown';
      // Clean up name if it's duplicated (remove duplicate parts)
      final String cleanRequesterName = _cleanDuplicateName(requesterName);
      
      // Get requester image - check both _requestDetails and widget.requestData
      String requesterImgPath = _requestDetails['img_path'] ?? widget.requestData['img_path'] ?? '';
      String requesterImgName = _requestDetails['img_name'] ?? widget.requestData['img_name'] ?? '';
      
      // If img_name is empty but img_path exists, try to get from original data
      if (requesterImgName.isEmpty && requesterImgPath.isNotEmpty) {
        // Check if we can get img_name from feedback or other sources
        debugPrint('⚠️ [MyRequestDetailPage] Requester img_name is empty, trying to get from original data');
      }
      
      final String requesterImageUrl = _getImageUrl(requesterImgPath, requesterImgName);
      debugPrint('🔍 [MyRequestDetailPage] Requester - name: $cleanRequesterName (original: $requesterName), img_path: $requesterImgPath, img_name: $requesterImgName, final URL: $requesterImageUrl');

      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
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
          children: [
            // Profile images with arrow
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Requester image with position
                Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
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
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint('❌ [MyRequestDetailPage] Requester image error: $error, URL: $requesterImageUrl');
                                  return const Icon(
                                    Icons.person,
                                    color: Colors.green,
                                    size: 25,
                                  );
                                },
                              )
                            : const Icon(
                                Icons.person,
                                color: Colors.green,
                                size: 25,
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cleanRequesterName,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Arrow
                Container(
                  width: 40,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBB342),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 16),
                // Approver image with position
                Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
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
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint('❌ [MyRequestDetailPage] Approver image error: $error, URL: $approverImageUrl');
                                  return const Icon(
                                    Icons.person,
                                    color: Colors.green,
                                    size: 25,
                                  );
                                },
                              )
                            : const Icon(
                                Icons.person,
                                color: Colors.green,
                                size: 25,
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      positionName.isNotEmpty ? positionName : 'Approver',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Date and time
            Text(
              _formatDate(createdAt),
              style: TextStyle(
                fontSize: 14,
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
    } catch (e) {
      debugPrint('🔍 [AdminBR] Feedback error: $e');
      return const SizedBox.shrink();
    }
  }

  Color _getDecideColor(String decide) {
    switch (decide.toLowerCase()) {
      case 'checked':
      case 'approved':
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

  Widget _buildApprovalHistorySection(bool isDarkMode) {
    final String approvedAt = _formatDate(_requestDetails['approved_at']);
    final String approvedBy = _requestDetails['approved_by'] ?? 'Unknown';
    final String approvalComment = _requestDetails['approval_comment'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          Text(
            'Approval History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // Approval Flow
          Row(
            children: [
              _buildApprovalStep('Ms. Lusi', true, true, isDarkMode),
              const SizedBox(width: 8),
              _buildApprovalArrow(),
              const SizedBox(width: 8),
              _buildApprovalStep('Marketing', true, true, isDarkMode),
              const SizedBox(width: 8),
              _buildApprovalArrow(),
              const SizedBox(width: 8),
              _buildApprovalStep('Manager', true, true, isDarkMode),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Approved - $approvedAt',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            approvalComment,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white : Colors.black87,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalStep(String name, bool isCompleted, bool isCurrent, bool isDarkMode) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? const Color(0xFFDBB342) : Colors.grey[300],
            border: Border.all(
              color: isCurrent ? const Color(0xFFDBB342) : Colors.grey[400]!,
              width: 2,
            ),
          ),
          child: Icon(
            isCompleted ? Icons.check : Icons.person,
            color: isCompleted ? Colors.white : Colors.grey[600],
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            fontSize: 10,
            color: isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalArrow() {
    return Container(
      width: 20,
      height: 2,
      color: const Color(0xFFDBB342),
    );
  }

  /// Get user-friendly error message from exception
  String _getUserFriendlyErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Network errors
    if (errorString.contains('socket') || 
        errorString.contains('network') || 
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return 'Unable to connect to server. Please check your internet connection and try again.';
    }
    
    // Authentication errors
    if (errorString.contains('auth') || 
        errorString.contains('token') || 
        errorString.contains('unauthorized') ||
        errorString.contains('401')) {
      return 'Your session has expired. Please log in again.';
    }
    
    // Server errors (5xx)
    if (errorString.contains('500') || 
        errorString.contains('502') || 
        errorString.contains('503') ||
        errorString.contains('504')) {
      return 'Server error occurred. Please try again later or contact IT support.';
    }
    
    // Client errors (4xx) - but not auth
    if (errorString.contains('400') || 
        errorString.contains('403') || 
        errorString.contains('404') ||
        errorString.contains('422') ||
        errorString.contains('202')) {
      return 'Unable to process your request. Please try again or contact IT support if the problem persists.';
    }
    
    // Generic errors
    if (errorString.contains('failed to update') || 
        errorString.contains('failed to cancel') ||
        errorString.contains('failed to approve') ||
        errorString.contains('failed to decline')) {
      return 'Unable to complete the action. Please try again or contact IT support.';
    }
    
    // Default message
    return 'An error occurred. Please try again or contact IT support if the problem persists.';
  }

  /// Get image URL from img_path and img_name
  /// If img_path is full URL and img_name is query string, combine them
  /// Otherwise, use img_path if available, fallback to img_name
  String _getImageUrl(String? imagePath, [String? imageName]) {
    // If both are provided, check if we need to combine them
    if (imagePath != null && imagePath.isNotEmpty && 
        imageName != null && imageName.isNotEmpty) {
      // If img_path is full URL and img_name is query string, combine them
      if ((imagePath.startsWith('http://') || imagePath.startsWith('https://')) &&
          imageName.startsWith('?')) {
        // Combine: full URL + query string
        debugPrint('🔍 [MyRequestDetailPage] Combining img_path + img_name: $imagePath$imageName');
        return '$imagePath$imageName';
      }
    }
    
    // Use img_path if available
    if (imagePath != null && imagePath.isNotEmpty) {
      // If already a full URL, return as is
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        return imagePath;
      }
      // Regular path, prepend base URL
      return '$_imageBaseUrl$imagePath';
    }
    
    // Fallback to img_name if img_path is empty
    if (imageName != null && imageName.isNotEmpty) {
      // If starts with '?' it's a query string, append to base URL
      if (imageName.startsWith('?')) {
        return '$_imageBaseUrl$imageName';
      }
      // Regular path, prepend base URL
      return '$_imageBaseUrl$imageName';
    }
    
    return '';
  }

  String _getItemImageUrl(String? imageRef) {
    if (imageRef == null || imageRef.isEmpty) return '';
    return imageRef.startsWith('http') ? imageRef : '$_imageBaseUrl$imageRef';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')} ${_getMonthName(date.month)} ${date.year} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  /// Clean duplicate name (e.g., "Admin SBH1 Admin SBH1" -> "Admin SBH1")
  String _cleanDuplicateName(String name) {
    if (name.isEmpty) return name;
    
    final parts = name.trim().split(' ');
    if (parts.length < 2) return name;
    
    // Check if first part and last part are the same
    if (parts.length >= 4) {
      final firstTwo = '${parts[0]} ${parts[1]}';
      final lastTwo = '${parts[parts.length - 2]} ${parts[parts.length - 1]}';
      if (firstTwo == lastTwo) {
        // Remove duplicate, return first part
        return firstTwo;
      }
    }
    
    // Check if name is repeated (e.g., "Admin SBH1 Admin SBH1")
    final nameLower = name.toLowerCase();
    final firstHalf = name.substring(0, name.length ~/ 2).trim();
    final secondHalf = name.substring(name.length ~/ 2).trim();
    if (firstHalf.toLowerCase() == secondHalf.toLowerCase()) {
      return firstHalf;
    }
    
    return name;
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase().trim();
    
    // Handle status variations with contains check
    if (statusLower.contains('manager pending')) {
      return Colors.orange; // Orange for Manager Pending...
    }
    if (statusLower.contains('branch')) {
      return const Color(0xFFDBB342); // Yellow for Branchs
    }
    if (statusLower.contains('received')) {
      return Colors.green; // Green for Received
    }
    if (statusLower.contains('approved')) {
      return Colors.green; // Green for Approved
    }
    if (statusLower.contains('reject') || 
        statusLower.contains('cancel') || 
        statusLower.contains('decline')) {
      return Colors.red; // Red for Rejected/Reject/Cancel/Decline
    }
    
    // Fallback to switch for exact matches
    switch (statusLower) {
      case 'approved':
        return Colors.green;
      case 'received':
        return Colors.green;
      case 'exported':
        return Colors.blue;
      case 'decline':
      case 'declined':
      case 'rejected':
      case 'reject':
      case 'cancel':
      case 'canceled':
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
