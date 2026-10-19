import 'package:fatoura/features/returns/domain/entities/sales_return.dart';

abstract class SalesReturnRepository {
  Future<List<SalesReturn>> getReturns({
    String? originalInvoiceId,
    String? customerId,
    DateTime? fromDate,
    DateTime? toDate,
  });
  Future<SalesReturn?> getReturnById(String id);
  Future<void> saveReturn(SalesReturn salesReturn);
  Future<double> getReturnedQuantityForItem(String invoiceItemId);
}
