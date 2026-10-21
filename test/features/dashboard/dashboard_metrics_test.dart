import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:fatoura/features/invoices/data/repositories/invoice_repository_impl.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/parties/data/repositories/party_repository_impl.dart';
import 'package:fatoura/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';
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
  late PartyRepositoryImpl partyRepo;
  late DashboardCubit dashboardCubit;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fatoura_dash_test_');
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
    partyRepo = PartyRepositoryImpl(db);

    dashboardCubit = DashboardCubit(
      invoiceRepository: invoiceRepo,
      purchaseRepository: purchaseRepo,
      paymentRepository: paymentRepo,
      partyRepository: partyRepo,
      returnRepository: returnRepo,
    );
  });

  tearDown(() async {
    await dashboardCubit.close();
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Dashboard Financial Metrics & Invariants (Section 11)', () {
    test('Calculates gross sales, returns, and net sales correctly in default currency', () async {
      final now = DateTime.now();

      // 1. Create an active sales invoice: 5,000 EGP
      final inv1 = Invoice(
        id: 'inv_dash_1',
        invoiceNumber: 'INV-001',
        shopName: 'Fatoura Shop',
        customerId: 'cust_1',
        customerName: 'Customer One',
        issueDate: now,
        documentStatus: DocumentStatus.issued,
        paymentStatus: PaymentStatus.unpaid,
        subtotal: 5000.0,
        taxableBase: 5000.0,
        finalTotal: 5000.0,
        totalPaid: 0.0,
        remainingBalance: 5000.0,
        currency: 'EGP',
        items: const [
          InvoiceItem(
            id: 'item_dash_1',
            description: 'Consulting Service',
            quantity: 5.0,
            unitPrice: 1000.0,
            lineTotal: 5000.0,
            isService: true,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      await invoiceRepo.saveInvoice(inv1);

      // 2. Create a second invoice in USD: $1,000 (must NOT be added to EGP totals)
      final invUsd = Invoice(
        id: 'inv_dash_usd',
        invoiceNumber: 'INV-USD-001',
        shopName: 'Fatoura Shop',
        customerId: 'cust_usd',
        customerName: 'International Client',
        issueDate: now,
        documentStatus: DocumentStatus.issued,
        paymentStatus: PaymentStatus.unpaid,
        subtotal: 1000.0,
        taxableBase: 1000.0,
        finalTotal: 1000.0,
        totalPaid: 0.0,
        remainingBalance: 1000.0,
        currency: 'USD',
        items: const [
          InvoiceItem(
            id: 'item_dash_usd',
            description: 'Remote Support',
            quantity: 1.0,
            unitPrice: 1000.0,
            lineTotal: 1000.0,
            isService: true,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      await invoiceRepo.saveInvoice(invUsd);

      // 3. Create a sales return for 1,200 EGP against inv1
      final ret1 = SalesReturn(
        id: 'ret_dash_1',
        returnNumber: 'RET-001',
        originalInvoiceId: inv1.id,
        originalInvoiceNumber: inv1.invoiceNumber,
        customerId: inv1.customerId,
        customerName: inv1.customerName,
        returnDate: now,
        returnReason: 'Damaged item',
        totalRefundAmount: 1200.0,
        refundMethod: RefundMethod.credit,
        currency: 'EGP',
        items: const [
          SalesReturnItem(
            id: 'ret_item_1',
            invoiceItemId: 'item_dash_1',
            description: 'Consulting Service',
            returnedQuantity: 1.2,
            unitPrice: 1000.0,
            refundAmount: 1200.0,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      await returnRepo.saveReturn(ret1);

      // 4. Create customer payment of 2,000 EGP
      final pay1 = Payment(
        id: 'pay_dash_1',
        partyId: 'cust_1',
        partyName: 'Customer One',
        amount: 2000.0,
        paymentDate: now,
        method: PaymentMethod.cash,
        isCustomerPayment: true,
        currency: 'EGP',
        createdAt: now,
        updatedAt: now,
      );
      await paymentRepo.savePayment(pay1);

      // 5. Create purchase bill of 3,500 EGP with remaining payable of 3,500 EGP
      final pur1 = PurchaseInvoice(
        id: 'pur_dash_1',
        purchaseNumber: 'PO-001',
        supplierId: 'sup_1',
        supplierName: 'Supplier One',
        issueDate: now,
        documentStatus: DocumentStatus.issued,
        isStockReceived: true,
        subtotal: 3500.0,
        taxableBase: 3500.0,
        finalTotal: 3500.0,
        remainingPayable: 3500.0,
        currency: 'EGP',
        items: const [],
        createdAt: now,
        updatedAt: now,
      );
      await purchaseRepo.savePurchase(pur1);

      // 6. Create a cancelled invoice of 10,000 EGP (must be ignored)
      final cancelledInv = Invoice(
        id: 'inv_dash_cancelled',
        invoiceNumber: 'INV-CANCELLED',
        shopName: 'Fatoura Shop',
        customerId: 'cust_1',
        customerName: 'Customer One',
        issueDate: now,
        documentStatus: DocumentStatus.cancelled,
        paymentStatus: PaymentStatus.unpaid,
        subtotal: 10000.0,
        taxableBase: 10000.0,
        finalTotal: 10000.0,
        totalPaid: 0.0,
        remainingBalance: 10000.0,
        currency: 'EGP',
        items: const [],
        createdAt: now,
        updatedAt: now,
      );
      await invoiceRepo.saveInvoice(cancelledInv);

      // Load EGP metrics
      await dashboardCubit.loadDashboardMetrics('EGP');
      expect(dashboardCubit.state, isA<DashboardLoaded>());
      final egpData = (dashboardCubit.state as DashboardLoaded).data;

      // Assertions for EGP
      expect(egpData.currency, equals('EGP'));
      expect(egpData.grossSales, equals(5000.0));
      expect(egpData.totalReturns, equals(1200.0));
      // Net Sales = 5000 - 1200 = 3800
      expect(egpData.totalSales, equals(3800.0));
      expect(egpData.totalCollected, equals(2000.0));
      // Remaining customer receivables on inv1: 5000 - 1200 return credit = 3800
      expect(egpData.customerDebts, equals(3800.0));
      // Purchases
      expect(egpData.totalPurchases, equals(3500.0));
      expect(egpData.supplierPayables, equals(3500.0));

      // Now verify dynamic switching to USD:
      await dashboardCubit.loadDashboardMetrics('USD');
      final usdData = (dashboardCubit.state as DashboardLoaded).data;

      expect(usdData.currency, equals('USD'));
      expect(usdData.grossSales, equals(1000.0));
      expect(usdData.totalReturns, equals(0.0));
      expect(usdData.totalSales, equals(1000.0));
      expect(usdData.customerDebts, equals(1000.0));
      expect(usdData.totalPurchases, equals(0.0));
      expect(usdData.supplierPayables, equals(0.0));
    });
  });
}
