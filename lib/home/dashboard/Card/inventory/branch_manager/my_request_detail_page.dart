import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../inventory_app_bar.dart';
import '../widgets/comment_modal.dart';

/// My Request Detail page for Branch_manager role
/// Allows branch managers to edit and manage their request items
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

  // Base URL for images
  final String _imageBaseUrl = 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/';

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

      String topicUid = widget.requestData['topic_uniq_id'] ?? widget.requestData['topicid'] ?? '';
      if (topicUid.isEmpty) {
        throw Exception('No topic UID found in request data');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/inventory/my-request-topic-detail/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null) {
          final result = data['results'];
          final requestDetails = {
            'id': result['id'],
            'topic_uniq_id': result['topic_uniq_id'],
            'title': result['title'],
            'product_priority': result['product_priority'],
            'employee_name': result['employee_name'],
            'img_path': result['img_path'],
            'branch_name': result['branch_name'],
            'status': result['status'],
            'request_stock': result['request_stock'],
            'department_name': result['department_name'],
            'created_at': result['created_at'],
          };

          final List<dynamic> details = result['details'] ?? [];

          setState(() {
            _requestDetails = requestDetails;
            _requestItems = List<Map<String, dynamic>>.from(details.map((e) => Map<String, dynamic>.from(e)));
            _isLoading = false;
            _isError = false;
          });
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
    final String imageUrl = _getImageUrl(_requestDetails['img_path']);

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
                color: const Color(0xFF9C27B0), // Pink border
                width: 2,
              ),
            ),
            child: ClipOval(
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Color(0xFF9C27B0), size: 30),
                    )
                  : const Icon(Icons.person, color: Color(0xFF9C27B0), size: 30),
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
        ...List.generate(_requestItems.length, (i) => _buildRequestedItemCard(_requestItems[i], isDarkMode, i)),
      ],
    );
  }

  Widget _buildRequestedItemCard(Map<String, dynamic> item, bool isDarkMode, int index) {
    final String name = item['name'] ?? 'Unknown Item';
    final int quantity = (item['quantity'] is String) ? int.tryParse(item['quantity']) ?? 0 : (item['quantity'] ?? 0);
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
                            color: const Color(0xFF9C27B0),
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
          _isFinalStatus
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    quantity.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9C27B0),
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
                        color: const Color(0xFF9C27B0).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        quantity.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9C27B0),
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
                        onConfirm: (c) { comment = c; Navigator.of(context).pop(); },
                        onCancel: () { Navigator.of(context).pop(); },
                      ),
                    );
                    if ((comment ?? '').trim().isNotEmpty) {
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

  void _updateQuantity(String itemId, int newQuantity) {
    if (newQuantity < 0) return;
    
    setState(() {
      final itemIndex = _requestItems.indexWhere((item) => item['id'] == itemId);
      if (itemIndex != -1) {
        _requestItems[itemIndex]['quantity'] = newQuantity;
      }
    });
  }

  void _deleteItem(String itemId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Item'),
          content: const Text('Are you sure you want to delete this item from your request?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _requestItems.removeWhere((item) => item['id'] == itemId);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Item deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  bool get _isFinalStatus {
    final s = (_requestDetails['status'] ?? '').toString().toLowerCase();
    return s.contains('approved') || s.contains('declined') || s.contains('rejected') || s.contains('received') || s.contains('exported');
  }

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

      final body = {
        'title': _requestDetails['title'] ?? '',
        'details': _requestItems.map((e) => {
              'barcode': e['barcode'] ?? e['bar_code'] ?? '',
              'quantity': (e['quantity'] is String) ? int.tryParse(e['quantity']) ?? 0 : (e['quantity'] ?? 0),
            }).toList(),
        'confirmed': 0,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/api/inventory/request_topic/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request updated successfully')));
        await _loadRequestDetails();
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Failed to update (${response.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
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
      final response = await http.put(
        Uri.parse('$baseUrl/api/inventory/request-cancel/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'comment': comment}),
      );
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request cancelled')));
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to cancel (${response.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
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
      final response = await http.get(
        Uri.parse('$baseUrl/api/inventory/request_reply/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode != 200) return const SizedBox.shrink();
      final decoded = jsonDecode(response.body);
      final results = (decoded is Map && decoded['results'] != null) ? decoded['results'] : decoded;
      if (results == null) return const SizedBox.shrink();

      final String status = (_requestDetails['status'] ?? '').toString();
      final String when = (results['created_at'] ?? '').toString();
      final String comment = (results['comment'] ?? '').toString();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(status, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 6),
          Text(when, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54)),
          const SizedBox(height: 8),
          Text(comment, style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white : Colors.black87)),
        ],
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  String _getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    return imagePath.startsWith('http') ? imagePath : '$_imageBaseUrl$imagePath';
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
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[month - 1];
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'decline':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
