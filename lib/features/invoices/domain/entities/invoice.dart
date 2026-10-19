import 'package:equatable/equatable.dart';

enum DocumentStatus { draft, issued, cancelled }

enum PaymentStatus { unpaid, partiallyPaid, fullyPaid, refunded }

enum InvoiceTemplate { product, service, mixed }

class InvoiceItem extends Equatable {
  final String id;
  final String? productId;
  final String description;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
  final bool isService;

  const InvoiceItem({
    required this.id,
    this.productId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.isService = false,
  });

  InvoiceItem copyWith({
    String? id,
    String? productId,
    String? description,
    double? quantity,
    double? unitPrice,
    double? lineTotal,
    bool? isService,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      lineTotal: lineTotal ?? this.lineTotal,
      isService: isService ?? this.isService,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'lineTotal': lineTotal,
      'isService': isService,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'] as String? ?? '',
      productId: map['productId'] as String?,
      description: map['description'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      lineTotal: (map['lineTotal'] as num?)?.toDouble() ?? 0.0,
      isService: map['isService'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    id,
    productId,
    description,
    quantity,
    unitPrice,
    lineTotal,
    isService,
  ];
}

class Invoice extends Equatable {
  final String id;
  final String invoiceNumber; // e.g. Ftr-19.10.2026-0001
  final DateTime issueDate;

  // Shop snapshot
  final String shopName;
  final String shopPhone;
  final String shopAddress;
  final String shopTaxNumber;
  final String shopLogoPath;
  final String shopSignaturePath;

  // Customer snapshot (Optional for cash sales)
  final String? customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;

  final List<InvoiceItem> items;

  // Financials
  final double subtotal;
  final String discountType; // 'fixed' or 'percentage'
  final double discountInput;
  final double discountAmount;
  final double taxableBase;
  final double taxRate;
  final double taxAmount;
  final double finalTotal;
  final double totalPaid;
  final double remainingBalance;

  final DocumentStatus documentStatus;
  final PaymentStatus paymentStatus;

  // Cancellation metadata
  final DateTime? cancelledAt;
  final String? cancellationReason;

  final InvoiceTemplate template;
  final String currency;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.issueDate,
    required this.shopName,
    this.shopPhone = '',
    this.shopAddress = '',
    this.shopTaxNumber = '',
    this.shopLogoPath = '',
    this.shopSignaturePath = '',
    this.customerId,
    this.customerName = '',
    this.customerPhone = '',
    this.customerAddress = '',
    required this.items,
    required this.subtotal,
    this.discountType = 'fixed',
    this.discountInput = 0.0,
    this.discountAmount = 0.0,
    required this.taxableBase,
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
    required this.finalTotal,
    this.totalPaid = 0.0,
    required this.remainingBalance,
    this.documentStatus = DocumentStatus.issued,
    this.paymentStatus = PaymentStatus.unpaid,
    this.template = InvoiceTemplate.product,
    this.cancelledAt,
    this.cancellationReason,
    this.currency = 'EGP',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDraft => documentStatus == DocumentStatus.draft;
  bool get isIssued => documentStatus == DocumentStatus.issued;
  bool get isCancelled => documentStatus == DocumentStatus.cancelled;
  bool get isCashSale => customerId == null || customerId!.isEmpty;

  Invoice copyWith({
    String? id,
    String? invoiceNumber,
    DateTime? issueDate,
    String? shopName,
    String? shopPhone,
    String? shopAddress,
    String? shopTaxNumber,
    String? shopLogoPath,
    String? shopSignaturePath,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    List<InvoiceItem>? items,
    double? subtotal,
    String? discountType,
    double? discountInput,
    double? discountAmount,
    double? taxableBase,
    double? taxRate,
    double? taxAmount,
    double? finalTotal,
    double? totalPaid,
    double? remainingBalance,
    DocumentStatus? documentStatus,
    PaymentStatus? paymentStatus,
    InvoiceTemplate? template,
    DateTime? cancelledAt,
    String? cancellationReason,
    String? currency,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      issueDate: issueDate ?? this.issueDate,
      shopName: shopName ?? this.shopName,
      shopPhone: shopPhone ?? this.shopPhone,
      shopAddress: shopAddress ?? this.shopAddress,
      shopTaxNumber: shopTaxNumber ?? this.shopTaxNumber,
      shopLogoPath: shopLogoPath ?? this.shopLogoPath,
      shopSignaturePath: shopSignaturePath ?? this.shopSignaturePath,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discountType: discountType ?? this.discountType,
      discountInput: discountInput ?? this.discountInput,
      discountAmount: discountAmount ?? this.discountAmount,
      taxableBase: taxableBase ?? this.taxableBase,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      finalTotal: finalTotal ?? this.finalTotal,
      totalPaid: totalPaid ?? this.totalPaid,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      documentStatus: documentStatus ?? this.documentStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      template: template ?? this.template,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'issueDate': issueDate.toIso8601String(),
      'shopName': shopName,
      'shopPhone': shopPhone,
      'shopAddress': shopAddress,
      'shopTaxNumber': shopTaxNumber,
      'shopLogoPath': shopLogoPath,
      'shopSignaturePath': shopSignaturePath,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'items': items.map((x) => x.toMap()).toList(),
      'subtotal': subtotal,
      'discountType': discountType,
      'discountInput': discountInput,
      'discountAmount': discountAmount,
      'taxableBase': taxableBase,
      'taxRate': taxRate,
      'taxAmount': taxAmount,
      'finalTotal': finalTotal,
      'totalPaid': totalPaid,
      'remainingBalance': remainingBalance,
      'documentStatus': documentStatus.name,
      'paymentStatus': paymentStatus.name,
      'template': template.name,
      'cancelledAt': cancelledAt?.toIso8601String(),
      'cancellationReason': cancellationReason,
      'currency': currency,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    final parsedItems =
        (map['items'] as List<dynamic>?)
            ?.map(
              (x) => InvoiceItem.fromMap(Map<String, dynamic>.from(x as Map)),
            )
            .toList() ??
        [];

    final templateName = map['template'] as String?;
    final InvoiceTemplate resolvedTemplate;
    if (templateName != null) {
      resolvedTemplate = InvoiceTemplate.values.firstWhere(
        (e) => e.name == templateName,
        orElse: () => InvoiceTemplate.product,
      );
    } else {
      if (parsedItems.isNotEmpty && parsedItems.every((it) => it.isService)) {
        resolvedTemplate = InvoiceTemplate.service;
      } else if (parsedItems.isNotEmpty && parsedItems.every((it) => !it.isService)) {
        resolvedTemplate = InvoiceTemplate.product;
      } else {
        resolvedTemplate = InvoiceTemplate.mixed;
      }
    }

    return Invoice(
      id: map['id'] as String? ?? '',
      invoiceNumber: map['invoiceNumber'] as String? ?? '',
      issueDate:
          DateTime.tryParse(map['issueDate'] as String? ?? '') ??
          DateTime.now(),
      shopName: map['shopName'] as String? ?? '',
      shopPhone: map['shopPhone'] as String? ?? '',
      shopAddress: map['shopAddress'] as String? ?? '',
      shopTaxNumber: map['shopTaxNumber'] as String? ?? '',
      shopLogoPath: map['shopLogoPath'] as String? ?? '',
      shopSignaturePath: map['shopSignaturePath'] as String? ?? '',
      customerId: map['customerId'] as String?,
      customerName: map['customerName'] as String? ?? '',
      customerPhone: map['customerPhone'] as String? ?? '',
      customerAddress: map['customerAddress'] as String? ?? '',
      items: parsedItems,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountType: map['discountType'] as String? ?? 'fixed',
      discountInput: (map['discountInput'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0.0,
      taxableBase: (map['taxableBase'] as num?)?.toDouble() ?? 0.0,
      taxRate: (map['taxRate'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['taxAmount'] as num?)?.toDouble() ?? 0.0,
      finalTotal: (map['finalTotal'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (map['totalPaid'] as num?)?.toDouble() ?? 0.0,
      remainingBalance: (map['remainingBalance'] as num?)?.toDouble() ?? 0.0,
      documentStatus: DocumentStatus.values.firstWhere(
        (e) => e.name == map['documentStatus'],
        orElse: () => DocumentStatus.issued,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == map['paymentStatus'],
        orElse: () => PaymentStatus.unpaid,
      ),
      template: resolvedTemplate,
      cancelledAt: map['cancelledAt'] != null
          ? DateTime.tryParse(map['cancelledAt'] as String)
          : null,
      cancellationReason: map['cancellationReason'] as String?,
      currency: map['currency'] as String? ?? 'EGP',
      notes: map['notes'] as String? ?? '',
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
    invoiceNumber,
    issueDate,
    customerId,
    customerName,
    items,
    finalTotal,
    totalPaid,
    remainingBalance,
    documentStatus,
    paymentStatus,
    template,
    cancelledAt,
    createdAt,
  ];
}
