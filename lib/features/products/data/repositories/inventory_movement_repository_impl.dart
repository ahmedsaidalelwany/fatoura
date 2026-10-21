import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/products/domain/entities/inventory_movement.dart';
import 'package:fatoura/features/products/domain/repositories/inventory_movement_repository.dart';

class InventoryMovementRepositoryImpl implements InventoryMovementRepository {
  final HiveDatabase database;

  InventoryMovementRepositoryImpl(this.database);

  @override
  Future<void> recordMovement(InventoryMovement movement) async {
    final box = database.inventoryMovementsBox;
    await box.put(movement.id, movement.toMap());
  }

  @override
  Future<List<InventoryMovement>> getMovements({
    String? productId,
    InventoryMovementType? movementType,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final box = database.inventoryMovementsBox;
    final results = <InventoryMovement>[];

    for (final key in box.keys) {
      final map = box.get(key);
      if (map != null) {
        final movement = InventoryMovement.fromMap(Map<String, dynamic>.from(map));

        if (productId != null && movement.productId != productId) {
          continue;
        }
        if (movementType != null && movement.movementType != movementType) {
          continue;
        }
        if (fromDate != null &&
            movement.timestamp.isBefore(
              DateTime(fromDate.year, fromDate.month, fromDate.day),
            )) {
          continue;
        }
        if (toDate != null &&
            movement.timestamp.isAfter(
              DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59),
            )) {
          continue;
        }

        results.add(movement);
      }
    }

    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results;
  }

  @override
  Future<double> getReconciledStock(String productId) async {
    final movements = await getMovements(productId: productId);
    double total = 0.0;
    for (final m in movements) {
      total += m.quantityDelta;
    }
    return total;
  }
}
