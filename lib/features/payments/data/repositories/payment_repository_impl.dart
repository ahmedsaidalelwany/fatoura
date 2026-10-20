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
  Future<void> savePayment(Payment payment) async {
    if (payment.amount <= 0.0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    final box = database.paymentsBox;

    // Idempotency guard: If this payment ID was already persisted, do not duplicate allocations.
    if (box.containsKey(payment.id)) {
      return;
    }

    // 1. Process allocations to invoices / purchases
    for (final alloc in payment.allocations) {
      if (alloc.amount > 0) {
        if (payment.isCustomerPayment) {
          final invoice = await invoiceRepository.getInvoiceById(
            alloc.invoiceId,
          );
          if (invoice == null) {
            throw ArgumentError('Invoice ${alloc.invoiceId} does not exist.');
          }
          if (alloc.amount > invoice.remainingBalance + 0.0001) {
            throw ArgumentError(
              'Allocation amount (${alloc.amount}) exceeds invoice remaining balance (${invoice.remainingBalance}).',
            );
          }
          await invoiceRepository.recordPaymentOnInvoice(
            invoiceId: alloc.invoiceId,
            paymentAmount: alloc.amount,
          );
        } else {
          // Supplier payment to purchase invoice
          if (purchaseRepository != null) {
            final purchase = await purchaseRepository!.getPurchaseById(
              alloc.invoiceId,
            );
            if (purchase != null &&
                alloc.amount > purchase.remainingPayable + 0.0001) {
              throw ArgumentError(
                'Allocation amount (${alloc.amount}) exceeds purchase remaining payable (${purchase.remainingPayable}).',
              );
            }
            await purchaseRepository!.recordPaymentOnPurchase(
              purchaseId: alloc.invoiceId,
              paymentAmount: alloc.amount,
            );
          } else {
            final purchaseBox = database.purchasesBox;
            final purchaseMap = purchaseBox.get(alloc.invoiceId);
            if (purchaseMap != null) {
              final currentPaid = Decimal.parse(
                ((purchaseMap['amountPaid'] as num?)?.toDouble() ?? 0.0)
                    .toString(),
              );
              final allocAmount = Decimal.parse(alloc.amount.toString());
              final finalTotal = Decimal.parse(
                ((purchaseMap['finalTotal'] as num?)?.toDouble() ?? 0.0)
                    .toString(),
              );
              final newPaid = currentPaid + allocAmount;
              final newRemaining = (finalTotal - newPaid) > Decimal.zero
                  ? (finalTotal - newPaid)
                  : Decimal.zero;
              final newStatus = newRemaining == Decimal.zero
                  ? 'fullyPaid'
                  : 'partiallyPaid';

              purchaseMap['amountPaid'] = newPaid.toDouble();
              purchaseMap['remainingPayable'] = newRemaining.toDouble();
              purchaseMap['paymentStatus'] = newStatus;
              purchaseMap['updatedAt'] = DateTime.now().toIso8601String();
              await purchaseBox.put(alloc.invoiceId, purchaseMap);
            }
          }
        }
      }
    }

    // 2. Persist the payment record
    await box.put(payment.id, payment.toMap());
  }
}
