import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/invoices/domain/repositories/invoice_repository.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';
import 'package:fatoura/features/payments/domain/repositories/payment_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final HiveDatabase database;
  final InvoiceRepository invoiceRepository;

  PaymentRepositoryImpl({
    required this.database,
    required this.invoiceRepository,
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
    // 1. Process allocations to invoices
    for (final alloc in payment.allocations) {
      if (alloc.amount > 0) {
        if (payment.isCustomerPayment) {
          await invoiceRepository.recordPaymentOnInvoice(
            invoiceId: alloc.invoiceId,
            paymentAmount: alloc.amount,
          );
        } else {
          // Supplier payment to purchase invoice
          final purchaseBox = database.purchasesBox;
          final purchaseMap = purchaseBox.get(alloc.invoiceId);
          if (purchaseMap != null) {
            final currentPaid =
                (purchaseMap['amountPaid'] as num?)?.toDouble() ?? 0.0;
            final finalTotal =
                (purchaseMap['finalTotal'] as num?)?.toDouble() ?? 0.0;
            final newPaid = currentPaid + alloc.amount;
            final newRemaining = (finalTotal - newPaid) > 0
                ? (finalTotal - newPaid)
                : 0.0;
            final newStatus = newRemaining == 0.0
                ? 'fullyPaid'
                : 'partiallyPaid';

            purchaseMap['amountPaid'] = newPaid;
            purchaseMap['remainingPayable'] = newRemaining;
            purchaseMap['paymentStatus'] = newStatus;
            purchaseMap['updatedAt'] = DateTime.now().toIso8601String();
            await purchaseBox.put(alloc.invoiceId, purchaseMap);
          }
        }
      }
    }

    // 2. Persist the payment record
    final box = database.paymentsBox;
    await box.put(payment.id, payment.toMap());
  }
}
