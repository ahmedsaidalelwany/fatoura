import 'package:decimal/decimal.dart';
import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/invoices/domain/repositories/invoice_repository.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';
import 'package:fatoura/features/payments/domain/repositories/payment_repository.dart';
import 'package:fatoura/features/purchases/domain/repositories/purchase_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final HiveDatabase database;
  final InvoiceRepository invoiceRepository;
  final PurchaseRepository? purchaseRepository;

  PaymentRepositoryImpl({
    required this.database,
    required this.invoiceRepository,
    this.purchaseRepository,
  });

  @override
  Future<List<Payment>> getPayments({
    String? partyId,
    bool? isCustomerPayment,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final box = database.paymentsBox;
    final results = <Payment>[];

    for (final key in box.keys) {
      final map = box.get(key);
      if (map != null) {
        final payment = Payment.fromMap(Map<String, dynamic>.from(map));

        if (partyId != null && payment.partyId != partyId) {
          continue;
        }
        if (isCustomerPayment != null &&
            payment.isCustomerPayment != isCustomerPayment) {
          continue;
        }
        if (fromDate != null &&
            payment.paymentDate.isBefore(
              DateTime(fromDate.year, fromDate.month, fromDate.day),
            )) {
          continue;
        }
        if (toDate != null &&
            payment.paymentDate.isAfter(
              DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59),
            )) {
          continue;
        }

        results.add(payment);
      }
    }

    results.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    return results;
  }

  @override
  Future<Payment?> getPaymentById(String id) async {
    final box = database.paymentsBox;
    final map = box.get(id);
    if (map == null) return null;
    return Payment.fromMap(Map<String, dynamic>.from(map));
  }

  @override
  Future<List<Payment>> getPaymentsForInvoice(String invoiceId) async {
    final box = database.paymentsBox;
    final results = <Payment>[];

    for (final key in box.keys) {
      final map = box.get(key);
      if (map != null) {
        final payment = Payment.fromMap(Map<String, dynamic>.from(map));
        final hasAllocation = payment.allocations.any(
          (alloc) => alloc.invoiceId == invoiceId,
        );
        if (hasAllocation) {
          results.add(payment);
        }
      }
    }

    results.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    return results;
  }

  @override
  Future<void> savePayment(Payment payment) => database.runExclusive(() async {
    if (payment.amount <= 0.0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    final totalAllocated = payment.allocations.fold<Decimal>(
      Decimal.zero,
      (sum, a) => sum + Decimal.parse(a.amount.toString()),
    );
    final paymentAmountDecimal = Decimal.parse(payment.amount.toString());
    if (totalAllocated > paymentAmountDecimal) {
      throw ArgumentError(
        'Sum of payment allocations ($totalAllocated) cannot exceed payment amount ($paymentAmountDecimal).',
      );
    }

    final box = database.paymentsBox;

    // Idempotency guard: If this payment ID was already persisted, do not duplicate allocations.
    if (box.containsKey(payment.id)) {
      return;
    }

    final invoiceAllocations = <String, double>{};
    final purchaseAllocations = <String, double>{};
    for (final alloc in payment.allocations) {
      if (alloc.amount > 0) {
        if (payment.isCustomerPayment) {
          invoiceAllocations.update(
            alloc.invoiceId,
            (amount) => amount + alloc.amount,
            ifAbsent: () => alloc.amount,
          );
        } else {
          purchaseAllocations.update(
            alloc.invoiceId,
            (amount) => amount + alloc.amount,
            ifAbsent: () => alloc.amount,
          );
        }
      }
    }

    final invoiceSnapshots = <String, Map>{};
    for (final entry in invoiceAllocations.entries) {
      final invoice = await invoiceRepository.getInvoiceById(entry.key);
      if (invoice == null) {
        throw ArgumentError('Invoice ${entry.key} does not exist.');
      }
      if (invoice.currency != payment.currency) {
        throw ArgumentError(
          'Payment currency (${payment.currency}) does not match invoice currency (${invoice.currency}).',
        );
      }
      if (entry.value > invoice.remainingBalance + 0.0001) {
        throw ArgumentError(
          'Allocation amount (${entry.value}) exceeds invoice remaining balance (${invoice.remainingBalance}).',
        );
      }
      invoiceSnapshots[entry.key] = Map<String, dynamic>.from(
        database.invoicesBox.get(entry.key)!,
      );
    }

    final purchaseSnapshots = <String, Map>{};
    for (final entry in purchaseAllocations.entries) {
      final purchaseMap = database.purchasesBox.get(entry.key);
      if (purchaseMap == null) {
        throw ArgumentError('Purchase ${entry.key} does not exist.');
      }
      if (purchaseRepository != null) {
        final purchase = await purchaseRepository!.getPurchaseById(entry.key);
        if (purchase == null) {
          throw ArgumentError('Purchase ${entry.key} does not exist.');
        }
        if (purchase.currency != payment.currency) {
          throw ArgumentError(
            'Payment currency (${payment.currency}) does not match purchase currency (${purchase.currency}).',
          );
        }
        if (entry.value > purchase.remainingPayable + 0.0001) {
          throw ArgumentError(
            'Allocation amount (${entry.value}) exceeds purchase remaining payable (${purchase.remainingPayable}).',
          );
        }
      } else {
        final purCurrency = purchaseMap['currency'] as String?;
        if (purCurrency != null && purCurrency != payment.currency) {
          throw ArgumentError(
            'Payment currency (${payment.currency}) does not match purchase currency ($purCurrency).',
          );
        }
      }
      purchaseSnapshots[entry.key] = Map<String, dynamic>.from(purchaseMap);
    }

    try {
      for (final entry in invoiceAllocations.entries) {
        await invoiceRepository.recordPaymentOnInvoice(
          invoiceId: entry.key,
          paymentAmount: entry.value,
        );
      }
      for (final entry in purchaseAllocations.entries) {
        if (purchaseRepository != null) {
          await purchaseRepository!.recordPaymentOnPurchase(
            purchaseId: entry.key,
            paymentAmount: entry.value,
          );
        } else {
          final purchaseMap = database.purchasesBox.get(entry.key)!;
          final currentPaid = Decimal.parse(
            ((purchaseMap['amountPaid'] as num?)?.toDouble() ?? 0.0).toString(),
          );
          final allocAmount = Decimal.parse(entry.value.toString());
          final finalTotal = Decimal.parse(
            ((purchaseMap['finalTotal'] as num?)?.toDouble() ?? 0.0).toString(),
          );
          final newPaid = currentPaid + allocAmount;
          final newRemaining = (finalTotal - newPaid) > Decimal.zero
              ? (finalTotal - newPaid)
              : Decimal.zero;
          purchaseMap['amountPaid'] = newPaid.toDouble();
          purchaseMap['remainingPayable'] = newRemaining.toDouble();
          purchaseMap['paymentStatus'] = newRemaining == Decimal.zero
              ? 'fullyPaid'
              : 'partiallyPaid';
          purchaseMap['updatedAt'] = DateTime.now().toIso8601String();
          await database.purchasesBox.put(entry.key, purchaseMap);
        }
      }

      await box.put(payment.id, payment.toMap());
    } catch (_) {
      for (final entry in invoiceSnapshots.entries) {
        await database.invoicesBox.put(entry.key, entry.value);
      }
      for (final entry in purchaseSnapshots.entries) {
        await database.purchasesBox.put(entry.key, entry.value);
      }
      await box.delete(payment.id);
      rethrow;
    }
  });
}
