import 'package:fatoura/features/products/domain/entities/product.dart';

abstract class ProductRepository {
  Future<List<Product>> getProducts({
    String? query,
    String? category,
    bool includeArchived = false,
  });
  Future<Product?> getProductById(String id);

  /// Looks up a product by its barcode value (exact match).
  Future<Product?> getProductByBarcode(String barcode);

  /// Returns true if the barcode is not already assigned to another product.
  /// Pass [excludeProductId] to allow editing the product's own barcode.
  Future<bool> isBarcodeUnique(String barcode, {String? excludeProductId});

  Future<void> saveProduct(Product product);
  Future<void> archiveProduct(String id);

  /// Adjusts the stock quantity of a product by [delta].
  /// Positive delta = intake; negative = deduction.
  /// [reason] is required for audit trail purposes.
  Future<Product?> adjustStock(
    String productId, {
    required double delta,
    required String reason,
  });

  Future<List<String>> getCategories();
}
