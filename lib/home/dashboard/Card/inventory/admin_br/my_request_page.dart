import 'package:flutter/material.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../inventory_app_bar.dart';
import 'my_request_detail_page.dart';

/// My Request page for AdminBR users
/// Displays a list of inventory requests made by the current user
class MyRequestPage extends StatefulWidget {
  const MyRequestPage({super.key});

  @override
  State<MyRequestPage> createState() => _MyRequestPageState();
}

class _MyRequestPageState extends State<MyRequestPage> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';

  // Base URL for images
  final String _imageBaseUrl = 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/';

  @override
  void initState() {
    super.initState();
    _fetchMyRequests();
  }

  /// Fetch inventory requests for the current user
  Future<void> _fetchMyRequests() async {
    try {
      setState(() {
        _isLoading = true;
        _isError = false;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final baseUrl = dotenv.env['BASE_URL'];

      if (token == null || baseUrl == null) {
        throw Exception('Token or base URL not found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/inventory/request/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null) {
          final requests = List<Map<String, dynamic>>.from(data['results']);
          
          // Debug: Log first request to see available fields
          if (requests.isNotEmpty) {
            debugPrint('🔍 [MyRequestPage] First request data: ${requests[0]}');
            debugPrint('🔍 [MyRequestPage] First request img_path: ${requests[0]['img_path']}');
            debugPrint('🔍 [MyRequestPage] First request img_name: ${requests[0]['img_name']}');
          }
          
          setState(() {
            _requests = requests;
            _isLoading = false;
          });
        } else {
          setState(() {
            _requests = [];
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to fetch requests: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Get status color based on status text
  Color _getStatusColor(String status) {
    debugPrint('🔍 [MyRequestPage] Status: "$status"');
    
    switch (status.toLowerCase()) {
      // Pending/Processing statuses - Yellow/Orange
      case 'supervisor pending...':
      case 'supervisor pending':
      case 'manager pending':
      case 'manager pending...':
      case 'pending':
      case 'waiting':
        return Colors.orange;
      
      // Approved/Received statuses - Green
      case 'approved':
      case 'received':
      case 'completed':
      case 'checked':
        return Colors.green;
      
      // Declined/Rejected statuses - Red
      case 'decline':
      case 'declined':
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      
      // Default - Orange for unknown statuses
      default:
        return Colors.orange;
    }
  }

  void _openRequestDetail(Map<String, dynamic> request) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => MyRequestDetailPage(
          requestData: request,
        ),
      ),
    ).then((changed) {
      if (changed == true) {
        _fetchMyRequests();
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
                          const Icon(Icons.error, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading requests',
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
                            onPressed: _fetchMyRequests,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDBB342),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _requests.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2,
                                size: 64,
                                color: isDarkMode ? Colors.white54 : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No requests found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You haven\'t made any inventory requests yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchMyRequests,
                          color: const Color(0xFFDBB342),
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: MediaQuery.of(context).size.width < 360 ? 10 : 12,
                              vertical: 8,
                            ),
                            itemCount: _requests.length,
                            itemBuilder: (context, index) {
                              final request = _requests[index];
                              return _buildRequestCard(request, isDarkMode);
                            },
                          ),
                        ),
        );
      },
    );
  }

  /// Get image URL by combining img_path and img_name for S3 pre-signed URLs
  String _getImageUrl(String? imagePath, [String? imageName]) {
    // If both are provided, check if we need to combine them
    if (imagePath != null && imagePath.isNotEmpty && 
        imageName != null && imageName.isNotEmpty) {
      // If img_path is full URL and img_name is query string, combine them
      if ((imagePath.startsWith('http://') || imagePath.startsWith('https://')) &&
          imageName.startsWith('?')) {
        // Combine: full URL + query string
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

  Widget _buildRequestCard(Map<String, dynamic> request, bool isDarkMode) {
    final String title = request['title'] ?? 'No Title';
    final String status = request['status'] ?? 'Unknown';
    final String createdAt = request['created_at'] ?? '';
    final String type = 'for Office'; // Fixed as specified
    
    // Check multiple possible field names for image path
    final String imgPath = request['img_path'] ?? 
                          request['employee_img_path'] ?? 
                          request['requestor_img_path'] ?? 
                          request['profile_img_path'] ?? 
                          '';
    
    // Check multiple possible field names for image name/query string
    final String imgName = request['img_name'] ?? 
                           request['employee_img_name'] ?? 
                           request['requestor_img_name'] ?? 
                           request['profile_img_name'] ?? 
                           '';
    
    final String imageUrl = _getImageUrl(imgPath, imgName);
    
    // Debug logging for image URL
    debugPrint('🔍 [MyRequestPage] Request "${title}" - img_path: "$imgPath", img_name: "$imgName", final URL: "$imageUrl"');
    debugPrint('🔍 [MyRequestPage] Request keys: ${request.keys.toList()}');

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final cardPadding = isSmallScreen ? 10.0 : 12.0;
    final iconSize = isSmallScreen ? 36.0 : 40.0;
    final iconInnerSize = isSmallScreen ? 20.0 : 22.0;
    
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 10),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.purple.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.15)
                : Colors.grey.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openRequestDetail(request),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Row(
            children: [
              // Request Icon
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.inventory_2,
                  color: Colors.purple,
                  size: iconInnerSize,
                ),
              ),
              SizedBox(width: isSmallScreen ? 10 : 12),
              // Request Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 2 : 3),
                    Text(
                      'Submitted on ${_formatDate(createdAt)}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 11,
                        color: isDarkMode ? Colors.white70 : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 2 : 3),
                    Row(
                      children: [
                        Text(
                          'Type: ',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 11,
                            color: isDarkMode ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        Text(
                          type,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 2 : 3),
                    Row(
                      children: [
                        Text(
                          'Status: ',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 11,
                            color: isDarkMode ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        Flexible(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 6 : 7,
                              vertical: isSmallScreen ? 2 : 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 10 : 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
