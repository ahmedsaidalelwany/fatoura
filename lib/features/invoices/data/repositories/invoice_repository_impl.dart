import 'package:decimal/decimal.dart';
import 'package:fatoura/core/precision/financial_calculator.dart';
import 'package:fatoura/core/precision/money.dart';
import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/invoices/domain/repositories/invoice_repository.dart';

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
    await box.put(invoice.id, invoice.toMap());
  }

  @override
  Future<void> cancelInvoice(String invoiceId, String reason) async {
    final invoice = await getInvoiceById(invoiceId);
    if (invoice == null) {
      throw ArgumentError('Invoice $invoiceId does not exist.');
    }
    if (invoice.isCancelled) {
      return; // Already cancelled
    }

    final cancelled = invoice.copyWith(
      documentStatus: DocumentStatus.cancelled,
      cancelledAt: DateTime.now(),
      cancellationReason: reason.trim(),
      updatedAt: DateTime.now(),
    );
    await saveInvoice(cancelled);
  }

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

    final credit = Money.fromNum(creditAmount, invoice.currency);
    final finalTotal = Money.fromNum(invoice.finalTotal, invoice.currency);
    final totalPaid = Money.fromNum(invoice.totalPaid, invoice.currency);

    final newRemaining = FinancialCalculator.calculateRemainingBalance(
      finalTotal: finalTotal,
      totalPaid: totalPaid,
      totalReturnCredits: credit,
    );

    final PaymentStatus newPaymentStatus;
    if (newRemaining.isZero && (invoice.totalPaid > 0 || creditAmount > 0)) {
      newPaymentStatus = PaymentStatus.refunded;
    } else if (invoice.totalPaid > 0) {
      newPaymentStatus = PaymentStatus.partiallyPaid;
    } else {
      newPaymentStatus = PaymentStatus.unpaid;
    }

    final updated = invoice.copyWith(
      remainingBalance: newRemaining.toDouble(),
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
