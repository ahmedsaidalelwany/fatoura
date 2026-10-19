import 'package:equatable/equatable.dart';

import 'package:fatoura/features/invoices/domain/entities/invoice.dart';

class PurchaseInvoiceItem extends Equatable {
  final String id;
  final String description;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  const PurchaseInvoiceItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'lineTotal': lineTotal,
    };
  }

  factory PurchaseInvoiceItem.fromMap(Map<String, dynamic> map) {
    return PurchaseInvoiceItem(
      id: map['id'] as String? ?? '',
      description: map['description'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      lineTotal: (map['lineTotal'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  List<Object?> get props => [id, description, quantity, unitPrice, lineTotal];
}

class PurchaseInvoice extends Equatable {
  final String id;
  final String purchaseNumber;
  final String supplierId;
  final String supplierName;
  final String supplierPhone;
  final DateTime issueDate;
  final List<PurchaseInvoiceItem> items;
  final double subtotal;
  final String discountType;
  final double discountInput;
  final double discountAmount;
  final double taxableBase;
  final double taxRate;
  final double taxAmount;
  final double finalTotal;
  final double amountPaid;
  final double remainingPayable;
  final String currency;
  final String notes;
  final DocumentStatus documentStatus;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PurchaseInvoice({
    required this.id,
    required this.purchaseNumber,
    required this.supplierId,
    required this.supplierName,
    this.supplierPhone = '',
    required this.issueDate,
    required this.items,
    required this.subtotal,
    this.discountType = 'fixed',
    this.discountInput = 0.0,
    this.discountAmount = 0.0,
    required this.taxableBase,
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
    required this.finalTotal,
    this.amountPaid = 0.0,
    required this.remainingPayable,
    this.currency = 'SAR',
    this.notes = '',
    this.documentStatus = DocumentStatus.issued,
    this.paymentStatus = PaymentStatus.unpaid,
    required this.createdAt,
    required this.updatedAt,
  });

  PurchaseInvoice copyWith({
    String? id,
    String? purchaseNumber,
    String? supplierId,
    String? supplierName,
    String? supplierPhone,
    DateTime? issueDate,
    List<PurchaseInvoiceItem>? items,
    double? subtotal,
    String? discountType,
    double? discountInput,
    double? discountAmount,
    double? taxableBase,
    double? taxRate,
    double? taxAmount,
    double? finalTotal,
    double? amountPaid,
    double? remainingPayable,
    String? currency,
    String? notes,
    DocumentStatus? documentStatus,
    PaymentStatus? paymentStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PurchaseInvoice(
      id: id ?? this.id,
      purchaseNumber: purchaseNumber ?? this.purchaseNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      supplierPhone: supplierPhone ?? this.supplierPhone,
      issueDate: issueDate ?? this.issueDate,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discountType: discountType ?? this.discountType,
      discountInput: discountInput ?? this.discountInput,
      discountAmount: discountAmount ?? this.discountAmount,
      taxableBase: taxableBase ?? this.taxableBase,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      finalTotal: finalTotal ?? this.finalTotal,
      amountPaid: amountPaid ?? this.amountPaid,
      remainingPayable: remainingPayable ?? this.remainingPayable,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      documentStatus: documentStatus ?? this.documentStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchaseNumber': purchaseNumber,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'supplierPhone': supplierPhone,
      'issueDate': issueDate.toIso8601String(),
      'items': items.map((x) => x.toMap()).toList(),
      'subtotal': subtotal,
      'discountType': discountType,
      'discountInput': discountInput,
      'discountAmount': discountAmount,
      'taxableBase': taxableBase,
      'taxRate': taxRate,
      'taxAmount': taxAmount,
      'finalTotal': finalTotal,
      'amountPaid': amountPaid,
      'remainingPayable': remainingPayable,
      'currency': currency,
      'notes': notes,
      'documentStatus': documentStatus.name,
      'paymentStatus': paymentStatus.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PurchaseInvoice.fromMap(Map<String, dynamic> map) {
    return PurchaseInvoice(
      id: map['id'] as String? ?? '',
      purchaseNumber: map['purchaseNumber'] as String? ?? '',
      supplierId: map['supplierId'] as String? ?? '',
      supplierName: map['supplierName'] as String? ?? '',
      supplierPhone: map['supplierPhone'] as String? ?? '',
      issueDate:
          DateTime.tryParse(map['issueDate'] as String? ?? '') ??
          DateTime.now(),
      items:
          (map['items'] as List<dynamic>?)
              ?.map(
                (x) => PurchaseInvoiceItem.fromMap(
                  Map<String, dynamic>.from(x as Map),
                ),
              )
              .toList() ??
          [],
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountType: map['discountType'] as String? ?? 'fixed',
      discountInput: (map['discountInput'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0.0,
      taxableBase: (map['taxableBase'] as num?)?.toDouble() ?? 0.0,
      taxRate: (map['taxRate'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['taxAmount'] as num?)?.toDouble() ?? 0.0,
      finalTotal: (map['finalTotal'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0.0,
      remainingPayable: (map['remainingPayable'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'SAR',
      notes: map['notes'] as String? ?? '',
      documentStatus: DocumentStatus.values.firstWhere(
        (e) => e.name == map['documentStatus'],
        orElse: () => DocumentStatus.issued,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == map['paymentStatus'],
        orElse: () => PaymentStatus.unpaid,
      ),
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
    purchaseNumber,
    supplierId,
    supplierName,
    finalTotal,
    amountPaid,
    remainingPayable,
    documentStatus,
    paymentStatus,
    createdAt,
  ];
}
