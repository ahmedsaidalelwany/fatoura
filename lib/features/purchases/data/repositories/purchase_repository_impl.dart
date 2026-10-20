import 'package:decimal/decimal.dart';
import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
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
    await box.put(purchase.id, purchase.toMap());
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
  Future<void> cancelPurchase(String purchaseId, String reason) async {
    final purchase = await getPurchaseById(purchaseId);
    if (purchase == null) {
      throw ArgumentError('Purchase $purchaseId does not exist.');
    }
    if (purchase.isCancelled) {
      return;
    }
    final cancelled = purchase.copyWith(
      documentStatus: DocumentStatus.cancelled,
      updatedAt: DateTime.now(),
    );
    await savePurchase(cancelled);
  }
}
