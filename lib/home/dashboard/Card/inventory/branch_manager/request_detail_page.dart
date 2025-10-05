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

/// Request Detail page for Branch_manager role
/// Displays detailed information about a request and allows appropriate actions
class RequestDetailPage extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const RequestDetailPage({
    super.key,
    required this.requestData,
  });

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage> {
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
    debugPrint('🔍 [RequestDetailPage] initState called with requestData: ${widget.requestData}');
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

      debugPrint('🔍 [RequestDetailPage] Fetching details for topic: $topicUid');
      debugPrint('🔍 [RequestDetailPage] API URL: $baseUrl/api/inventory/request_topic/$topicUid');

      final response = await http.get(
        Uri.parse('$baseUrl/api/inventory/request_topic/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('🔍 [RequestDetailPage] Response status: ${response.statusCode}');
      debugPrint('🔍 [RequestDetailPage] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null) {
          final result = data['results'];
          
          // Extract request details
          final requestDetails = {
            'id': result['id'],
            'topic_uniq_id': result['topic_uniq_id'],
            'title': result['title'],
            'product_priority': result['product_priority'],
            'employee_name': result['employee_name'], // API uses employee_name
            'img_path': result['img_path'], // Full URL from API
            'branch_name': result['branch_name'],
            'status': result['status'],
            'created_at': result['created_at'],
          };
          
          final List<dynamic> details = result['details'] ?? [];
          
          debugPrint('🔍 [RequestDetailPage] Raw details: $details');
          
          setState(() {
            _requestDetails = requestDetails;
            _requestItems = List<Map<String, dynamic>>.from(
                details.map((e) => Map<String, dynamic>.from(e)));
            _isLoading = false;
            _isError = false;
          });
          
          debugPrint('🔍 [RequestDetailPage] Loaded ${_requestItems.length} items');
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
      debugPrint('🔍 [RequestDetailPage] Error: $e');
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
                            onPressed: _loadRequestDetails,
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
                color: const Color(0xFFDBB342), // Yellow border
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
    // Check which page this detail view is from
    final String source = widget.requestData['source'] ?? 'approval';
    
    // Don't show any buttons for view-only pages
    if (source == 'view_only') {
      return const SizedBox.shrink(); // Hide buttons completely
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Left Button - Approve (for approvals) or Receive (for My Receive)
          Expanded(
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _getLeftButtonAction(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getLeftButtonColor(),
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
                  : Text(
                      _getLeftButtonText(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // Right Button - Decline (for approvals) or Cancel (for My Receive)
          Expanded(
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _getRightButtonAction(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getRightButtonColor(),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _getRightButtonText(),
                style: const TextStyle(
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

  // Helper methods for button logic
  VoidCallback? _getLeftButtonAction() {
    final String source = widget.requestData['source'] ?? 'approval';
    switch (source) {
      case 'receive':
        return _handleReceive;
      case 'approval':
        return _handleApprove;
      default:
        return _handleApprove;
    }
  }

  Color _getLeftButtonColor() {
    final String source = widget.requestData['source'] ?? 'approval';
    switch (source) {
      case 'receive':
        return const Color(0xFFDBB342); // Yellow
      case 'approval':
        return Colors.green;
      default:
        return Colors.green;
    }
  }

  String _getLeftButtonText() {
    final String source = widget.requestData['source'] ?? 'approval';
    switch (source) {
      case 'receive':
        return 'Receive';
      case 'approval':
        return 'Approve';
      default:
        return 'Approve';
    }
  }

  VoidCallback? _getRightButtonAction() {
    final String source = widget.requestData['source'] ?? 'approval';
    switch (source) {
      case 'receive':
        return _handleCancel;
      case 'approval':
        return _handleDecline;
      default:
        return _handleDecline;
    }
  }

  Color _getRightButtonColor() {
    final String source = widget.requestData['source'] ?? 'approval';
    switch (source) {
      case 'receive':
        return Colors.grey[400]!;
      case 'approval':
        return Colors.red;
      default:
        return Colors.red;
    }
  }

  String _getRightButtonText() {
    final String source = widget.requestData['source'] ?? 'approval';
    switch (source) {
      case 'receive':
        return 'Cancel';
      case 'approval':
        return 'Decline';
      default:
        return 'Decline';
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
    Navigator.of(context).pop(); // Go back to previous page
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

      // Make API call to approve with comment
      final response = await http.put(
        Uri.parse('$baseUrl/api/inventory/approve/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'comment': comment,
          'action': 'approve',
        }),
      );

      debugPrint('🔍 [Branch_manager] Approval response status: ${response.statusCode}');
      debugPrint('🔍 [Branch_manager] Approval response body: ${response.body}');
      
      if (response.statusCode == 200) {
        if (mounted) {
          // Show success modal
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return SuccessModal(
                action: 'Approved',
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
        throw Exception('Failed to approve request: ${response.statusCode}');
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

      // Make API call to decline with comment
      final response = await http.put(
        Uri.parse('$baseUrl/api/inventory/decline/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'comment': comment,
          'action': 'decline',
        }),
      );

      debugPrint('🔍 [Branch_manager] Decline response status: ${response.statusCode}');
      debugPrint('🔍 [Branch_manager] Decline response body: ${response.body}');
      
      if (response.statusCode == 200) {
        if (mounted) {
          // Show success modal
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return SuccessModal(
                action: 'Declined',
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
        throw Exception('Failed to decline request: ${response.statusCode}');
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

      debugPrint('🔍 [Branch_manager] Receive response status: ${response.statusCode}');
      debugPrint('🔍 [Branch_manager] Receive response body: ${response.body}');
      
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
      case 'decline':
        return Colors.red;
      case 'exported':
        return Colors.blue;
      case 'manager pending':
        return Colors.green; // Green for Manager Pending as per design
      default:
        return Colors.orange;
    }
  }
}
