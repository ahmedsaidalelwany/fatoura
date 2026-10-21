import 'dart:io';

import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/core/storage/sequence_manager.dart';
import 'package:fatoura/features/audit/data/repositories/audit_repository_impl.dart';
import 'package:fatoura/features/invoices/data/repositories/invoice_repository_impl.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/invoices/presentation/cubit/invoices_cubit.dart';
import 'package:fatoura/features/parties/data/repositories/party_repository_impl.dart';
import 'package:fatoura/features/parties/domain/entities/party.dart';
import 'package:fatoura/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';
import 'package:fatoura/features/payments/presentation/cubit/payments_cubit.dart';
import 'package:fatoura/features/products/data/repositories/product_repository_impl.dart';
import 'package:fatoura/features/products/domain/entities/product.dart';
import 'package:fatoura/features/returns/data/repositories/sales_return_repository_impl.dart';
import 'package:fatoura/features/returns/domain/entities/sales_return.dart';
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
      returnRepository: returnRepo,
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

  Future<Product> seedStockProduct(
    String id,
    String name,
    double price, {
    double quantity = 100,
  }) async {
    final product = Product(
      id: id,
      name: name,
      defaultUnitPrice: price,
      trackInventory: true,
      stockQuantity: quantity,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await productRepo.saveProduct(product);
    return product;
  }

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
    final product = await seedStockProduct(
      'walk_in_goods',
      'مبيعات مباشرة',
      80,
    );
    final inv = await invoicesCubit.createInvoice(
      customerId: null,
      customerName: 'عميل عام (نقدي)',
      rawItems: [
        (
          productId: product.id,
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
    final product = await seedStockProduct('paid_goods', 'بضاعة نقدية', 100);
    final inv = await invoicesCubit.createInvoice(
      customerId: 'cust_cash_sale',
      customerName: 'عميل نقدي فوري',
      rawItems: [
        (
          productId: product.id,
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
    final product = await seedStockProduct(
      'partial_goods',
      'جهاز كهربائي',
      1000,
    );
    final inv = await invoicesCubit.createInvoice(
      customerId: 'cust_partial',
      customerName: 'عميل بالتقسيط',
      rawItems: [
        (
          productId: product.id,
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

  test(
    'Failed multi-invoice payment leaves earlier invoice balances unchanged',
    () async {
      final invoice = await invoicesCubit.createInvoice(
        customerId: 'cust_atomic_payment',
        customerName: 'عميل اختبار الدفع',
        rawItems: [
          (
            productId: null,
            description: 'خدمة',
            quantity: 1.0,
            unitPrice: 100.0,
            isService: true,
          ),
        ],
      );
      final now = DateTime.now();
      final payment = Payment(
        id: 'payment_partial_failure',
        amount: 50.0,
        paymentDate: now,
        partyId: 'cust_atomic_payment',
        isCustomerPayment: true,
        allocations: [
          PaymentAllocation(
            id: 'valid_allocation',
            paymentId: 'payment_partial_failure',
            invoiceId: invoice!.id,
            invoiceNumber: invoice.invoiceNumber,
            amount: 40.0,
            allocatedAt: now,
          ),
          PaymentAllocation(
            id: 'missing_allocation',
            paymentId: 'payment_partial_failure',
            invoiceId: 'missing_invoice',
            invoiceNumber: 'missing',
            amount: 10.0,
            allocatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      await expectLater(paymentRepo.savePayment(payment), throwsArgumentError);

      final unchangedInvoice = await invoiceRepo.getInvoiceById(invoice.id);
      expect(unchangedInvoice!.totalPaid, 0.0);
      expect(unchangedInvoice.remainingBalance, 100.0);
      expect(await paymentRepo.getPaymentById(payment.id), isNull);
    },
  );

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
    final stockAfterCancel = await productRepo.getProductById(
      serviceProduct.id,
    );
    expect(stockAfterCancel!.stockQuantity, 0.0); // Never incremented
  });

  test(
    'Partial payment and full payment lifecycle works and prevents overpayment',
    () async {
      final product = await seedStockProduct(
        'lifecycle_goods',
        'بند رقم 1',
        500,
      );
      final inv = await invoicesCubit.createInvoice(
        customerId: 'cust_1',
        customerName: 'محمد أحمد',
        rawItems: [
          (
            productId: product.id,
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
    final product = await seedStockProduct('cancel_goods', 'سلعة مباعة', 100);
    final inv = await invoicesCubit.createInvoice(
      customerId: 'cust_1',
      customerName: 'محمد أحمد',
      rawItems: [
        (
          productId: product.id,
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
    final product = await seedStockProduct('return_goods', 'سلعة تجريبية', 100);
    final inv = await invoicesCubit.createInvoice(
      customerId: 'cust_return_test',
      customerName: 'عميل مرتجعات',
      rawItems: [
        (
          productId: product.id,
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

  test(
    'Cannot cancel invoice with recorded payments or active returns',
    () async {
      // 1. Create invoice with partial payment
      final paidProduct = await seedStockProduct(
        'paid_cancel_goods',
        'سلعة مدفوعة',
        200,
      );
      final paidInv = await invoicesCubit.createInvoice(
        customerId: 'cust_paid_cancel',
        customerName: 'عميل مسدد',
        rawItems: [
          (
            productId: paidProduct.id,
            description: 'سلعة مدفوعة',
            quantity: 1.0,
            unitPrice: 200.0,
            isService: false,
          ),
        ],
        initialPaymentStatus: PaymentStatus.partiallyPaid,
        initialPaidAmount: 50.0,
      );
      expect(paidInv, isNotNull);

      // Attempt to cancel -> must be rejected because payment exists
      await invoicesCubit.cancelInvoice(paidInv!.id, 'محاولة إلغاء خاطئة');
      expect(invoicesCubit.state, isA<InvoicesError>());
      final invoiceAfter = await invoiceRepo.getInvoiceById(paidInv.id);
      expect(invoiceAfter!.isCancelled, isFalse);

      // 2. Create invoice and process return, then attempt cancel
      final returnedProduct = await seedStockProduct(
        'return_cancel_goods',
        'سلعة مرتجعة',
        100,
      );
      final retInv = await invoicesCubit.createInvoice(
        customerId: 'cust_ret_cancel',
        customerName: 'عميل مرتجع',
        rawItems: [
          (
            productId: returnedProduct.id,
            description: 'سلعة مرتجعة',
            quantity: 2.0,
            unitPrice: 100.0,
            isService: false,
          ),
        ],
      );
      expect(retInv, isNotNull);

      await returnRepo.saveReturn(
        SalesReturn(
          id: 'ret_test_1',
          returnNumber: 'Ret-01.01.2026-0001',
          returnDate: DateTime.now(),
          originalInvoiceId: retInv!.id,
          originalInvoiceNumber: retInv.invoiceNumber,
          items: [
            SalesReturnItem(
              id: 'ret_item_1',
              invoiceItemId: retInv.items.first.id,
              description: 'سلعة مرتجعة',
              returnedQuantity: 0.5,
              unitPrice: 100.0,
              refundAmount: 50.0,
            ),
          ],
          totalRefundAmount: 50.0,
          returnReason: 'تالف',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Attempt to cancel -> must be rejected because sales return exists
      await invoicesCubit.cancelInvoice(
        retInv.id,
        'محاولة إلغاء مع وجود مرتجع',
      );
      expect(invoicesCubit.state, isA<InvoicesError>());
      final retInvAfter = await invoiceRepo.getInvoiceById(retInv.id);
      expect(retInvAfter!.isCancelled, isFalse);
    },
  );

  test('Unallocated on-account payment deducts customer receivable balance correctly', () async {
    final partyRepo = PartyRepositoryImpl(db);
    final customer = Party(
      id: 'cust_ledger_test',
      name: 'شركة النور',
      phone: '01012341234',
      openingReceivable: 1000.0, // Customer owes 1000 EGP opening balance
      isCustomer: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await partyRepo.saveParty(customer);

    // Initial receivable balance must be 1000 EGP
    final initialBal = await partyRepo.getCustomerReceivableBalance(
      'cust_ledger_test',
    );
    expect(initialBal, 1000.0);

    // Customer makes on-account payment of 400 EGP (no invoice allocation)
    final payment = Payment(
      id: 'pay_on_account_1',
      amount: 400.0,
      currency: 'EGP',
      paymentDate: DateTime.now(),
      method: PaymentMethod.cash,
      partyId: 'cust_ledger_test',
      partyName: 'شركة النور',
      isCustomerPayment: true,
      allocations: const [], // Unallocated on-account payment
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await paymentRepo.savePayment(payment);

    // Balance must now be 600.0 (1000 - 400), verifying fix of Defect 2!
    final updatedBal = await partyRepo.getCustomerReceivableBalance(
      'cust_ledger_test',
    );
    expect(updatedBal, 600.0);
  });

  test('SequenceManager concurrent allocations produce strictly unique sequence numbers', () async {
    final now = DateTime.now();
    final results = await Future.wait([
      seqManager.getNextInvoiceNumber(now),
      seqManager.getNextInvoiceNumber(now),
      seqManager.getNextInvoiceNumber(now),
      seqManager.getNextInvoiceNumber(now),
      seqManager.getNextInvoiceNumber(now),
    ]);

    // All 5 allocated numbers must be distinct
    final uniqueSet = results.toSet();
    expect(uniqueSet.length, 5);
    expect(results[0], contains('0001'));
    expect(results[4], contains('0005'));
  });
}
