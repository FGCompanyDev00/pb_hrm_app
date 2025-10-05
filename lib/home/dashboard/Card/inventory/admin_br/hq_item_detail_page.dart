import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import '../inventory_app_bar.dart';

/// HQ Item Detail page for AdminBR users
/// Displays detailed information about a specific HQ item
class HQItemDetailPage extends StatefulWidget {
  final Map<String, dynamic> itemData;

  const HQItemDetailPage({
    super.key,
    required this.itemData,
  });

  @override
  State<HQItemDetailPage> createState() => _HQItemDetailPageState();
}

class _HQItemDetailPageState extends State<HQItemDetailPage> {
  // Base URL for images
  final String _imageBaseUrl = 'https://demo-flexiflows-inventory-pictures.s3.ap-southeast-1.amazonaws.com/';

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        final isDarkMode = themeNotifier.isDarkMode;
        final item = widget.itemData;

        // Extract item data
        final String name = item['name'] ?? 'No Name';
        final String barcode = item['barcode'] ?? 'No Barcode';
        final String instock = item['instock'] ?? '0';
        final String unit = item['unit'] ?? 'pcs';
        final String minimum = item['minimum'] ?? '0';
        final String minPrice = item['min_price'] ?? '0';
        final String importId = item['import_id']?.toString() ?? 'N/A';
        final String id = item['id']?.toString() ?? 'N/A';
        final String rawImageUrl = item['img_ref'] ?? '';
        final String imageUrl = rawImageUrl.isNotEmpty
            ? (rawImageUrl.startsWith('http') ? rawImageUrl : '$_imageBaseUrl$rawImageUrl')
            : '';

        return Scaffold(
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          appBar: const InventoryAppBar(
            title: 'HQ Item Details',
            showBack: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item Image Section
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFDBB342).withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode
                              ? Colors.black.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                child: Icon(
                                  Icons.inventory_2,
                                  color: isDarkMode ? Colors.white : Colors.grey[600],
                                  size: 64,
                                ),
                              ),
                            )
                          : Container(
                              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                              child: Icon(
                                Icons.inventory_2,
                                color: isDarkMode ? Colors.white : Colors.grey[600],
                                size: 64,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Item Information Section
                _buildInfoSection(
                  'Item Information',
                  [
                    _buildInfoRow('Name', name, isDarkMode),
                    _buildInfoRow('Barcode', barcode, isDarkMode),
                    _buildInfoRow('Import ID', importId, isDarkMode),
                    _buildInfoRow('Item ID', id, isDarkMode),
                  ],
                  isDarkMode,
                ),
                const SizedBox(height: 20),

                // Stock Information Section
                _buildInfoSection(
                  'Stock Information',
                  [
                    _buildInfoRow('Current Stock', '$instock $unit', isDarkMode, valueColor: Colors.green),
                    _buildInfoRow('Minimum Stock', '$minimum $unit', isDarkMode, valueColor: Colors.orange),
                    _buildInfoRow('Unit', unit, isDarkMode),
                  ],
                  isDarkMode,
                ),
                const SizedBox(height: 20),

                // Price Information Section
                _buildInfoSection(
                  'Price Information',
                  [
                    _buildInfoRow('Minimum Price', '${double.parse(minPrice).toStringAsFixed(2)} LAK', isDarkMode, valueColor: const Color(0xFFDBB342)),
                  ],
                  isDarkMode,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFDBB342).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFDBB342),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDarkMode, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor ?? (isDarkMode ? Colors.white : Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
