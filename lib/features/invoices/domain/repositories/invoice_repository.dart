import 'package:fatoura/features/invoices/domain/entities/invoice.dart';

abstract class InvoiceRepository {
  Future<List<Invoice>> getInvoices({
    String? customerId,
    DocumentStatus? documentStatus,
    PaymentStatus? paymentStatus,
    DateTime? fromDate,
    DateTime? toDate,
    String? query,
  });
  Future<Invoice?> getInvoiceById(String id);
  Future<Invoice?> getInvoiceByNumber(String invoiceNumber);
  Future<void> saveInvoice(Invoice invoice);
  Future<void> cancelInvoice(String invoiceId, String reason);
  Future<void> recordPaymentOnInvoice({
    required String invoiceId,
    required double paymentAmount,
  });
  Future<void> recordReturnCreditOnInvoice({
    required String invoiceId,
    required double creditAmount,
  });
  Future<void> deleteDraftInvoice(String invoiceId);
}
