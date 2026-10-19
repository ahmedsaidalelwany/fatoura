import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/purchases/domain/entities/purchase_invoice.dart';

abstract class PurchaseRepository {
  Future<List<PurchaseInvoice>> getPurchases({
    String? supplierId,
    DocumentStatus? documentStatus,
    PaymentStatus? paymentStatus,
    DateTime? fromDate,
    DateTime? toDate,
    String? query,
  });
  Future<PurchaseInvoice?> getPurchaseById(String id);
  Future<void> savePurchase(PurchaseInvoice purchase);
  Future<void> recordPaymentOnPurchase({
    required String purchaseId,
    required double paymentAmount,
  });
  Future<void> updateStockReceiptStatus(String purchaseId, bool isReceived);
}
