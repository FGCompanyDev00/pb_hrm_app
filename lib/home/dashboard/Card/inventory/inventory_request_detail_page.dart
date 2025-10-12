// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'inventory_app_bar.dart';

class InventoryRequestDetailPage extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> requestData;

  const InventoryRequestDetailPage({
    super.key,
    required this.requestId,
    required this.requestData,
  });

  @override
  State<InventoryRequestDetailPage> createState() => _InventoryRequestDetailPageState();
}

class _InventoryRequestDetailPageState extends State<InventoryRequestDetailPage> {
  Map<String, dynamic> _requestDetails = {};
  List<Map<String, dynamic>> _requestItems = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  @override
  void initState() {
    super.initState();
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
      
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/inventory/request_topic/${widget.requestId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null) {
          final results = data['results'];
          setState(() {
            _requestDetails = Map<String, dynamic>.from(results);
            _requestItems = results['details'] != null 
                ? List<Map<String, dynamic>>.from(results['details'])
                : [];
            _isLoading = false;
            _isError = false;
          });
        } else {
          throw Exception('No results found in response');
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
                  ? _buildErrorState(isDarkMode)
                  : _buildRequestDetails(isDarkMode),
        );
      },
    );
  }

  Widget _buildErrorState(bool isDarkMode) {
    return Center(
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
    );
  }

  Widget _buildRequestDetails(bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Request Summary Section
          _buildRequestSummary(isDarkMode),
          
          const SizedBox(height: 24),
          
          // Requested Items List
          _buildRequestedItemsList(isDarkMode),
          
          const SizedBox(height: 24),
          
          // Approval Timeline
          // _buildApprovalTimeline(isDarkMode), // Commented out - not in use yet
        ],
      ),
    );
  }

  Widget _buildRequestSummary(bool isDarkMode) {
    final String employeeName = _requestDetails['employee_name'] ?? 'Unknown';
    final String submittedDate = _requestDetails['created_at'] ?? '';
    final String status = _requestDetails['status'] ?? 'Unknown';
    
    // Determine status color
    Color statusColor;
    Color statusBgColor;
    if (status.toLowerCase().contains('approved')) {
      statusColor = Colors.green;
      statusBgColor = Colors.green.withOpacity(0.2);
    } else if (status.toLowerCase().contains('pending')) {
      statusColor = const Color(0xFFDBB342);
      statusBgColor = const Color(0xFFDBB342).withOpacity(0.2);
    } else {
      statusColor = Colors.blue;
      statusBgColor = Colors.blue.withOpacity(0.2);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFDBB342).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // Profile picture
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[300],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          
          // Request info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employeeName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Submitted on ${_formatDate(submittedDate)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Status: $status',
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
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

  Widget _buildRequestedItemsList(bool isDarkMode) {
    if (_requestItems.isEmpty) {
      return _buildEmptyState(isDarkMode);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Requested Items',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        ..._requestItems.map((item) => _buildRequestItemCard(item, isDarkMode)).toList(),
      ],
    );
  }

  Widget _buildRequestItemCard(Map<String, dynamic> item, bool isDarkMode) {
    final String name = item['name'] ?? 'Unknown Item';
    // final String barcode = item['barcode'] ?? ''; // Not used in current UI
    final int quantity = item['quantity'] ?? 1;
    // final String unit = item['unit'] ?? ''; // Not used in current UI
    final String imageUrl = item['img_ref'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFDBB342).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // Item Image
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFDBB342).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.computer,
                        color: isDarkMode ? Colors.white : const Color(0xFFDBB342),
                        size: 24,
                      ),
                    ),
                  )
                : Icon(
                    Icons.computer,
                    color: isDarkMode ? Colors.white : const Color(0xFFDBB342),
                    size: 24,
                  ),
          ),
          const SizedBox(width: 16),
          
          // Item Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'For Office',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // Quantity
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              quantity.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: isDarkMode ? Colors.white54 : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No items in this request',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalTimeline(bool isDarkMode) {
    final String status = _requestDetails['status'] ?? 'Unknown';
    final String departmentName = _requestDetails['department_name'] ?? 'Unknown Department';
    final String createdDate = _requestDetails['created_at'] ?? '';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Approval Timeline',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFDBB342).withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              // Approval flow visualization
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Requestor
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[300],
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  
                  // Arrow
                  const SizedBox(width: 16),
                  const Icon(Icons.arrow_forward, color: Colors.grey, size: 24),
                  const SizedBox(width: 16),
                  
                  // Approver
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[300],
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Approval details
              Text(
                '$status - ${_formatDate(createdDate)} $departmentName',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
