import 'dart:io';

import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/products/data/repositories/product_repository_impl.dart';
import 'package:fatoura/features/products/domain/entities/product.dart';
import 'package:fatoura/features/products/presentation/cubit/products_cubit.dart';
import 'package:fatoura/features/shop_setup/presentation/pages/shop_setup_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BusinessType Migration Tests', () {
    test(
      'BusinessType.compatibleDefault safely maps legacy strings without reset',
      () {
        // Null or empty defaults to product
        expect(BusinessType.compatibleDefault(null), BusinessType.product);
        expect(BusinessType.compatibleDefault(''), BusinessType.product);
        expect(BusinessType.compatibleDefault('   '), BusinessType.product);

        // Stable codes are preserved exactly
        expect(BusinessType.compatibleDefault('product'), BusinessType.product);
        expect(BusinessType.compatibleDefault('service'), BusinessType.service);
        expect(BusinessType.compatibleDefault('mixed'), BusinessType.mixed);

        // Legacy Arabic free-text values mapped intelligently
        expect(
          BusinessType.compatibleDefault('خدمات طبية'),
          BusinessType.service,
        );
        expect(
          BusinessType.compatibleDefault('نشاط مختلط'),
          BusinessType.mixed,
        );
        expect(
          BusinessType.compatibleDefault('متجر تجاري'),
          BusinessType.product,
        );
      },
    );

    test('BusinessType labels and descriptions support Arabic and English', () {
      expect(
        BusinessType.label(BusinessType.product, isArabic: true),
        'بيع المنتجات',
      );
      expect(
        BusinessType.label(BusinessType.service, isArabic: false),
        'Services',
      );
      expect(
        BusinessType.label(BusinessType.mixed, isArabic: true),
        'بيع المنتجات وتقديم الخدمات',
      );
      expect(
        BusinessType.description(
          BusinessType.product,
          isArabic: true,
        ).isNotEmpty,
        isTrue,
      );
    });
  });

  group('Product Barcode & Inventory Tests', () {
    late Directory tempDir;
    late HiveDatabase db;
    late ProductRepositoryImpl productRepo;
    late ProductsCubit productsCubit;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fatoura_prod_test_');
      db = HiveDatabase.instance;
      await db.init(customPath: tempDir.path);
      productRepo = ProductRepositoryImpl(db);
      productsCubit = ProductsCubit(productRepo);
    });

    tearDown(() async {
      await productsCubit.close();
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'Barcode preserves leading zeros and is stored strictly as String',
      () async {
        const barcodeWithLeadingZero = '001234567890';
        final now = DateTime.now();

        final p = Product(
          id: 'prod_001',
          name: 'كتاب محاسبة',
          barcode: barcodeWithLeadingZero,
          defaultUnitPrice: 150.0,
          createdAt: now,
          updatedAt: now,
        );

        await productRepo.saveProduct(p);

        final retrieved = await productRepo.getProductById('prod_001');
        expect(retrieved, isNotNull);
        expect(retrieved!.barcode, barcodeWithLeadingZero);
        expect(retrieved.barcode.startsWith('00'), isTrue);

        final byBarcode = await productRepo.getProductByBarcode(
          barcodeWithLeadingZero,
        );
        expect(byBarcode, isNotNull);
        expect(byBarcode!.id, 'prod_001');
      },
    );

    test('Barcode uniqueness validation prevents duplicate barcodes on different products', () async {
      const sharedBarcode = '628100000001';
      final now = DateTime.now();

      final p1 = Product(
        id: 'prod_1',
        name: 'منتج أ',
        barcode: sharedBarcode,
        defaultUnitPrice: 10.0,
        createdAt: now,
        updatedAt: now,
      );
      await productRepo.saveProduct(p1);

      // Checking uniqueness for the same product must be true (editing existing product)
      final uniqueSelf = await productRepo.isBarcodeUnique(
        sharedBarcode,
        excludeProductId: 'prod_1',
      );
      expect(uniqueSelf, isTrue);

      // Checking uniqueness for a new or different product must be false
      final uniqueOther = await productRepo.isBarcodeUnique(
        sharedBarcode,
        excludeProductId: 'prod_2',
      );
      expect(uniqueOther, isFalse);
    });

    test('Stock adjustments correctly update product quantity and inventory status', () async {
      final now = DateTime.now();
      final p = Product(
        id: 'prod_stock_test',
        name: 'شاحن هاتف',
        defaultUnitPrice: 200.0,
        stockQuantity: 10.0,
        reorderLevel: 3.0,
        trackInventory: true,
        createdAt: now,
        updatedAt: now,
      );
      await productRepo.saveProduct(p);

      // Initial state: not low stock, not out of stock
      final initial = await productRepo.getProductById('prod_stock_test');
      expect(initial!.isLowStock, isFalse);
      expect(initial.isOutOfStock, isFalse);

      // Deduct 8 items (sales movement) -> remaining: 2.0 (below reorder level of 3.0)
      await productRepo.adjustStock(
        'prod_stock_test',
        delta: -8.0,
        reason: 'Sale',
      );
      final lowStock = await productRepo.getProductById('prod_stock_test');
      expect(lowStock!.stockQuantity, 2.0);
      expect(lowStock.isLowStock, isTrue);
      expect(lowStock.isOutOfStock, isFalse);

      // Deduct 2 items -> remaining: 0.0 (out of stock)
      await productRepo.adjustStock(
        'prod_stock_test',
        delta: -2.0,
        reason: 'Sale',
      );
      final outStock = await productRepo.getProductById('prod_stock_test');
      expect(outStock!.stockQuantity, 0.0);
      expect(outStock.isOutOfStock, isTrue);

      // Replenish 15 items (purchase movement) -> remaining: 15.0
      await productRepo.adjustStock(
        'prod_stock_test',
        delta: 15.0,
        reason: 'Purchase',
      );
      final replenished = await productRepo.getProductById('prod_stock_test');
      expect(replenished!.stockQuantity, 15.0);
      expect(replenished.isLowStock, isFalse);
      expect(replenished.isOutOfStock, isFalse);
    });

    test(
      'Throws StateError if adjustment would produce negative inventory',
      () async {
        final now = DateTime.now();
        final p = Product(
          id: 'prod_neg_test',
          name: 'Item With Stock Guard',
          defaultUnitPrice: 20.0,
          stockQuantity: 3.0,
          trackInventory: true,
          createdAt: now,
          updatedAt: now,
        );
        await productRepo.saveProduct(p);

        expect(
          () => productRepo.adjustStock(
            'prod_neg_test',
            delta: -4.0,
            reason: 'Excessive sale',
          ),
          throwsA(isA<StateError>()),
        );
        // Verify quantity was not modified
        final fetched = await productRepo.getProductById('prod_neg_test');
        expect(fetched!.stockQuantity, 3.0);
      },
    );
  });
}
