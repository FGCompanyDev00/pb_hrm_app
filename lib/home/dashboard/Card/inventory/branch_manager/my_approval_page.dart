import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:pb_hrsystem/services/inventory_approval_service.dart';
import '../inventory_app_bar.dart';
import 'request_detail_page.dart';

/// My Approval page for Branch_manager role
/// Displays requests that the branch manager needs to approve
class MyApprovalPage extends StatefulWidget {
  const MyApprovalPage({super.key});

  @override
  State<MyApprovalPage> createState() => _MyApprovalPageState();
}

class _MyApprovalPageState extends State<MyApprovalPage> {
  List<Map<String, dynamic>> _approvalRequests = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';

  // Base URL for images
  final String _imageBaseUrl = 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/';

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 [BranchManager MyApproval] initState called');
    _fetchApprovalRequests();
  }

  Future<void> _fetchApprovalRequests() async {
    debugPrint('🔍 [BranchManager MyApproval] Starting to fetch approval requests...');
    
    setState(() {
      _isLoading = true;
      _isError = false;
      _errorMessage = '';
    });

    try {
      debugPrint('🔍 [BranchManager MyApproval] Calling InventoryApprovalService.fetchBranchManagerWaitings()...');
      final results = await InventoryApprovalService.fetchBranchManagerWaitings();
      
      debugPrint('🔍 [BranchManager MyApproval] API call completed');
      debugPrint('🔍 [BranchManager MyApproval] Results count: ${results.length}');
      
      if (results.isNotEmpty) {
        debugPrint('🔍 [BranchManager MyApproval] First result sample:');
        debugPrint('   - Keys: ${results[0].keys.toList()}');
        debugPrint('   - Title: ${results[0]['title']}');
        debugPrint('   - Status: ${results[0]['status']}');
        debugPrint('   - Requestor: ${results[0]['requestor_name']}');
        debugPrint('   - Topic UID: ${results[0]['topic_uniq_id'] ?? results[0]['topicid']}');
      } else {
        debugPrint('⚠️ [BranchManager MyApproval] Results list is empty');
      }
      
      setState(() {
        _approvalRequests = results;
        _isLoading = false;
        _isError = false;
      });
      
      debugPrint('✅ [BranchManager MyApproval] State updated successfully');
      debugPrint('   - _approvalRequests.length: ${_approvalRequests.length}');
      debugPrint('   - _isLoading: $_isLoading');
      debugPrint('   - _isError: $_isError');
    } catch (e, stackTrace) {
      debugPrint('❌ [BranchManager MyApproval] Error occurred:');
      debugPrint('   - Error: $e');
      debugPrint('   - StackTrace: $stackTrace');
      
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = e.toString();
      });
      
      debugPrint('❌ [BranchManager MyApproval] Error state set:');
      debugPrint('   - _isLoading: $_isLoading');
      debugPrint('   - _isError: $_isError');
      debugPrint('   - _errorMessage: $_errorMessage');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 [BranchManager MyApproval] build() called');
    debugPrint('   - _isLoading: $_isLoading');
    debugPrint('   - _isError: $_isError');
    debugPrint('   - _approvalRequests.length: ${_approvalRequests.length}');
    debugPrint('   - _errorMessage: $_errorMessage');
    
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        final isDarkMode = themeNotifier.isDarkMode;
        
        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
          appBar: InventoryAppBar(
            title: 'My Approval',
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
                            'Error loading approval requests',
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
                            onPressed: _fetchApprovalRequests,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDBB342),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _approvalRequests.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.approval_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No approval requests',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'There are no requests waiting for your approval',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchApprovalRequests,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _approvalRequests.length,
                            itemBuilder: (context, index) {
                              final request = _approvalRequests[index];
                              return _buildApprovalCard(request, isDarkMode);
                            },
                          ),
                        ),
        );
      },
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> request, bool isDarkMode) {
    debugPrint('🔍 [BranchManager MyApproval] Building approval card');
    debugPrint('   - Request keys: ${request.keys.toList()}');
    
    final String title = request['title'] ?? 'No Title';
    final String requestorName = request['requestor_name'] ?? 'Unknown';
    final String status = request['status'] ?? 'Unknown';
    final String createdAt = request['created_at'] ?? '';
    final String type = 'for Office'; // Fixed as specified
    final String rawImageUrl = request['img_path'] ?? request['img_name'] ?? '';
    final String imageUrl = rawImageUrl.isNotEmpty
        ? (rawImageUrl.startsWith('http') ? rawImageUrl : '$_imageBaseUrl$rawImageUrl')
        : '';
    
    debugPrint('   - Title: $title');
    debugPrint('   - Requestor: $requestorName');
    debugPrint('   - Status: $status');
    debugPrint('   - Image URL: ${imageUrl.isNotEmpty ? "Set" : "Empty"}');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.3), // Green border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openRequestDetail(request),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Request Icon - Pink as per design
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withOpacity(0.1), // Pink background
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.search,
                    color: Color(0xFF9C27B0), // Pink icon
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Request Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9C27B0), // Pink text
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Submitted on ${_formatDate(createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Type: $type',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Status: $status',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Profile Picture
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF4CAF50), // Green border
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
                                  color: const Color(0xFF4CAF50),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.person,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                          )
                        : Icon(
                            Icons.person,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openRequestDetail(Map<String, dynamic> request) {
    debugPrint('🔍 [BranchManager MyApproval] Opening request detail');
    debugPrint('   - Request keys: ${request.keys.toList()}');
    debugPrint('   - Title: ${request['title']}');
    debugPrint('   - Topic UID: ${request['topic_uniq_id'] ?? request['topicid']}');
    
    // Add source field to identify this is from approval page
    final requestWithSource = Map<String, dynamic>.from(request);
    requestWithSource['source'] = 'approval';
    
    debugPrint('   - Source set to: approval');
    
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RequestDetailPage(
          requestData: requestWithSource,
        ),
      ),
    ).then((changed) {
      debugPrint('🔍 [BranchManager MyApproval] Returned from detail page');
      debugPrint('   - Changed: $changed');
      if (changed == true) {
        debugPrint('   - Refreshing approval requests list...');
        _fetchApprovalRequests();
      }
    });
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year},${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'manager pending':
        return Colors.green; // Green for Manager Pending as per design
      case 'decline':
        return Colors.red;
      default:
        return Colors.green;
    }
  }
}
