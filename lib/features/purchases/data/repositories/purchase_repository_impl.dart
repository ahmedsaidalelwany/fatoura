import 'package:decimal/decimal.dart';
import 'package:uuid/uuid.dart';

import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';
import 'package:fatoura/features/products/domain/entities/inventory_movement.dart';
import 'package:fatoura/features/products/domain/entities/product.dart';
import 'package:fatoura/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:fatoura/features/purchases/domain/repositories/purchase_repository.dart';

class PurchaseRepositoryImpl implements PurchaseRepository {
  final HiveDatabase database;

  PurchaseRepositoryImpl(this.database);

  @override
  Future<List<PurchaseInvoice>> getPurchases({
    String? supplierId,
    DocumentStatus? documentStatus,
    PaymentStatus? paymentStatus,
    DateTime? fromDate,
    DateTime? toDate,
    String? query,
  }) async {
    final box = database.purchasesBox;
    final results = <PurchaseInvoice>[];

    for (final key in box.keys) {
      final map = box.get(key);
      if (map != null) {
        final purchase = PurchaseInvoice.fromMap(
          Map<String, dynamic>.from(map),
        );

        if (supplierId != null && purchase.supplierId != supplierId) {
          continue;
        }
        if (documentStatus != null &&
            purchase.documentStatus != documentStatus) {
          continue;
        }
        if (paymentStatus != null && purchase.paymentStatus != paymentStatus) {
          continue;
        }
        if (fromDate != null &&
            purchase.issueDate.isBefore(
              DateTime(fromDate.year, fromDate.month, fromDate.day),
            )) {
          continue;
        }
        if (toDate != null &&
            purchase.issueDate.isAfter(
              DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59),
            )) {
          continue;
        }
        if (query != null && query.trim().isNotEmpty) {
          final q = query.trim().toLowerCase();
          final matchesNumber = purchase.purchaseNumber.toLowerCase().contains(
            q,
          );
          final matchesSupplier = purchase.supplierName.toLowerCase().contains(
            q,
          );
          final matchesItem = purchase.items.any(
            (item) => item.description.toLowerCase().contains(q),
          );
          if (!matchesNumber && !matchesSupplier && !matchesItem) {
            continue;
          }
        }

        results.add(purchase);
      }
    }

    results.sort((a, b) => b.issueDate.compareTo(a.issueDate));
    return results;
  }

  @override
  Future<PurchaseInvoice?> getPurchaseById(String id) async {
    final box = database.purchasesBox;
    final map = box.get(id);
    if (map == null) return null;
    return PurchaseInvoice.fromMap(Map<String, dynamic>.from(map));
  }

  @override
  Future<void> savePurchase(PurchaseInvoice purchase) async {
    final box = database.purchasesBox;
    final existingMap = box.get(purchase.id);
    final wasStockReceived =
        existingMap != null && (existingMap['isStockReceived'] == true);

    if (wasStockReceived) {
      final existing = PurchaseInvoice.fromMap(
        Map<String, dynamic>.from(existingMap),
      );
      if (!_receivedPurchaseTermsMatch(existing, purchase)) {
        throw StateError(
          'لا يمكن تعديل بنود أو قيمة فاتورة مشتريات بعد استلام المخزون. '
          'أنشئ مستند تسوية أو إرجاع موثق بدلًا من تعديل السجل الأصلي.',
        );
      }
      await box.put(purchase.id, purchase.toMap());
      return;
    }

    if (!purchase.isStockReceived) {
      await box.put(purchase.id, purchase.toMap());
      return;
    }

    await database.runExclusive(() async {
      final latestMap = box.get(purchase.id);
      final latestWasStockReceived =
          latestMap != null && (latestMap['isStockReceived'] == true);
      if (latestWasStockReceived) {
        final latest = PurchaseInvoice.fromMap(
          Map<String, dynamic>.from(latestMap!),
        );
        if (!_receivedPurchaseTermsMatch(latest, purchase)) {
          throw StateError(
            'تم استلام فاتورة المشتريات بالفعل بمحتوى مختلف. أعد تحميلها قبل المتابعة.',
          );
        }
        return;
      }

      if (purchase.items.isEmpty) {
        throw StateError('لا يمكن استلام فاتورة مشتريات دون بنود.');
      }

      final productsBox = database.productsBox;
      final additions = <String, double>{};
      final itemUnitPrices = <String, double>{};
      for (final item in purchase.items) {
        final productId = item.productId;
        if (productId == null || productId.trim().isEmpty) {
          throw StateError(
            'كل بند في فاتورة المشتريات المستلمة يجب أن يرتبط بمنتج مسجل بالمخزون.',
          );
        }
        if (!item.quantity.isFinite || item.quantity <= 0) {
          throw StateError(
            'يجب أن تكون كمية المنتج في المشتريات أكبر من الصفر.',
          );
        }
        if (!item.unitPrice.isFinite || item.unitPrice < 0) {
          throw StateError('سعر شراء المنتج غير صالح.');
        }
        if (productsBox.get(productId) == null) {
          throw StateError(
            'المنتج المرتبط ببند المشتريات غير موجود في قاعدة البيانات: $productId',
          );
        }
        additions[productId] = (additions[productId] ?? 0.0) + item.quantity;
        if (item.unitPrice > 0) {
          itemUnitPrices[productId] = item.unitPrice;
        }
      }
      final originalProducts = <String, Map>{};
      final updatedProducts = <String, Map<String, dynamic>>{};
      final movementsToCreate = <InventoryMovement>[];
      final now = DateTime.now();

      for (final entry in additions.entries) {
        final productMap = productsBox.get(entry.key);
        if (productMap == null) {
          throw StateError(
            'المنتج المرتبط ببند المشتريات غير موجود في قاعدة البيانات: ${entry.key}',
          );
        }
        final product = Product.fromMap(Map<String, dynamic>.from(productMap));
        if (product.trackInventory) {
          originalProducts[entry.key] = productMap;
          final oldQty = product.stockQuantity;
          final newQty = oldQty + entry.value;
          final newCost = itemUnitPrices[entry.key] ?? product.costPrice;
          final updated = product.copyWith(
            stockQuantity: newQty,
            costPrice: newCost,
            updatedAt: now,
          );
          updatedProducts[entry.key] = updated.toMap();

          movementsToCreate.add(
            InventoryMovement(
              id: const Uuid().v4(),
              productId: product.id,
              productName: product.name,
              quantityDelta: entry.value,
              quantityBefore: oldQty,
              quantityAfter: newQty,
              movementType: InventoryMovementType.purchaseReceipt,
              sourceDocumentType: 'purchase_invoice',
              sourceDocumentId: purchase.id,
              sourceDocumentNumber: purchase.purchaseNumber,
              reason: 'Purchase receipt: ${purchase.purchaseNumber}',
              timestamp: now,
              createdAt: now,
            ),
          );
        }
      }

      final createdMovementIds = <String>[];
      try {
        for (final entry in updatedProducts.entries) {
          await productsBox.put(entry.key, entry.value);
        }
        for (final m in movementsToCreate) {
          await database.inventoryMovementsBox.put(m.id, m.toMap());
          createdMovementIds.add(m.id);
        }
        await box.put(purchase.id, purchase.toMap());
      } catch (_) {
        for (final entry in originalProducts.entries) {
          await productsBox.put(entry.key, entry.value);
        }
        for (final mId in createdMovementIds) {
          await database.inventoryMovementsBox.delete(mId);
        }
        rethrow;
      }
    });
  }

  bool _receivedPurchaseTermsMatch(
    PurchaseInvoice existing,
    PurchaseInvoice incoming,
  ) {
    if (existing.purchaseNumber != incoming.purchaseNumber ||
        existing.supplierId != incoming.supplierId ||
        existing.currency != incoming.currency ||
        existing.issueDate != incoming.issueDate ||
        existing.subtotal != incoming.subtotal ||
        existing.discountType != incoming.discountType ||
        existing.discountInput != incoming.discountInput ||
        existing.discountAmount != incoming.discountAmount ||
        existing.taxableBase != incoming.taxableBase ||
        existing.taxRate != incoming.taxRate ||
        existing.taxAmount != incoming.taxAmount ||
        existing.finalTotal != incoming.finalTotal ||
        existing.items.length != incoming.items.length) {
      return false;
    }

    final existingItems = <String, PurchaseInvoiceItem>{
      for (final item in existing.items) item.id: item,
    };
    for (final item in incoming.items) {
      final previous = existingItems[item.id];
      if (previous == null ||
          previous.productId != item.productId ||
          previous.description != item.description ||
          previous.quantity != item.quantity ||
          previous.unitPrice != item.unitPrice ||
          previous.lineTotal != item.lineTotal) {
        return false;
      }
    }
    return true;
  }

  @override
  Future<void> recordPaymentOnPurchase({
    required String purchaseId,
    required double paymentAmount,
  }) async {
    final purchase = await getPurchaseById(purchaseId);
    if (purchase == null) {
      throw ArgumentError('Purchase $purchaseId does not exist.');
    }

    final currentPaid = Decimal.parse(purchase.amountPaid.toString());
    final deltaPayment = Decimal.parse(paymentAmount.toString());
    final newPaidDecimal = currentPaid + deltaPayment;
    final finalTotalDecimal = Decimal.parse(purchase.finalTotal.toString());

    final newRemainingDecimal =
        (finalTotalDecimal - newPaidDecimal) > Decimal.zero
        ? finalTotalDecimal - newPaidDecimal
        : Decimal.zero;

    final PaymentStatus newStatus;
    if (newRemainingDecimal == Decimal.zero) {
      newStatus = PaymentStatus.fullyPaid;
    } else if (newPaidDecimal > Decimal.zero) {
      newStatus = PaymentStatus.partiallyPaid;
    } else {
      newStatus = PaymentStatus.unpaid;
    }

    final updated = purchase.copyWith(
      amountPaid: newPaidDecimal.toDouble(),
      remainingPayable: newRemainingDecimal.toDouble(),
      paymentStatus: newStatus,
      updatedAt: DateTime.now(),
    );
    await savePurchase(updated);
  }

  @override
  Future<void> updateStockReceiptStatus(
    String purchaseId,
    bool isReceived,
  ) async {
    final purchase = await getPurchaseById(purchaseId);
    if (purchase == null) return;
    final updated = purchase.copyWith(
      isStockReceived: isReceived,
      updatedAt: DateTime.now(),
    );
    await savePurchase(updated);
  }

  @override
  Future<void> cancelPurchase(
    String purchaseId,
    String reason,
  ) => database.runExclusive(() async {
    final box = database.purchasesBox;
    final map = box.get(purchaseId);
    if (map == null) {
      throw ArgumentError('Purchase $purchaseId does not exist.');
    }
    final purchase = PurchaseInvoice.fromMap(Map<String, dynamic>.from(map));
    if (purchase.isCancelled) {
      return;
    }

    // 1. Dependency check: Cannot cancel purchase with recorded payments
    if (purchase.amountPaid > 0) {
      throw StateError(
        'لا يمكن إلغاء فاتورة مشتريات مسجل عليها مدفوعات. يجب تسوية أو استرداد المدفوعات أولاً.',
      );
    }

    // Also check if any payment in paymentsBox is allocated to this purchase
    final paymentsBox = database.paymentsBox;
    for (final key in paymentsBox.keys) {
      final pMap = paymentsBox.get(key);
      if (pMap != null) {
        final payment = Payment.fromMap(Map<String, dynamic>.from(pMap));
        final hasAlloc = payment.allocations.any(
          (a) => a.invoiceId == purchaseId,
        );
        if (hasAlloc && payment.amount > 0) {
          throw StateError(
            'لا يمكن إلغاء فاتورة مشتريات مسجل عليها مدفوعات. يجب تسوية أو استرداد المدفوعات أولاً.',
          );
        }
      }
    }

    final productsBox = database.productsBox;
    final originalProducts = <String, Map>{};
    final updatedProducts = <String, Map<String, dynamic>>{};
    final movementsToCreate = <InventoryMovement>[];
    final now = DateTime.now();

    // 2. Inventory reversal if stock was received
    if (purchase.isStockReceived) {
      final demands = <String, double>{};
      for (final item in purchase.items) {
        final productId = item.productId;
        if (productId == null || productId.isEmpty) continue;
        demands[productId] = (demands[productId] ?? 0.0) + item.quantity;
      }

      // Pre-validate stock availability to prevent negative stock
      for (final entry in demands.entries) {
        final productMap = productsBox.get(entry.key);
        if (productMap == null) {
          throw StateError('المنتج غير موجود في قاعدة البيانات: ${entry.key}');
        }
        final product = Product.fromMap(Map<String, dynamic>.from(productMap));
        if (product.trackInventory && product.stockQuantity < entry.value) {
          throw StateError(
            'المخزون الحالي (${product.stockQuantity}) غير كافٍ لعكس استلام المشتريات (${entry.value}). قد تكون البضاعة بيعت.',
          );
        }
        originalProducts[entry.key] = productMap;
        final newQty = product.stockQuantity - entry.value;
        updatedProducts[entry.key] = product
            .copyWith(stockQuantity: newQty, updatedAt: now)
            .toMap();

        movementsToCreate.add(
          InventoryMovement(
            id: const Uuid().v4(),
            productId: entry.key,
            productName: product.name,
            quantityDelta: -entry.value,
            quantityBefore: product.stockQuantity,
            quantityAfter: newQty,
            movementType: InventoryMovementType.purchaseCancellation,
            sourceDocumentType: 'purchase_invoice',
            sourceDocumentId: purchase.id,
            sourceDocumentNumber: purchase.purchaseNumber,
            reason:
                'Purchase cancellation: ${purchase.purchaseNumber} - $reason',
            timestamp: now,
            createdAt: now,
          ),
        );
      }
    }

    final cancelled = purchase.copyWith(
      documentStatus: DocumentStatus.cancelled,
      cancellationReason: reason,
      cancelledAt: now,
      updatedAt: now,
    );

    // Apply mutations with snapshot rollback
    final createdMovementIds = <String>[];
    try {
      for (final entry in updatedProducts.entries) {
        await productsBox.put(entry.key, entry.value);
      }
      for (final movement in movementsToCreate) {
        createdMovementIds.add(movement.id);
        await database.inventoryMovementsBox.put(movement.id, movement.toMap());
      }
      await box.put(cancelled.id, cancelled.toMap());
    } catch (_) {
      for (final entry in originalProducts.entries) {
        await productsBox.put(entry.key, entry.value);
      }
      for (final mId in createdMovementIds) {
        await database.inventoryMovementsBox.delete(mId);
      }
      rethrow;
    }
  });
}
