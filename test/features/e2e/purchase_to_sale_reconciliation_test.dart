import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/invoices/data/repositories/invoice_repository_impl.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/parties/data/repositories/party_repository_impl.dart';
import 'package:fatoura/features/parties/domain/entities/party.dart';
import 'package:fatoura/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';
import 'package:fatoura/features/products/data/repositories/inventory_movement_repository_impl.dart';
import 'package:fatoura/features/products/data/repositories/product_repository_impl.dart';
import 'package:fatoura/features/products/domain/entities/inventory_movement.dart';
import 'package:fatoura/features/products/domain/entities/product.dart';
import 'package:fatoura/features/purchases/data/repositories/purchase_repository_impl.dart';
import 'package:fatoura/features/purchases/domain/entities/purchase_invoice.dart';
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
  late ProductRepositoryImpl productRepo;
  late InventoryMovementRepositoryImpl movementRepo;
  late PartyRepositoryImpl partyRepo;
  late ReportsCubit reportsCubit;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fatoura_e2e_recon_test_');
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
    partyRepo = PartyRepositoryImpl(db);

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

  group('E2E Lifecycle 1 — Acquisition to Sale to Return to Ledger Reconciliation', () {
    test('Executes complete full-cycle inventory acquisition, sales, return, and ledger reconciliation', () async {
      final now = DateTime.now();

      // 1. Setup Customer and Supplier
      final supplier = Party(
        id: 'sup-e2e-1',
        name: 'Delta Food Supplies',
        isCustomer: false,
        isSupplier: true,
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 10)),
      );
      await partyRepo.saveParty(supplier);

      final customer = Party(
        id: 'cust-e2e-1',
        name: 'Metro Hypermarket',
        isCustomer: true,
        isSupplier: false,
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 10)),
      );
      await partyRepo.saveParty(customer);

      // 2. Stage 1: Product Initialization with Opening Stock
      final initialProduct = Product(
        id: 'prod-rice-1',
        name: 'Basmati Rice 5kg',
        barcode: '6221234567890',
        stockQuantity: 10.0,
        costPrice: 200.0,
        defaultUnitPrice: 250.0,
        trackInventory: true,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 5)),
      );
      await productRepo.saveProduct(initialProduct);

      // Record opening stock movement
      await movementRepo.recordMovement(
        InventoryMovement(
          id: 'mov-init-1',
          productId: initialProduct.id,
          productName: initialProduct.name,
          quantityDelta: 10.0,
          quantityBefore: 0.0,
          quantityAfter: 10.0,
          movementType: InventoryMovementType.openingStock,
          sourceDocumentType: 'initial_count',
          timestamp: now.subtract(const Duration(days: 5)),
          createdAt: now.subtract(const Duration(days: 5)),
        ),
      );

      var fetchedProd = await productRepo.getProductById(initialProduct.id);
      expect(fetchedProd?.stockQuantity, equals(10.0));

      // 3. Stage 2: Purchase Draft (Verify stock unaffected)
      final purchaseDraft = PurchaseInvoice(
        id: 'purch-draft-1',
        purchaseNumber: 'PO-2026-001',
        supplierId: supplier.id,
        supplierName: supplier.name,
        issueDate: now.subtract(const Duration(days: 4)),
        documentStatus: DocumentStatus.draft,
        isStockReceived: false,
        subtotal: 4000.0,
        taxableBase: 4000.0,
        finalTotal: 4000.0,
        remainingPayable: 4000.0,
        currency: 'EGP',
        items: [
          PurchaseInvoiceItem(
            id: 'pitem-1',
            productId: initialProduct.id,
            description: initialProduct.name,
            quantity: 20.0,
            unitPrice: 200.0,
            lineTotal: 4000.0,
          ),
        ],
        createdAt: now.subtract(const Duration(days: 4)),
        updatedAt: now.subtract(const Duration(days: 4)),
      );
      await purchaseRepo.savePurchase(purchaseDraft);

      // Verify stock is still 10.0
      fetchedProd = await productRepo.getProductById(initialProduct.id);
      expect(fetchedProd?.stockQuantity, equals(10.0));

      // 4. Stage 3: Goods Receipt (Confirm purchase, verify stock +20 and movement logged)
      final confirmedPurchase = purchaseDraft.copyWith(
        documentStatus: DocumentStatus.issued,
        isStockReceived: true,
      );
      await purchaseRepo.savePurchase(confirmedPurchase);

      fetchedProd = await productRepo.getProductById(initialProduct.id);
      expect(
        fetchedProd?.stockQuantity,
        equals(30.0),
      ); // 10 opening + 20 purchase

      final movementsAfterPurchase = await movementRepo.getMovements(
        productId: initialProduct.id,
      );
      expect(
        movementsAfterPurchase.any(
          (m) =>
              m.movementType == InventoryMovementType.purchaseReceipt &&
              m.quantityDelta == 20.0,
        ),
        isTrue,
      );

      // 5. Stage 4: Supplier Payment
      final supplierPayment = Payment(
        id: 'pay-sup-1',
        referenceNumber: 'PAY-SUP-001',
        partyId: supplier.id,
        partyName: supplier.name,
        amount: 2500.0,
        paymentDate: now.subtract(const Duration(days: 3)),
        method: PaymentMethod.bank,
        isCustomerPayment: false,
        currency: 'EGP',
        allocations: [
          PaymentAllocation(
            id: 'alloc-sup-1',
            paymentId: 'pay-sup-1',
            invoiceId: confirmedPurchase.id,
            invoiceNumber: confirmedPurchase.purchaseNumber,
            amount: 2500.0,
            allocatedAt: now.subtract(const Duration(days: 3)),
          ),
        ],
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 3)),
      );
      await paymentRepo.savePayment(supplierPayment);

      final fetchedPurchase = await purchaseRepo.getPurchaseById(
        confirmedPurchase.id,
      );
      expect(fetchedPurchase?.amountPaid, equals(2500.0));
      expect(fetchedPurchase?.remainingPayable, equals(1500.0));

      // 6. Stage 5: Simulated Barcode Scanner Lookup
      final scannedProd = await productRepo.getProductByBarcode(
        '6221234567890',
      );
      expect(scannedProd, isNotNull);
      expect(scannedProd?.id, equals(initialProduct.id));
      expect(scannedProd?.stockQuantity, equals(30.0));

      // 7. Stage 6: Sales Invoice Issuance (Sell 15 units)
      // Subtotal = 15 * 250 = 3750, 14% Tax = 525, Total = 4275
      final salesInvoice = Invoice(
        id: 'inv-e2e-1',
        invoiceNumber: 'INV-2026-001',
        shopName: 'Fatoura Retail',
        customerId: customer.id,
        customerName: customer.name,
        issueDate: now.subtract(const Duration(days: 2)),
        documentStatus: DocumentStatus.issued,
        paymentStatus: PaymentStatus.unpaid,
        subtotal: 3750.0,
        taxableBase: 3750.0,
        taxRate: 14.0,
        taxAmount: 525.0,
        finalTotal: 4275.0,
        remainingBalance: 4275.0,
        currency: 'EGP',
        items: [
          InvoiceItem(
            id: 'sitem-1',
            productId: initialProduct.id,
            description: initialProduct.name,
            quantity: 15.0,
            unitPrice: 250.0,
            lineTotal: 3750.0,
          ),
        ],
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      );
      await invoiceRepo.saveInvoice(salesInvoice);

      // Verify stock decreased from 30 to 15
      fetchedProd = await productRepo.getProductById(initialProduct.id);
      expect(fetchedProd?.stockQuantity, equals(15.0));

      // 8. Stage 7: Customer Partial Payment (3000 EGP)
      final customerPayment = Payment(
        id: 'pay-cust-1',
        referenceNumber: 'PAY-CUST-001',
        partyId: customer.id,
        partyName: customer.name,
        amount: 3000.0,
        paymentDate: now.subtract(const Duration(days: 1)),
        method: PaymentMethod.cash,
        isCustomerPayment: true,
        currency: 'EGP',
        allocations: [
          PaymentAllocation(
            id: 'alloc-cust-1',
            paymentId: 'pay-cust-1',
            invoiceId: salesInvoice.id,
            invoiceNumber: salesInvoice.invoiceNumber,
            amount: 3000.0,
            allocatedAt: now.subtract(const Duration(days: 1)),
          ),
        ],
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      );
      await paymentRepo.savePayment(customerPayment);

      final fetchedInvoiceAfterPay = await invoiceRepo.getInvoiceById(
        salesInvoice.id,
      );
      expect(fetchedInvoiceAfterPay?.totalPaid, equals(3000.0));
      expect(fetchedInvoiceAfterPay?.remainingBalance, equals(1275.0));

      // 9. Stage 8: Sales Return (Return 3 units for credit)
      // Returned base = 3 * 250 = 750, 14% tax = 105, Total refund = 855.0
      final salesReturn = SalesReturn(
        id: 'ret-e2e-1',
        returnNumber: 'RET-2026-001',
        originalInvoiceId: salesInvoice.id,
        originalInvoiceNumber: salesInvoice.invoiceNumber,
        customerId: customer.id,
        customerName: customer.name,
        returnDate: now,
        returnReason: 'Customer ordered excess quantity',
        totalRefundAmount: 855.0,
        refundMethod: RefundMethod.credit,
        currency: 'EGP',
        items: [
          SalesReturnItem(
            id: 'ritem-1',
            invoiceItemId: 'sitem-1',
            description: initialProduct.name,
            returnedQuantity: 3.0,
            unitPrice: 250.0,
            refundAmount: 855.0,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      await returnRepo.saveReturn(salesReturn);

      // Verify stock restored from 15 to 18
      fetchedProd = await productRepo.getProductById(initialProduct.id);
      expect(fetchedProd?.stockQuantity, equals(18.0));

      // Verify invoice remaining balance reduced by 855 (from 1275 down to 420)
      final fetchedInvoiceAfterRet = await invoiceRepo.getInvoiceById(
        salesInvoice.id,
      );
      expect(fetchedInvoiceAfterRet?.remainingBalance, equals(420.0));

      // 10. Stage 9: Stock Ledger Reconciliation
      final reconciledStock = await movementRepo.getReconciledStock(
        initialProduct.id,
      );
      expect(reconciledStock, equals(18.0));
      expect(fetchedProd?.stockQuantity, equals(reconciledStock));

      // 11. Stage 10: Financial Statement Running Balance Verification
      // Customer Statement
      await reportsCubit.generateReport(
        type: ReportType.customerStatement,
        fromDate: now.subtract(const Duration(days: 30)),
        toDate: now.add(const Duration(days: 1)),
        partyId: customer.id,
      );
      final custReport = reportsCubit.state as ReportsLoaded;
      final custEntries = custReport.data.statementEntries;

      expect(custEntries.length, equals(3));
      // First entry: Invoice (+4275 debit)
      expect(custEntries[0].documentNumber, equals('INV-2026-001'));
      expect(custEntries[0].debit, equals(4275.0));
      expect(custEntries[0].credit, equals(0.0));
      expect(custEntries[0].runningBalance, equals(4275.0));

      // Second entry: Payment (-3000 credit)
      expect(custEntries[1].documentNumber, equals('PAY-CUST-001'));
      expect(custEntries[1].debit, equals(0.0));
      expect(custEntries[1].credit, equals(3000.0));
      expect(custEntries[1].runningBalance, equals(1275.0));

      // Third entry: Sales Return (-855 credit)
      expect(custEntries[2].documentNumber, equals('RET-2026-001'));
      expect(custEntries[2].debit, equals(0.0));
      expect(custEntries[2].credit, equals(855.0));
      expect(custEntries[2].runningBalance, equals(420.0));

      // Supplier Statement
      await reportsCubit.generateReport(
        type: ReportType.supplierStatement,
        fromDate: now.subtract(const Duration(days: 30)),
        toDate: now.add(const Duration(days: 1)),
        partyId: supplier.id,
      );
      final supReport = reportsCubit.state as ReportsLoaded;
      final supEntries = supReport.data.statementEntries;

      expect(supEntries.length, equals(2));
      // First entry: Purchase (+4000 payable)
      expect(supEntries[0].documentNumber, equals('PO-2026-001'));
      expect(supEntries[0].debit, equals(4000.0));
      expect(supEntries[0].credit, equals(0.0));
      expect(supEntries[0].runningBalance, equals(4000.0));

      // Second entry: Payment (-2500 payment)
      expect(supEntries[1].documentNumber, equals('PAY-SUP-001'));
      expect(supEntries[1].debit, equals(0.0));
      expect(supEntries[1].credit, equals(2500.0));
      expect(supEntries[1].runningBalance, equals(1500.0));
    });
  });

  group(
    'E2E Lifecycle 2 — Purchase Cancellation and Over-Selling Prevention',
    () {
      test('Enforces stock reversal on cancellation and strictly blocks cancellation if stock was sold', () async {
        final now = DateTime.now();

        final supplier = Party(
          id: 'sup-e2e-2',
          name: 'El-Basha Oils',
          isCustomer: false,
          isSupplier: true,
          createdAt: now,
          updatedAt: now,
        );
        await partyRepo.saveParty(supplier);

        final product = Product(
          id: 'prod-oil-1',
          name: 'Extra Virgin Olive Oil 1L',
          barcode: '6229876543210',
          stockQuantity: 0.0,
          costPrice: 150.0,
          defaultUnitPrice: 190.0,
          trackInventory: true,
          createdAt: now,
          updatedAt: now,
        );
        await productRepo.saveProduct(product);

        // Confirm purchase of 10 bottles
        final purchaseWithPayment = PurchaseInvoice(
          id: 'po-oil-paid',
          purchaseNumber: 'PO-OIL-001',
          supplierId: supplier.id,
          supplierName: supplier.name,
          issueDate: now,
          documentStatus: DocumentStatus.issued,
          isStockReceived: true,
          subtotal: 1500.0,
          taxableBase: 1500.0,
          finalTotal: 1500.0,
          remainingPayable: 1500.0,
          currency: 'EGP',
          items: [
            PurchaseInvoiceItem(
              id: 'poitem-paid',
              productId: product.id,
              description: product.name,
              quantity: 10.0,
              unitPrice: 150.0,
              lineTotal: 1500.0,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        );
        await purchaseRepo.savePurchase(purchaseWithPayment);

        var currentProd = await productRepo.getProductById(product.id);
        expect(currentProd?.stockQuantity, equals(10.0));

        // Guard 1: Cannot cancel if payments recorded
        final payment = Payment(
          id: 'pay-oil-1',
          partyId: supplier.id,
          partyName: supplier.name,
          amount: 300.0,
          paymentDate: now,
          method: PaymentMethod.cash,
          isCustomerPayment: false,
          currency: 'EGP',
          allocations: [
            PaymentAllocation(
              id: 'alloc-oil-1',
              paymentId: 'pay-oil-1',
              invoiceId: purchaseWithPayment.id,
              invoiceNumber: purchaseWithPayment.purchaseNumber,
              amount: 300.0,
              allocatedAt: now,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        );
        await paymentRepo.savePayment(payment);

        expect(
          () async => purchaseRepo.cancelPurchase(
            purchaseWithPayment.id,
            'Supplier defective goods',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('لا يمكن إلغاء فاتورة مشتريات مسجل عليها مدفوعات'),
            ),
          ),
        );

        // Guard 2: Second purchase for stock overselling check
        final purchaseUnpaid = PurchaseInvoice(
          id: 'po-oil-unpaid',
          purchaseNumber: 'PO-OIL-002',
          supplierId: supplier.id,
          supplierName: supplier.name,
          issueDate: now,
          documentStatus: DocumentStatus.issued,
          isStockReceived: true,
          subtotal: 1500.0,
          taxableBase: 1500.0,
          finalTotal: 1500.0,
          remainingPayable: 1500.0,
          currency: 'EGP',
          items: [
            PurchaseInvoiceItem(
              id: 'poitem-unpaid',
              productId: product.id,
              description: product.name,
              quantity: 10.0,
              unitPrice: 150.0,
              lineTotal: 1500.0,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        );
        await purchaseRepo.savePurchase(purchaseUnpaid);

        // Current stock is now 20 (10 from purchase 1 + 10 from purchase 2)
        currentProd = await productRepo.getProductById(product.id);
        expect(currentProd?.stockQuantity, equals(20.0));

        // Sell 18 bottles out of 20. Remaining stock = 2
        final invoice = Invoice(
          id: 'inv-oil-1',
          invoiceNumber: 'INV-OIL-001',
          shopName: 'Fatoura Retail',
          customerId: 'cust-walk-in',
          customerName: 'Walk-in Customer',
          issueDate: now,
          documentStatus: DocumentStatus.issued,
          paymentStatus: PaymentStatus.fullyPaid,
          subtotal: 3420.0,
          taxableBase: 3420.0,
          finalTotal: 3420.0,
          totalPaid: 3420.0,
          remainingBalance: 0.0,
          currency: 'EGP',
          items: [
            InvoiceItem(
              id: 'sitem-oil-1',
              productId: product.id,
              description: product.name,
              quantity: 18.0,
              unitPrice: 190.0,
              lineTotal: 3420.0,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        );
        await invoiceRepo.saveInvoice(invoice);

        currentProd = await productRepo.getProductById(product.id);
        expect(currentProd?.stockQuantity, equals(2.0));

        // Attempting to cancel 10 units purchase (purchaseUnpaid) when only 2 units in stock MUST fail!
        expect(
          () async => purchaseRepo.cancelPurchase(
            purchaseUnpaid.id,
            'Supplier cancelled order',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(
                'المخزون الحالي (2.0) غير كافٍ لعكس استلام المشتريات (10.0)',
              ),
            ),
          ),
        );

        // Stock remains safely intact at 2.0
        currentProd = await productRepo.getProductById(product.id);
        expect(currentProd?.stockQuantity, equals(2.0));

        // Return the 18 bottles via Sales Return, restoring stock to 20
        final oilReturn = SalesReturn(
          id: 'ret-oil-1',
          returnNumber: 'RET-OIL-001',
          originalInvoiceId: invoice.id,
          originalInvoiceNumber: invoice.invoiceNumber,
          customerId: invoice.customerId,
          customerName: invoice.customerName,
          returnDate: now,
          returnReason: 'Customer return',
          totalRefundAmount: 3420.0,
          refundMethod: RefundMethod.cash,
          currency: 'EGP',
          items: [
            SalesReturnItem(
              id: 'ritem-oil-1',
              invoiceItemId: 'sitem-oil-1',
              description: product.name,
              returnedQuantity: 18.0,
              unitPrice: 190.0,
              refundAmount: 3420.0,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        );
        await returnRepo.saveReturn(oilReturn);

        currentProd = await productRepo.getProductById(product.id);
        expect(currentProd?.stockQuantity, equals(20.0));

        // Now cancel purchase: stock drops from 20 down to 10!
        await purchaseRepo.cancelPurchase(
          purchaseUnpaid.id,
          'Supplier recalled stock',
        );

        currentProd = await productRepo.getProductById(product.id);
        expect(currentProd?.stockQuantity, equals(10.0));

        final cancelledPurchase = await purchaseRepo.getPurchaseById(
          purchaseUnpaid.id,
        );
        expect(
          cancelledPurchase?.documentStatus,
          equals(DocumentStatus.cancelled),
        );
        expect(
          cancelledPurchase?.cancellationReason,
          equals('Supplier recalled stock'),
        );

        // Check inventory movement
        final movements = await movementRepo.getMovements(
          productId: product.id,
        );
        expect(
          movements.any(
            (m) =>
                m.movementType == InventoryMovementType.purchaseCancellation &&
                m.quantityDelta == -10.0,
          ),
          isTrue,
        );
      });
    },
  );
}
