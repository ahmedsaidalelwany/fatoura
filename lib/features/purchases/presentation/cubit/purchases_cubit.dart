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
import 'package:fatoura/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:fatoura/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:fatoura/features/shop_setup/domain/repositories/shop_profile_repository.dart';

abstract class PurchasesState extends Equatable {
  const PurchasesState();
  @override
  List<Object?> get props => [];
}

class PurchasesInitial extends PurchasesState {}

class PurchasesLoading extends PurchasesState {}

class PurchasesLoaded extends PurchasesState {
  final List<PurchaseInvoice> purchases;

  const PurchasesLoaded(this.purchases);

  @override
  List<Object?> get props => [purchases];
}

class PurchaseOperationSuccess extends PurchasesState {
  final String message;
  final PurchaseInvoice? purchase;

  const PurchaseOperationSuccess(this.message, {this.purchase});

  @override
  List<Object?> get props => [message, purchase];
}

class PurchasesError extends PurchasesState {
  final String message;

  const PurchasesError(this.message);

  @override
  List<Object?> get props => [message];
}

class PurchasesCubit extends Cubit<PurchasesState> {
  final PurchaseRepository purchaseRepository;
  final ShopProfileRepository shopProfileRepository;
  final SequenceManager sequenceManager;
  final AuditRepository auditRepository;

  PurchasesCubit({
    required this.purchaseRepository,
    required this.shopProfileRepository,
    required this.sequenceManager,
    required this.auditRepository,
  }) : super(PurchasesInitial());

  Future<void> loadPurchases({
    String? supplierId,
    DocumentStatus? documentStatus,
    PaymentStatus? paymentStatus,
    DateTime? fromDate,
    DateTime? toDate,
    String? query,
  }) async {
    emit(PurchasesLoading());
    try {
      final list = await purchaseRepository.getPurchases(
        supplierId: supplierId,
        documentStatus: documentStatus,
        paymentStatus: paymentStatus,
        fromDate: fromDate,
        toDate: toDate,
        query: query,
      );
      emit(PurchasesLoaded(list));
    } catch (e) {
      emit(PurchasesError(e.toString()));
    }
  }

  Future<PurchaseInvoice?> createPurchase({
    required String supplierId,
    required String supplierName,
    String supplierPhone = '',
    required List<({String description, double quantity, double unitPrice})>
    rawItems,
    DiscountType discountType = DiscountType.fixed,
    double discountValue = 0.0,
    double taxRate = 0.0,
    String notes = '',
  }) async {
    if (rawItems.isEmpty) {
      emit(const PurchasesError('Purchase must contain at least one item.'));
      return null;
    }

    emit(PurchasesLoading());
    try {
      final shopProfile = await shopProfileRepository.getProfile();
      final currency = shopProfile?.defaultCurrency ?? 'EGP';

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

      final now = DateTime.now();
      final purchaseNumber = await sequenceManager.getNextPurchaseNumber(now);
      final purchaseId = const Uuid().v4();

      final items = <PurchaseInvoiceItem>[];
      for (int i = 0; i < rawItems.length; i++) {
        final raw = rawItems[i];
        final calc = calcResult.items[i];
        items.add(
          PurchaseInvoiceItem(
            id: const Uuid().v4(),
            description: raw.description.trim(),
            quantity: calc.quantity.toDouble(),
            unitPrice: calc.unitPrice.toDouble(),
            lineTotal: calc.lineTotal.toDouble(),
          ),
        );
      }

      final purchase = PurchaseInvoice(
        id: purchaseId,
        purchaseNumber: purchaseNumber,
        supplierId: supplierId,
        supplierName: supplierName.trim(),
        supplierPhone: supplierPhone.trim(),
        issueDate: now,
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
        amountPaid: 0.0,
        remainingPayable: calcResult.finalTotal.toDouble(),
        currency: currency,
        notes: notes.trim(),
        documentStatus: DocumentStatus.issued,
        paymentStatus: PaymentStatus.unpaid,
        createdAt: now,
        updatedAt: now,
      );

      await purchaseRepository.savePurchase(purchase);

      await auditRepository.logAction(
        AuditLog(
          id: const Uuid().v4(),
          action: 'create_purchase',
          documentType: 'purchase_invoice',
          documentId: purchase.id,
          description:
              'Recorded purchase ${purchase.purchaseNumber} from $supplierName for ${purchase.finalTotal} $currency',
          timestamp: now,
        ),
      );

      emit(
        PurchaseOperationSuccess(
          'Purchase recorded successfully',
          purchase: purchase,
        ),
      );
      await loadPurchases();
      return purchase;
    } catch (e) {
      emit(PurchasesError(e.toString()));
      return null;
    }
  }
}
