import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:pb_hrsystem/services/inventory_approval_service.dart';
import '../inventory_app_bar.dart';
import 'requestor_detail_page.dart';

/// Approval in Branch page for AdminHQ users
/// Currently uses the same API endpoint but will be changed in the future
class ApprovalInBranchPage extends StatefulWidget {
  const ApprovalInBranchPage({super.key});

  @override
  State<ApprovalInBranchPage> createState() => _ApprovalInBranchPageState();
}

class _ApprovalInBranchPageState extends State<ApprovalInBranchPage> {
  List<Map<String, dynamic>> _approvalRequests = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';

  // Base URL for images
  final String _imageBaseUrl = 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/';

  @override
  void initState() {
    super.initState();
    _fetchApprovalRequests();
  }

  Future<void> _fetchApprovalRequests() async {
    setState(() {
      _isLoading = true;
      _isError = false;
      _errorMessage = '';
    });

    try {
      final results = await InventoryApprovalService.fetchWaitings();
      setState(() {
        _approvalRequests = results;
        _isLoading = false;
        _isError = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _openRequestorDetail(Map<String, dynamic> request) {
    // Add source field to identify this is from approval page
    final requestWithSource = Map<String, dynamic>.from(request);
    requestWithSource['source'] = 'approval';
    
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RequestorDetailPage(
          requestData: requestWithSource,
        ),
      ),
    ).then((changed) {
      if (changed == true) {
        _fetchApprovalRequests();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        final isDarkMode = themeNotifier.isDarkMode;

        return Scaffold(
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          appBar: const InventoryAppBar(
            title: 'Approval in Branch',
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
                            'Error loading approval requests',
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
                            onPressed: _fetchApprovalRequests,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDBB342),
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
                                Icons.swap_horiz,
                                size: 64,
                                color: isDarkMode ? Colors.white54 : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No branch approval requests',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'All branch requests have been processed',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchApprovalRequests,
                          color: const Color(0xFFDBB342),
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
    final String title = request['title'] ?? 'No Title';
    final String requestorName = request['requestor_name'] ?? 'Unknown';
    final String status = request['status'] ?? 'Unknown';
    final String createdAt = request['created_at'] ?? '';
    final String type = 'for Office'; // Fixed as specified
    final String rawImageUrl = request['img_path'] ?? request['img_name'] ?? '';
    final String imageUrl = rawImageUrl.isNotEmpty
        ? (rawImageUrl.startsWith('http') ? rawImageUrl : '$_imageBaseUrl$rawImageUrl')
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: InkWell(
        onTap: () => _openRequestorDetail(request),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Request Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.pink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.swap_horiz,
                  color: Colors.pink,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Request Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.pink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submitted on ${_formatDate(createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Type: $type',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Status: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Supervisor Pending ...',
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
              // Requestor Profile Picture
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.pink.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.person,
                            color: isDarkMode ? Colors.white : Colors.grey[600],
                            size: 24,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          color: isDarkMode ? Colors.white : Colors.grey[600],
                          size: 24,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
}
