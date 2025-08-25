// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'inventory_app_bar.dart';

class InventoryEditRequestPage extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> requestData;

  const InventoryEditRequestPage({
    super.key,
    required this.requestId,
    required this.requestData,
  });

  @override
  State<InventoryEditRequestPage> createState() => _InventoryEditRequestPageState();
}

class _InventoryEditRequestPageState extends State<InventoryEditRequestPage> {
  final TextEditingController _titleController = TextEditingController();
  List<Map<String, dynamic>> _requestItems = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  bool _isUpdating = false;

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.requestData['title'] ?? '';
    _fetchRequestDetails();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
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
          if (results['details'] != null) {
            setState(() {
              _requestItems = List<Map<String, dynamic>>.from(results['details']);
              _isLoading = false;
              _isError = false;
            });
          } else {
            throw Exception('No details found in request');
          }
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

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      setState(() {
        _requestItems.removeAt(index);
      });
    } else {
      setState(() {
        _requestItems[index] = {
          ..._requestItems[index],
          'quantity': newQuantity,
        };
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _requestItems.removeAt(index);
    });
  }

  Future<void> _updateRequest() async {
    if (_requestItems.isEmpty) {
      _showErrorSnackBar('Request must have at least one item.');
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a title for your request.');
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      // Prepare the update payload
      final payload = {
        'title': _titleController.text.trim(),
        'details': _requestItems.map((item) => {
          'barcode': item['barcode'],
          'quantity': item['quantity'],
        }).toList(),
        'confirmed': 0, // 0 means not confirmed (pending)
      };

      final response = await http.put(
        Uri.parse('$baseUrl/api/inventory/request_topic/${widget.requestId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['statusCode'] == 200 || data['statusCode'] == 201) {
          _showSuccessSnackBar('Request updated successfully!');
          // Navigate back
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to update request');
        }
      } else {
        throw Exception('Failed to update request: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating request: ${e.toString()}');
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  void _cancelRequest() {
    Navigator.of(context).pop();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
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
            title: 'Edit My Request',
            showBack: true,
          ),
          body: Column(
            children: [
              // Title Input Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildTitleInput(isDarkMode),
              ),
              
              // Request Items List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _isError
                        ? _buildErrorState(isDarkMode)
                        : _requestItems.isEmpty
                            ? _buildEmptyState(isDarkMode)
                            : _buildRequestItemsList(isDarkMode),
              ),
            ],
          ),
          // Action Buttons
          bottomNavigationBar: _buildActionButtons(isDarkMode),
        );
      },
    );
  }

  Widget _buildTitleInput(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFDBB342).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request Title',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: 'Enter request title...',
              hintStyle: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.grey[600],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: const Color(0xFFDBB342).withOpacity(0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFDBB342),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
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

  Widget _buildRequestItemsList(bool isDarkMode) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _requestItems.length,
      itemBuilder: (context, index) {
        final item = _requestItems[index];
        return _buildRequestItemCard(item, index, isDarkMode);
      },
    );
  }

  Widget _buildRequestItemCard(Map<String, dynamic> item, int index, bool isDarkMode) {
    final String name = item['name'] ?? 'Unknown Item';
    // final String barcode = item['barcode'] ?? ''; // Not used in current UI
    final int quantity = item['quantity'] ?? 1;
    final String imageUrl = item['img_ref'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFDBB342).withOpacity(0.3),
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
                const SizedBox(width: 12),
                
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
                
                // Delete Button
                IconButton(
                  onPressed: () => _removeItem(index),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Remove item',
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Quantity Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quantity:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                Row(
                  children: [
                    // Decrease Button
                    IconButton(
                      onPressed: () => _updateQuantity(index, quantity - 1),
                      icon: const Icon(Icons.remove_circle_outline),
                      color: const Color(0xFFDBB342),
                      tooltip: 'Decrease quantity',
                    ),
                    
                    // Quantity Display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    
                    // Increase Button
                    IconButton(
                      onPressed: () => _updateQuantity(index, quantity + 1),
                      icon: const Icon(Icons.add_circle_outline),
                      color: const Color(0xFFDBB342),
                      tooltip: 'Increase quantity',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Update Button
            Expanded(
              child: ElevatedButton(
                onPressed: _isUpdating || _requestItems.isEmpty ? null : _updateRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDBB342),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isUpdating
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Updating...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Update',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Cancel Button
            Expanded(
              child: ElevatedButton(
                onPressed: _isUpdating ? null : _cancelRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.grey[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
