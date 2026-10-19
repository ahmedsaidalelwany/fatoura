import 'package:equatable/equatable.dart';

enum RefundMethod { cash, credit }

class SalesReturnItem extends Equatable {
  final String id;
  final String invoiceItemId;
  final String description;
  final double returnedQuantity;
  final double unitPrice;
  final double refundAmount;

  const SalesReturnItem({
    required this.id,
    required this.invoiceItemId,
    required this.description,
    required this.returnedQuantity,
    required this.unitPrice,
    required this.refundAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceItemId': invoiceItemId,
      'description': description,
      'returnedQuantity': returnedQuantity,
      'unitPrice': unitPrice,
      'refundAmount': refundAmount,
    };
  }

  factory SalesReturnItem.fromMap(Map<String, dynamic> map) {
    return SalesReturnItem(
      id: map['id'] as String? ?? '',
      invoiceItemId: map['invoiceItemId'] as String? ?? '',
      description: map['description'] as String? ?? '',
      returnedQuantity: (map['returnedQuantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      refundAmount: (map['refundAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  List<Object?> get props => [
    id,
    invoiceItemId,
    description,
    returnedQuantity,
    unitPrice,
    refundAmount,
  ];
}

class SalesReturn extends Equatable {
  final String id;
  final String returnNumber;
  final DateTime returnDate;
  final String originalInvoiceId;
  final String originalInvoiceNumber;
  final String? customerId;
  final String customerName;
  final List<SalesReturnItem> items;
  final double totalRefundAmount;
  final String returnReason;
  final RefundMethod refundMethod;
  final String notes;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SalesReturn({
    required this.id,
    required this.returnNumber,
    required this.returnDate,
    required this.originalInvoiceId,
    required this.originalInvoiceNumber,
    this.customerId,
    this.customerName = '',
    required this.items,
    required this.totalRefundAmount,
    required this.returnReason,
    this.refundMethod = RefundMethod.cash,
    this.notes = '',
    this.currency = 'SAR',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'returnNumber': returnNumber,
      'returnDate': returnDate.toIso8601String(),
      'originalInvoiceId': originalInvoiceId,
      'originalInvoiceNumber': originalInvoiceNumber,
      'customerId': customerId,
      'customerName': customerName,
      'items': items.map((x) => x.toMap()).toList(),
      'totalRefundAmount': totalRefundAmount,
      'returnReason': returnReason,
      'refundMethod': refundMethod.name,
      'notes': notes,
      'currency': currency,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SalesReturn.fromMap(Map<String, dynamic> map) {
    return SalesReturn(
      id: map['id'] as String? ?? '',
      returnNumber: map['returnNumber'] as String? ?? '',
      returnDate:
          DateTime.tryParse(map['returnDate'] as String? ?? '') ??
          DateTime.now(),
      originalInvoiceId: map['originalInvoiceId'] as String? ?? '',
      originalInvoiceNumber: map['originalInvoiceNumber'] as String? ?? '',
      customerId: map['customerId'] as String?,
      customerName: map['customerName'] as String? ?? '',
      items:
          (map['items'] as List<dynamic>?)
              ?.map(
                (x) => SalesReturnItem.fromMap(
                  Map<String, dynamic>.from(x as Map),
                ),
              )
              .toList() ??
          [],
      totalRefundAmount: (map['totalRefundAmount'] as num?)?.toDouble() ?? 0.0,
      returnReason: map['returnReason'] as String? ?? '',
      refundMethod: RefundMethod.values.firstWhere(
        (e) => e.name == map['refundMethod'],
        orElse: () => RefundMethod.cash,
      ),
      notes: map['notes'] as String? ?? '',
      currency: map['currency'] as String? ?? 'SAR',
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
    returnNumber,
    returnDate,
    originalInvoiceId,
    items,
    totalRefundAmount,
    returnReason,
    refundMethod,
    createdAt,
  ];
}
