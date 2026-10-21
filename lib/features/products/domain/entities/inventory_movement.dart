import 'package:equatable/equatable.dart';

enum InventoryMovementType {
  sale,
  purchaseReceipt,
  customerReturn,
  supplierReturn,
  manualAdjustment,
  purchaseCancellation,
  salesCancellation,
  openingStock,
  reconciliation,
}

class InventoryMovement extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final double quantityDelta; // Positive for additions, negative for deductions
  final double quantityBefore;
  final double quantityAfter;
  final InventoryMovementType movementType;
  final String sourceDocumentType; // 'sales_invoice', 'purchase_invoice', 'sales_return', 'stock_adjustment', etc.
  final String sourceDocumentId;
  final String sourceDocumentNumber;
  final String reason;
  final DateTime timestamp;
  final DateTime createdAt;

  const InventoryMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantityDelta,
    required this.quantityBefore,
    required this.quantityAfter,
    required this.movementType,
    required this.sourceDocumentType,
    this.sourceDocumentId = '',
    this.sourceDocumentNumber = '',
    this.reason = '',
    required this.timestamp,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'quantityDelta': quantityDelta,
      'quantityBefore': quantityBefore,
      'quantityAfter': quantityAfter,
      'movementType': movementType.name,
      'sourceDocumentType': sourceDocumentType,
      'sourceDocumentId': sourceDocumentId,
      'sourceDocumentNumber': sourceDocumentNumber,
      'reason': reason,
      'timestamp': timestamp.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory InventoryMovement.fromMap(Map<String, dynamic> map) {
    final typeName = map['movementType'] as String? ?? 'manualAdjustment';
    final type = InventoryMovementType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => InventoryMovementType.manualAdjustment,
    );

    return InventoryMovement(
      id: map['id'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      quantityDelta: (map['quantityDelta'] as num?)?.toDouble() ?? 0.0,
      quantityBefore: (map['quantityBefore'] as num?)?.toDouble() ?? 0.0,
      quantityAfter: (map['quantityAfter'] as num?)?.toDouble() ?? 0.0,
      movementType: type,
      sourceDocumentType: map['sourceDocumentType'] as String? ?? '',
      sourceDocumentId: map['sourceDocumentId'] as String? ?? '',
      sourceDocumentNumber: map['sourceDocumentNumber'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        quantityDelta,
        quantityBefore,
        quantityAfter,
        movementType,
        sourceDocumentType,
        sourceDocumentId,
        timestamp,
      ];
}
