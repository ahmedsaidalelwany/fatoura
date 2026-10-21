import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/invoices/data/repositories/invoice_repository_impl.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/parties/data/repositories/party_repository_impl.dart';
import 'package:fatoura/features/parties/domain/entities/party.dart';
import 'package:fatoura/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';
import 'package:fatoura/features/products/data/repositories/product_repository_impl.dart';
import 'package:fatoura/features/products/domain/entities/product.dart';
import 'package:fatoura/features/purchases/data/repositories/purchase_repository_impl.dart';
import 'package:fatoura/features/reports/presentation/cubit/reports_cubit.dart';
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
  late ProductRepositoryImpl productRepo;
  late ReportsCubit reportsCubit;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fatoura_reports_test_');
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
    productRepo = ProductRepositoryImpl(db);

    reportsCubit = ReportsCubit(
      invoiceRepository: invoiceRepo,
      purchaseRepository: purchaseRepo,
      paymentRepository: paymentRepo,
      returnRepository: returnRepo,
      partyRepository: partyRepo,
    );
  });

  tearDown(() async {
    await reportsCubit.close();
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Reports & Statements Financial Correctness (FAT-007 & FAT-008)', () {
    test('Customer Statement calculates running balances chronologically and distinguishes cash vs credit refunds', () async {
      final now = DateTime(2026, 1, 1);
      final customer = Party(
        id: 'cust_chronological',
        name: 'شركة النور',
        isCustomer: true,
        openingReceivable: 100.0, // Opening balance: 100.0
        createdAt: now,
        updatedAt: now,
      );
      await partyRepo.saveParty(customer);

      final product = Product(
        id: 'prod_reports_1',
        name: 'بضاعة تجريبية',
        defaultUnitPrice: 50.0,
        costPrice: 30.0,
        stockQuantity: 100.0,
        trackInventory: true,
        createdAt: now,
        updatedAt: now,
      );
      await productRepo.saveProduct(product);

      // Transaction 1: Invoice on 2026-01-05 for 200.0 (Running balance should be 100 + 200 = 300)
      final inv = Invoice(
        id: 'inv_rep_1',
        invoiceNumber: 'INV-001',
        issueDate: DateTime(2026, 1, 5),
        shopName: 'مؤسسة التجارة',
        customerId: customer.id,
        customerName: customer.name,
        currency: 'EGP',
        subtotal: 200.0,
        taxableBase: 200.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        finalTotal: 200.0,
        totalPaid: 0.0,
        remainingBalance: 200.0,
        documentStatus: DocumentStatus.issued,
        paymentStatus: PaymentStatus.unpaid,
        items: [
          InvoiceItem(
            id: 'item_rep_1',
            productId: product.id,
            description: product.name,
            quantity: 4.0,
            unitPrice: 50.0,
            lineTotal: 200.0,
          ),
        ],
        createdAt: DateTime(2026, 1, 5),
        updatedAt: DateTime(2026, 1, 5),
      );
      await invoiceRepo.saveInvoice(inv);

      // Transaction 2: Payment on 2026-01-10 for 150.0 (Running balance should be 300 - 150 = 150)
      final payment = Payment(
        id: 'pay_rep_1',
        amount: 150.0,
        currency: 'EGP',
        paymentDate: DateTime(2026, 1, 10),
        partyId: customer.id,
        partyName: customer.name,
        isCustomerPayment: true,
        allocations: [
          PaymentAllocation(
            id: 'alloc_rep_1',
            paymentId: 'pay_rep_1',
            invoiceId: inv.id,
            invoiceNumber: inv.invoiceNumber,
            amount: 150.0,
            allocatedAt: DateTime(2026, 1, 10),
          ),
        ],
        createdAt: DateTime(2026, 1, 10),
        updatedAt: DateTime(2026, 1, 10),
      );
      await paymentRepo.savePayment(payment);

      // Transaction 3: Cash refund return on 2026-01-15 for 50.0
      // Because customer received cash, customer's account debt DOES NOT DECREASE!
      final cashReturn = SalesReturn(
        id: 'ret_cash_1',
        returnNumber: 'RET-001',
        returnDate: DateTime(2026, 1, 15),
        originalInvoiceId: inv.id,
        originalInvoiceNumber: inv.invoiceNumber,
        customerId: customer.id,
        customerName: customer.name,
        refundMethod: RefundMethod.cash,
        totalRefundAmount: 50.0,
        returnReason: 'بضاعة معيبة تم استردادها نقداً',
        items: [
          SalesReturnItem(
            id: 'ret_item_cash_1',
            invoiceItemId: 'item_rep_1',
            description: product.name,
            returnedQuantity: 1.0,
            unitPrice: 50.0,
            refundAmount: 50.0,
          ),
        ],
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
      );
      await returnRepo.saveReturn(cashReturn);

      // Transaction 4: Credit return on 2026-01-20 for 50.0
      // Because it is a store credit, customer's account debt DECREASES: 150 - 50 = 100!
      final creditReturn = SalesReturn(
        id: 'ret_credit_1',
        returnNumber: 'RET-002',
        returnDate: DateTime(2026, 1, 20),
        originalInvoiceId: inv.id,
        originalInvoiceNumber: inv.invoiceNumber,
        customerId: customer.id,
        customerName: customer.name,
        refundMethod: RefundMethod.credit,
        totalRefundAmount: 50.0,
        returnReason: 'بضاعة معيبة تم إرجاعها كرصيد دائن',
        items: [
          SalesReturnItem(
            id: 'ret_item_credit_1',
            invoiceItemId: 'item_rep_1',
            description: product.name,
            returnedQuantity: 1.0,
            unitPrice: 50.0,
            refundAmount: 50.0,
          ),
        ],
        createdAt: DateTime(2026, 1, 20),
        updatedAt: DateTime(2026, 1, 20),
      );
      await returnRepo.saveReturn(creditReturn);

      // Generate customer statement
      await reportsCubit.generateReport(
        type: ReportType.customerStatement,
        fromDate: DateTime(2026, 1, 1),
        toDate: DateTime(2026, 1, 31),
        partyId: customer.id,
        defaultCurrency: 'EGP',
      );

      expect(reportsCubit.state, isA<ReportsLoaded>());
      final report = (reportsCubit.state as ReportsLoaded).data;

      // Verify that Cash return was NOT deducted from customer's receivable ledger
      // Transactions included in ledger: Invoice (+200), Payment (-150), Credit Return (-50)
      expect(report.statementEntries.length, 3);

      // Entry 1: Invoice (2026-01-05) -> running balance = 100 + 200 = 300.0
      expect(report.statementEntries[0].documentType, 'Sales Invoice');
      expect(report.statementEntries[0].debit, 200.0);
      expect(report.statementEntries[0].runningBalance, 300.0);

      // Entry 2: Payment (2026-01-10) -> running balance = 300 - 150 = 150.0
      expect(report.statementEntries[1].documentType, 'Payment Received');
      expect(report.statementEntries[1].credit, 150.0);
      expect(report.statementEntries[1].runningBalance, 150.0);

      // Entry 3: Credit Return (2026-01-20) -> running balance = 150 - 50 = 100.0
      expect(report.statementEntries[2].documentType, 'Sales Return');
      expect(report.statementEntries[2].credit, 50.0);
      expect(report.statementEntries[2].runningBalance, 100.0);

      // Final net balance must be exactly 100.0
      expect(report.totalNet, 100.0);
    });

    test('Multi-currency Period Sales separates totals by currency', () async {
      final now = DateTime(2026, 2, 1);

      // EGP Invoice: 1000 EGP
      final egpInv = Invoice(
        id: 'inv_egp',
        invoiceNumber: 'INV-EGP-001',
        issueDate: now,
        shopName: 'مؤسسة التجارة',
        currency: 'EGP',
        subtotal: 1000.0,
        taxableBase: 1000.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        finalTotal: 1000.0,
        totalPaid: 1000.0,
        remainingBalance: 0.0,
        documentStatus: DocumentStatus.issued,
        paymentStatus: PaymentStatus.fullyPaid,
        items: const [],
        createdAt: now,
        updatedAt: now,
      );
      await invoiceRepo.saveInvoice(egpInv);

      // USD Invoice: 50 USD
      final usdInv = Invoice(
        id: 'inv_usd',
        invoiceNumber: 'INV-USD-001',
        issueDate: now,
        shopName: 'مؤسسة التجارة',
        currency: 'USD',
        subtotal: 50.0,
        taxableBase: 50.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        finalTotal: 50.0,
        totalPaid: 50.0,
        remainingBalance: 0.0,
        documentStatus: DocumentStatus.issued,
        paymentStatus: PaymentStatus.fullyPaid,
        items: const [],
        createdAt: now,
        updatedAt: now,
      );
      await invoiceRepo.saveInvoice(usdInv);

      // EUR Invoice: 40 EUR
      final eurInv = Invoice(
        id: 'inv_eur',
        invoiceNumber: 'INV-EUR-001',
        issueDate: now,
        shopName: 'مؤسسة التجارة',
        currency: 'EUR',
        subtotal: 40.0,
        taxableBase: 40.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        finalTotal: 40.0,
        totalPaid: 40.0,
        remainingBalance: 0.0,
        documentStatus: DocumentStatus.issued,
        paymentStatus: PaymentStatus.fullyPaid,
        items: const [],
        createdAt: now,
        updatedAt: now,
      );
      await invoiceRepo.saveInvoice(eurInv);

      await reportsCubit.generateReport(
        type: ReportType.periodSales,
        fromDate: DateTime(2026, 2, 1),
        toDate: DateTime(2026, 2, 28),
        defaultCurrency: 'EGP',
      );

      expect(reportsCubit.state, isA<ReportsLoaded>());
      final report = (reportsCubit.state as ReportsLoaded).data;

      // Primary currency total (EGP)
      expect(report.totalGross, 1000.0);
      expect(report.currency, 'EGP');

      // Currency breakdown: must NOT sum 1000 + 50 + 40 into 1090!
      expect(report.totalsByCurrency['EGP'], 1000.0);
      expect(report.totalsByCurrency['USD'], 50.0);
      expect(report.totalsByCurrency['EUR'], 40.0);
    });
  });
}
