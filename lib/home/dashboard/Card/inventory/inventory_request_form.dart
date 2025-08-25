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
import 'inventory_order_detail_page.dart';

class InventoryRequestForm extends StatefulWidget {
  final String categoryUid;
  final String categoryName;

  const InventoryRequestForm({
    super.key,
    required this.categoryUid,
    required this.categoryName,
  });

  @override
  State<InventoryRequestForm> createState() => _InventoryRequestFormState();
}

class _InventoryRequestFormState extends State<InventoryRequestForm> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  final List<InventoryCartItem> _cartItems = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  
  // Base URL for images
  final String _imageBaseUrl = 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/';

  @override
  void initState() {
    super.initState();
    _fetchCategoryItems();
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }
  
  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_items);
      } else {
        _filteredItems = _items.where((item) {
          final title = item['name']?.toString().toLowerCase() ?? '';
          final description = item['description']?.toString().toLowerCase() ?? '';
          return title.contains(query) || description.contains(query);
        }).toList();
      }
    });
  }

  void _addToCart(Map<String, dynamic> item) {
    final cartItem = InventoryCartItem.fromInventoryItem(item, widget.categoryName);
    
    // Check if item already exists in cart
    final existingIndex = _cartItems.indexWhere((cartItem) => cartItem.barcode == item['barcode']);
    
    if (existingIndex != -1) {
      // Increment quantity if item already exists
      setState(() {
        _cartItems[existingIndex] = _cartItems[existingIndex].copyWith(
          quantity: _cartItems[existingIndex].quantity + 1,
        );
      });
      _showAddedToCartSnackBar('${item['name']} quantity increased');
    } else {
      // Add new item to cart
      setState(() {
        _cartItems.add(cartItem);
      });
      _showAddedToCartSnackBar('${item['name']} added to cart');
    }
  }

  void _openOrderDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InventoryOrderDetailPage(
          cartItems: _cartItems,
          categoryName: widget.categoryName,
        ),
      ),
    ).then((result) {
      // Refresh cart if order was submitted successfully
      if (result == true) {
        setState(() {
          _cartItems.clear();
        });
      }
    });
  }

  void _showAddedToCartSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _fetchCategoryItems() async {
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

      // Try loading from cache first
      final cacheKey = 'inventory_category_${widget.categoryUid}';
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final List<dynamic> cachedList = jsonDecode(cached);
        setState(() {
          _items = List<Map<String, dynamic>>.from(
              cachedList.map((e) => Map<String, dynamic>.from(e)));
          _filteredItems = List.from(_items);
          _isLoading = false;
        });
      }

      // Fetch fresh data
      final response = await http.get(
        Uri.parse('$baseUrl/api/inventory/appliances/category/${widget.categoryUid}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null) {
          final List<dynamic> results = data['results'];
          setState(() {
            _items = List<Map<String, dynamic>>.from(
                results.map((e) => Map<String, dynamic>.from(e)));
            _filteredItems = List.from(_items);
            _isLoading = false;
            _isError = false;
          });
          // Cache the results
          await prefs.setString(cacheKey, jsonEncode(results));
        } else {
          throw Exception('No results in API response');
        }
      } else {
        throw Exception('Failed to fetch items: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        final isDarkMode = themeNotifier.isDarkMode;

        return Scaffold(
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          appBar: InventoryAppBar(
            title: widget.categoryName,
            showBack: true,
            actions: [
              // Cart Icon with Badge
              Stack(
                children: [
                  IconButton(
                    onPressed: _cartItems.isEmpty ? null : _openOrderDetail,
                    icon: const Icon(Icons.shopping_cart),
                    tooltip: 'View Cart',
                  ),
                  if (_cartItems.isNotEmpty)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          '${_cartItems.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildSearchBar(isDarkMode),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _isError
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error, color: Colors.red, size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading items',
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
                                  onPressed: _fetchCategoryItems,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDBB342),
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _filteredItems.isEmpty
                            ? Center(
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
                                      'No items found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    if (_searchController.text.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Try a different search term',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDarkMode ? Colors.white70 : Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : _buildItemsList(isDarkMode),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFDBB342).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: isDarkMode ? Colors.white70 : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(bool isDarkMode) {
    return RefreshIndicator(
      onRefresh: _fetchCategoryItems,
      color: const Color(0xFFDBB342),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredItems.length,
        itemBuilder: (context, index) {
          final item = _filteredItems[index];
          final String name = item['name'] ?? 'Unknown Item';
          // final String description = item['description'] ?? 'No description available'; // Not used, using name instead
          // final String status = item['status'] ?? 'Available'; // Not used in current UI
          final String rawImageUrl = item['img_name'] ?? item['img_ref'] ?? '';
          final String imageUrl = rawImageUrl.isNotEmpty
              ? (rawImageUrl.startsWith('http') ? rawImageUrl : '$_imageBaseUrl$rawImageUrl')
              : '';
          
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['barcode'] ?? 'No Barcode',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              name, // Use name as description
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode ? Colors.white70 : Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Add Button
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        child: ElevatedButton(
                          onPressed: () => _addToCart(item),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDBB342),
                            foregroundColor: Colors.white,
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                            minimumSize: const Size(48, 48),
                          ),
                          child: const Icon(Icons.add, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // For Office Label
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBB342).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'For Office',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFDBB342),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.category_outlined,
                        size: 16,
                        color: isDarkMode ? Colors.white70 : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.categoryName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (item['created_at'] != null)
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: isDarkMode ? Colors.white70 : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(item['created_at']),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(width: 16),
                      // Stock Information
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 16,
                            color: isDarkMode ? Colors.white70 : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Stock: ${item['instock'] ?? '0'} ${item['unit'] ?? ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
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
