import 'dart:io';

import 'package:fatoura/core/pdf/invoice_pdf_generator.dart';
import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/core/storage/sequence_manager.dart';
import 'package:fatoura/features/audit/data/repositories/audit_repository_impl.dart';
import 'package:fatoura/features/invoices/data/repositories/invoice_repository_impl.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/invoices/presentation/cubit/invoices_cubit.dart';
import 'package:fatoura/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:fatoura/features/products/data/repositories/product_repository_impl.dart';
import 'package:fatoura/features/products/domain/entities/product.dart';
import 'package:fatoura/features/shop_setup/data/repositories/shop_profile_repository_impl.dart';
import 'package:fatoura/features/shop_setup/domain/entities/shop_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveDatabase db;
  late SequenceManager seqManager;
  late ShopProfileRepositoryImpl shopRepo;
  late InvoiceRepositoryImpl invoiceRepo;
  late PaymentRepositoryImpl paymentRepo;
  late AuditRepositoryImpl auditRepo;
  late ProductRepositoryImpl productRepo;
  late InvoicesCubit invoicesCubit;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'fatoura_invoice_stock_test_',
    );
    db = HiveDatabase.instance;
    await db.init(customPath: tempDir.path);

    seqManager = SequenceManager(db);
    shopRepo = ShopProfileRepositoryImpl(db);
    invoiceRepo = InvoiceRepositoryImpl(db);
    auditRepo = AuditRepositoryImpl(db);
    productRepo = ProductRepositoryImpl(db);
    paymentRepo = PaymentRepositoryImpl(
      database: db,
      invoiceRepository: invoiceRepo,
    );

    await shopRepo.saveProfile(
      ShopProfile(
        id: 'test_shop_stock',
        name: 'متجر اختبار المخزون',
        businessType: 'تجارة تجزئة',
        defaultCurrency: 'EGP',
        phone: '01000000000',
        address: 'القاهرة، مصر',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    invoicesCubit = InvoicesCubit(
      invoiceRepository: invoiceRepo,
      shopProfileRepository: shopRepo,
      sequenceManager: seqManager,
      auditRepository: auditRepo,
      productRepository: productRepo,
      paymentRepository: paymentRepo,
    );
  });

  tearDown(() async {
    await invoicesCubit.close();
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Strict Stock Validation & Cumulative Checks', () {
    test('Rejects a physical product that is missing from storage', () async {
      final invoice = await invoicesCubit.createInvoice(
        customerId: 'cust_missing_product',
        customerName: 'عميل منتج مفقود',
        rawItems: [
          (
            productId: 'missing_product',
            description: 'منتج غير مسجل',
            quantity: 1.0,
            unitPrice: 100.0,
            isService: false,
          ),
        ],
      );

      expect(invoice, isNull);
      expect(invoicesCubit.state, isA<InvoicesError>());
      expect(await invoiceRepo.getInvoices(), isEmpty);
    });

    test(
      'Repository rejects an issued invoice that bypasses the Cubit',
      () async {
        final now = DateTime.now();
        final invoice = Invoice(
          id: 'direct_missing_product',
          invoiceNumber: 'Ftr-direct-missing',
          issueDate: now,
          shopName: 'متجر اختبار المخزون',
          items: const [
            InvoiceItem(
              id: 'missing_item',
              productId: 'missing_product',
              description: 'منتج غير مسجل',
              quantity: 1,
              unitPrice: 100,
              lineTotal: 100,
            ),
          ],
          subtotal: 100,
          taxableBase: 100,
          finalTotal: 100,
          remainingBalance: 100,
          createdAt: now,
          updatedAt: now,
        );

        await expectLater(invoiceRepo.saveInvoice(invoice), throwsStateError);
        expect(await invoiceRepo.getInvoiceById(invoice.id), isNull);
      },
    );

    test('Concurrent sales cannot both consume the last unit', () async {
      await productRepo.saveProduct(
        Product(
          id: 'last_unit',
          name: 'وحدة أخيرة',
          defaultUnitPrice: 100,
          trackInventory: true,
          stockQuantity: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final results = await Future.wait([
        invoicesCubit.createInvoice(
          customerName: 'عميل 1',
          rawItems: [
            (
              productId: 'last_unit',
              description: 'وحدة أخيرة',
              quantity: 1,
              unitPrice: 100,
              isService: false,
            ),
          ],
        ),
        invoicesCubit.createInvoice(
          customerName: 'عميل 2',
          rawItems: [
            (
              productId: 'last_unit',
              description: 'وحدة أخيرة',
              quantity: 1,
              unitPrice: 100,
              isService: false,
            ),
          ],
        ),
      ]);

      expect(results.whereType<Invoice>(), hasLength(1));
      expect((await productRepo.getProductById('last_unit'))!.stockQuantity, 0);
      expect(await invoiceRepo.getInvoices(), hasLength(1));
    });

    test('Rejects invoice when physical product requested quantity exceeds available stock', () async {
      final product = Product(
        id: 'prod_stock_5',
        name: 'شاشة حاسوب',
        defaultUnitPrice: 2500.0,
        costPrice: 2000.0,
        trackInventory: true,
        stockQuantity: 5.0,
        reorderLevel: 1.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await productRepo.saveProduct(product);

      // Attempt to order 6 units when only 5 exist
      final inv = await invoicesCubit.createInvoice(
        customerId: 'cust_stock_1',
        customerName: 'عميل شاشات',
        rawItems: [
          (
            productId: 'prod_stock_5',
            description: 'شاشة حاسوب',
            quantity: 6.0,
            unitPrice: 2500.0,
            isService: false,
          ),
        ],
      );

      expect(inv, isNull);
      expect(invoicesCubit.state, isA<InvoicesError>());
      final errorState = invoicesCubit.state as InvoicesError;
      expect(errorState.message, contains('المخزون غير كافٍ'));
      expect(errorState.message, contains('6.0')); // demanded
      expect(errorState.message, contains('5.0')); // available

      // Verify product stock did not change
      final unchangedProduct = await productRepo.getProductById('prod_stock_5');
      expect(unchangedProduct!.stockQuantity, 5.0);
    });

    test('Rejects invoice when cumulative demand across multiple lines for same product exceeds stock', () async {
      final product = Product(
        id: 'prod_multi_line',
        name: 'كابل بيانات',
        defaultUnitPrice: 50.0,
        costPrice: 30.0,
        trackInventory: true,
        stockQuantity: 4.0,
        reorderLevel: 1.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await productRepo.saveProduct(product);

      // Two line items of 3 units each = total 6 demanded, stock is only 4
      final inv = await invoicesCubit.createInvoice(
        customerId: 'cust_stock_2',
        customerName: 'عميل كابلات',
        rawItems: [
          (
            productId: 'prod_multi_line',
            description: 'كابل بيانات - دفعة 1',
            quantity: 3.0,
            unitPrice: 50.0,
            isService: false,
          ),
          (
            productId: 'prod_multi_line',
            description: 'كابل بيانات - دفعة 2',
            quantity: 3.0,
            unitPrice: 50.0,
            isService: false,
          ),
        ],
      );

      expect(inv, isNull);
      expect(invoicesCubit.state, isA<InvoicesError>());
      final errorState = invoicesCubit.state as InvoicesError;
      expect(errorState.message, contains('المخزون غير كافٍ'));
      expect(
        errorState.message,
        contains('6.0'),
      ); // Total demanded across lines
      expect(errorState.message, contains('4.0')); // Available
    });

    test('Rejects non-positive or zero quantities', () async {
      final invZero = await invoicesCubit.createInvoice(
        customerId: 'cust_invalid',
        customerName: 'عميل كمية صفرية',
        rawItems: [
          (
            productId: null,
            description: 'بند غير صالح',
            quantity: 0.0,
            unitPrice: 100.0,
            isService: false,
          ),
        ],
      );
      expect(invZero, isNull);
      expect(invoicesCubit.state, isA<InvoicesError>());

      final invNeg = await invoicesCubit.createInvoice(
        customerId: 'cust_invalid',
        customerName: 'عميل كمية سالبة',
        rawItems: [
          (
            productId: null,
            description: 'بند غير صالح',
            quantity: -2.0,
            unitPrice: 100.0,
            isService: false,
          ),
        ],
      );
      expect(invNeg, isNull);
      expect(invoicesCubit.state, isA<InvoicesError>());
    });

    test(
      'Services bypass stock validation completely even if inventory is zero',
      () async {
        final serviceProd = Product(
          id: 'serv_maintenance',
          name: 'خدمة صيانة دورية',
          defaultUnitPrice: 300.0,
          costPrice: 0.0,
          trackInventory: false,
          stockQuantity: 0.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await productRepo.saveProduct(serviceProd);

        final inv = await invoicesCubit.createInvoice(
          customerId: 'cust_service',
          customerName: 'عميل خدمة',
          rawItems: [
            (
              productId: 'serv_maintenance',
              description: 'صيانة دورية للأجهزة',
              quantity: 5.0,
              unitPrice: 300.0,
              isService: true,
            ),
          ],
          template: InvoiceTemplate.service,
        );

        expect(inv, isNotNull);
        expect(inv!.template, InvoiceTemplate.service);
        expect(inv.finalTotal, 1500.0);

        // Verify product stock is untouched
        final prod = await productRepo.getProductById('serv_maintenance');
        expect(prod!.stockQuantity, 0.0);
      },
    );
  });

  group('Invoice Templates & Dual PDF Generation', () {
    test('InvoiceTemplate serialization, deserialization, and defaults', () {
      final invProduct = Invoice(
        id: 'inv_tpl_1',
        invoiceNumber: 'Ftr-01.01.2026-0001',
        issueDate: DateTime.now(),
        shopName: 'متجر تجريبي',
        items: const [
          InvoiceItem(
            id: 'item_1',
            description: 'قلم جاف',
            quantity: 2.0,
            unitPrice: 10.0,
            lineTotal: 20.0,
            isService: false,
          ),
        ],
        subtotal: 20.0,
        taxableBase: 20.0,
        finalTotal: 20.0,
        remainingBalance: 20.0,
        template: InvoiceTemplate.product,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = invProduct.toMap();
      expect(map['template'], 'product');

      final fromMap = Invoice.fromMap(map);
      expect(fromMap.template, InvoiceTemplate.product);

      // Mixed template
      final invMixed = invProduct.copyWith(template: InvoiceTemplate.mixed);
      final mapMixed = invMixed.toMap();
      expect(mapMixed['template'], 'mixed');
      expect(Invoice.fromMap(mapMixed).template, InvoiceTemplate.mixed);

      // Service template
      final invService = invProduct.copyWith(template: InvoiceTemplate.service);
      final mapService = invService.toMap();
      expect(mapService['template'], 'service');
      expect(Invoice.fromMap(mapService).template, InvoiceTemplate.service);
    });

    test(
      'Dual PDF printing: generates both A4 and Thermal 80mm receipt formats',
      () async {
        final inv = Invoice(
          id: 'inv_pdf_test',
          invoiceNumber: 'Ftr-19.10.2026-0099',
          issueDate: DateTime.now(),
          shopName: 'مؤسسة فاتورة الحديثة',
          shopPhone: '01012345678',
          shopAddress: 'مدينة نصر، القاهرة',
          shopTaxNumber: '123-456-789',
          customerName: 'شركة الأمل للتجارة',
          customerPhone: '01198765432',
          items: const [
            InvoiceItem(
              id: 'item_a',
              description: 'طابعة باركود حرارية',
              quantity: 1.0,
              unitPrice: 3500.0,
              lineTotal: 3500.0,
              isService: false,
            ),
            InvoiceItem(
              id: 'item_b',
              description: 'خدمة التثبيت والتدريب',
              quantity: 2.0,
              unitPrice: 500.0,
              lineTotal: 1000.0,
              isService: true,
            ),
          ],
          subtotal: 4500.0,
          taxableBase: 4500.0,
          taxRate: 14.0,
          taxAmount: 630.0,
          finalTotal: 5130.0,
          totalPaid: 2000.0,
          remainingBalance: 3130.0,
          template: InvoiceTemplate.mixed,
          currency: 'EGP',
          notes: 'شكراً لتعاملكم معنا',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // 1. Generate A4 PDF
        final a4Bytes = await InvoicePdfGenerator.generateA4Pdf(
          invoice: inv,
          isArabic: true,
        );
        expect(a4Bytes, isNotEmpty);
        expect(a4Bytes.length, greaterThan(1000));
        // Standard PDF magic header: %PDF-
        expect(String.fromCharCodes(a4Bytes.take(4)), '%PDF');

        // 2. Generate Thermal Receipt PDF (80mm)
        final thermalBytes =
            await InvoicePdfGenerator.generateThermalReceiptPdf(
              invoice: inv,
              isArabic: true,
            );
        expect(thermalBytes, isNotEmpty);
        expect(thermalBytes.length, greaterThan(1000));
        expect(String.fromCharCodes(thermalBytes.take(4)), '%PDF');
      },
    );
  });
}
