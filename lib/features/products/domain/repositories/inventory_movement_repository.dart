import 'package:fatoura/features/products/domain/entities/inventory_movement.dart';

abstract class InventoryMovementRepository {
  Future<void> recordMovement(InventoryMovement movement);
  Future<List<InventoryMovement>> getMovements({
    String? productId,
    InventoryMovementType? movementType,
    DateTime? fromDate,
    DateTime? toDate,
  });
  Future<double> getReconciledStock(String productId);
}
