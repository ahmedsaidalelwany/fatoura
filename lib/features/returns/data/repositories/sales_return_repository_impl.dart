import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/invoices/domain/repositories/invoice_repository.dart';
import 'package:fatoura/features/products/domain/repositories/product_repository.dart';
import 'package:fatoura/features/returns/domain/entities/sales_return.dart';
import 'package:fatoura/features/returns/domain/repositories/sales_return_repository.dart';

class SalesReturnRepositoryImpl implements SalesReturnRepository {
  final HiveDatabase database;
  final InvoiceRepository invoiceRepository;
  final ProductRepository? productRepository;

  SalesReturnRepositoryImpl({
    required this.database,
    required this.invoiceRepository,
    this.productRepository,
  });

  @override
  Future<List<SalesReturn>> getReturns({
    String? originalInvoiceId,
    String? customerId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final box = database.salesReturnsBox;
    final results = <SalesReturn>[];

    for (final key in box.keys) {
      final map = box.get(key);
      if (map != null) {
        final ret = SalesReturn.fromMap(Map<String, dynamic>.from(map));

        if (originalInvoiceId != null &&
            ret.originalInvoiceId != originalInvoiceId) {
          continue;
        }
        if (customerId != null && ret.customerId != customerId) {
          continue;
        }
        if (fromDate != null &&
            ret.returnDate.isBefore(
              DateTime(fromDate.year, fromDate.month, fromDate.day),
            )) {
          continue;
        }
        if (toDate != null &&
            ret.returnDate.isAfter(
              DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59),
            )) {
          continue;
        }

        results.add(ret);
      }
    }

    results.sort((a, b) => b.returnDate.compareTo(a.returnDate));
    return results;
  }

  @override
  Future<SalesReturn?> getReturnById(String id) async {
    final box = database.salesReturnsBox;
    final map = box.get(id);
    if (map == null) return null;
    return SalesReturn.fromMap(Map<String, dynamic>.from(map));
  }

  @override
  Future<double> getReturnedQuantityForItem(String invoiceItemId) async {
    final box = database.salesReturnsBox;
    var totalReturned = 0.0;

    for (final key in box.keys) {
      final map = box.get(key);
      if (map != null) {
        final ret = SalesReturn.fromMap(Map<String, dynamic>.from(map));
        for (final item in ret.items) {
          if (item.invoiceItemId == invoiceItemId) {
            totalReturned += item.returnedQuantity;
          }
        }
      }
    }

    return totalReturned;
  }

  @override
  Future<void> saveReturn(SalesReturn salesReturn) async {
    // If refund method is account credit, apply credit on the original invoice balance
    if (salesReturn.refundMethod == RefundMethod.credit) {
      await invoiceRepository.recordReturnCreditOnInvoice(
        invoiceId: salesReturn.originalInvoiceId,
        creditAmount: salesReturn.totalRefundAmount,
      );
    }

    // Restore stock for returned products (physical goods only, not services)
    if (productRepository != null) {
      final originalInvoice = await invoiceRepository.getInvoiceById(
        salesReturn.originalInvoiceId,
      );
      if (originalInvoice != null) {
        for (final retItem in salesReturn.items) {
          final matchedItem = originalInvoice.items
              .where((i) => i.id == retItem.invoiceItemId)
              .firstOrNull;
          if (matchedItem != null &&
              !matchedItem.isService &&
              matchedItem.productId != null &&
              matchedItem.productId!.isNotEmpty) {
            await productRepository!.adjustStock(
              matchedItem.productId!,
              delta: retItem.returnedQuantity,
              reason: 'Return received: ${salesReturn.returnNumber}',
            );
          }
        }
      }
    }

    final box = database.salesReturnsBox;
    await box.put(salesReturn.id, salesReturn.toMap());
  }
}
