import 'package:flutter/material.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../inventory_app_bar.dart';
import 'requestor_detail_page.dart';

/// My Request page for AdminHQ users
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
          setState(() {
            _requests = List<Map<String, dynamic>>.from(data['results']);
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
    // Debug print to see actual status values
    debugPrint('🔍 [MyRequestPage] Status: "$status"');
    
    switch (status.toLowerCase()) {
      // Pending/Processing statuses - Yellow/Orange
      case 'supervisor pending...':
      case 'supervisor pending':
      case 'manager pending':
      case 'manager pending...':
      case 'pending':
      case 'waiting':
        debugPrint('🔍 [MyRequestPage] Status "$status" mapped to ORANGE');
        return Colors.orange;
      
      // Approved/Received statuses - Green
      case 'approved':
      case 'received':
      case 'completed':
      case 'delivered':
        debugPrint('🔍 [MyRequestPage] Status "$status" mapped to GREEN');
        return Colors.green;
      
      // Rejected/Declined statuses - Red
      case 'rejected':
      case 'decline':
      case 'declined':
      case 'canceled':
      case 'cancelled':
      case 'failed':
        debugPrint('🔍 [MyRequestPage] Status "$status" mapped to RED');
        return Colors.red;
      
      // In Progress statuses - Blue
      case 'in progress':
      case 'processing':
      case 'under review':
        debugPrint('🔍 [MyRequestPage] Status "$status" mapped to BLUE');
        return Colors.blue;
      
      // On Hold statuses - Purple
      case 'on hold':
      case 'suspended':
      case 'paused':
        debugPrint('🔍 [MyRequestPage] Status "$status" mapped to PURPLE');
        return Colors.purple;
      
      // Default - Gray
      default:
        debugPrint('🔍 [MyRequestPage] Status "$status" mapped to GRAY (default)');
        return Colors.grey;
    }
  }

  /// Format date string to readable format
  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year},${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  /// Open requestor detail page
  void _openRequestorDetail(Map<String, dynamic> request) {
    // Add source field to identify this is from My Request page
    final requestWithSource = Map<String, dynamic>.from(request);
    requestWithSource['source'] = 'my_request';
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestorDetailPage(
          requestData: requestWithSource,
        ),
      ),
    );
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
          body: RefreshIndicator(
            onRefresh: _fetchMyRequests,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: isDarkMode ? Colors.white54 : Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode ? Colors.white70 : Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchMyRequests,
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
                                  Icons.inbox_outlined,
                                  size: 64,
                                  color: isDarkMode ? Colors.white54 : Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Requests Found',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'You haven\'t made any inventory requests yet.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _requests.length,
                            itemBuilder: (context, index) {
                              final request = _requests[index];
                              return InkWell(
                                onTap: () => _openRequestorDetail(request),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.grey[850] : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF9C27B0).withOpacity(0.3),
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
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // Left side - Icon
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF9C27B0).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.inventory_2,
                                              color: Color(0xFF9C27B0),
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Center - Request details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  request['title'] ?? 'No Title',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(0xFF9C27B0),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Submitted on ${_formatDate(request['created_at'])}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Type: for Office',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.orange[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Text(
                                                      'Status: ',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 6,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: _getStatusColor(request['status'] ?? ''),
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                      child: Text(
                                                        request['status'] ?? 'Unknown',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Right side - Profile picture
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(24),
                                              border: Border.all(
                                                color: const Color(0xFF9C27B0).withOpacity(0.3),
                                                width: 2,
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(24),
                                              child: request['img_path'] != null
                                                  ? Image.network(
                                                      request['img_path'],
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
                                                      errorBuilder: (context, error, stackTrace) => Container(
                                                        color: Colors.grey[200],
                                                        child: Icon(
                                                          Icons.person,
                                                          color: Colors.grey[600],
                                                          size: 24,
                                                        ),
                                                      ),
                                                    )
                                                  : Container(
                                                      color: Colors.grey[200],
                                                      child: Icon(
                                                        Icons.person,
                                                        color: Colors.grey[600],
                                                        size: 24,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          ),
          ),
        );
      },
    );
  }
}
