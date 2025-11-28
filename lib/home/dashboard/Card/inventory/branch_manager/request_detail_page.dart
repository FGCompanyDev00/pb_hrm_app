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
  bool _isFeedbackExpanded = false;
  final TextEditingController _titleController = TextEditingController();

  // Base URL for images
  final String _imageBaseUrl = 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/';

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 [RequestDetailPage] initState called with requestData: ${widget.requestData}');
    _loadRequestDetails();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
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
          
          // Initialize title controller
          _titleController.text = result['title'] ?? '';
          
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
            title: _getPageTitle(),
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
                          if (_canEditItems) ...[
                            const SizedBox(height: 16),
                            _buildTitleField(isDarkMode),
                          ],
                          const SizedBox(height: 16),
                          _buildRequestedItemsSection(isDarkMode),
                          // Feedback Section (if final status)
                          if (_isFinalStatus) ...[
                            const SizedBox(height: 16),
                            _buildFeedbackSectionWidget(isDarkMode),
                          ],
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
        ...List.generate(_requestItems.length, (index) => _buildRequestedItemCard(_requestItems[index], isDarkMode, index)),
      ],
    );
  }

  Widget _buildRequestedItemCard(Map<String, dynamic> item, bool isDarkMode, int index) {
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
          // Quantity controls or display
          _canEditItems
              ? Row(
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
                )
              : Container(
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

  Widget _buildTitleField(bool isDarkMode) {
    return Container(
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

  Widget _buildActionButtons(bool isDarkMode) {
    // Check which page this detail view is from
    final String source = widget.requestData['source'] ?? 'approval';
    
    // Don't show any buttons for view-only pages
    if (source == 'view_only') {
      return const SizedBox.shrink(); // Hide buttons completely
    }
    
    // For Manager Pending status, show Update and Cancel buttons
    if (_canEditItems) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _submitUpdate,
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
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Update',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton(
                onPressed: _isProcessing
                    ? null
                    : () async {
                        String? comment;
                        await showDialog(
                          context: context,
                          builder: (context) => CommentModal(
                            action: 'Cancel',
                            onConfirm: (c) {
                              comment = c;
                              Navigator.of(context).pop();
                            },
                            onCancel: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        );
                        if ((comment ?? '').trim().isNotEmpty) {
                          await _submitCancel((comment ?? '').trim());
                        }
                      },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDBB342), width: 2),
                  foregroundColor: const Color(0xFFDBB342),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isProcessing ? 'Cancelling...' : 'Cancel',
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
    
    // For other statuses, show Approve/Decline buttons
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
        debugPrint('🔍 [Branch_manager] Approval failed with status: ${response.statusCode}');
        debugPrint('🔍 [Branch_manager] Response body: ${response.body}');
        
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

      // Make API call to decline with comment
      final response = await http.put(
        Uri.parse('$baseUrl/api/inventory/decline/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'comment': comment,
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
        debugPrint('🔍 [Branch_manager] Decline failed with status: ${response.statusCode}');
        debugPrint('🔍 [Branch_manager] Response body: ${response.body}');
        
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
    final statusStr = status.toLowerCase().trim().replaceAll(RegExp(r'[.\s]+'), ' ');
    if (statusStr.contains('approved')) {
      return Colors.green;
    } else if (statusStr.contains('manager pending')) {
      return Colors.orange; // Orange for Manager Pending
    } else if (statusStr.contains('decline') || statusStr.contains('rejected')) {
      return Colors.red;
    } else if (statusStr.contains('exported')) {
      return Colors.blue;
    } else if (statusStr.contains('pending')) {
      return Colors.orange;
    }
    return Colors.orange;
  }

  String _getPageTitle() {
    if (_canEditItems) {
      return 'My Request';
    }
    return 'Requestor Detail';
  }

  bool get _canEditItems {
    final statusStr = (_requestDetails['status'] ?? '').toString();
    final s = statusStr.toLowerCase().trim().replaceAll(RegExp(r'[.\s]+'), ' ');
    // Check for manager pending status (with or without dots, case insensitive)
    final canEdit = s.contains('manager pending');
    debugPrint('🔍 [BranchManager RequestDetail] Status: "$statusStr", Normalized: "$s", CanEditItems: $canEdit');
    return canEdit;
  }

  bool get _isFinalStatus {
    final statusStr = (_requestDetails['status'] ?? '').toString();
    final s = statusStr.toLowerCase().trim().replaceAll(RegExp(r'[.\s]+'), ' ');
    final isFinal = s.contains('approved') || 
                    s.contains('cancel') || 
                    s.contains('cancelled') || 
                    s.contains('rejected') || 
                    s.contains('decline') || 
                    s.contains('declined');
    debugPrint('🔍 [BranchManager RequestDetail] Status: "$statusStr", Normalized: "$s", IsFinalStatus: $isFinal');
    return isFinal;
  }

  void _incrementQuantity(int index) {
    if (index < 0 || index >= _requestItems.length) return;
    setState(() {
      final current = (_requestItems[index]['quantity'] is String)
          ? int.tryParse(_requestItems[index]['quantity']) ?? 0
          : (_requestItems[index]['quantity'] ?? 0);
      _requestItems[index]['quantity'] = current + 1;
    });
  }

  void _decrementQuantity(int index) {
    if (index < 0 || index >= _requestItems.length) return;
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
    if (index < 0 || index >= _requestItems.length) return;
    setState(() {
      _requestItems.removeAt(index);
    });
  }

  Future<void> _submitUpdate() async {
    if (_isProcessing) return;
    
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
                       widget.requestData['topicid'] ?? 
                       _requestDetails['topic_uniq_id'] ?? '';
      if (topicUid.isEmpty) {
        throw Exception('No topic UID found in request data');
      }

      // Prepare details array with barcode and quantity
      final List<Map<String, dynamic>> details = _requestItems
          .where((item) {
            final qty = (item['quantity'] is String)
                ? int.tryParse(item['quantity']) ?? 0
                : (item['quantity'] ?? 0);
            return qty > 0;
          })
          .map((item) {
            final qty = (item['quantity'] is String)
                ? int.tryParse(item['quantity']) ?? 0
                : (item['quantity'] ?? 0);
            return {
              'barcode': item['barcode'] ?? '',
              'quantity': qty,
            };
          })
          .toList();

      if (details.isEmpty) {
        throw Exception('Please add at least one item with quantity > 0');
      }

      final requestBody = {
        'title': _titleController.text.trim(),
        'details': details,
        'confirmed': 0, // Default to 0, can be updated based on business logic
      };

      debugPrint('🔍 [BranchManager RequestDetail] Update request body: $requestBody');

      final response = await http.put(
        Uri.parse('$baseUrl/api/inventory/request_topic/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('🔍 [BranchManager RequestDetail] Update response status: ${response.statusCode}');
      debugPrint('🔍 [BranchManager RequestDetail] Update response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          // Show success modal
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return SuccessModal(
                action: 'Updated',
                onClose: () {
                  // Close success modal and navigate back
                  Navigator.of(context).pop(); // Close success modal
                  // Use a small delay to ensure modal is closed before popping page
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) {
                      final nav = Navigator.of(context);
                      if (nav.canPop()) {
                        nav.pop(true); // Go back to previous page with refresh flag
                      }
                    }
                  });
                },
              );
            },
          );
        }
      } else {
        throw Exception('Failed to update request: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating request: $e'),
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

  Future<void> _submitCancel(String comment) async {
    if (_isProcessing) return;
    
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
                       widget.requestData['topicid'] ?? 
                       _requestDetails['topic_uniq_id'] ?? '';
      if (topicUid.isEmpty) {
        throw Exception('No topic UID found in request data');
      }

      final requestBody = {
        'comment': comment.trim(),
      };

      debugPrint('🔍 [BranchManager RequestDetail] Cancel request body: $requestBody');

      final response = await http.put(
        Uri.parse('$baseUrl/api/inventory/request-cancel/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('🔍 [BranchManager RequestDetail] Cancel response status: ${response.statusCode}');
      debugPrint('🔍 [BranchManager RequestDetail] Cancel response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          // Show success modal
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return SuccessModal(
                action: 'Cancelled',
                onClose: () {
                  // Close success modal and navigate back
                  Navigator.of(context).pop(); // Close success modal
                  // Use a small delay to ensure modal is closed before popping page
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) {
                      final nav = Navigator.of(context);
                      if (nav.canPop()) {
                        nav.pop(true); // Go back to previous page with refresh flag
                      }
                    }
                  });
                },
              );
            },
          );
        }
      } else {
        throw Exception('Failed to cancel request: ${response.statusCode}');
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
                      final String decide = feedback['decide'] ?? '';
                      final String createdAt = feedback['created_at'] ?? '';
                      final String employeeName = feedback['employee_name'] ?? 'Unknown';
                      final String employeeSurname = feedback['employee_surname'] ?? '';
                      final String imgPath = feedback['img_path'] ?? '';
                      final String positionName = feedback['position_name'] ?? '';
                      
                      final String approverName = '$employeeName $employeeSurname'.trim();
                      final String approverImageUrl = _getImageUrl(imgPath);
                      
                      // Get requester image from request details
                      final String requesterImgPath = _requestDetails['img_path'] ?? '';
                      final String requesterImgName = _requestDetails['img_name'] ?? '';
                      final String requesterImageUrl = _getImageUrl(
                        requesterImgPath.isNotEmpty ? requesterImgPath : requesterImgName
                      );

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
                            // Profile images with arrow (Approval person -> Arrow -> Current user)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Approval person image
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFDBB342),
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
                                              color: Color(0xFFDBB342),
                                              size: 20,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person,
                                            color: Color(0xFFDBB342),
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
                                // Current user (requester) image
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFDBB342),
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
                                              color: Color(0xFFDBB342),
                                              size: 20,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person,
                                            color: Color(0xFFDBB342),
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
                            // Status
                            if (decide.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getDecideColor(decide),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  decide,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
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
      final topicUid = _requestDetails['topic_uniq_id'] ?? 
                       widget.requestData['topic_uniq_id'] ?? 
                       widget.requestData['topicid'] ?? '';
      
      if (token == null || baseUrl == null || topicUid == null || topicUid.isEmpty) {
        debugPrint('⚠️ [BranchManager RequestDetail] Missing token, baseUrl, or topicUid for feedback');
        return [];
      }
      
      debugPrint('🔍 [BranchManager RequestDetail] Fetching feedback for topic: $topicUid');
      final response = await http.get(
        Uri.parse('$baseUrl/api/inventory/request_reply/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      debugPrint('🔍 [BranchManager RequestDetail] Feedback response status: ${response.statusCode}');
      debugPrint('🔍 [BranchManager RequestDetail] Feedback response body: ${response.body}');
      
      if (response.statusCode != 200) {
        debugPrint('⚠️ [BranchManager RequestDetail] Feedback API returned status: ${response.statusCode}');
        return [];
      }
      
      final decoded = jsonDecode(response.body);
      final List<dynamic> feedbackList = (decoded is List) 
          ? decoded 
          : (decoded['results'] ?? []);
      
      debugPrint('✅ [BranchManager RequestDetail] Fetched ${feedbackList.length} feedback items');
      return feedbackList.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e, stackTrace) {
      debugPrint('❌ [BranchManager RequestDetail] Feedback error: $e');
      debugPrint('   StackTrace: $stackTrace');
      return [];
    }
  }

  Color _getDecideColor(String decide) {
    final decideStr = decide.toLowerCase().trim();
    if (decideStr.contains('approved') || decideStr.contains('checked') || decideStr.contains('received')) {
      return Colors.green;
    } else if (decideStr.contains('edit')) {
      return Colors.orange;
    } else if (decideStr.contains('declined') || decideStr.contains('rejected') || decideStr.contains('cancel')) {
      return Colors.red;
    }
    return Colors.blue;
  }
}
