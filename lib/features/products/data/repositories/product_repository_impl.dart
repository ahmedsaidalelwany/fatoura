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
            if (product.name.toLowerCase().contains(q) ||
                product.sku.toLowerCase().contains(q) ||
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
