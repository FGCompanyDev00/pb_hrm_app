import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../inventory_app_bar.dart';
import 'hq_item_detail_page.dart';

/// Request From HQ page for AdminBR users
/// Displays inventory items available from headquarters
/// Uses API endpoint: GET {{baseUrl}}/api/inventory/appliances/branchs
/// Response structure: { statusCode, title, message, results: [...] }
class RequestFromHQPage extends StatefulWidget {
  const RequestFromHQPage({super.key});

  @override
  State<RequestFromHQPage> createState() => _RequestFromHQPageState();
}

class _RequestFromHQPageState extends State<RequestFromHQPage> {
  List<Map<String, dynamic>> _allItems = []; // All items from API
  List<Map<String, dynamic>> _filteredItems = []; // Filtered items to display
  List<Map<String, dynamic>> _categories = []; // Unique categories
  String? _selectedCategoryUid; // Selected category UID (null = All Categories)
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';

  // Base URL for images
  final String _imageBaseUrl = 'https://demo-flexiflows-inventory-pictures.s3.ap-southeast-1.amazonaws.com/';

  @override
  void initState() {
    super.initState();
    _fetchHQItems();
  }

  Future<void> _fetchHQItems() async {
    setState(() {
      _isLoading = true;
      _isError = false;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final baseUrl = dotenv.env['BASE_URL'];

      if (token == null || baseUrl == null) {
        throw Exception('Authentication token or base URL not found');
      }

      debugPrint('🔍 [RequestFromHQPage] Fetching HQ items from: $baseUrl/api/inventory/appliances/branchs');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/inventory/appliances/branchs'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('🔍 [RequestFromHQPage] Response status: ${response.statusCode}');
      debugPrint('🔍 [RequestFromHQPage] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('🔍 [RequestFromHQPage] Response data type: ${responseData.runtimeType}');
        debugPrint('🔍 [RequestFromHQPage] Response data: $responseData');
        
        List<dynamic> items = [];
        
        // Handle API response structure: { statusCode, title, message, results: [...] }
        if (responseData is Map) {
          // Check for 'results' key first (matches API response structure)
          if (responseData.containsKey('results') && responseData['results'] is List) {
            items = responseData['results'];
            debugPrint('✅ [RequestFromHQPage] Found results array with ${items.length} items');
          } else if (responseData.containsKey('data') && responseData['data'] is List) {
            items = responseData['data'];
            debugPrint('✅ [RequestFromHQPage] Found data array with ${items.length} items');
          } else if (responseData.containsKey('items') && responseData['items'] is List) {
            items = responseData['items'];
            debugPrint('✅ [RequestFromHQPage] Found items array with ${items.length} items');
          } else {
            debugPrint('⚠️ [RequestFromHQPage] No results/data/items found in response');
          }
        } else if (responseData is List) {
          // Direct list response (fallback)
          items = responseData;
          debugPrint('✅ [RequestFromHQPage] Direct list response with ${items.length} items');
        }
        
        final allItems = List<Map<String, dynamic>>.from(
          items.map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            } else if (item is Map) {
              return Map<String, dynamic>.from(item);
            } else {
              debugPrint('⚠️ [RequestFromHQPage] Unexpected item type: ${item.runtimeType}');
              return <String, dynamic>{};
            }
          })
        );
        
        // Extract unique categories
        final Map<String, Map<String, dynamic>> categoryMap = {};
        for (var item in allItems) {
          final categoryUid = item['category_uid']?.toString();
          final categoryName = item['category_name']?.toString();
          
          debugPrint('🔍 [RequestFromHQPage] Item: ${item['name']}, category_uid: $categoryUid, category_name: $categoryName');
          
          if (categoryUid != null && categoryUid.isNotEmpty && categoryName != null && categoryName.isNotEmpty) {
            if (!categoryMap.containsKey(categoryUid)) {
              categoryMap[categoryUid] = {
                'category_uid': categoryUid,
                'category_name': categoryName,
              };
              debugPrint('✅ [RequestFromHQPage] Added category: $categoryName ($categoryUid)');
            }
          } else {
            debugPrint('⚠️ [RequestFromHQPage] Item missing category info: ${item['name']}');
          }
        }
        
        setState(() {
          _allItems = allItems;
          _categories = categoryMap.values.toList()
            ..sort((a, b) => (a['category_name'] as String).compareTo(b['category_name'] as String));
          _selectedCategoryUid = null; // Reset filter to "All Categories"
          _filteredItems = _allItems; // Show all items initially
          _isLoading = false;
          _isError = false;
        });
        
        debugPrint('✅ [RequestFromHQPage] HQ items loaded: ${_allItems.length} items');
        debugPrint('✅ [RequestFromHQPage] Categories found: ${_categories.length} categories');
        if (_categories.isNotEmpty) {
          debugPrint('📋 [RequestFromHQPage] Category list:');
          for (var cat in _categories) {
            debugPrint('   - ${cat['category_name']} (${cat['category_uid']})');
          }
        } else {
          debugPrint('⚠️ [RequestFromHQPage] No categories found! Check if items have category_uid and category_name');
        }
        
        // If no items found, show empty state
        if (_allItems.isEmpty) {
          debugPrint('⚠️ [RequestFromHQPage] No items found in response');
        }
      } else {
        throw Exception('Failed to fetch HQ items: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = e.toString();
      });
      debugPrint('❌ [RequestFromHQPage] Error fetching HQ items: $e');
    }
  }

  /// Filter items by selected category
  void _filterByCategory(String? categoryUid) {
    setState(() {
      _selectedCategoryUid = categoryUid;
      if (categoryUid == null) {
        // Show all items
        _filteredItems = _allItems;
      } else {
        // Filter by category
        _filteredItems = _allItems.where((item) {
          final itemCategoryUid = item['category_uid']?.toString();
          return itemCategoryUid == categoryUid;
        }).toList();
      }
    });
    debugPrint('🔍 [RequestFromHQPage] Filtered to ${_filteredItems.length} items (Category: ${categoryUid ?? "All"})');
  }

  void _openHQItemDetail(Map<String, dynamic> item) {
    // Add source field to identify this is from HQ items page
    final itemWithSource = Map<String, dynamic>.from(item);
    itemWithSource['source'] = 'hq_item';
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HQItemDetailPage(
          itemData: itemWithSource,
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
            title: 'Request From HQ',
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
                            'Error loading HQ requests',
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
                            onPressed: _fetchHQItems,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDBB342),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _allItems.isEmpty
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
                                'No HQ items available',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No items are available from headquarters',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Category Filter - Always visible at top (show even if no categories to display "All")
                            if (_allItems.isNotEmpty) _buildCategoryFilter(isDarkMode),
                            // Items List with RefreshIndicator
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: _fetchHQItems,
                                color: const Color(0xFFDBB342),
                                child: _filteredItems.isEmpty
                                    ? SingleChildScrollView(
                                        physics: const AlwaysScrollableScrollPhysics(),
                                        child: SizedBox(
                                          height: MediaQuery.of(context).size.height * 0.5,
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.filter_alt_off,
                                                  size: 64,
                                                  color: isDarkMode ? Colors.white54 : Colors.grey[400],
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  'No items in this category',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDarkMode ? Colors.white : Colors.black,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Try selecting a different category',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.all(16),
                                        itemCount: _filteredItems.length,
                                        itemBuilder: (context, index) {
                                          final item = _filteredItems[index];
                                          return _buildHQItemCard(item, isDarkMode);
                                        },
                                      ),
                              ),
                            ),
                          ],
                        ),
        );
      },
    );
  }

  /// Build category filter dropdown
  Widget _buildCategoryFilter(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFDBB342).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            color: const Color(0xFFDBB342),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedCategoryUid,
                isExpanded: true,
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                ),
                dropdownColor: isDarkMode ? Colors.grey[850] : Colors.white,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                items: [
                  // All Categories option
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(
                          Icons.category,
                          size: 18,
                          color: const Color(0xFFDBB342),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'All Categories (${_allItems.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Category options
                  ..._categories.map((category) {
                    final categoryUid = category['category_uid'] as String;
                    final categoryName = category['category_name'] as String;
                    final itemCount = _allItems.where((item) {
                      return item['category_uid']?.toString() == categoryUid;
                    }).length;
                    
                    return DropdownMenuItem<String?>(
                      value: categoryUid,
                      child: Row(
                        children: [
                          Icon(
                            Icons.label,
                            size: 18,
                            color: const Color(0xFF2196F3),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$categoryName ($itemCount)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
                onChanged: (String? value) {
                  _filterByCategory(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Safe parse double from string, handles null, empty, and invalid values
  double _safeParseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    
    final String stringValue = value.toString().trim();
    if (stringValue.isEmpty) return defaultValue;
    
    // Remove commas and other formatting
    final cleanedValue = stringValue.replaceAll(',', '').replaceAll(' ', '');
    
    try {
      return double.parse(cleanedValue);
    } catch (e) {
      debugPrint('⚠️ [RequestFromHQPage] Failed to parse double: $value, error: $e');
      return defaultValue;
    }
  }

  Widget _buildHQItemCard(Map<String, dynamic> item, bool isDarkMode) {
    final String name = item['name'] ?? 'No Name';
    final String barcode = item['barcode'] ?? 'No Barcode';
    final String categoryName = item['category_name']?.toString() ?? '';
    final String instock = item['instock']?.toString() ?? '0';
    final String unit = item['unit']?.toString() ?? 'pcs';
    final String minimum = item['minimum']?.toString() ?? '0';
    final double minPrice = _safeParseDouble(item['min_price'], defaultValue: 0.0);
    final String rawImageUrl = item['img_ref']?.toString() ?? '';
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
        onTap: () => _openHQItemDetail(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Item Image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFDBB342).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.inventory_2,
                            color: isDarkMode ? Colors.white : Colors.grey[600],
                            size: 24,
                          ),
                        )
                      : Icon(
                          Icons.inventory_2,
                          color: isDarkMode ? Colors.white : Colors.grey[600],
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
                      'Barcode: $barcode',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                    if (categoryName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF2196F3).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          categoryName,
                          style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF2196F3),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Stock: $instock $unit',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Min: $minimum',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Price: ${minPrice.toStringAsFixed(2)} LAK',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFFDBB342),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow Icon
              Icon(
                Icons.arrow_forward_ios,
                color: isDarkMode ? Colors.white54 : Colors.grey[400],
                size: 16,
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
