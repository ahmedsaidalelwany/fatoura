import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String id;
  final String name;
  final String sku;
  final String description;
  final double defaultUnitPrice;
  final String category;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.name,
    this.sku = '',
    this.description = '',
    required this.defaultUnitPrice,
    this.category = '',
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    String? description,
    double? defaultUnitPrice,
    String? category,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      description: description ?? this.description,
      defaultUnitPrice: defaultUnitPrice ?? this.defaultUnitPrice,
      category: category ?? this.category,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'description': description,
      'defaultUnitPrice': defaultUnitPrice,
      'category': category,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      sku: map['sku'] as String? ?? '',
      description: map['description'] as String? ?? '',
      defaultUnitPrice: (map['defaultUnitPrice'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String? ?? '',
      isArchived: map['isArchived'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    sku,
    description,
    defaultUnitPrice,
    category,
    isArchived,
    createdAt,
    updatedAt,
  ];
}
