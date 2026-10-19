import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/products/domain/entities/product.dart';
import 'package:fatoura/features/products/domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  final HiveDatabase database;

  ProductRepositoryImpl(this.database);

  @override
  Future<List<Product>> getProducts({
    String? query,
    String? category,
    bool includeArchived = false,
  }) async {
    final box = database.productsBox;
    final results = <Product>[];

    for (final key in box.keys) {
      final map = box.get(key);
      if (map != null) {
        final product = Product.fromMap(Map<String, dynamic>.from(map));
        if (includeArchived || !product.isArchived) {
          if (category != null &&
              category.isNotEmpty &&
              product.category != category) {
            continue;
          }
          if (query == null || query.trim().isEmpty) {
            results.add(product);
          } else {
            final q = query.trim().toLowerCase();
            // Search by name, SKU, barcode (exact prefix for barcode), and description
            if (product.name.toLowerCase().contains(q) ||
                product.sku.toLowerCase().contains(q) ||
                // Barcode search: exact match or starts-with for scanner prefix
                product.barcode.toLowerCase().contains(q) ||
                product.description.toLowerCase().contains(q)) {
              results.add(product);
            }
          }
        }
      }
    }

    results.sort((a, b) => a.name.compareTo(b.name));
    return results;
  }

  @override
  Future<Product?> getProductById(String id) async {
    final box = database.productsBox;
    final map = box.get(id);
    if (map == null) return null;
    return Product.fromMap(Map<String, dynamic>.from(map));
  }

  /// Looks up a product by its exact barcode value.
  /// Barcode comparison is exact and case-insensitive.
  /// Returns null if no matching active product is found.
  @override
  Future<Product?> getProductByBarcode(String barcode) async {
    if (barcode.trim().isEmpty) return null;
    final box = database.productsBox;
    final normalized = barcode.trim();

    for (final key in box.keys) {
      final map = box.get(key);
      if (map != null) {
        final product = Product.fromMap(Map<String, dynamic>.from(map));
        // Only match active (non-archived) products
        if (!product.isArchived &&
            product.barcode.isNotEmpty &&
            product.barcode == normalized) {
          return product;
        }
      }
    }
    return null;
  }

  /// Checks whether a barcode is already assigned to another product.
  /// Pass [excludeProductId] to allow the product being edited to keep its barcode.
  @override
  Future<bool> isBarcodeUnique(
    String barcode, {
    String? excludeProductId,
  }) async {
    if (barcode.trim().isEmpty) return true; // Empty is always unique (optional)
    final box = database.productsBox;
    final normalized = barcode.trim();

    for (final key in box.keys) {
      final map = box.get(key);
      if (map != null) {
        final product = Product.fromMap(Map<String, dynamic>.from(map));
        if (product.barcode == normalized &&
            product.id != (excludeProductId ?? '')) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  Future<void> saveProduct(Product product) async {
    final box = database.productsBox;
    await box.put(product.id, product.toMap());
  }

  @override
  Future<void> archiveProduct(String id) async {
    final product = await getProductById(id);
    if (product != null) {
      await saveProduct(
        product.copyWith(isArchived: true, updatedAt: DateTime.now()),
      );
    }
  }

  /// Adjusts stock quantity for a product and returns the updated product.
  /// Use a positive [delta] for stock intake and negative for sales deduction.
  /// [reason] is mandatory and is stored for audit/movement tracing.
  @override
  Future<Product?> adjustStock(
    String productId, {
    required double delta,
    required String reason,
  }) async {
    final product = await getProductById(productId);
    if (product == null) return null;
    if (!product.trackInventory) return product; // No-op for non-tracked items

    final newQty = product.stockQuantity + delta;
    final updated = product.copyWith(
      stockQuantity: newQty,
      updatedAt: DateTime.now(),
    );
    await saveProduct(updated);
    return updated;
  }

  @override
  Future<List<String>> getCategories() async {
    final box = database.productsBox;
    final categories = <String>{};

    for (final key in box.keys) {
      final map = box.get(key);
      if (map != null) {
        final cat = map['category'] as String?;
        if (cat != null && cat.trim().isNotEmpty) {
          categories.add(cat.trim());
        }
      }
    }

    final list = categories.toList()..sort();
    return list;
  }
}
