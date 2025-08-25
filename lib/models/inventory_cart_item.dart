class InventoryCartItem {
  final String barcode;
  final String name;
  final String description;
  final String? imageUrl;
  final String categoryName;
  final String? price;
  final String? unit;
  final String? status;
  final String? instock; // Add stock information
  int quantity;

  InventoryCartItem({
    required this.barcode,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.categoryName,
    this.price,
    this.unit,
    this.status,
    this.instock,
    this.quantity = 1,
  });

  // Create from inventory item map
  factory InventoryCartItem.fromInventoryItem(Map<String, dynamic> item, String categoryName) {
    final String rawImageUrl = item['img_name'] ?? item['img_ref'] ?? '';
    final String imageUrl = rawImageUrl.isNotEmpty
        ? (rawImageUrl.startsWith('http') ? rawImageUrl : 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/$rawImageUrl')
        : '';
    
    return InventoryCartItem(
      barcode: item['barcode'] ?? '',
      name: item['name'] ?? 'Unknown Item',
      description: item['description'] ?? 'No description available',
      imageUrl: imageUrl,
      categoryName: categoryName,
      price: item['min_price']?.toString() ?? '',
      unit: item['unit'] ?? '',
      status: item['status'] ?? 'Available',
      instock: item['instock']?.toString() ?? '',
      quantity: 1,
    );
  }

  // Convert to API request format
  Map<String, dynamic> toApiFormat() {
    return {
      'barcode': barcode,
      'quantity': quantity,
    };
  }

  // Copy with new quantity
  InventoryCartItem copyWith({int? quantity}) {
    return InventoryCartItem(
      barcode: barcode,
      name: name,
      description: description,
      imageUrl: imageUrl,
      categoryName: categoryName,
      price: price,
      unit: unit,
      status: status,
      instock: instock,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InventoryCartItem && other.barcode == barcode;
  }

  @override
  int get hashCode => barcode.hashCode;

  @override
  String toString() {
    return 'InventoryCartItem(barcode: $barcode, name: $name, quantity: $quantity)';
  }
}
