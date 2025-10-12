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

/// Requestor Detail page for AdminHQ users
/// Displays detailed information about a request and allows receive/cancel actions
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

  // Base URL for images
  final String _imageBaseUrl = 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/';

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 [RequestorDetailPage] initState called with requestData: ${widget.requestData}');
    debugPrint('🔍 [RequestorDetailPage] topic_uniq_id: ${widget.requestData['topic_uniq_id']}');
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

              // Get the topic ID from the request data - check both possible field names
        String topicUid = widget.requestData['topic_uniq_id'] ?? 
                         widget.requestData['topicid'] ?? '';
        if (topicUid.isEmpty) {
          throw Exception('No topic UID found in request data');
        }

      debugPrint('🔍 [RequestorDetailPage] Fetching details for topic: $topicUid');
      debugPrint('🔍 [RequestorDetailPage] API URL: $baseUrl/api/inventory/request_topic/$topicUid');

      final response = await http.get(
        Uri.parse('$baseUrl/api/inventory/request_topic/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('🔍 [RequestorDetailPage] Response status: ${response.statusCode}');
      debugPrint('🔍 [RequestorDetailPage] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null) {
          final result = data['results'];
          
          // Extract request details and items
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
          
          debugPrint('🔍 [RequestorDetailPage] Raw details: $details');
          
          setState(() {
            _requestDetails = requestDetails;
            _requestItems = List<Map<String, dynamic>>.from(
                details.map((e) => Map<String, dynamic>.from(e)));
            _isLoading = false;
            _isError = false;
          });
          
          debugPrint('🔍 [RequestorDetailPage] Loaded ${_requestItems.length} items');
          for (int i = 0; i < _requestItems.length; i++) {
            final item = _requestItems[i];
            debugPrint('🔍 [RequestorDetailPage] Item $i: name="${item['name']}", img_ref="${item['img_ref']}"');
          }
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

  Future<void> _receiveItem() async {
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

      // Get the topic ID from the request data - check both possible field names
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

      debugPrint('🔍 [RequestorDetailPage] Receive response status: ${response.statusCode}');
      debugPrint('🔍 [RequestorDetailPage] Receive response body: ${response.body}');
      
      // Accept 200 (OK) as success
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item received successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        throw Exception('Failed to receive item: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error receiving item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _cancelItem() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Request'),
          content: const Text('Are you sure you want to cancel this request?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Request cancelled successfully'),
                    backgroundColor: Colors.orange,
                  ),
                );
                // Don't navigate back, just show confirmation
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  void _approveItem() {
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

  void _declineItem() {
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

      if (response.statusCode == 200) {
        // Show success modal
        if (mounted) {
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
        debugPrint('🔍 [AdminHQ] Approval failed with status: ${response.statusCode}');
        debugPrint('🔍 [AdminHQ] Response body: ${response.body}');
        
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

      if (response.statusCode == 200) {
        // Show success modal
        if (mounted) {
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
        debugPrint('🔍 [AdminHQ] Decline failed with status: ${response.statusCode}');
        debugPrint('🔍 [AdminHQ] Response body: ${response.body}');
        
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

  // Helper methods for button logic
  VoidCallback? _getLeftButtonAction() {
    final String source = widget.requestData['source'] ?? 'approval';
    switch (source) {
      case 'my_receive':
        return _receiveItem;
      case 'approval':
        return _approveItem;
      default:
        return _approveItem;
    }
  }

  Color _getLeftButtonColor() {
    final String source = widget.requestData['source'] ?? 'approval';
    switch (source) {
      case 'my_receive':
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
      case 'my_receive':
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
      case 'my_receive':
        return _cancelItem;
      case 'approval':
        return _declineItem;
      default:
        return _declineItem;
    }
  }

  Color _getRightButtonColor() {
    final String source = widget.requestData['source'] ?? 'approval';
    switch (source) {
      case 'my_receive':
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
      case 'my_receive':
        return 'Cancel';
      case 'approval':
        return 'Decline';
      default:
        return 'Decline';
    }
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
                  : Column(
                      children: [
                        // Requestor Information Section
                        _buildRequestorInfo(isDarkMode),
                        const SizedBox(height: 16),
                        // Requested Items List
                        Expanded(
                          child: _buildRequestedItemsList(isDarkMode),
                        ),
                        // Feedback Section (if final status)
                        if (_isFinalStatus)
                          FutureBuilder<Widget>(
                            future: _buildFeedbackSection(isDarkMode),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              return snapshot.data ?? const SizedBox.shrink();
                            },
                          ),
                        // Action Buttons
                        _buildActionButtons(isDarkMode),
                      ],
                    ),
        );
      },
    );
  }

  Widget _buildRequestorInfo(bool isDarkMode) {
    // Debug: Log available fields
    debugPrint('🔍 [RequestorDetailPage] Available fields in requestData: ${widget.requestData.keys.toList()}');
    debugPrint('🔍 [RequestorDetailPage] employee_name: ${widget.requestData['employee_name']}');
    debugPrint('🔍 [RequestorDetailPage] requestor_name: ${widget.requestData['requestor_name']}');
    debugPrint('🔍 [RequestorDetailPage] full_name: ${widget.requestData['full_name']}');
    
    // Check multiple possible field names for employee name
    final String requestorName = widget.requestData['employee_name'] ?? 
                                widget.requestData['requestor_name'] ?? 
                                widget.requestData['full_name'] ?? 
                                'Unknown';
    final String createdAt = widget.requestData['created_at'] ?? '';
    final String status = widget.requestData['status'] ?? 'Unknown';
    final String rawImageUrl = widget.requestData['img_path'] ?? widget.requestData['img_name'] ?? '';
    final String imageUrl = rawImageUrl.isNotEmpty
        ? (rawImageUrl.startsWith('http') ? rawImageUrl : '$_imageBaseUrl$rawImageUrl')
        : '';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.pink.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Requestor Profile Picture
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.pink.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person,
                        color: isDarkMode ? Colors.white : Colors.grey[600],
                        size: 32,
                      ),
                    )
                  : Icon(
                      Icons.person,
                      color: isDarkMode ? Colors.white : Colors.grey[600],
                      size: 32,
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
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Cat Icon (as shown in the image)
          Icon(
            Icons.pets,
            size: 32,
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestedItemsList(bool isDarkMode) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _requestItems.length,
      itemBuilder: (context, index) {
        final item = _requestItems[index];
        return _buildRequestedItemCard(item, isDarkMode);
      },
    );
  }

  Widget _buildRequestedItemCard(Map<String, dynamic> item, bool isDarkMode) {
    final String name = item['name'] ?? 'Unknown Item';
    final String type = 'for Office'; // Fixed type
    final String imageUrl = item['img_ref'] ?? ''; // Use img_ref from API

    debugPrint('🔍 [RequestorDetailPage] Building item card: name="$name", img_ref="$imageUrl"');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Item Image
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[300],
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
                  name, // Use name instead of description
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
                  type,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDarkMode) {
    // Check which page this detail view is from
    final String source = widget.requestData['source'] ?? 'approval';
    
    // Don't show any buttons for My Request page
    if (source == 'my_request') {
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
      case 'received':
        return Colors.green;
      case 'decline':
      case 'declined':
        return Colors.red;
      case 'rejected':
        return Colors.red;
      case 'exported':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  bool get _isFinalStatus {
    final s = (_requestDetails['status'] ?? '').toString().toLowerCase();
    return s.contains('approved') || s.contains('decline') || s.contains('declined') || s.contains('rejected') || s.contains('received') || s.contains('exported');
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
      
      debugPrint('🔍 [AdminHQ RequestorDetail] Fetching feedback for topic: $topicUid');
      final response = await http.get(
        Uri.parse('$baseUrl/api/inventory/request_reply/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      debugPrint('🔍 [AdminHQ RequestorDetail] Feedback response status: ${response.statusCode}');
      debugPrint('🔍 [AdminHQ RequestorDetail] Feedback response body: ${response.body}');
      
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
      final String approverImageUrl = _getImageUrl(imgPath);
      final String requesterImageUrl = _getImageUrl(_requestDetails['img_path']);
      
      debugPrint('🔍 [AdminHQ RequestorDetail] Approver image URL: $approverImageUrl');
      debugPrint('🔍 [AdminHQ RequestorDetail] Requester image URL: $requesterImageUrl');
      debugPrint('🔍 [AdminHQ RequestorDetail] Position name: $positionName');
      debugPrint('🔍 [AdminHQ RequestorDetail] Decide: $decide');
      debugPrint('🔍 [AdminHQ RequestorDetail] Comment: $comment');

      return Container(
        margin: const EdgeInsets.all(16),
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
            // Profile images with arrow (Approver -> Requester)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Approver image with position (LEFT)
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
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint('🔍 [AdminHQ] Approver image error: $error');
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
                // Requester image (RIGHT)
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
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint('🔍 [AdminHQ] Requester image error: $error');
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
                      'Requester',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
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
      debugPrint('🔍 [AdminHQ RequestorDetail] Feedback error: $e');
      return const SizedBox.shrink();
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
    return imagePath.startsWith('http') ? imagePath : '$_imageBaseUrl$imagePath';
  }
}
