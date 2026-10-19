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

  const ProductOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
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
    String description = '',
    required double defaultUnitPrice,
    String category = '',
  }) async {
    if (name.trim().isEmpty) {
      emit(const ProductsError('Product name cannot be empty.'));
      return;
    }
    if (defaultUnitPrice < 0.0) {
      emit(const ProductsError('Unit price cannot be negative.'));
      return;
    }

    emit(ProductsLoading());
    try {
      final productId = id ?? const Uuid().v4();
      final now = DateTime.now();

      final product = Product(
        id: productId,
        name: name.trim(),
        sku: sku.trim(),
        description: description.trim(),
        defaultUnitPrice: defaultUnitPrice,
        category: category.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveProduct(product);
      emit(const ProductOperationSuccess('Product saved successfully'));
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
