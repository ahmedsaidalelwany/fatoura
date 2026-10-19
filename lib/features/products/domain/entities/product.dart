import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String id;
  final String name;

  /// SKU (Stock Keeping Unit) — alphanumeric internal reference.
  final String sku;

  /// Barcode — stored as a plain string to preserve leading zeros and support
  /// EAN-13, EAN-8, UPC-A, UPC-E, Code 128, and other formats.
  /// Never apply numeric arithmetic or locale digit substitution to this field.
  final String barcode;

  final String description;
  final double defaultUnitPrice;
  final double costPrice;
  final String category;
  final bool isArchived;

  /// Stock quantity. Only relevant for product-type items.
  /// May be fractional for weight-based products.
  final double stockQuantity;

  /// Reorder threshold. Alert when stockQuantity falls below this level.
  final double reorderLevel;

  /// Whether stock quantity is tracked for this product.
  final bool trackInventory;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.name,
    this.sku = '',
    this.barcode = '',
    this.description = '',
    required this.defaultUnitPrice,
    this.costPrice = 0.0,
    this.category = '',
    this.isArchived = false,
    this.stockQuantity = 0.0,
    this.reorderLevel = 0.0,
    this.trackInventory = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    String? barcode,
    String? description,
    double? defaultUnitPrice,
    double? costPrice,
    String? category,
    bool? isArchived,
    double? stockQuantity,
    double? reorderLevel,
    bool? trackInventory,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      description: description ?? this.description,
      defaultUnitPrice: defaultUnitPrice ?? this.defaultUnitPrice,
      costPrice: costPrice ?? this.costPrice,
      category: category ?? this.category,
      isArchived: isArchived ?? this.isArchived,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      trackInventory: trackInventory ?? this.trackInventory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'description': description,
      'defaultUnitPrice': defaultUnitPrice,
      'costPrice': costPrice,
      'category': category,
      'isArchived': isArchived,
      'stockQuantity': stockQuantity,
      'reorderLevel': reorderLevel,
      'trackInventory': trackInventory,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      sku: map['sku'] as String? ?? '',
      // Barcode must be read as a String to preserve leading zeros.
      // Never cast to int or apply numeric operations.
      barcode: map['barcode'] as String? ?? '',
      description: map['description'] as String? ?? '',
      defaultUnitPrice: (map['defaultUnitPrice'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String? ?? '',
      isArchived: map['isArchived'] as bool? ?? false,
      stockQuantity: (map['stockQuantity'] as num?)?.toDouble() ?? 0.0,
      reorderLevel: (map['reorderLevel'] as num?)?.toDouble() ?? 0.0,
      trackInventory: map['trackInventory'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Whether this product is low on stock relative to its reorder level.
  bool get isLowStock =>
      trackInventory && reorderLevel > 0 && stockQuantity <= reorderLevel;

  /// Whether this product is out of stock.
  bool get isOutOfStock => trackInventory && stockQuantity <= 0;

  @override
  List<Object?> get props => [
    id,
    name,
    sku,
    barcode,
    description,
    defaultUnitPrice,
    costPrice,
    category,
    isArchived,
    stockQuantity,
    reorderLevel,
    trackInventory,
    createdAt,
    updatedAt,
  ];
}
