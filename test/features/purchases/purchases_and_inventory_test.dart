import 'dart:io';

import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/core/storage/sequence_manager.dart';
import 'package:fatoura/features/audit/data/repositories/audit_repository_impl.dart';
import 'package:fatoura/features/invoices/data/repositories/invoice_repository_impl.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/parties/data/repositories/party_repository_impl.dart';
import 'package:fatoura/features/parties/domain/entities/party.dart';
import 'package:fatoura/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';
import 'package:fatoura/features/products/data/repositories/product_repository_impl.dart';
import 'package:fatoura/features/products/domain/entities/product.dart';
import 'package:fatoura/features/purchases/data/repositories/purchase_repository_impl.dart';
import 'package:fatoura/features/purchases/presentation/cubit/purchases_cubit.dart';
import 'package:fatoura/features/shop_setup/data/repositories/shop_profile_repository_impl.dart';
import 'package:fatoura/features/shop_setup/domain/entities/shop_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late HiveDatabase db;
  late SequenceManager seqManager;
  late ShopProfileRepositoryImpl shopRepo;
  late PurchaseRepositoryImpl purchaseRepo;
  late InvoiceRepositoryImpl invoiceRepo;
  late PaymentRepositoryImpl paymentRepo;
  late PartyRepositoryImpl partyRepo;
  late AuditRepositoryImpl auditRepo;
  late ProductRepositoryImpl productRepo;
  late PurchasesCubit purchasesCubit;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fatoura_purchases_test_');
    db = HiveDatabase.instance;
    await db.init(customPath: tempDir.path);

    seqManager = SequenceManager(db);
    shopRepo = ShopProfileRepositoryImpl(db);
    purchaseRepo = PurchaseRepositoryImpl(db);
    invoiceRepo = InvoiceRepositoryImpl(db);
    partyRepo = PartyRepositoryImpl(db);
    auditRepo = AuditRepositoryImpl(db);
    productRepo = ProductRepositoryImpl(db);
    paymentRepo = PaymentRepositoryImpl(
      database: db,
      invoiceRepository: invoiceRepo,
    );

    await shopRepo.saveProfile(
      ShopProfile(
        id: 'test_shop_purchases',
        name: 'مؤسسة التوريدات',
        businessType: 'تجارة وتوريد',
        defaultCurrency: 'EGP',
        phone: '01011112222',
        address: 'الإسكندرية',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // Create a supplier party
    final supplier = Party(
      id: 'supp_al_ahram',
      name: 'شركة الأهرام للتوريدات',
      phone: '01234567890',
      isCustomer: false,
      isSupplier: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await partyRepo.saveParty(supplier);

    purchasesCubit = PurchasesCubit(
      purchaseRepository: purchaseRepo,
      shopProfileRepository: shopRepo,
      sequenceManager: seqManager,
      auditRepository: auditRepo,
      productRepository: productRepo,
      paymentRepository: paymentRepo,
      partyRepository: partyRepo,
    );
  });

  tearDown(() async {
    await purchasesCubit.close();
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Supplier Purchases & Stock Integration Tests', () {
    test('Confirmed purchase creates stock inventory and updates cost price', () async {
      // 1. Initial product with 5 units at cost 100
      final product = Product(
        id: 'prod_cement',
        name: 'شيكارة أسمنت',
        defaultUnitPrice: 180.0,
        costPrice: 140.0,
        trackInventory: true,
        stockQuantity: 5.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await productRepo.saveProduct(product);

      // 2. Issue confirmed purchase for 20 units at new cost 145
      final purchase = await purchasesCubit.createPurchase(
        supplierId: 'supp_al_ahram',
        supplierName: 'شركة الأهرام للتوريدات',
        rawItems: [
          (
            productId: 'prod_cement',
            description: 'شيكارة أسمنت ممتاز',
            quantity: 20.0,
            unitPrice: 145.0,
          ),
        ],
        isDraft: false, // Confirmed purchase!
        initialPaymentStatus: PaymentStatus.fullyPaid,
      );

      expect(purchase, isNotNull);
      expect(purchase!.isStockReceived, isTrue);
      expect(purchase.documentStatus, DocumentStatus.issued);
      expect(purchase.finalTotal, 20.0 * 145.0); // 2900.0

      // Verify product stock is incremented: 5 + 20 = 25
      final updatedProduct = await productRepo.getProductById('prod_cement');
      expect(updatedProduct, isNotNull);
      expect(updatedProduct!.stockQuantity, 25.0);
      // Cost price updated to latest purchase unit cost
      expect(updatedProduct.costPrice, 145.0);
    });

    test('Draft purchase does NOT increment inventory', () async {
      final product = Product(
        id: 'prod_paint',
        name: 'علبة دهان',
        defaultUnitPrice: 250.0,
        costPrice: 190.0,
        trackInventory: true,
        stockQuantity: 10.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await productRepo.saveProduct(product);

      // Create draft purchase for 15 units
      final draftPurchase = await purchasesCubit.createPurchase(
        supplierId: 'supp_al_ahram',
        supplierName: 'شركة الأهرام للتوريدات',
        rawItems: [
          (
            productId: 'prod_paint',
            description: 'علبة دهان أبيض',
            quantity: 15.0,
            unitPrice: 195.0,
          ),
        ],
        isDraft: true, // Draft!
      );

      expect(draftPurchase, isNotNull);
      expect(draftPurchase!.isDraft, isTrue);
      expect(draftPurchase.isStockReceived, isFalse);

      // Product stock must remain exactly 10.0
      final prodAfterDraft = await productRepo.getProductById('prod_paint');
      expect(prodAfterDraft!.stockQuantity, 10.0);
      expect(prodAfterDraft.costPrice, 190.0); // Not updated yet
    });

    test('confirmStockReceipt transitions draft, increments stock, and is idempotent', () async {
      final product = Product(
        id: 'prod_pipes',
        name: 'ماسورة سباكة',
        defaultUnitPrice: 80.0,
        costPrice: 50.0,
        trackInventory: true,
        stockQuantity: 10.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await productRepo.saveProduct(product);

      // Create draft purchase for 5 pipes
      final draft = await purchasesCubit.createPurchase(
        supplierId: 'supp_al_ahram',
        supplierName: 'شركة الأهرام للتوريدات',
        rawItems: [
          (
            productId: 'prod_pipes',
            description: 'ماسورة بلاستيك 1 بوصة',
            quantity: 5.0,
            unitPrice: 55.0,
          ),
        ],
        isDraft: true,
      );
      expect(draft, isNotNull);

      // First confirmation: stock should increase from 10 to 15
      final success1 = await purchasesCubit.confirmStockReceipt(draft!.id);
      expect(success1, isTrue);

      final prodAfterConfirm = await productRepo.getProductById('prod_pipes');
      expect(prodAfterConfirm!.stockQuantity, 15.0);
      expect(prodAfterConfirm.costPrice, 55.0);

      // Second confirmation (IDEMPOTENCY TEST): must NOT increment stock again!
      final success2 = await purchasesCubit.confirmStockReceipt(draft.id);
      expect(success2, isTrue);

      final prodAfterSecondConfirm = await productRepo.getProductById('prod_pipes');
      expect(prodAfterSecondConfirm!.stockQuantity, 15.0); // Strictly unchanged!
    });

    test('Supplier return decrements stock and validates sufficient available inventory', () async {
      final product = Product(
        id: 'prod_bricks',
        name: 'طوب بناء',
        defaultUnitPrice: 3.0,
        costPrice: 2.0,
        trackInventory: true,
        stockQuantity: 100.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await productRepo.saveProduct(product);

      // Create confirmed purchase
      final purchase = await purchasesCubit.createPurchase(
        supplierId: 'supp_al_ahram',
        supplierName: 'شركة الأهرام للتوريدات',
        rawItems: [
          (
            productId: 'prod_bricks',
            description: 'طوب أحمر',
            quantity: 100.0,
            unitPrice: 2.0,
          ),
        ],
        isDraft: false,
        initialPaymentStatus: PaymentStatus.unpaid,
      );
      expect(purchase, isNotNull);
      // Stock became 100 + 100 = 200
      var prod = await productRepo.getProductById('prod_bricks');
      expect(prod!.stockQuantity, 200.0);

      // Return 30 units: valid return
      final returnSuccess = await purchasesCubit.recordPurchaseReturn(
        purchaseId: purchase!.id,
        productId: 'prod_bricks',
        returnQuantity: 30.0,
        reason: 'طوب معيب مكسور',
        refundAmount: 60.0,
        isCashRefund: false,
      );
      expect(returnSuccess, isTrue);

      // Stock reduced to 170
      prod = await productRepo.getProductById('prod_bricks');
      expect(prod!.stockQuantity, 170.0);

      // Remaining payable reduced: 200 - 60 = 140
      final updatedPurchase = await purchaseRepo.getPurchaseById(purchase.id);
      expect(updatedPurchase!.remainingPayable, 140.0);

      // Attempt to return 500 units (more than 170 in stock) -> MUST FAIL!
      final invalidReturn = await purchasesCubit.recordPurchaseReturn(
        purchaseId: purchase.id,
        productId: 'prod_bricks',
        returnQuantity: 500.0,
        reason: 'إرجاع زائد عن المخزون',
      );
      expect(invalidReturn, isFalse);
      expect(purchasesCubit.state, isA<PurchasesError>());
      final err = purchasesCubit.state as PurchasesError;
      expect(err.message, contains('insufficient to return 500.0 units'));

      // Stock remains 170
      prod = await productRepo.getProductById('prod_bricks');
      expect(prod!.stockQuantity, 170.0);
    });
  });

  group('Supplier Payment States & Subsequent Payments', () {
    test('Purchase payment lifecycle: Unpaid -> Partial Payment -> Full Payment', () async {
      // Create unpaid purchase for EGP 1000
      final purchase = await purchasesCubit.createPurchase(
        supplierId: 'supp_al_ahram',
        supplierName: 'شركة الأهرام للتوريدات',
        rawItems: [
          (
            productId: null,
            description: 'مستلزمات عامة',
            quantity: 10.0,
            unitPrice: 100.0,
          ),
        ],
        initialPaymentStatus: PaymentStatus.unpaid,
      );
      expect(purchase, isNotNull);
      expect(purchase!.finalTotal, 1000.0);
      expect(purchase.amountPaid, 0.0);
      expect(purchase.remainingPayable, 1000.0);
      expect(purchase.paymentStatus, PaymentStatus.unpaid);

      // Record partial payment of EGP 400
      final partialSuccess = await purchasesCubit.recordSupplierPayment(
        purchaseId: purchase.id,
        amount: 400.0,
        method: PaymentMethod.bank,
        notes: 'TRX-1001',
      );
      expect(partialSuccess, isTrue);

      final afterPartial = await purchaseRepo.getPurchaseById(purchase.id);
      expect(afterPartial!.amountPaid, 400.0);
      expect(afterPartial.remainingPayable, 600.0);
      expect(afterPartial.paymentStatus, PaymentStatus.partiallyPaid);

      // Record final payment of EGP 600
      final fullSuccess = await purchasesCubit.recordSupplierPayment(
        purchaseId: purchase.id,
        amount: 600.0,
        method: PaymentMethod.cash,
        notes: 'CASH-1002',
      );
      expect(fullSuccess, isTrue);

      final afterFull = await purchaseRepo.getPurchaseById(purchase.id);
      expect(afterFull!.amountPaid, 1000.0);
      expect(afterFull.remainingPayable, 0.0);
      expect(afterFull.paymentStatus, PaymentStatus.fullyPaid);
    });
  });
}
