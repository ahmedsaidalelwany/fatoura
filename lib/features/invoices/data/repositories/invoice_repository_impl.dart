import 'package:decimal/decimal.dart';
import 'package:fatoura/core/precision/financial_calculator.dart';
import 'package:fatoura/core/precision/money.dart';
import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/invoices/domain/repositories/invoice_repository.dart';
import 'package:fatoura/features/products/domain/entities/inventory_movement.dart';
import 'package:fatoura/features/products/domain/entities/product.dart';
import 'package:uuid/uuid.dart';

class InvoiceRepositoryImpl implements InvoiceRepository {
  final HiveDatabase database;

  InvoiceRepositoryImpl(this.database);

  @override
  Future<List<Invoice>> getInvoices({
    String? customerId,
    DocumentStatus? documentStatus,
    PaymentStatus? paymentStatus,
    DateTime? fromDate,
    DateTime? toDate,
    String? query,
  }) async {
    final box = database.invoicesBox;
    final results = <Invoice>[];

    for (final key in box.keys) {
      final map = box.get(key);
      if (map != null) {
        final invoice = Invoice.fromMap(Map<String, dynamic>.from(map));

        // Filters
        if (customerId != null && invoice.customerId != customerId) {
          continue;
        }
        if (documentStatus != null &&
            invoice.documentStatus != documentStatus) {
          continue;
        }
        if (paymentStatus != null && invoice.paymentStatus != paymentStatus) {
          continue;
        }
        if (fromDate != null &&
            invoice.issueDate.isBefore(
              DateTime(fromDate.year, fromDate.month, fromDate.day),
            )) {
          continue;
        }
        if (toDate != null &&
            invoice.issueDate.isAfter(
              DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59),
            )) {
          continue;
        }
        if (query != null && query.trim().isNotEmpty) {
          final q = query.trim().toLowerCase();
          final matchesNumber = invoice.invoiceNumber.toLowerCase().contains(q);
          final matchesCustomer = invoice.customerName.toLowerCase().contains(
            q,
          );
          final matchesItem = invoice.items.any(
            (item) => item.description.toLowerCase().contains(q),
          );
          if (!matchesNumber && !matchesCustomer && !matchesItem) {
            continue;
          }
        }

        results.add(invoice);
      }
    }

    // Sort by issueDate descending
    results.sort((a, b) => b.issueDate.compareTo(a.issueDate));
    return results;
  }

  @override
  Future<Invoice?> getInvoiceById(String id) async {
    final box = database.invoicesBox;
    final map = box.get(id);
    if (map == null) return null;
    return Invoice.fromMap(Map<String, dynamic>.from(map));
  }

  @override
  Future<Invoice?> getInvoiceByNumber(String invoiceNumber) async {
    final box = database.invoicesBox;
    for (final key in box.keys) {
      final map = box.get(key);
      if (map != null && map['invoiceNumber'] == invoiceNumber) {
        return Invoice.fromMap(Map<String, dynamic>.from(map));
      }
    }
    return null;
  }

  @override
  Future<void> saveInvoice(Invoice invoice) async {
    final box = database.invoicesBox;
    final existingMap = box.get(invoice.id);
    final existingStatus = existingMap?['documentStatus'] as String?;
    final needsIssueCommit =
        invoice.isIssued &&
        (existingMap == null || existingStatus == DocumentStatus.draft.name);
    if (invoice.isIssued &&
        existingMap != null &&
        existingStatus != DocumentStatus.draft.name &&
        existingStatus != DocumentStatus.issued.name) {
      throw StateError('لا يمكن إعادة اعتماد فاتورة ملغاة.');
    }
    if (!needsIssueCommit) {
      await box.put(invoice.id, invoice.toMap());
      return;
    }

    await database.runExclusive(() async {
      final latestMap = box.get(invoice.id);
      final latestStatus = latestMap?['documentStatus'] as String?;
      if (latestStatus == DocumentStatus.issued.name) {
        await box.put(invoice.id, invoice.toMap());
        return;
      }
      if (latestMap != null && latestStatus != DocumentStatus.draft.name) {
        throw StateError('لا يمكن اعتماد فاتورة حالتها غير صالحة.');
      }

      final demands = <String, double>{};
      for (final item in invoice.items.where((item) => !item.isService)) {
        final productId = item.productId;
        if (productId == null || productId.isEmpty) {
          throw StateError(
            'لا يمكن بيع بند منتج غير مرتبط بمنتج مسجل في المخزون.',
          );
        }
        if (!item.quantity.isFinite || item.quantity <= 0) {
          throw StateError('يجب أن تكون كمية المنتج أكبر من الصفر.');
        }
        demands[productId] = (demands[productId] ?? 0) + item.quantity;
      }

      final productsBox = database.productsBox;
      final originalProducts = <String, Map>{};
      final updatedProducts = <String, Map<String, dynamic>>{};
      for (final entry in demands.entries) {
        final productMap = productsBox.get(entry.key);
        if (productMap == null) {
          throw StateError('المنتج غير موجود في قاعدة البيانات: ${entry.key}');
        }
        final product = Product.fromMap(Map<String, dynamic>.from(productMap));
        if (product.isArchived || !product.trackInventory) {
          throw StateError('المنتج غير متاح للبيع: ${product.name}');
        }
        if (!product.stockQuantity.isFinite ||
            entry.value > product.stockQuantity) {
          throw StateError(
            'المخزون غير كافٍ للمنتج (${product.name}). '
            'الكمية المطلوبة: ${entry.value}، المتاح في المخزن: ${product.stockQuantity}.',
          );
        }
        originalProducts[entry.key] = productMap;
        updatedProducts[entry.key] = product
            .copyWith(
              stockQuantity: product.stockQuantity - entry.value,
              updatedAt: DateTime.now(),
            )
            .toMap();
      }

      final createdMovementIds = <String>[];
      try {
        for (final entry in updatedProducts.entries) {
          await productsBox.put(entry.key, entry.value);

          final oldProduct = Product.fromMap(
            Map<String, dynamic>.from(originalProducts[entry.key]!),
          );
          final movement = InventoryMovement(
            id: const Uuid().v4(),
            productId: entry.key,
            productName: oldProduct.name,
            quantityDelta: -demands[entry.key]!,
            quantityBefore: oldProduct.stockQuantity,
            quantityAfter: oldProduct.stockQuantity - demands[entry.key]!,
            movementType: InventoryMovementType.sale,
            sourceDocumentType: 'sales_invoice',
            sourceDocumentId: invoice.id,
            sourceDocumentNumber: invoice.invoiceNumber,
            reason: 'Sales invoice: ${invoice.invoiceNumber}',
            timestamp: DateTime.now(),
            createdAt: DateTime.now(),
          );
          createdMovementIds.add(movement.id);
          await database.inventoryMovementsBox.put(
            movement.id,
            movement.toMap(),
          );
        }
        await box.put(invoice.id, invoice.toMap());
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

  @override
  Future<void> cancelInvoice(
    String invoiceId,
    String reason,
  ) => database.runExclusive(() async {
    final box = database.invoicesBox;
    final invoiceMap = box.get(invoiceId);
    if (invoiceMap == null) {
      throw ArgumentError('Invoice $invoiceId does not exist.');
    }
    final invoice = Invoice.fromMap(Map<String, dynamic>.from(invoiceMap));
    if (invoice.isCancelled) return;

    final productsBox = database.productsBox;
    final originalProducts = <String, Map>{};
    final updatedProducts = <String, Map<String, dynamic>>{};
    final returns = <String, double>{};
    if (invoice.isIssued) {
      for (final item in invoice.items.where((item) => !item.isService)) {
        final productId = item.productId;
        if (productId == null || productId.isEmpty) continue;
        returns[productId] = (returns[productId] ?? 0) + item.quantity;
      }
      for (final entry in returns.entries) {
        final productMap = productsBox.get(entry.key);
        if (productMap == null) {
          throw StateError('المنتج غير موجود في قاعدة البيانات: ${entry.key}');
        }
        final product = Product.fromMap(Map<String, dynamic>.from(productMap));
        originalProducts[entry.key] = productMap;
        updatedProducts[entry.key] = product
            .copyWith(
              stockQuantity: product.stockQuantity + entry.value,
              updatedAt: DateTime.now(),
            )
            .toMap();
      }
    }

    final cancelled = invoice.copyWith(
      documentStatus: DocumentStatus.cancelled,
      cancelledAt: DateTime.now(),
      cancellationReason: reason.trim(),
      updatedAt: DateTime.now(),
    );
    final createdMovementIds = <String>[];
    try {
      for (final entry in updatedProducts.entries) {
        await productsBox.put(entry.key, entry.value);

        final oldProduct = Product.fromMap(
          Map<String, dynamic>.from(originalProducts[entry.key]!),
        );
        final movement = InventoryMovement(
          id: const Uuid().v4(),
          productId: entry.key,
          productName: oldProduct.name,
          quantityDelta: returns[entry.key]!,
          quantityBefore: oldProduct.stockQuantity,
          quantityAfter: oldProduct.stockQuantity + returns[entry.key]!,
          movementType: InventoryMovementType.salesCancellation,
          sourceDocumentType: 'sales_invoice',
          sourceDocumentId: invoice.id,
          sourceDocumentNumber: invoice.invoiceNumber,
          reason: 'Invoice cancelled: ${invoice.invoiceNumber}. ${reason.trim()}',
          timestamp: DateTime.now(),
          createdAt: DateTime.now(),
        );
        createdMovementIds.add(movement.id);
        await database.inventoryMovementsBox.put(
          movement.id,
          movement.toMap(),
        );
      }
      await box.put(invoiceId, cancelled.toMap());
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

  @override
  Future<void> recordPaymentOnInvoice({
    required String invoiceId,
    required double paymentAmount,
  }) async {
    final invoice = await getInvoiceById(invoiceId);
    if (invoice == null) {
      throw ArgumentError('Invoice $invoiceId does not exist.');
    }

    final newTotalPaidDecimal =
        Decimal.parse(invoice.totalPaid.toString()) +
        Decimal.parse(paymentAmount.toString());

    final finalTotal = Money.fromNum(invoice.finalTotal, invoice.currency);
    final totalPaid = Money.fromDecimal(newTotalPaidDecimal, invoice.currency);

    final newRemaining = FinancialCalculator.calculateRemainingBalance(
      finalTotal: finalTotal,
      totalPaid: totalPaid,
    );

    final PaymentStatus newPaymentStatus;
    if (newRemaining.isZero) {
      newPaymentStatus = PaymentStatus.fullyPaid;
    } else if (newTotalPaidDecimal > Decimal.zero) {
      newPaymentStatus = PaymentStatus.partiallyPaid;
    } else {
      newPaymentStatus = PaymentStatus.unpaid;
    }

    final updated = invoice.copyWith(
      totalPaid: totalPaid.toDouble(),
      remainingBalance: newRemaining.toDouble(),
      paymentStatus: newPaymentStatus,
      updatedAt: DateTime.now(),
    );
    await saveInvoice(updated);
  }

  @override
  Future<void> recordReturnCreditOnInvoice({
    required String invoiceId,
    required double creditAmount,
  }) async {
    final invoice = await getInvoiceById(invoiceId);
    if (invoice == null) return;

    if (creditAmount <= 0.0) return;

    // Deduct from current remaining balance directly to support cumulative returns
    final currentRemaining = Decimal.parse(invoice.remainingBalance.toString());
    final credit = Decimal.parse(creditAmount.toString());

    final newRemainingDecimal = currentRemaining > credit
        ? currentRemaining - credit
        : Decimal.zero;
    final newRemaining = newRemainingDecimal.toDouble();

    final PaymentStatus newPaymentStatus;
    if (newRemaining == 0.0 && (invoice.totalPaid > 0 || creditAmount > 0)) {
      newPaymentStatus = PaymentStatus.refunded;
    } else if (invoice.totalPaid > 0) {
      newPaymentStatus = PaymentStatus.partiallyPaid;
    } else {
      newPaymentStatus = PaymentStatus.unpaid;
    }

    final updated = invoice.copyWith(
      remainingBalance: newRemaining,
      paymentStatus: newPaymentStatus,
      updatedAt: DateTime.now(),
    );
    await saveInvoice(updated);
  }

  @override
  Future<void> deleteDraftInvoice(String invoiceId) async {
    final invoice = await getInvoiceById(invoiceId);
    if (invoice != null && invoice.isDraft) {
      final box = database.invoicesBox;
      await box.delete(invoiceId);
    }
  }
}
