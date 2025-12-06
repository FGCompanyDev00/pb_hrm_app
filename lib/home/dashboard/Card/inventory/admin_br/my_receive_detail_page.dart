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

/// My Receive Detail page for AdminBR users
/// Shows items ready for receiving with Receive/Cancel actions
class MyReceiveDetailPage extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const MyReceiveDetailPage({
    super.key,
    required this.requestData,
  });

  @override
  State<MyReceiveDetailPage> createState() => _MyReceiveDetailPageState();
}

class _MyReceiveDetailPageState extends State<MyReceiveDetailPage> {
  Map<String, dynamic> _requestDetails = {};
  List<Map<String, dynamic>> _requestItems = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  bool _isProcessing = false;

  // Base URL for images
  final String _imageBaseUrl = 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/';

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 [MyReceiveDetailPage] initState called with requestData: ${widget.requestData}');
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

      debugPrint('🔍 [MyReceiveDetailPage] Fetching details for topic: $topicUid');
      debugPrint('🔍 [MyReceiveDetailPage] API URL: $baseUrl/api/inventory/request_topic/$topicUid');

      final response = await http.get(
        Uri.parse('$baseUrl/api/inventory/request_topic/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('🔍 [MyReceiveDetailPage] Response status: ${response.statusCode}');
      debugPrint('🔍 [MyReceiveDetailPage] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('🔍 [MyReceiveDetailPage] Full API response: $data');
        debugPrint('🔍 [MyReceiveDetailPage] Response keys: ${data.keys.toList()}');
        
        if (data['results'] != null) {
          final result = data['results'];
          debugPrint('🔍 [MyReceiveDetailPage] Result type: ${result.runtimeType}');
          debugPrint('🔍 [MyReceiveDetailPage] Result: $result');
          
          // Handle if result is a List (from exports endpoint)
          if (result is List && result.isNotEmpty) {
            debugPrint('⚠️ [MyReceiveDetailPage] Result is a List, taking first item');
            final firstResult = result[0] as Map<String, dynamic>;
            debugPrint('🔍 [MyReceiveDetailPage] First result keys: ${firstResult.keys.toList()}');
            
            // Extract request details from first item
            final requestDetails = {
              'id': firstResult['id'],
              'topic_uniq_id': firstResult['topic_uniq_id'] ?? widget.requestData['topic_uniq_id'],
              'title': firstResult['title'] ?? widget.requestData['title'],
              'product_priority': firstResult['product_priority'],
              'employee_name': firstResult['employee_name'] ?? widget.requestData['requestor_name'],
              'img_path': firstResult['img_path'] ?? widget.requestData['img_path'],
              'branch_name': firstResult['branch_name'] ?? widget.requestData['branch_name'],
              'status': firstResult['status'] ?? widget.requestData['status'],
              'created_at': firstResult['created_at'] ?? widget.requestData['created_at'],
            };
            
            // Try to get details from first result
            final List<dynamic> details = firstResult['details'] ?? [];
            debugPrint('🔍 [MyReceiveDetailPage] Details from first result: $details (${details.length} items)');
            
            setState(() {
              _requestDetails = requestDetails;
              _requestItems = List<Map<String, dynamic>>.from(
                  details.map((e) => Map<String, dynamic>.from(e)));
              _isLoading = false;
              _isError = false;
            });
            
            debugPrint('🔍 [MyReceiveDetailPage] Loaded ${_requestItems.length} items');
          } else if (result is Map) {
            // Extract request details
            debugPrint('🔍 [MyReceiveDetailPage] Result is a Map, keys: ${result.keys.toList()}');
            final requestDetails = {
              'id': result['id'],
              'topic_uniq_id': result['topic_uniq_id'] ?? widget.requestData['topic_uniq_id'],
              'title': result['title'] ?? widget.requestData['title'],
              'product_priority': result['product_priority'],
              'employee_name': result['employee_name'] ?? widget.requestData['requestor_name'],
              'img_path': result['img_path'] ?? widget.requestData['img_path'],
              'branch_name': result['branch_name'] ?? widget.requestData['branch_name'],
              'status': result['status'] ?? widget.requestData['status'],
              'created_at': result['created_at'] ?? widget.requestData['created_at'],
            };
            
            final List<dynamic> details = result['details'] ?? [];
            debugPrint('🔍 [MyReceiveDetailPage] Raw details: $details (${details.length} items)');
            
            if (details.isEmpty) {
              debugPrint('⚠️ [MyReceiveDetailPage] Details array is empty!');
              debugPrint('🔍 [MyReceiveDetailPage] Result keys available: ${result.keys.toList()}');
            }
            
            setState(() {
              _requestDetails = requestDetails;
              _requestItems = List<Map<String, dynamic>>.from(
                  details.map((e) => Map<String, dynamic>.from(e)));
              _isLoading = false;
              _isError = false;
            });
            
            debugPrint('🔍 [MyReceiveDetailPage] Loaded ${_requestItems.length} items');
          } else {
            debugPrint('⚠️ [MyReceiveDetailPage] Unexpected result type: ${result.runtimeType}');
            throw Exception('Unexpected API response structure');
          }
        } else {
          debugPrint('⚠️ [MyReceiveDetailPage] No results in API response');
          debugPrint('🔍 [MyReceiveDetailPage] Available keys: ${data.keys.toList()}');
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
      debugPrint('🔍 [MyReceiveDetailPage] Error: $e');
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
        if (_requestItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 48,
                  color: isDarkMode ? Colors.white54 : Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'No items found',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Items list is empty',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white54 : Colors.grey[500],
                  ),
                ),
              ],
            ),
          )
        else
          ...(_requestItems.map((item) => _buildRequestedItemCard(item, isDarkMode))),
      ],
    );
  }

  Widget _buildRequestedItemCard(Map<String, dynamic> item, bool isDarkMode) {
    final String name = item['name'] ?? 'Unknown Item';
    final dynamic quantityValue = item['quantity'];
    final int quantity = (quantityValue is String) ? int.tryParse(quantityValue) ?? 0 : (quantityValue ?? 0);
    final String imageUrl = item['img_ref'] ?? ''; // API uses img_ref for item images

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
                  'for Office',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Quantity
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
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Receive Button
          Expanded(
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handleReceive,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDBB342), // Yellow
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Receive',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // Cancel Button
          Expanded(
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handleCancel,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[400], // Gray
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleReceive() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CommentModal(
          action: 'Receive',
          onConfirm: (comment) {
            Navigator.of(context).pop(); // Close comment modal
            _processReceive(comment);
          },
          onCancel: () {
            Navigator.of(context).pop(); // Close comment modal
          },
        );
      },
    );
  }

  void _handleCancel() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CommentModal(
          action: 'Cancel',
          onConfirm: (comment) {
            Navigator.of(context).pop(); // Close comment modal
            _processCancel(comment);
          },
          onCancel: () {
            Navigator.of(context).pop(); // Close comment modal
          },
        );
      },
    );
  }

  Future<void> _processReceive(String comment) async {
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

      final response = await http.put(
        Uri.parse('$baseUrl/api/inventory/received/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('🔍 [AdminBR] Receive response status: ${response.statusCode}');
      debugPrint('🔍 [AdminBR] Receive response body: ${response.body}');
      
      if (response.statusCode == 200) {
        if (mounted) {
          // Show success modal
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return SuccessModal(
                action: 'Received',
                onClose: () {
                  final nav = Navigator.of(context);
                  if (nav.canPop()) nav.pop();
                  final rootNav = Navigator.of(context, rootNavigator: true);
                  if (rootNav.canPop()) rootNav.pop(true);
                },
              );
            },
          );
        }
      } else {
        throw Exception('Failed to receive item: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error receiving items: $e'),
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

  Future<void> _processCancel(String comment) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Mock API call for AdminBR (UI/UX only)
      await Future.delayed(const Duration(seconds: 1)); // Simulate API delay
      
      // Log the comment for testing purposes
      debugPrint('🔍 [AdminBR] Cancel comment: $comment');
      
      if (mounted) {
        // Show success modal
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return SuccessModal(
              action: 'Cancelled',
              onClose: () {
                final nav = Navigator.of(context);
                if (nav.canPop()) nav.pop();
                final rootNav = Navigator.of(context, rootNavigator: true);
                if (rootNav.canPop()) rootNav.pop(true);
              },
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling request: $e'),
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

  String _getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    return imagePath.startsWith('http') ? imagePath : '$_imageBaseUrl$imagePath';
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'declined':
        return Colors.red;
      case 'exported':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
