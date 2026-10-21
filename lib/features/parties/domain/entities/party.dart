import 'package:equatable/equatable.dart';

enum PartyType { customer, supplier, both }

class Party extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String email;
  final String notes;
  final bool isCustomer;
  final bool isSupplier;
  final double openingReceivable; // What the customer owes us initially
  final String openingReceivableCurrency;
  final double openingPayable; // What we owe the supplier initially
  final String openingPayableCurrency;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Party({
    required this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.email = '',
    this.notes = '',
    this.isCustomer = true,
    this.isSupplier = false,
    this.openingReceivable = 0.0,
    this.openingReceivableCurrency = 'EGP',
    this.openingPayable = 0.0,
    this.openingPayableCurrency = 'EGP',
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Party copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? email,
    String? notes,
    bool? isCustomer,
    bool? isSupplier,
    double? openingReceivable,
    String? openingReceivableCurrency,
    double? openingPayable,
    String? openingPayableCurrency,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Party(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      isCustomer: isCustomer ?? this.isCustomer,
      isSupplier: isSupplier ?? this.isSupplier,
      openingReceivable: openingReceivable ?? this.openingReceivable,
      openingReceivableCurrency:
          openingReceivableCurrency ?? this.openingReceivableCurrency,
      openingPayable: openingPayable ?? this.openingPayable,
      openingPayableCurrency:
          openingPayableCurrency ?? this.openingPayableCurrency,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'email': email,
      'notes': notes,
      'isCustomer': isCustomer,
      'isSupplier': isSupplier,
      'openingReceivable': openingReceivable,
      'openingReceivableCurrency': openingReceivableCurrency,
      'openingPayable': openingPayable,
      'openingPayableCurrency': openingPayableCurrency,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Party.fromMap(Map<String, dynamic> map) {
    return Party(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      email: map['email'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      isCustomer: map['isCustomer'] as bool? ?? true,
      isSupplier: map['isSupplier'] as bool? ?? false,
      openingReceivable: (map['openingReceivable'] as num?)?.toDouble() ?? 0.0,
      openingReceivableCurrency:
          map['openingReceivableCurrency'] as String? ?? 'EGP',
      openingPayable: (map['openingPayable'] as num?)?.toDouble() ?? 0.0,
      openingPayableCurrency:
          map['openingPayableCurrency'] as String? ?? 'EGP',
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
    phone,
    address,
    email,
    notes,
    isCustomer,
    isSupplier,
    openingReceivable,
    openingReceivableCurrency,
    openingPayable,
    openingPayableCurrency,
    isArchived,
    createdAt,
    updatedAt,
  ];
}
