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
/// Displays inventory requests that come from headquarters
class RequestFromHQPage extends StatefulWidget {
  const RequestFromHQPage({super.key});

  @override
  State<RequestFromHQPage> createState() => _RequestFromHQPageState();
}

class _RequestFromHQPageState extends State<RequestFromHQPage> {
  List<Map<String, dynamic>> _hqItems = [];
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
        
        // Handle different response structures
        if (responseData is List) {
          // Direct list response
          items = responseData;
        } else if (responseData is Map) {
          // Check for common list keys
          if (responseData.containsKey('data') && responseData['data'] is List) {
            items = responseData['data'];
          } else if (responseData.containsKey('results') && responseData['results'] is List) {
            items = responseData['results'];
          } else if (responseData.containsKey('items') && responseData['items'] is List) {
            items = responseData['items'];
          } else {
            // If it's a single item, wrap it in a list
            items = [responseData];
          }
        }
        
        setState(() {
          _hqItems = List<Map<String, dynamic>>.from(
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
          _isLoading = false;
          _isError = false;
        });
        debugPrint('✅ [RequestFromHQPage] HQ items loaded: ${_hqItems.length} items');
        
        // If no items found, show empty state
        if (_hqItems.isEmpty) {
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
                  : _hqItems.isEmpty
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
                      : RefreshIndicator(
                          onRefresh: _fetchHQItems,
                          color: const Color(0xFFDBB342),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _hqItems.length,
                            itemBuilder: (context, index) {
                              final item = _hqItems[index];
                              return _buildHQItemCard(item, isDarkMode);
                            },
                          ),
                        ),
        );
      },
    );
  }

  Widget _buildHQItemCard(Map<String, dynamic> item, bool isDarkMode) {
    final String name = item['name'] ?? 'No Name';
    final String barcode = item['barcode'] ?? 'No Barcode';
    final String instock = item['instock'] ?? '0';
    final String unit = item['unit'] ?? 'pcs';
    final String minimum = item['minimum'] ?? '0';
    final String minPrice = item['min_price'] ?? '0';
    final String rawImageUrl = item['img_ref'] ?? '';
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
                      'Price: ${double.parse(minPrice).toStringAsFixed(2)} LAK',
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
