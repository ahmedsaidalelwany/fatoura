import 'package:equatable/equatable.dart';

enum PaymentMethod { cash, bank, card, other }

class PaymentAllocation extends Equatable {
  final String id;
  final String paymentId;
  final String invoiceId;
  final String invoiceNumber;
  final double amount;
  final DateTime allocatedAt;

  const PaymentAllocation({
    required this.id,
    required this.paymentId,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.amount,
    required this.allocatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'paymentId': paymentId,
      'invoiceId': invoiceId,
      'invoiceNumber': invoiceNumber,
      'amount': amount,
      'allocatedAt': allocatedAt.toIso8601String(),
    };
  }

  factory PaymentAllocation.fromMap(Map<String, dynamic> map) {
    return PaymentAllocation(
      id: map['id'] as String? ?? '',
      paymentId: map['paymentId'] as String? ?? '',
      invoiceId: map['invoiceId'] as String? ?? '',
      invoiceNumber: map['invoiceNumber'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      allocatedAt:
          DateTime.tryParse(map['allocatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    paymentId,
    invoiceId,
    invoiceNumber,
    amount,
    allocatedAt,
  ];
}

class Payment extends Equatable {
  final String id;
  final double amount;
  final String currency;
  final DateTime paymentDate;
  final PaymentMethod method;
  final String? partyId;
  final String partyName;
  final bool
  isCustomerPayment; // true = received from customer, false = paid to supplier
  final String referenceNumber;
  final String notes;
  final List<PaymentAllocation> allocations;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Payment({
    required this.id,
    required this.amount,
    this.currency = 'EGP',
    required this.paymentDate,
    this.method = PaymentMethod.cash,
    this.partyId,
    this.partyName = '',
    this.isCustomerPayment = true,
    this.referenceNumber = '',
    this.notes = '',
    this.allocations = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  double get totalAllocated =>
      allocations.fold(0.0, (sum, item) => sum + item.amount);

  double get unallocatedAmount =>
      (amount - totalAllocated) > 0.0 ? (amount - totalAllocated) : 0.0;

  Payment copyWith({
    String? id,
    double? amount,
    String? currency,
    DateTime? paymentDate,
    PaymentMethod? method,
    String? partyId,
    String? partyName,
    bool? isCustomerPayment,
    String? referenceNumber,
    String? notes,
    List<PaymentAllocation>? allocations,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Payment(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      paymentDate: paymentDate ?? this.paymentDate,
      method: method ?? this.method,
      partyId: partyId ?? this.partyId,
      partyName: partyName ?? this.partyName,
      isCustomerPayment: isCustomerPayment ?? this.isCustomerPayment,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
      allocations: allocations ?? this.allocations,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'currency': currency,
      'paymentDate': paymentDate.toIso8601String(),
      'method': method.name,
      'partyId': partyId,
      'partyName': partyName,
      'isCustomerPayment': isCustomerPayment,
      'referenceNumber': referenceNumber,
      'notes': notes,
      'allocations': allocations.map((x) => x.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'EGP',
      paymentDate:
          DateTime.tryParse(map['paymentDate'] as String? ?? '') ??
          DateTime.now(),
      method: PaymentMethod.values.firstWhere(
        (e) => e.name == map['method'],
        orElse: () => PaymentMethod.cash,
      ),
      partyId: map['partyId'] as String?,
      partyName: map['partyName'] as String? ?? '',
      isCustomerPayment: map['isCustomerPayment'] as bool? ?? true,
      referenceNumber: map['referenceNumber'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      allocations:
          (map['allocations'] as List<dynamic>?)
              ?.map(
                (x) => PaymentAllocation.fromMap(
                  Map<String, dynamic>.from(x as Map),
                ),
              )
              .toList() ??
          [],
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
    amount,
    currency,
    paymentDate,
    method,
    partyId,
    partyName,
    isCustomerPayment,
    allocations,
    createdAt,
  ];
}
