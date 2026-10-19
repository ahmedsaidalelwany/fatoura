import 'package:equatable/equatable.dart';

class ShopProfile extends Equatable {
  final String id;
  final String name;
  final String businessType;
  final String phone;
  final String address;
  final String defaultCurrency;
  final String taxNumber;
  final bool defaultTaxEnabled;
  final double defaultTaxRate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShopProfile({
    required this.id,
    required this.name,
    required this.businessType,
    this.phone = '',
    this.address = '',
    this.defaultCurrency = 'EGP',
    this.taxNumber = '',
    this.defaultTaxEnabled = false,
    this.defaultTaxRate = 15.0,
    required this.createdAt,
    required this.updatedAt,
  });

  ShopProfile copyWith({
    String? id,
    String? name,
    String? businessType,
    String? phone,
    String? address,
    String? defaultCurrency,
    String? taxNumber,
    bool? defaultTaxEnabled,
    double? defaultTaxRate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShopProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      businessType: businessType ?? this.businessType,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      taxNumber: taxNumber ?? this.taxNumber,
      defaultTaxEnabled: defaultTaxEnabled ?? this.defaultTaxEnabled,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'businessType': businessType,
      'phone': phone,
      'address': address,
      'defaultCurrency': defaultCurrency,
      'taxNumber': taxNumber,
      'defaultTaxEnabled': defaultTaxEnabled,
      'defaultTaxRate': defaultTaxRate,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ShopProfile.fromMap(Map<String, dynamic> map) {
    return ShopProfile(
      id: map['id'] as String? ?? 'default_shop',
      name: map['name'] as String? ?? '',
      businessType: map['businessType'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      defaultCurrency: map['defaultCurrency'] as String? ?? 'EGP',
      taxNumber: map['taxNumber'] as String? ?? '',
      defaultTaxEnabled: map['defaultTaxEnabled'] as bool? ?? false,
      defaultTaxRate: (map['defaultTaxRate'] as num?)?.toDouble() ?? 15.0,
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
    businessType,
    phone,
    address,
    defaultCurrency,
    taxNumber,
    defaultTaxEnabled,
    defaultTaxRate,
    createdAt,
    updatedAt,
  ];
}
