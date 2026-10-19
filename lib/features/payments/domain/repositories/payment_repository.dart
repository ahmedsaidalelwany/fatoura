import 'package:fatoura/features/payments/domain/entities/payment.dart';

abstract class PaymentRepository {
  Future<List<Payment>> getPayments({
    String? partyId,
    bool? isCustomerPayment,
    DateTime? fromDate,
    DateTime? toDate,
  });
  Future<Payment?> getPaymentById(String id);
  Future<List<Payment>> getPaymentsForInvoice(String invoiceId);
  Future<void> savePayment(Payment payment);
}
