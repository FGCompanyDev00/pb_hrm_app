// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'inventory_edit_request_page.dart';
import 'inventory_request_detail_page.dart';

class InventoryApprovalPage extends StatefulWidget {
  const InventoryApprovalPage({super.key});

  @override
  State<InventoryApprovalPage> createState() => _InventoryApprovalPageState();
}

class _InventoryApprovalPageState extends State<InventoryApprovalPage> {
  bool _isApprovalTabSelected = true; // true = Approval tab, false = Approved tab
  List<Map<String, dynamic>> _approvalRequests = [];
  List<Map<String, dynamic>> _approvedRequests = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      print('🔍 Fetching approval requests from: $baseUrl/api/inventory/request/');
      print('🔑 Token: ${token.substring(0, 10)}...');

      // Fetch approval requests (pending)
      final approvalResponse = await http.get(
        Uri.parse('$baseUrl/api/inventory/request/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📊 Approval API Response Status: ${approvalResponse.statusCode}');
      print('📊 Approval API Response Body: ${approvalResponse.body}');

      if (approvalResponse.statusCode == 200) {
        final approvalData = jsonDecode(approvalResponse.body);
        print('📊 Parsed Approval Data Type: ${approvalData.runtimeType}');
        print('📊 Parsed Approval Data: $approvalData');
        
        if (approvalData is List) {
          _approvalRequests = List<Map<String, dynamic>>.from(approvalData);
          print('✅ Approval requests loaded: ${_approvalRequests.length} items');
        } else if (approvalData is Map && approvalData.containsKey('data')) {
          // Handle case where API returns { "data": [...] }
          final data = approvalData['data'];
          if (data is List) {
            _approvalRequests = List<Map<String, dynamic>>.from(data);
            print('✅ Approval requests loaded from data: ${_approvalRequests.length} items');
          } else {
            _approvalRequests = [];
            print('❌ No valid data list found in approval response');
          }
        } else if (approvalData is Map && approvalData.containsKey('results')) {
          // Handle case where API returns { "results": [...] }
          final results = approvalData['results'];
          if (results is List) {
            _approvalRequests = List<Map<String, dynamic>>.from(results);
            print('✅ Approval requests loaded from results: ${_approvalRequests.length} items');
          } else {
            _approvalRequests = [];
            print('❌ No valid results list found in approval response');
          }
        } else {
          _approvalRequests = [];
          print('❌ No valid data structure found in approval response');
        }
      } else {
        throw Exception('Failed to fetch approval requests: ${approvalResponse.statusCode}');
      }

      print('🔍 Fetching approved requests from: $baseUrl/api/inventory/approver/');

      // Fetch approved requests
      final approvedResponse = await http.get(
        Uri.parse('$baseUrl/api/inventory/approver/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📊 Approved API Response Status: ${approvedResponse.statusCode}');
      print('📊 Approved API Response Body: ${approvedResponse.body}');

      if (approvedResponse.statusCode == 200) {
        final approvedData = jsonDecode(approvedResponse.body);
        print('📊 Parsed Approved Data Type: ${approvedData.runtimeType}');
        print('📊 Parsed Approved Data: $approvedData');
        
        if (approvedData is List) {
          _approvedRequests = List<Map<String, dynamic>>.from(approvedData);
          print('✅ Approved requests loaded: ${_approvedRequests.length} items');
        } else if (approvedData is Map && approvedData.containsKey('data')) {
          // Handle case where API returns { "data": [...] }
          final data = approvedData['data'];
          if (data is List) {
            _approvedRequests = List<Map<String, dynamic>>.from(data);
            print('✅ Approved requests loaded from data: ${_approvedRequests.length} items');
          } else {
            _approvedRequests = [];
            print('❌ No valid data list found in approved response');
          }
        } else if (approvedData is Map && approvedData.containsKey('results')) {
          // Handle case where API returns { "results": [...] }
          final results = approvedData['results'];
          if (results is List) {
            _approvedRequests = List<Map<String, dynamic>>.from(results);
            print('✅ Approved requests loaded from results: ${_approvedRequests.length} items');
          } else {
            _approvedRequests = [];
            print('❌ No valid results list found in approved response');
          }
        } else {
          _approvedRequests = [];
          print('❌ No valid data structure found in approved response');
        }
      } else {
        throw Exception('Failed to fetch approved requests: ${approvedResponse.statusCode}');
      }

      setState(() {
        _isLoading = false;
        _isError = false;
      });
      
      print('🎯 Final State - Approval: ${_approvalRequests.length}, Approved: ${_approvedRequests.length}');
    } catch (e) {
      print('❌ Error in _fetchApprovalRequests: $e');
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = e.toString();
      });
    }
  }



  void _onApprovalItemTap(Map<String, dynamic> request) {
    // Navigate to edit request page for pending requests
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InventoryEditRequestPage(
          requestId: request['topicid'] ?? request['id'] ?? '',
          requestData: request,
        ),
      ),
    ).then((_) {
      // Refresh data when returning from edit page
      _fetchApprovalRequests();
    });
  }

  void _onApprovedItemTap(Map<String, dynamic> request) {
    // Navigate to request detail page for approved requests
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InventoryRequestDetailPage(
          requestId: request['topic_uniq_id'] ?? request['id'] ?? '',
          requestData: request,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      body: Column(
        children: [
          _buildHeader(isDarkMode, screenSize),
          
          SizedBox(height: screenSize.height * 0.005),
          _buildTabBar(screenSize),
          SizedBox(height: screenSize.height * 0.005),
          
          // Content Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isError
                    ? _buildErrorState(isDarkMode)
                    : _isApprovalTabSelected
                        ? _buildApprovalList(isDarkMode, screenSize)
                        : _buildApprovedList(isDarkMode, screenSize),
          ),
        ],
      ),
    );
  }

  /// Builds the header section with background image and title.
  Widget _buildHeader(bool isDarkMode, Size screenSize) {
    return Container(
      height: screenSize.height * 0.17,
      width: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png',
          ),
          fit: BoxFit.cover,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.04,
            vertical: screenSize.height * 0.015,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: screenSize.width * 0.07,
                ),
                onPressed: () => Navigator.maybePop(context),
              ),
              Text(
                'Approval',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: screenSize.width * 0.06,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: screenSize.width * 0.12),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the tab bar for toggling between Approval and Approved.
  Widget _buildTabBar(Size screenSize) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.02,
        vertical: screenSize.height * 0.004,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isApprovalTabSelected) {
                  setState(() {
                    _isApprovalTabSelected = true;
                  });
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: screenSize.height * 0.008,
                ),
                decoration: BoxDecoration(
                  color: _isApprovalTabSelected
                      ? (isDarkMode ? Colors.orangeAccent : Colors.amber)
                      : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    bottomLeft: Radius.circular(20.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: screenSize.width * 0.07,
                      color: _isApprovalTabSelected
                          ? (isDarkMode ? Colors.white : Colors.white)
                          : (isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600),
                    ),
                    SizedBox(width: screenSize.width * 0.02),
                    Text(
                      'Approval',
                      style: TextStyle(
                        color: _isApprovalTabSelected
                            ? (isDarkMode ? Colors.white : Colors.white)
                            : (isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600),
                        fontWeight: FontWeight.bold,
                        fontSize: screenSize.width * 0.04,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: screenSize.width * 0.002),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isApprovalTabSelected) {
                  setState(() {
                    _isApprovalTabSelected = false;
                  });
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: screenSize.height * 0.008,
                ),
                decoration: BoxDecoration(
                  color: !_isApprovalTabSelected
                      ? (isDarkMode ? Colors.orangeAccent : Colors.amber)
                      : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20.0),
                    bottomRight: Radius.circular(20.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description,
                      size: screenSize.width * 0.07,
                      color: !_isApprovalTabSelected
                          ? (isDarkMode ? Colors.white : Colors.white)
                          : (isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600),
                    ),
                    SizedBox(width: screenSize.width * 0.02),
                    Text(
                      'Approved',
                      style: TextStyle(
                        color: !_isApprovalTabSelected
                            ? (isDarkMode ? Colors.white : Colors.white)
                            : (isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600),
                        fontWeight: FontWeight.bold,
                        fontSize: screenSize.width * 0.04,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _fetchApprovalRequests,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDBB342),
                ),
                child: const Text('Retry'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  print('🔍 Debug: Current state');
                  print('🔍 Loading: $_isLoading');
                  print('🔍 Error: $_isError');
                  print('🔍 Error Message: $_errorMessage');
                  print('🔍 Approval Requests: ${_approvalRequests.length}');
                  print('🔍 Approved Requests: ${_approvedRequests.length}');
                  print('🔍 Base URL: $baseUrl');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                child: const Text('Debug'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalList(bool isDarkMode, Size screenSize) {
    if (_approvalRequests.isEmpty) {
      return _buildEmptyState(isDarkMode, 'No pending requests', Icons.pending_actions);
    }

    return RefreshIndicator(
      onRefresh: _fetchApprovalRequests,
      color: const Color(0xFFDBB342),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: screenSize.width * 0.04,
          vertical: screenSize.height * 0.008,
        ),
        itemCount: _approvalRequests.length,
        itemBuilder: (context, index) {
          final request = _approvalRequests[index];
          return _buildRequestCard(request, isDarkMode, screenSize, _onApprovalItemTap);
        },
      ),
    );
  }

  Widget _buildApprovedList(bool isDarkMode, Size screenSize) {
    if (_approvedRequests.isEmpty) {
      return _buildEmptyState(isDarkMode, 'No approved requests', Icons.check_circle_outline);
    }

    return RefreshIndicator(
      onRefresh: _fetchApprovalRequests,
      color: const Color(0xFFDBB342),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: screenSize.width * 0.04,
          vertical: screenSize.height * 0.008,
        ),
        itemCount: _approvedRequests.length,
        itemBuilder: (context, index) {
          final request = _approvedRequests[index];
          return _buildRequestCard(request, isDarkMode, screenSize, _onApprovedItemTap);
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, bool isDarkMode, Size screenSize, Function(Map<String, dynamic>) onTap) {
    final String title = request['title'] ?? 'Your Asset';
    final String status = request['status'] ?? 'Pending';
    final String date = request['created_at'] ?? '';
    final String employeeName = request['full_name'] ?? request['employee_name'] ?? 'Unknown';
    final String type = 'For Office'; // Default type
    
    // Format date
    String formattedDate = 'Unknown date';
    if (date.isNotEmpty) {
      try {
        final dateTime = DateTime.parse(date);
        formattedDate = '${dateTime.day.toString().padLeft(2, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.year}';
      } catch (e) {
        formattedDate = date;
      }
    }

    // Determine status color - following inventory_request_form.dart theme
    Color statusColor;
    Color statusBgColor;
    if (status.toLowerCase().contains('approved') || status.toLowerCase().contains('checked') || status.toLowerCase().contains('received')) {
      statusColor = Colors.green;
      statusBgColor = Colors.green.withOpacity(0.2);
    } else if (status.toLowerCase().contains('decline') || status.toLowerCase().contains('declined') || status.toLowerCase().contains('rejected')) {
      statusColor = Colors.red;
      statusBgColor = Colors.red.withOpacity(0.2);
    } else if (status.toLowerCase().contains('pending')) {
      statusColor = const Color(0xFFDBB342); // Yellow/gold theme
      statusBgColor = const Color(0xFFDBB342).withOpacity(0.2);
    } else if (status.toLowerCase().contains('canceled')) {
      statusColor = Colors.blue;
      statusBgColor = Colors.blue.withOpacity(0.2);
    } else {
      statusColor = Colors.grey;
      statusBgColor = Colors.grey.withOpacity(0.2);
    }

    return GestureDetector(
      onTap: () => onTap(request),
      child: Container(
        margin: EdgeInsets.only(bottom: screenSize.height * 0.01),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(screenSize.width * 0.03),
          border: Border.all(
            color: const Color(0xFFDBB342).withOpacity(0.3), // Yellow/gold border like inventory_request_form
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
          padding: EdgeInsets.all(screenSize.width * 0.04),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left side with asset icon
              Container(
                width: screenSize.width * 0.1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Asset icon (top) - using yellow/gold theme
                    Container(
                      width: screenSize.width * 0.06,
                      height: screenSize.width * 0.06,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBB342).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.inventory_2,
                        color: const Color(0xFFDBB342), // Yellow/gold icon
                        size: screenSize.width * 0.04,
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.003),
                    // Title below icon
                    Text(
                      'Your Asset',
                      style: TextStyle(
                        color: const Color(0xFFDBB342), // Yellow/gold text
                        fontSize: screenSize.width * 0.022,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(width: screenSize.width * 0.025),

              // Information Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: screenSize.width * 0.032,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.002),
                    Text(
                      'Submitted on $formattedDate',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                        fontSize: screenSize.width * 0.026,
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.002),
                    Text(
                      'Type: $type',
                      style: TextStyle(
                        color: const Color(0xFFDBB342), // Yellow/gold theme
                        fontSize: screenSize.width * 0.026,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.002),
                    Text(
                      employeeName,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                        fontSize: screenSize.width * 0.026,
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.004),
                    Row(
                      children: [
                        Text(
                          'Status: ',
                          style: TextStyle(
                            fontSize: screenSize.width * 0.026,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenSize.width * 0.01,
                            vertical: screenSize.height * 0.001,
                          ),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(screenSize.width * 0.012),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: screenSize.width * 0.024,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: screenSize.width * 0.02),

              // Profile Image - RIGHT SIDE as shown in the image
              CircleAvatar(
                radius: screenSize.width * 0.045,
                backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: screenSize.width * 0.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: isDarkMode ? Colors.white54 : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
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
}
