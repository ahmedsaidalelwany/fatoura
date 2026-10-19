import 'package:fatoura/features/products/domain/entities/product.dart';

abstract class ProductRepository {
  Future<List<Product>> getProducts({
    String? query,
    String? category,
    bool includeArchived = false,
  });
  Future<Product?> getProductById(String id);
  Future<void> saveProduct(Product product);
  Future<void> archiveProduct(String id);
  Future<List<String>> getCategories();
}
