import 'dart:io';

import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/core/storage/sequence_manager.dart';
import 'package:fatoura/features/audit/data/repositories/audit_repository_impl.dart';
import 'package:fatoura/features/invoices/data/repositories/invoice_repository_impl.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/invoices/presentation/cubit/invoices_cubit.dart';
import 'package:fatoura/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';
import 'package:fatoura/features/payments/presentation/cubit/payments_cubit.dart';
import 'package:fatoura/features/products/data/repositories/product_repository_impl.dart';
import 'package:fatoura/features/products/domain/entities/product.dart';
import 'package:fatoura/features/returns/data/repositories/sales_return_repository_impl.dart';
import 'package:fatoura/features/returns/presentation/cubit/returns_cubit.dart';
import 'package:fatoura/features/shop_setup/data/repositories/shop_profile_repository_impl.dart';
import 'package:fatoura/features/shop_setup/domain/entities/shop_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late HiveDatabase db;
  late SequenceManager seqManager;
  late ShopProfileRepositoryImpl shopRepo;
  late InvoiceRepositoryImpl invoiceRepo;
  late PaymentRepositoryImpl paymentRepo;
  late SalesReturnRepositoryImpl returnRepo;
  late AuditRepositoryImpl auditRepo;
  late ProductRepositoryImpl productRepo;

  late InvoicesCubit invoicesCubit;
  late PaymentsCubit paymentsCubit;
  late ReturnsCubit returnsCubit;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fatoura_test_');
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
    returnRepo = SalesReturnRepositoryImpl(
      database: db,
      invoiceRepository: invoiceRepo,
    );

    // Save a shop profile with logo and signature
    await shopRepo.saveProfile(
      ShopProfile(
        id: 'test_shop',
        name: 'مؤسسة فاتورة التجريبية',
        businessType: 'تجارة عامة',
        defaultCurrency: 'EGP',
        logoPath: '/app/documents/shop_logo.png',
        signaturePath: '/app/documents/shop_signature.png',
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

    paymentsCubit = PaymentsCubit(
      paymentRepository: paymentRepo,
      invoiceRepository: invoiceRepo,
      auditRepository: auditRepo,
    );

    returnsCubit = ReturnsCubit(
      returnRepository: returnRepo,
      invoiceRepository: invoiceRepo,
      sequenceManager: seqManager,
      auditRepository: auditRepo,
    );
  });

  tearDown(() async {
    await invoicesCubit.close();
    await paymentsCubit.close();
    await returnsCubit.close();
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Invoice issuance allocates daily sequence Ftr-DD.MM.YYYY-0001 and calculates correctly', () async {
    final inv = await invoicesCubit.createInvoice(
      customerId: 'cust_1',
      customerName: 'محمد أحمد',
      rawItems: [
        (
          productId: null,
          description: 'خدمة محاسبية',
          quantity: 2.0,
          unitPrice: 150.0,
          isService: true,
        ),
      ],
      discountValue: 0.0,
      taxRate: 15.0,
    );

    expect(inv, isNotNull);
    expect(inv!.invoiceNumber, startsWith('Ftr-'));
    expect(inv.invoiceNumber, endsWith('-0001'));
    expect(inv.subtotal, 300.0);
    expect(inv.taxAmount, 45.0);
    expect(inv.finalTotal, 345.0);
    expect(inv.remainingBalance, 345.0);
    expect(inv.paymentStatus, PaymentStatus.unpaid);
    expect(inv.shopLogoPath, '/app/documents/shop_logo.png');
    expect(inv.shopSignaturePath, '/app/documents/shop_signature.png');

    // Second invoice on the same date must get -0002
    final inv2 = await invoicesCubit.createInvoice(
      customerId: 'cust_2',
      customerName: 'خالد عمر',
      rawItems: [
        (
          productId: null,
          description: 'استشارة',
          quantity: 1.0,
          unitPrice: 200.0,
          isService: true,
        ),
      ],
    );

    expect(inv2, isNotNull);
    expect(inv2!.invoiceNumber, endsWith('-0002'));
  });

  test('Walk-in customer invoice issuance without customerId succeeds and records customer name', () async {
    final inv = await invoicesCubit.createInvoice(
      customerId: null,
      customerName: 'عميل عام (نقدي)',
      rawItems: [
        (
          productId: null,
          description: 'مبيعات مباشرة',
          quantity: 1.0,
          unitPrice: 80.0,
          isService: false,
        ),
      ],
    );

    expect(inv, isNotNull);
    expect(inv!.customerId, isNull);
    expect(inv.customerName, 'عميل عام (نقدي)');
    expect(inv.finalTotal, 80.0);
  });

  test('Initial full payment on invoice creation records payment and updates balances to 0', () async {
    final inv = await invoicesCubit.createInvoice(
      customerId: 'cust_cash_sale',
      customerName: 'عميل نقدي فوري',
      rawItems: [
        (
          productId: null,
          description: 'بضاعة نقدية',
          quantity: 2.0,
          unitPrice: 100.0,
          isService: false,
        ),
      ],
      initialPaymentStatus: PaymentStatus.fullyPaid,
      initialPaidAmount: 200.0,
      initialPaymentMethod: PaymentMethod.cash,
    );

    expect(inv, isNotNull);
    expect(inv!.finalTotal, 200.0);
    expect(inv.totalPaid, 200.0);
    expect(inv.remainingBalance, 0.0);
    expect(inv.paymentStatus, PaymentStatus.fullyPaid);

    // Verify payment record in repository
    final payments = await paymentRepo.getPaymentsForInvoice(inv.id);
    expect(payments.length, 1);
    expect(payments.first.amount, 200.0);
    expect(payments.first.method, PaymentMethod.cash);
  });

  test('Initial partial payment on invoice creation records payment and sets remaining balance', () async {
    final inv = await invoicesCubit.createInvoice(
      customerId: 'cust_partial',
      customerName: 'عميل بالتقسيط',
      rawItems: [
        (
          productId: null,
          description: 'جهاز كهربائي',
          quantity: 1.0,
          unitPrice: 1000.0,
          isService: false,
        ),
      ],
      initialPaymentStatus: PaymentStatus.partiallyPaid,
      initialPaidAmount: 400.0,
      initialPaymentMethod: PaymentMethod.bank,
    );

    expect(inv, isNotNull);
    expect(inv!.finalTotal, 1000.0);
    expect(inv.totalPaid, 400.0);
    expect(inv.remainingBalance, 600.0);
    expect(inv.paymentStatus, PaymentStatus.partiallyPaid);

    // Verify payment record in repository
    final payments = await paymentRepo.getPaymentsForInvoice(inv.id);
    expect(payments.length, 1);
    expect(payments.first.amount, 400.0);
    expect(payments.first.method, PaymentMethod.bank);
  });

  test('Tangible product decrements inventory on issuance and restores stock on cancellation', () async {
    final product = Product(
      id: 'prod_physical',
      name: 'هاتف ذكي',
      defaultUnitPrice: 5000.0,
      costPrice: 4000.0,
      trackInventory: true,
      stockQuantity: 10.0,
      reorderLevel: 2.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await productRepo.saveProduct(product);

    // 1. Issue invoice with quantity 3
    final inv = await invoicesCubit.createInvoice(
      customerId: 'cust_tech',
      customerName: 'مشتري هواتف',
      rawItems: [
        (
          productId: product.id,
          description: product.name,
          quantity: 3.0,
          unitPrice: 5000.0,
          isService: false,
        ),
      ],
    );

    expect(inv, isNotNull);
    final stockAfterSale = await productRepo.getProductById(product.id);
    expect(stockAfterSale!.stockQuantity, 7.0);

    // 2. Cancel invoice - stock must be restored back to 10
    await invoicesCubit.cancelInvoice(inv!.id, 'إلغاء بناء على طلب العميل');
    final stockAfterCancel = await productRepo.getProductById(product.id);
    expect(stockAfterCancel!.stockQuantity, 10.0);
  });

  test('Service line item (isService: true) bypasses stock deduction and stock restoration', () async {
    final serviceProduct = Product(
      id: 'prod_service',
      name: 'صيانة دورية',
      defaultUnitPrice: 250.0,
      costPrice: 0.0,
      trackInventory: false,
      stockQuantity: 0.0,
      reorderLevel: 0.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await productRepo.saveProduct(serviceProduct);

    // 1. Issue invoice with service item
    final inv = await invoicesCubit.createInvoice(
      customerId: 'cust_serv',
      customerName: 'عميل صيانة',
      rawItems: [
        (
          productId: serviceProduct.id,
          description: serviceProduct.name,
          quantity: 2.0,
          unitPrice: 250.0,
          isService: true,
        ),
      ],
    );

    expect(inv, isNotNull);
    final stockAfterSale = await productRepo.getProductById(serviceProduct.id);
    expect(stockAfterSale!.stockQuantity, 0.0); // Never decremented

    // 2. Cancel invoice - stock must remain unchanged
    await invoicesCubit.cancelInvoice(inv!.id, 'إلغاء حجز الخدمة');
    final stockAfterCancel = await productRepo.getProductById(serviceProduct.id);
    expect(stockAfterCancel!.stockQuantity, 0.0); // Never incremented
  });

  test(
    'Partial payment and full payment lifecycle works and prevents overpayment',
    () async {
      final inv = await invoicesCubit.createInvoice(
        customerId: 'cust_1',
        customerName: 'محمد أحمد',
        rawItems: [
          (
            productId: null,
            description: 'بند رقم 1',
            quantity: 1.0,
            unitPrice: 500.0,
            isService: false,
          ),
        ],
      );

      expect(inv, isNotNull);
      expect(inv!.remainingBalance, 500.0);

      // 1. Partial payment of 200
      final pay1Success = await paymentsCubit.recordPayment(
        amount: 200.0,
        method: PaymentMethod.cash,
        partyId: 'cust_1',
        invoiceId: inv.id,
        invoiceNumber: inv.invoiceNumber,
      );
      expect(pay1Success, isTrue);

      final updated1 = await invoiceRepo.getInvoiceById(inv.id);
      expect(updated1!.totalPaid, 200.0);
      expect(updated1.remainingBalance, 300.0);
      expect(updated1.paymentStatus, PaymentStatus.partiallyPaid);

      // 2. Overpayment attempt: Remaining is 300, trying to pay 400 must fail!
      final overpaySuccess = await paymentsCubit.recordPayment(
        amount: 400.0,
        method: PaymentMethod.bank,
        partyId: 'cust_1',
        invoiceId: inv.id,
        invoiceNumber: inv.invoiceNumber,
      );
      expect(overpaySuccess, isFalse);

      // 3. Exact remaining payment of 300
      final pay2Success = await paymentsCubit.recordPayment(
        amount: 300.0,
        method: PaymentMethod.card,
        partyId: 'cust_1',
        invoiceId: inv.id,
        invoiceNumber: inv.invoiceNumber,
      );
      expect(pay2Success, isTrue);

      final updated2 = await invoiceRepo.getInvoiceById(inv.id);
      expect(updated2!.totalPaid, 500.0);
      expect(updated2.remainingBalance, 0.0);
      expect(updated2.paymentStatus, PaymentStatus.fullyPaid);
    },
  );

  test('Invoice cancellation preserves historical document and records mandatory reason', () async {
    final inv = await invoicesCubit.createInvoice(
      customerId: 'cust_1',
      customerName: 'محمد أحمد',
      rawItems: [
        (
          productId: null,
          description: 'سلعة مباعة',
          quantity: 1.0,
          unitPrice: 100.0,
          isService: false,
        ),
      ],
    );

    expect(inv, isNotNull);
    await invoicesCubit.cancelInvoice(inv!.id, 'خطأ في تسعير البند');

    final cancelled = await invoiceRepo.getInvoiceById(inv.id);
    expect(cancelled, isNotNull);
    expect(cancelled!.isCancelled, isTrue);
    expect(cancelled.cancellationReason, 'خطأ في تسعير البند');
    expect(
      cancelled.invoiceNumber,
      inv.invoiceNumber,
    ); // Number permanently retained!
  });

  test('Cumulative return accounting correctly deducts successive returns from remaining balance', () async {
    // Original invoice: EGP 100
    final inv = await invoicesCubit.createInvoice(
      customerId: 'cust_return_test',
      customerName: 'عميل مرتجعات',
      rawItems: [
        (
          productId: null,
          description: 'سلعة تجريبية',
          quantity: 1.0,
          unitPrice: 100.0,
          isService: false,
        ),
      ],
    );
    expect(inv, isNotNull);
    expect(inv!.finalTotal, 100.0);
    expect(inv.remainingBalance, 100.0);

    // First credit return: EGP 20
    await invoiceRepo.recordReturnCreditOnInvoice(
      invoiceId: inv.id,
      creditAmount: 20.0,
    );
    final afterReturn1 = await invoiceRepo.getInvoiceById(inv.id);
    expect(afterReturn1, isNotNull);
    expect(afterReturn1!.remainingBalance, 80.0);

    // Second credit return: EGP 30
    await invoiceRepo.recordReturnCreditOnInvoice(
      invoiceId: inv.id,
      creditAmount: 30.0,
    );
    final afterReturn2 = await invoiceRepo.getInvoiceById(inv.id);
    expect(afterReturn2, isNotNull);
    // Crucial accounting invariant: Remaining balance must be 50.0 (100 - 20 - 30), NOT (100 - 30 = 70.0)
    expect(afterReturn2!.remainingBalance, 50.0);
  });
}
