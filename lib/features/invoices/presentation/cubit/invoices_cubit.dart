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

  InvoicesCubit({
    required this.invoiceRepository,
    required this.shopProfileRepository,
    required this.sequenceManager,
    required this.auditRepository,
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
      })
    >
    rawItems,
    DiscountType discountType = DiscountType.fixed,
    double discountValue = 0.0,
    double taxRate = 0.0,
    String notes = '',
    bool isDraft = false,
  }) async {
    if (rawItems.isEmpty) {
      emit(const InvoicesError('Invoice must contain at least one line item.'));
      return null;
    }

    emit(InvoicesLoading());
    try {
      final shopProfile = await shopProfileRepository.getProfile();
      final currency = shopProfile?.defaultCurrency ?? 'SAR';

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
          ),
        );
      }

      final invoice = Invoice(
        id: invoiceId,
        invoiceNumber: invoiceNumber,
        issueDate: now,
        shopName: shopProfile?.name ?? '',
        shopPhone: shopProfile?.phone ?? '',
        shopAddress: shopProfile?.address ?? '',
        shopTaxNumber: shopProfile?.taxNumber ?? '',
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
        finalTotal: calcResult.finalTotal.toDouble(),
        totalPaid: 0.0,
        remainingBalance: calcResult.finalTotal.toDouble(),
        documentStatus: isDraft ? DocumentStatus.draft : DocumentStatus.issued,
        paymentStatus: PaymentStatus.unpaid,
        currency: currency,
        notes: notes.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await invoiceRepository.saveInvoice(invoice);

      // Audit log
      await auditRepository.logAction(
        AuditLog(
          id: const Uuid().v4(),
          action: isDraft ? 'create_draft' : 'issue_invoice',
          documentType: 'sales_invoice',
          documentId: invoice.id,
          description:
              'Issued invoice ${invoice.invoiceNumber} for amount ${invoice.finalTotal} $currency',
          timestamp: now,
        ),
      );

      emit(
        InvoiceOperationSuccess(
          isDraft ? 'Draft saved' : 'Invoice issued successfully',
          invoice: invoice,
        ),
      );
      await loadInvoices();
      return invoice;
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
