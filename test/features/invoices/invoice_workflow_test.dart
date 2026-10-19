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
    paymentRepo = PaymentRepositoryImpl(
      database: db,
      invoiceRepository: invoiceRepo,
    );
    returnRepo = SalesReturnRepositoryImpl(
      database: db,
      invoiceRepository: invoiceRepo,
    );

    // Save a shop profile
    await shopRepo.saveProfile(
      ShopProfile(
        id: 'test_shop',
        name: 'مؤسسة فاتورة التجريبية',
        businessType: 'تجارة عامة',
        defaultCurrency: 'SAR',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    invoicesCubit = InvoicesCubit(
      invoiceRepository: invoiceRepo,
      shopProfileRepository: shopRepo,
      sequenceManager: seqManager,
      auditRepository: auditRepo,
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
        ),
      ],
    );

    expect(inv2, isNotNull);
    expect(inv2!.invoiceNumber, endsWith('-0002'));
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
}
