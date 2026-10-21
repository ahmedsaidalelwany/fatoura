import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/invoices/domain/repositories/invoice_repository.dart';
import 'package:fatoura/features/products/domain/entities/inventory_movement.dart';
import 'package:fatoura/features/products/domain/entities/product.dart';
import 'package:fatoura/features/products/domain/repositories/product_repository.dart';
import 'package:fatoura/features/returns/domain/entities/sales_return.dart';
import 'package:fatoura/features/returns/domain/repositories/sales_return_repository.dart';
import 'package:uuid/uuid.dart';

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
  Future<void> saveReturn(SalesReturn salesReturn) =>
      database.runExclusive(() async {
        final box = database.salesReturnsBox;

        // Idempotency: Ignore replayed return submission
        if (box.containsKey(salesReturn.id)) {
          return;
        }

        if (salesReturn.items.isEmpty) {
          throw ArgumentError('Sales return must contain at least one item.');
        }

        final originalInvoice = await invoiceRepository.getInvoiceById(
          salesReturn.originalInvoiceId,
        );
        if (originalInvoice == null) {
          throw ArgumentError(
            'Original invoice (${salesReturn.originalInvoiceId}) does not exist.',
          );
        }
        if (originalInvoice.isCancelled) {
          throw StateError(
            'Cannot process returns against a cancelled invoice.',
          );
        }

        // Validate item existence and remaining returnable quantity at persistence boundary
        for (final retItem in salesReturn.items) {
          if (retItem.returnedQuantity <= 0) {
            throw ArgumentError(
              'Returned quantity must be greater than zero for item ${retItem.description}.',
            );
          }
          final matchedItem = originalInvoice.items
              .where((i) => i.id == retItem.invoiceItemId)
              .firstOrNull;
          if (matchedItem == null) {
            throw ArgumentError(
              'Item "${retItem.description}" does not belong to original invoice (${originalInvoice.invoiceNumber}).',
            );
          }

          final alreadyReturned = await getReturnedQuantityForItem(
            retItem.invoiceItemId,
          );
          final maxReturnable = matchedItem.quantity - alreadyReturned;
          if (retItem.returnedQuantity > maxReturnable + 0.0001) {
            throw ArgumentError(
              'Cannot return ${retItem.returnedQuantity} of "${matchedItem.description}". '
              'Maximum returnable quantity is $maxReturnable (Already returned: $alreadyReturned).',
            );
          }
        }

        // Pre-mutation snapshots for atomic rollback
        final invoiceSnapshot = Map<String, dynamic>.from(
          database.invoicesBox.get(salesReturn.originalInvoiceId)!,
        );
        final productSnapshots = <String, Map<String, dynamic>>{};
        final createdMovementIds = <String>[];

        for (final retItem in salesReturn.items) {
          final matchedItem = originalInvoice.items
              .firstWhere((i) => i.id == retItem.invoiceItemId);
          if (!matchedItem.isService &&
              matchedItem.productId != null &&
              matchedItem.productId!.isNotEmpty) {
            final pMap = database.productsBox.get(matchedItem.productId!);
            if (pMap != null) {
              productSnapshots[matchedItem.productId!] =
                  Map<String, dynamic>.from(pMap);
            }
          }
        }

        try {
          // 1. If credit, update original invoice balance
          if (salesReturn.refundMethod == RefundMethod.credit) {
            await invoiceRepository.recordReturnCreditOnInvoice(
              invoiceId: salesReturn.originalInvoiceId,
              creditAmount: salesReturn.totalRefundAmount,
            );
          }

          // 2. Restore physical stock and record inventory movements
          for (final retItem in salesReturn.items) {
            final matchedItem = originalInvoice.items
                .firstWhere((i) => i.id == retItem.invoiceItemId);
            if (!matchedItem.isService &&
                matchedItem.productId != null &&
                matchedItem.productId!.isNotEmpty) {
              final prodId = matchedItem.productId!;
              final pMap = database.productsBox.get(prodId);
              if (pMap != null) {
                final product = Product.fromMap(
                  Map<String, dynamic>.from(pMap),
                );
                final newStock = product.stockQuantity + retItem.returnedQuantity;
                final updatedProduct = product.copyWith(
                  stockQuantity: newStock,
                  updatedAt: DateTime.now(),
                );
                await database.productsBox.put(prodId, updatedProduct.toMap());

                // Record persistent inventory movement
                final movement = InventoryMovement(
                  id: const Uuid().v4(),
                  productId: prodId,
                  productName: product.name,
                  quantityDelta: retItem.returnedQuantity,
                  quantityBefore: product.stockQuantity,
                  quantityAfter: newStock,
                  movementType: InventoryMovementType.customerReturn,
                  sourceDocumentType: 'sales_return',
                  sourceDocumentId: salesReturn.id,
                  sourceDocumentNumber: salesReturn.returnNumber,
                  reason: salesReturn.returnReason.isNotEmpty
                      ? salesReturn.returnReason
                      : 'Sales return: ${salesReturn.returnNumber}',
                  timestamp: DateTime.now(),
                  createdAt: DateTime.now(),
                );
                createdMovementIds.add(movement.id);
                await database.inventoryMovementsBox.put(
                  movement.id,
                  movement.toMap(),
                );
              }
            }
          }

          // 3. Persist return document
          await box.put(salesReturn.id, salesReturn.toMap());
        } catch (_) {
          // Safe rollback on any failure
          await database.invoicesBox.put(
            salesReturn.originalInvoiceId,
            invoiceSnapshot,
          );
          for (final entry in productSnapshots.entries) {
            await database.productsBox.put(entry.key, entry.value);
          }
          for (final mId in createdMovementIds) {
            await database.inventoryMovementsBox.delete(mId);
          }
          await box.delete(salesReturn.id);
          rethrow;
        }
      });
}
