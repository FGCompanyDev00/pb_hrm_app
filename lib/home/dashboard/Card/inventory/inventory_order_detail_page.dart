// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pb_hrsystem/models/inventory_cart_item.dart';
import 'inventory_app_bar.dart';

class InventoryOrderDetailPage extends StatefulWidget {
  final List<InventoryCartItem> cartItems;
  final String categoryName;

  const InventoryOrderDetailPage({
    super.key,
    required this.cartItems,
    required this.categoryName,
  });

  @override
  State<InventoryOrderDetailPage> createState() => _InventoryOrderDetailPageState();
}

class _InventoryOrderDetailPageState extends State<InventoryOrderDetailPage> {
  final TextEditingController _titleController = TextEditingController();
  List<InventoryCartItem> _cartItems = [];
  bool _isSubmitting = false;
  // bool _isError = false; // Not used in current UI
  // String _errorMessage = ''; // Not used in current UI

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  @override
  void initState() {
    super.initState();
    _cartItems = List.from(widget.cartItems);
    _generateDefaultTitle();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _generateDefaultTitle() {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _titleController.text = 'Request ${widget.categoryName} $dateStr $timeStr';
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      setState(() {
        _cartItems.removeAt(index);
      });
    } else {
      setState(() {
        _cartItems[index] = _cartItems[index].copyWith(quantity: newQuantity);
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  Future<void> _submitRequest() async {
    if (_cartItems.isEmpty) {
      _showErrorSnackBar('Cart is empty. Please add items first.');
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a title for your request.');
      return;
    }

          setState(() {
        _isSubmitting = true;
      });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      // Prepare the request payload
      final payload = {
        'title': _titleController.text.trim(),
        'details': _cartItems.map((item) => item.toApiFormat()).toList(),
        'request_stock': 1, // 1 means branch request to HQ branch
        'confirmed': 0, // 0 means not confirmed (pending)
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/inventory/request_topic'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['statusCode'] == 200 || data['statusCode'] == 201) {
          _showSuccessSnackBar('Request submitted successfully!');
          // Navigate back to inventory page
          if (mounted) {
            Navigator.of(context).pop(true); // Return true to indicate success
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to submit request');
        }
      } else {
        throw Exception('Failed to submit request: ${response.statusCode}');
      }
    } catch (e) {
      // setState(() {
      //   _isError = true;
      //   _errorMessage = e.toString();
      // });
      _showErrorSnackBar('Error submitting request: ${e.toString()}');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
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
          appBar: InventoryAppBar(
            title: 'Order Detail',
            showBack: true,
          ),
          body: Column(
            children: [
              // Title Input Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildTitleInput(isDarkMode),
              ),
              
              // Cart Items List
              Expanded(
                child: _cartItems.isEmpty
                    ? _buildEmptyCart(isDarkMode)
                    : _buildCartItemsList(isDarkMode),
              ),
            ],
          ),
          // Submit Button
          bottomNavigationBar: _buildSubmitButton(isDarkMode),
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

  Widget _buildEmptyCart(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: isDarkMode ? Colors.white54 : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add items from the inventory list',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white70 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemsList(bool isDarkMode) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cartItems.length,
      itemBuilder: (context, index) {
        final item = _cartItems[index];
        return _buildCartItemCard(item, index, isDarkMode);
      },
    );
  }

  Widget _buildCartItemCard(InventoryCartItem item, int index, bool isDarkMode) {
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
                  child: item.imageUrl?.isNotEmpty == true
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.imageUrl!,
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
                        item.barcode,
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
                          item.name, // Use name as description
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.white70 : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (item.price?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Price: ${item.price} ${item.unit ?? ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFFDBB342),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      // Stock Information
                      Text(
                        'Stock: ${item.instock ?? '0'} ${item.unit ?? ''}',
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
                      onPressed: () => _updateQuantity(index, item.quantity - 1),
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
                        item.quantity.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    
                    // Increase Button
                    IconButton(
                      onPressed: () => _updateQuantity(index, item.quantity + 1),
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

  Widget _buildSubmitButton(bool isDarkMode) {
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
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSubmitting || _cartItems.isEmpty ? null : _submitRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDBB342),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _isSubmitting
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
                        'Submitting...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Submit Request (${_cartItems.length} items)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
