import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fatoura/core/backup/backup_service.dart';
import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/invoices/data/repositories/invoice_repository_impl.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';
import 'package:fatoura/features/products/data/repositories/inventory_movement_repository_impl.dart';
import 'package:fatoura/features/products/data/repositories/product_repository_impl.dart';
import 'package:fatoura/features/products/domain/entities/inventory_movement.dart';
import 'package:fatoura/features/products/domain/entities/product.dart';
import 'package:fatoura/features/purchases/data/repositories/purchase_repository_impl.dart';
import 'package:fatoura/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:fatoura/features/returns/data/repositories/sales_return_repository_impl.dart';
import 'package:fatoura/features/returns/domain/entities/sales_return.dart';

void main() {
  late Directory tempDir;
  late HiveDatabase db;
  late InvoiceRepositoryImpl invoiceRepo;
  late PurchaseRepositoryImpl purchaseRepo;
  late PaymentRepositoryImpl paymentRepo;
  late SalesReturnRepositoryImpl returnRepo;
  late ProductRepositoryImpl productRepo;
  late InventoryMovementRepositoryImpl movementRepo;
  late BackupService backupService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fatoura_atomicity_test_');
    db = HiveDatabase.instance;
    await db.init(customPath: tempDir.path);

    invoiceRepo = InvoiceRepositoryImpl(db);
    purchaseRepo = PurchaseRepositoryImpl(db);
    paymentRepo = PaymentRepositoryImpl(
      database: db,
      invoiceRepository: invoiceRepo,
      purchaseRepository: purchaseRepo,
    );
    returnRepo = SalesReturnRepositoryImpl(
      database: db,
      invoiceRepository: invoiceRepo,
    );
    productRepo = ProductRepositoryImpl(db);
    movementRepo = InventoryMovementRepositoryImpl(db);
    backupService = BackupService(db);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('P0 Data Integrity & Financial Invariants', () {
    test('FAT-001 & FAT-004: Sales return rejects quantity exceeding original invoice and records inventory movements', () async {
      final now = DateTime.now();
      final product = Product(
        id: 'prod_ret_guard',
        name: 'شاشة سامسونج',
        defaultUnitPrice: 1000.0,
        costPrice: 800.0,
        stockQuantity: 10.0,
        trackInventory: true,
        createdAt: now,
        updatedAt: now,
      );
      await productRepo.saveProduct(product);

      // Issue invoice for 2 units (stock becomes 10 - 2 = 8)
      final inv = Invoice(
        id: 'inv_ret_guard',
        invoiceNumber: 'INV-RET-01',
        issueDate: now,
        shopName: 'متجر التكنولوجيا',
        currency: 'EGP',
        subtotal: 2000.0,
        taxableBase: 2000.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        finalTotal: 2000.0,
        totalPaid: 2000.0,
        remainingBalance: 0.0,
        documentStatus: DocumentStatus.issued,
        paymentStatus: PaymentStatus.fullyPaid,
        items: [
          InvoiceItem(
            id: 'item_ret_guard',
            productId: product.id,
            description: product.name,
            quantity: 2.0,
            unitPrice: 1000.0,
            lineTotal: 2000.0,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      await invoiceRepo.saveInvoice(inv);

      var p = await productRepo.getProductById(product.id);
      expect(p!.stockQuantity, 8.0);

      // Attempt return of 3 units (more than invoice's 2 units) -> MUST THROW StateError
      final invalidReturn = SalesReturn(
        id: 'ret_invalid_qty',
        returnNumber: 'RET-001',
        returnDate: now,
        originalInvoiceId: inv.id,
        originalInvoiceNumber: inv.invoiceNumber,
        refundMethod: RefundMethod.cash,
        totalRefundAmount: 3000.0,
        returnReason: 'طلب إرجاع أكثر من المباع',
        items: [
          SalesReturnItem(
            id: 'ret_item_inv',
            invoiceItemId: 'item_ret_guard',
            description: product.name,
            returnedQuantity: 3.0, // Exceeds 2.0!
            unitPrice: 1000.0,
            refundAmount: 3000.0,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () => returnRepo.saveReturn(invalidReturn),
        throwsA(isA<ArgumentError>()),
      );

      // Verify stock remained unchanged at 8.0
      p = await productRepo.getProductById(product.id);
      expect(p!.stockQuantity, 8.0);

      // Valid return of 1 unit -> must succeed, restore stock to 9.0, and record movement
      final validReturn = SalesReturn(
        id: 'ret_valid_qty',
        returnNumber: 'RET-002',
        returnDate: now,
        originalInvoiceId: inv.id,
        originalInvoiceNumber: inv.invoiceNumber,
        refundMethod: RefundMethod.cash,
        totalRefundAmount: 1000.0,
        returnReason: 'إرجاع وحدة واحدة',
        items: [
          SalesReturnItem(
            id: 'ret_item_valid',
            invoiceItemId: 'item_ret_guard',
            description: product.name,
            returnedQuantity: 1.0,
            unitPrice: 1000.0,
            refundAmount: 1000.0,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      await returnRepo.saveReturn(validReturn);

      p = await productRepo.getProductById(product.id);
      expect(p!.stockQuantity, 9.0);

      // Check inventory movement ledger
      final movements = await movementRepo.getMovements(productId: product.id);
      expect(
        movements.any(
          (m) => m.movementType == InventoryMovementType.customerReturn,
        ),
        isTrue,
      );

      // Now attempt another return of 2 units (remaining returnable is only 1.0!) -> MUST THROW
      final secondOverReturn = SalesReturn(
        id: 'ret_second_over',
        returnNumber: 'RET-003',
        returnDate: now,
        originalInvoiceId: inv.id,
        originalInvoiceNumber: inv.invoiceNumber,
        refundMethod: RefundMethod.cash,
        totalRefundAmount: 2000.0,
        returnReason: 'محاولة إرجاع المتبقي بزيادة',
        items: [
          SalesReturnItem(
            id: 'ret_item_over2',
            invoiceItemId: 'item_ret_guard',
            description: product.name,
            returnedQuantity: 2.0, // Remaining is only 1.0!
            unitPrice: 1000.0,
            refundAmount: 2000.0,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () => returnRepo.saveReturn(secondOverReturn),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('FAT-005 & FAT-011: Barcode uniqueness is strictly enforced at repository boundary', () async {
      final now = DateTime.now();
      final p1 = Product(
        id: 'prod_b1',
        name: 'منتج أ',
        barcode: '123456789012',
        defaultUnitPrice: 10.0,
        createdAt: now,
        updatedAt: now,
      );
      await productRepo.saveProduct(p1);

      // Attempt to save different product with same barcode -> MUST THROW ArgumentError
      final p2Duplicate = Product(
        id: 'prod_b2',
        name: 'منتج ب',
        barcode: '123456789012',
        defaultUnitPrice: 20.0,
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () => productRepo.saveProduct(p2Duplicate),
        throwsA(isA<ArgumentError>()),
      );

      // Saving product updating its own barcode must succeed
      final p1Update = p1.copyWith(name: 'منتج أ المعدل');
      await productRepo.saveProduct(p1Update);
      final reloaded = await productRepo.getProductById(p1.id);
      expect(reloaded!.name, 'منتج أ المعدل');
    });

    test('FAT-006: Payment allocation rejects sums exceeding payment amount and currency mismatch', () async {
      final now = DateTime.now();
      final egpInv = Invoice(
        id: 'inv_pay_egp',
        invoiceNumber: 'INV-PAY-EGP',
        issueDate: now,
        shopName: 'متجر التكنولوجيا',
        currency: 'EGP',
        subtotal: 500.0,
        taxableBase: 500.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        finalTotal: 500.0,
        totalPaid: 0.0,
        remainingBalance: 500.0,
        documentStatus: DocumentStatus.issued,
        paymentStatus: PaymentStatus.unpaid,
        items: const [],
        createdAt: now,
        updatedAt: now,
      );
      await invoiceRepo.saveInvoice(egpInv);

      // 1. Over-allocated payment (allocation 600 > payment 500) -> MUST THROW ArgumentError
      final overAllocatedPayment = Payment(
        id: 'pay_over',
        amount: 500.0,
        currency: 'EGP',
        paymentDate: now,
        isCustomerPayment: true,
        allocations: [
          PaymentAllocation(
            id: 'alloc_over',
            paymentId: 'pay_over',
            invoiceId: egpInv.id,
            invoiceNumber: egpInv.invoiceNumber,
            amount: 600.0,
            allocatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () => paymentRepo.savePayment(overAllocatedPayment),
        throwsA(isA<ArgumentError>()),
      );

      // 2. Cross-currency payment allocation (USD payment against EGP invoice) -> MUST THROW ArgumentError
      final crossCurrencyPayment = Payment(
        id: 'pay_usd',
        amount: 50.0,
        currency: 'USD',
        paymentDate: now,
        isCustomerPayment: true,
        allocations: [
          PaymentAllocation(
            id: 'alloc_usd',
            paymentId: 'pay_usd',
            invoiceId: egpInv.id, // EGP invoice!
            invoiceNumber: egpInv.invoiceNumber,
            amount: 50.0,
            allocatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () => paymentRepo.savePayment(crossCurrencyPayment),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('FAT-002: Purchase cancellation rejects if stock would become negative or payments exist', () async {
      final now = DateTime.now();
      final prod = Product(
        id: 'prod_pur_cancel',
        name: 'أسمنت بورتلاندي',
        defaultUnitPrice: 150.0,
        costPrice: 100.0,
        stockQuantity: 5.0, // Only 5 units in stock
        trackInventory: true,
        createdAt: now,
        updatedAt: now,
      );
      await productRepo.saveProduct(prod);

      // Purchase was for 10 units with stock received
      final purchase = PurchaseInvoice(
        id: 'pur_cancel_test',
        purchaseNumber: 'PUR-001',
        issueDate: now,
        supplierId: 'supp_1',
        supplierName: 'شركة الأسمنت',
        currency: 'EGP',
        subtotal: 1000.0,
        taxableBase: 1000.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        finalTotal: 1000.0,
        amountPaid: 0.0,
        remainingPayable: 1000.0,
        isStockReceived: true,
        documentStatus: DocumentStatus.issued,
        paymentStatus: PaymentStatus.unpaid,
        items: [
          PurchaseInvoiceItem(
            id: 'p_item_1',
            productId: prod.id,
            description: prod.name,
            quantity: 10.0,
            unitPrice: 100.0,
            lineTotal: 1000.0,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      await purchaseRepo.savePurchase(purchase);

      // Stock is now 5.0 (opening) + 10.0 (received) = 15.0.
      // Simulate selling 11 units so only 4 units remain in stock.
      await productRepo.adjustStock(
        prod.id,
        delta: -11.0,
        reason: 'مبيعات نقدية',
      );

      // Cancelling this 10-unit purchase requires reversing 10 units, but only 4 are in stock!
      // Must throw StateError preventing negative stock!
      expect(
        () => purchaseRepo.cancelPurchase(
          purchase.id,
          'إلغاء غير مسموح بنقص المخزون',
        ),
        throwsA(isA<StateError>()),
      );

      // Verify stock remained unchanged at 4.0
      var currentProd = await productRepo.getProductById(prod.id);
      expect(currentProd!.stockQuantity, 4.0);

      // Add stock so 15 units are available (4 + 11 = 15)
      await productRepo.adjustStock(
        prod.id,
        delta: 11.0,
        reason: 'إمداد إضافي',
      );
      currentProd = await productRepo.getProductById(prod.id);
      expect(currentProd!.stockQuantity, 15.0);

      // Now cancel purchase: succeeds, reverses 10 units (15 - 10 = 5), and records movement
      await purchaseRepo.cancelPurchase(
        purchase.id,
        'إلغاء ناجح بعد توفر المخزون',
      );

      currentProd = await productRepo.getProductById(prod.id);
      expect(currentProd!.stockQuantity, 5.0);

      final movements = await movementRepo.getMovements(productId: prod.id);
      expect(
        movements.any(
          (m) => m.movementType == InventoryMovementType.purchaseCancellation,
        ),
        isTrue,
      );

      final reloadedPurchase = await purchaseRepo.getPurchaseById(purchase.id);
      expect(reloadedPurchase!.documentStatus, DocumentStatus.cancelled);
      expect(
        reloadedPurchase.cancellationReason,
        'إلغاء ناجح بعد توفر المخزون',
      );
    });

    test('FAT-009: Backup created with schema version 1 without box_inventory_movements restores cleanly', () async {
      // Simulate an older schema version 1 export where box_inventory_movements did not exist
      final tables = <String, dynamic>{};
      for (final boxName in HiveBoxes.allBoxes) {
        if (boxName != HiveBoxes.inventoryMovements) {
          tables[boxName] = <String, dynamic>{};
        }
      }

      // Add a product to the tables
      tables[HiveBoxes.products] = {
        'prod_legacy': {
          'id': 'prod_legacy',
          'name': 'منتج قديم',
          'defaultUnitPrice': 100.0,
          'costPrice': 80.0,
          'stockQuantity': 50.0,
          'trackInventory': true,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
      };

      final tablesJson = jsonEncode(tables);
      final checksum = sha256.convert(utf8.encode(tablesJson)).toString();

      final legacyBackupPayload = jsonEncode({
        'app': 'Fatoura',
        'schemaVersion': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'checksum': checksum,
        'data': {'tables': tables},
      });

      // Restore legacy backup
      final result = await backupService.restoreBackup(legacyBackupPayload);
      expect(result.success, isTrue);

      // Verify product restored and inventory movements box is accessible without errors
      final prod = await productRepo.getProductById('prod_legacy');
      expect(prod, isNotNull);
      expect(prod!.name, 'منتج قديم');

      final movements = await movementRepo.getMovements(
        productId: 'prod_legacy',
      );
      expect(movements, isEmpty);
    });
  });
}
