import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:fatoura/features/products/domain/entities/product.dart';
import 'package:fatoura/features/products/domain/repositories/product_repository.dart';

abstract class ProductsState extends Equatable {
  const ProductsState();
  @override
  List<Object?> get props => [];
}

class ProductsInitial extends ProductsState {}

class ProductsLoading extends ProductsState {}

class ProductsLoaded extends ProductsState {
  final List<Product> products;
  final List<String> categories;

  const ProductsLoaded({required this.products, required this.categories});

  @override
  List<Object?> get props => [products, categories];
}

class ProductOperationSuccess extends ProductsState {
  final String message;
  final Product? product;

  const ProductOperationSuccess(this.message, {this.product});

  @override
  List<Object?> get props => [message, product];
}

class ProductsError extends ProductsState {
  final String message;

  const ProductsError(this.message);

  @override
  List<Object?> get props => [message];
}

class ProductsCubit extends Cubit<ProductsState> {
  final ProductRepository repository;

  ProductsCubit(this.repository) : super(ProductsInitial());

  Future<void> loadProducts({String? query, String? category}) async {
    emit(ProductsLoading());
    try {
      final products = await repository.getProducts(
        query: query,
        category: category,
      );
      final categories = await repository.getCategories();
      emit(ProductsLoaded(products: products, categories: categories));
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
  }

  Future<void> saveProduct({
    String? id,
    required String name,
    String sku = '',
    String barcode = '',
    String description = '',
    required double defaultUnitPrice,
    double costPrice = 0.0,
    String category = '',
    double stockQuantity = 0.0,
    double reorderLevel = 0.0,
    bool trackInventory = false,
  }) async {
    if (name.trim().isEmpty) {
      emit(const ProductsError('Product name cannot be empty.'));
      return;
    }
    if (defaultUnitPrice < 0.0) {
      emit(const ProductsError('Unit price cannot be negative.'));
      return;
    }

    // Validate barcode uniqueness if a barcode is provided
    if (barcode.trim().isNotEmpty) {
      final isUnique = await repository.isBarcodeUnique(
        barcode.trim(),
        excludeProductId: id,
      );
      if (!isUnique) {
        emit(
          ProductsError(
            'Barcode "${barcode.trim()}" is already assigned to another product.',
          ),
        );
        return;
      }
    }

    emit(ProductsLoading());
    try {
      final isNew = id == null || id.isEmpty;
      final productId = isNew ? const Uuid().v4() : id;
      final now = DateTime.now();

      // Preserve existing data when editing
      Product? existing;
      if (!isNew) {
        existing = await repository.getProductById(productId);
      }

      final product = Product(
        id: productId,
        name: name.trim(),
        sku: sku.trim(),
        barcode: barcode.trim(),
        description: description.trim(),
        defaultUnitPrice: defaultUnitPrice,
        costPrice: costPrice,
        category: category.trim(),
        isArchived: existing?.isArchived ?? false,
        stockQuantity: existing?.stockQuantity ?? stockQuantity,
        reorderLevel: reorderLevel,
        trackInventory: trackInventory,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      await repository.saveProduct(product);
      emit(
        ProductOperationSuccess('Product saved successfully', product: product),
      );
      await loadProducts();
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
  }

  /// Looks up a product by barcode. Returns the product or null.
  Future<Product?> findByBarcode(String barcode) async {
    if (barcode.trim().isEmpty) return null;
    try {
      return await repository.getProductByBarcode(barcode.trim());
    } catch (e) {
      return null;
    }
  }

  /// Adjusts stock quantity for a product.
  Future<void> adjustStock(
    String productId, {
    required double delta,
    required String reason,
  }) async {
    emit(ProductsLoading());
    try {
      await repository.adjustStock(productId, delta: delta, reason: reason);
      emit(const ProductOperationSuccess('Stock adjusted successfully'));
      await loadProducts();
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
  }

  Future<void> archiveProduct(String id) async {
    emit(ProductsLoading());
    try {
      await repository.archiveProduct(id);
      emit(const ProductOperationSuccess('Product archived successfully'));
      await loadProducts();
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
  }
}
