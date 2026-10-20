import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:fatoura/core/precision/financial_calculator.dart';
import 'package:fatoura/core/precision/money.dart';
import 'package:fatoura/core/storage/sequence_manager.dart';
import 'package:fatoura/features/audit/domain/entities/audit_log.dart';
import 'package:fatoura/features/audit/domain/repositories/audit_repository.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/invoices/domain/repositories/invoice_repository.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';
import 'package:fatoura/features/payments/domain/repositories/payment_repository.dart';
import 'package:fatoura/features/products/domain/repositories/product_repository.dart';
import 'package:fatoura/features/returns/domain/repositories/sales_return_repository.dart';
import 'package:fatoura/features/shop_setup/domain/repositories/shop_profile_repository.dart';

abstract class InvoicesState extends Equatable {
  const InvoicesState();
  @override
  List<Object?> get props => [];
}

class InvoicesInitial extends InvoicesState {}

class InvoicesLoading extends InvoicesState {}

class InvoicesLoaded extends InvoicesState {
  final List<Invoice> invoices;

  const InvoicesLoaded(this.invoices);

  @override
  List<Object?> get props => [invoices];
}

class InvoiceOperationSuccess extends InvoicesState {
  final String message;
  final Invoice? invoice;

  const InvoiceOperationSuccess(this.message, {this.invoice});

  @override
  List<Object?> get props => [message, invoice];
}

class InvoicesError extends InvoicesState {
  final String message;

  const InvoicesError(this.message);

  @override
  List<Object?> get props => [message];
}

class InvoicesCubit extends Cubit<InvoicesState> {
  final InvoiceRepository invoiceRepository;
  final ShopProfileRepository shopProfileRepository;
  final SequenceManager sequenceManager;
  final AuditRepository auditRepository;
  final ProductRepository? productRepository;
  final PaymentRepository? paymentRepository;
  final SalesReturnRepository? returnRepository;

  InvoicesCubit({
    required this.invoiceRepository,
    required this.shopProfileRepository,
    required this.sequenceManager,
    required this.auditRepository,
    this.productRepository,
    this.paymentRepository,
    this.returnRepository,
  }) : super(InvoicesInitial());

  Future<void> loadInvoices({
    String? customerId,
    DocumentStatus? documentStatus,
    PaymentStatus? paymentStatus,
    DateTime? fromDate,
    DateTime? toDate,
    String? query,
  }) async {
    emit(InvoicesLoading());
    try {
      final list = await invoiceRepository.getInvoices(
        customerId: customerId,
        documentStatus: documentStatus,
        paymentStatus: paymentStatus,
        fromDate: fromDate,
        toDate: toDate,
        query: query,
      );
      emit(InvoicesLoaded(list));
    } catch (e) {
      emit(InvoicesError(e.toString()));
    }
  }

  Future<Invoice?> createInvoice({
    String? customerId,
    String customerName = '',
    String customerPhone = '',
    String customerAddress = '',
    required List<
      ({
        String? productId,
        String description,
        double quantity,
        double unitPrice,
        bool isService,
      })
    >
    rawItems,
    DiscountType discountType = DiscountType.fixed,
    double discountValue = 0.0,
    double taxRate = 0.0,
    String notes = '',
    bool isDraft = false,
    PaymentStatus initialPaymentStatus = PaymentStatus.unpaid,
    double initialPaidAmount = 0.0,
    PaymentMethod initialPaymentMethod = PaymentMethod.cash,
    InvoiceTemplate? template,
  }) async {
    if (rawItems.isEmpty) {
      emit(const InvoicesError('Invoice must contain at least one line item.'));
      return null;
    }

    for (final item in rawItems) {
      if (item.quantity <= 0) {
        emit(const InvoicesError('يجب أن تكون كمية كل بند أكبر من الصفر.'));
        return null;
      }
      if (item.unitPrice < 0) {
        emit(const InvoicesError('لا يمكن أن يكون سعر الوحدة سالباً.'));
        return null;
      }
    }

    emit(InvoicesLoading());
    try {
      // Strict stock validation for physical items when not draft
      if (!isDraft && productRepository != null) {
        final cumulativeDemands = <String, double>{};
        final itemDescriptions = <String, String>{};
        for (final item in rawItems) {
          if (!item.isService &&
              item.productId != null &&
              item.productId!.isNotEmpty) {
            cumulativeDemands[item.productId!] =
                (cumulativeDemands[item.productId!] ?? 0.0) + item.quantity;
            itemDescriptions[item.productId!] = item.description;
          }
        }

        for (final entry in cumulativeDemands.entries) {
          final prodId = entry.key;
          final demandedQty = entry.value;
          final product = await productRepository!.getProductById(prodId);
          if (product != null && product.trackInventory) {
            if (product.stockQuantity < demandedQty) {
              final prodName = product.name.isNotEmpty
                  ? product.name
                  : (itemDescriptions[prodId] ?? 'المنتج');
              emit(
                InvoicesError(
                  'المخزون غير كافٍ للمنتج ($prodName). الكمية المطلوبة: $demandedQty، المتاح في المخزن: ${product.stockQuantity}.',
                ),
              );
              return null;
            }
          }
        }
      }

      final InvoiceTemplate resolvedTemplate;
      if (template != null) {
        resolvedTemplate = template;
      } else {
        if (rawItems.isNotEmpty && rawItems.every((it) => it.isService)) {
          resolvedTemplate = InvoiceTemplate.service;
        } else if (rawItems.isNotEmpty &&
            rawItems.every((it) => !it.isService)) {
          resolvedTemplate = InvoiceTemplate.product;
        } else {
          resolvedTemplate = InvoiceTemplate.mixed;
        }
      }

      final shopProfile = await shopProfileRepository.getProfile();
      final currency = shopProfile?.defaultCurrency ?? 'EGP';

      // 1. Authoritative calculation via FinancialCalculator
      final calcItems = rawItems
          .map(
            (item) => (
              quantity: Decimal.parse(item.quantity.toString()),
              unitPrice: Money.fromNum(item.unitPrice, currency),
            ),
          )
          .toList();

      final calcResult = FinancialCalculator.calculateInvoice(
        rawItems: calcItems,
        discountType: discountType,
        discountValue: Decimal.parse(discountValue.toString()),
        taxRatePercent: Decimal.parse(taxRate.toString()),
        currency: currency,
      );

      // 2. Generate unique atomic daily invoice number
      final now = DateTime.now();
      final invoiceNumber = await sequenceManager.getNextInvoiceNumber(now);
      final invoiceId = const Uuid().v4();

      // 3. Build line items with snapshots
      final items = <InvoiceItem>[];
      for (int i = 0; i < rawItems.length; i++) {
        final raw = rawItems[i];
        final calc = calcResult.items[i];
        items.add(
          InvoiceItem(
            id: const Uuid().v4(),
            productId: raw.productId,
            description: raw.description.trim(),
            quantity: calc.quantity.toDouble(),
            unitPrice: calc.unitPrice.toDouble(),
            lineTotal: calc.lineTotal.toDouble(),
            isService: raw.isService,
          ),
        );
      }

      // 4. Calculate initial payment parameters
      double initialTotalPaid = 0.0;
      PaymentStatus paymentStatus = PaymentStatus.unpaid;
      final finalTotal = calcResult.finalTotal.toDouble();

      if (!isDraft) {
        if (initialPaymentStatus == PaymentStatus.fullyPaid) {
          initialTotalPaid = finalTotal;
          paymentStatus = PaymentStatus.fullyPaid;
        } else if (initialPaymentStatus == PaymentStatus.partiallyPaid) {
          initialTotalPaid = initialPaidAmount.clamp(0.0, finalTotal);
          paymentStatus = initialTotalPaid >= finalTotal
              ? PaymentStatus.fullyPaid
              : (initialTotalPaid > 0
                    ? PaymentStatus.partiallyPaid
                    : PaymentStatus.unpaid);
        } else {
          initialTotalPaid = 0.0;
          paymentStatus = PaymentStatus.unpaid;
        }
      }

      // If paymentRepository is provided and payment is made, we record payment via repository
      final shouldRecordRepoPayment =
          !isDraft && initialTotalPaid > 0 && paymentRepository != null;

      final invoice = Invoice(
        id: invoiceId,
        invoiceNumber: invoiceNumber,
        issueDate: now,
        shopName: shopProfile?.name ?? '',
        shopPhone: shopProfile?.phone ?? '',
        shopAddress: shopProfile?.address ?? '',
        shopTaxNumber: shopProfile?.taxNumber ?? '',
        shopLogoPath: shopProfile?.logoPath ?? '',
        shopSignaturePath: shopProfile?.signaturePath ?? '',
        customerId: customerId,
        customerName: customerName.trim(),
        customerPhone: customerPhone.trim(),
        customerAddress: customerAddress.trim(),
        items: items,
        subtotal: calcResult.subtotal.toDouble(),
        discountType: discountType == DiscountType.fixed
            ? 'fixed'
            : 'percentage',
        discountInput: discountValue,
        discountAmount: calcResult.discountAmount.toDouble(),
        taxableBase: calcResult.taxableBase.toDouble(),
        taxRate: taxRate,
        taxAmount: calcResult.taxAmount.toDouble(),
        finalTotal: finalTotal,
        totalPaid: shouldRecordRepoPayment ? 0.0 : initialTotalPaid,
        remainingBalance: shouldRecordRepoPayment
            ? finalTotal
            : (finalTotal - initialTotalPaid).clamp(0.0, double.infinity),
        documentStatus: isDraft ? DocumentStatus.draft : DocumentStatus.issued,
        paymentStatus: shouldRecordRepoPayment
            ? PaymentStatus.unpaid
            : paymentStatus,
        template: resolvedTemplate,
        currency: currency,
        notes: notes.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await invoiceRepository.saveInvoice(invoice);

      // Record payment in PaymentRepository if applicable
      if (shouldRecordRepoPayment) {
        final paymentId = const Uuid().v4();
        final payment = Payment(
          id: paymentId,
          amount: initialTotalPaid,
          currency: currency,
          paymentDate: now,
          method: initialPaymentMethod,
          partyId: customerId,
          partyName: customerName.trim(),
          isCustomerPayment: true,
          referenceNumber: invoiceNumber,
          notes: 'Invoice payment: $invoiceNumber',
          allocations: [
            PaymentAllocation(
              id: const Uuid().v4(),
              paymentId: paymentId,
              invoiceId: invoice.id,
              invoiceNumber: invoice.invoiceNumber,
              amount: initialTotalPaid,
              allocatedAt: now,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        );
        await paymentRepository!.savePayment(payment);
      }

      // Deduct inventory stock for physical items if not draft
      if (!isDraft && productRepository != null) {
        for (final item in rawItems) {
          if (!item.isService &&
              item.productId != null &&
              item.productId!.isNotEmpty) {
            await productRepository!.adjustStock(
              item.productId!,
              delta: -item.quantity,
              reason: 'Invoice sale: ${invoice.invoiceNumber}',
            );
          }
        }
      }

      // Fetch latest invoice snapshot (with payment updates applied if any)
      final finalInvoice =
          await invoiceRepository.getInvoiceById(invoice.id) ?? invoice;

      // Audit log
      await auditRepository.logAction(
        AuditLog(
          id: const Uuid().v4(),
          action: isDraft ? 'create_draft' : 'issue_invoice',
          documentType: 'sales_invoice',
          documentId: finalInvoice.id,
          description:
              'Issued invoice ${finalInvoice.invoiceNumber} for amount ${finalInvoice.finalTotal} $currency (Paid: ${finalInvoice.totalPaid})',
          timestamp: now,
        ),
      );

      emit(
        InvoiceOperationSuccess(
          isDraft ? 'Draft saved' : 'Invoice issued successfully',
          invoice: finalInvoice,
        ),
      );
      await loadInvoices();
      return finalInvoice;
    } catch (e) {
      emit(InvoicesError(e.toString()));
      return null;
    }
  }

  Future<void> cancelInvoice(String invoiceId, String reason) async {
    if (reason.trim().isEmpty) {
      emit(const InvoicesError('Cancellation reason is required.'));
      return;
    }

    emit(InvoicesLoading());
    try {
      final invoice = await invoiceRepository.getInvoiceById(invoiceId);
      if (invoice == null) {
        emit(const InvoicesError('Invoice not found.'));
        return;
      }
      if (invoice.isCancelled) {
        emit(const InvoiceOperationSuccess('Invoice is already cancelled.'));
        return;
      }

      // 1. Dependency check: Cannot cancel invoice with recorded payments
      if (paymentRepository != null) {
        final payments = await paymentRepository!.getPaymentsForInvoice(
          invoiceId,
        );
        if (payments.isNotEmpty || invoice.totalPaid > 0) {
          emit(
            const InvoicesError(
              'لا يمكن إلغاء فاتورة مسجل عليها مدفوعات. يجب تسوية أو استرداد المدفوعات أولاً.',
            ),
          );
          return;
        }
      }

      // 2. Dependency check: Cannot cancel invoice with active sales returns
      if (returnRepository != null) {
        final returns = await returnRepository!.getReturns(
          originalInvoiceId: invoiceId,
        );
        if (returns.isNotEmpty ||
            invoice.paymentStatus == PaymentStatus.refunded) {
          emit(
            const InvoicesError(
              'لا يمكن إلغاء فاتورة يوجد عليها مرتجع مبيعات. يجب معالجة المرتجعات أولاً.',
            ),
          );
          return;
        }
      }

      // 3. Restore inventory stock for physical items if invoice was issued
      if (!invoice.isDraft && productRepository != null) {
        for (final item in invoice.items) {
          if (!item.isService &&
              item.productId != null &&
              item.productId!.isNotEmpty) {
            await productRepository!.adjustStock(
              item.productId!,
              delta: item.quantity,
              reason: 'Invoice cancelled: ${invoice.invoiceNumber}',
            );
          }
        }
      }

      await invoiceRepository.cancelInvoice(invoiceId, reason.trim());

      await auditRepository.logAction(
        AuditLog(
          id: const Uuid().v4(),
          action: 'cancel_invoice',
          documentType: 'sales_invoice',
          documentId: invoiceId,
          description: 'Cancelled invoice with reason: $reason',
          timestamp: DateTime.now(),
        ),
      );

      emit(const InvoiceOperationSuccess('Invoice cancelled successfully'));
      await loadInvoices();
    } catch (e) {
      emit(InvoicesError(e.toString()));
    }
  }

  Future<void> deleteDraft(String invoiceId) async {
    emit(InvoicesLoading());
    try {
      await invoiceRepository.deleteDraftInvoice(invoiceId);
      emit(const InvoiceOperationSuccess('Draft deleted'));
      await loadInvoices();
    } catch (e) {
      emit(InvoicesError(e.toString()));
    }
  }
}
