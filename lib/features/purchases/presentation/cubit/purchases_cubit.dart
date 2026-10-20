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
import 'package:fatoura/features/parties/domain/repositories/party_repository.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';
import 'package:fatoura/features/payments/domain/repositories/payment_repository.dart';
import 'package:fatoura/features/products/domain/repositories/product_repository.dart';
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
  final ProductRepository? productRepository;
  final PaymentRepository? paymentRepository;
  final PartyRepository? partyRepository;

  PurchasesCubit({
    required this.purchaseRepository,
    required this.shopProfileRepository,
    required this.sequenceManager,
    required this.auditRepository,
    this.productRepository,
    this.paymentRepository,
    this.partyRepository,
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
    PaymentStatus initialPaymentStatus = PaymentStatus.unpaid,
    double initialPaidAmount = 0.0,
    PaymentMethod initialPaymentMethod = PaymentMethod.cash,
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
      final finalTotal = calcResult.finalTotal.toDouble();

      final items = <PurchaseInvoiceItem>[];
      for (int i = 0; i < rawItems.length; i++) {
        final raw = rawItems[i];
        final calc = calcResult.items[i];
        items.add(
          PurchaseInvoiceItem(
            id: const Uuid().v4(),
            productId: raw.productId,
            description: raw.description.trim(),
            quantity: calc.quantity.toDouble(),
            unitPrice: calc.unitPrice.toDouble(),
            lineTotal: calc.lineTotal.toDouble(),
          ),
        );
      }

      // Calculate payment status and amounts
      double actualPaid = 0.0;
      PaymentStatus paymentStatus = PaymentStatus.unpaid;

      if (!isDraft) {
        if (initialPaymentStatus == PaymentStatus.fullyPaid) {
          actualPaid = finalTotal;
          paymentStatus = PaymentStatus.fullyPaid;
        } else if (initialPaymentStatus == PaymentStatus.partiallyPaid) {
          actualPaid = initialPaidAmount.clamp(0.0, finalTotal);
          paymentStatus = actualPaid >= finalTotal
              ? PaymentStatus.fullyPaid
              : (actualPaid > 0
                    ? PaymentStatus.partiallyPaid
                    : PaymentStatus.unpaid);
        } else {
          actualPaid = 0.0;
          paymentStatus = PaymentStatus.unpaid;
        }
      }

      final remainingPayable = (finalTotal - actualPaid).clamp(
        0.0,
        double.infinity,
      );
      final isStockReceived = !isDraft;
      final shouldRecordRepoPayment =
          !isDraft && actualPaid > 0 && paymentRepository != null;

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
        finalTotal: finalTotal,
        amountPaid: shouldRecordRepoPayment ? 0.0 : actualPaid,
        remainingPayable: shouldRecordRepoPayment
            ? finalTotal
            : remainingPayable,
        currency: currency,
        notes: notes.trim(),
        documentStatus: isDraft ? DocumentStatus.draft : DocumentStatus.issued,
        paymentStatus: shouldRecordRepoPayment
            ? PaymentStatus.unpaid
            : paymentStatus,
        isStockReceived: isStockReceived,
        createdAt: now,
        updatedAt: now,
      );

      await purchaseRepository.savePurchase(purchase);

      // 1. Stock receipt integration: Drafts MUST NOT increase stock.
      // Confirmed receipt increases stock for catalog items and updates valuation.
      if (!isDraft && productRepository != null) {
        for (final item in rawItems) {
          if (item.productId != null && item.productId!.isNotEmpty) {
            await productRepository!.adjustStock(
              item.productId!,
              delta: item.quantity,
              reason: 'Purchase receipt: $purchaseNumber',
            );
            // Update cost price on the product
            final prod = await productRepository!.getProductById(
              item.productId!,
            );
            if (prod != null) {
              await productRepository!.saveProduct(
                prod.copyWith(costPrice: item.unitPrice, updatedAt: now),
              );
            }
          }
        }
      }

      // 2. Payment recording integration: If payment is made, log in PaymentRepository
      if (shouldRecordRepoPayment) {
        final paymentId = const Uuid().v4();
        final payment = Payment(
          id: paymentId,
          amount: actualPaid,
          currency: currency,
          paymentDate: now,
          method: initialPaymentMethod,
          partyId: supplierId,
          partyName: supplierName.trim(),
          isCustomerPayment: false, // Supplier payment!
          referenceNumber: purchaseNumber,
          notes: 'Purchase payment: $purchaseNumber',
          allocations: [
            PaymentAllocation(
              id: const Uuid().v4(),
              paymentId: paymentId,
              invoiceId: purchase.id,
              invoiceNumber: purchase.purchaseNumber,
              amount: actualPaid,
              allocatedAt: now,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        );
        await paymentRepository!.savePayment(payment);
      }

      final finalPurchase =
          await purchaseRepository.getPurchaseById(purchase.id) ?? purchase;

      await auditRepository.logAction(
        AuditLog(
          id: const Uuid().v4(),
          action: isDraft ? 'create_purchase_draft' : 'create_purchase',
          documentType: 'purchase_invoice',
          documentId: finalPurchase.id,
          description:
              'Recorded purchase ${finalPurchase.purchaseNumber} from $supplierName for ${finalPurchase.finalTotal} $currency (Stock received: $isStockReceived, Paid: ${finalPurchase.amountPaid})',
          timestamp: now,
        ),
      );

      emit(
        PurchaseOperationSuccess(
          isDraft
              ? 'Purchase draft saved'
              : 'Purchase confirmed and stock received',
          purchase: finalPurchase,
        ),
      );
      await loadPurchases();
      return finalPurchase;
    } catch (e) {
      emit(PurchasesError(e.toString()));
      return null;
    }
  }

  /// Confirms receipt of goods for an existing draft or unposted purchase.
  /// Strictly prevents duplicate stock increments (idempotent).
  Future<bool> confirmStockReceipt(String purchaseId) async {
    emit(PurchasesLoading());
    try {
      final purchase = await purchaseRepository.getPurchaseById(purchaseId);
      if (purchase == null) {
        emit(const PurchasesError('Purchase not found.'));
        return false;
      }

      // Idempotency: Prevent duplicate stock increase!
      if (purchase.isStockReceived) {
        emit(
          PurchaseOperationSuccess(
            'Stock was already confirmed and received for this purchase.',
            purchase: purchase,
          ),
        );
        await loadPurchases();
        return true;
      }

      final now = DateTime.now();
      if (productRepository != null) {
        for (final item in purchase.items) {
          if (item.productId != null && item.productId!.isNotEmpty) {
            await productRepository!.adjustStock(
              item.productId!,
              delta: item.quantity,
              reason: 'Confirmed purchase receipt: ${purchase.purchaseNumber}',
            );
            final prod = await productRepository!.getProductById(
              item.productId!,
            );
            if (prod != null) {
              await productRepository!.saveProduct(
                prod.copyWith(costPrice: item.unitPrice, updatedAt: now),
              );
            }
          }
        }
      }

      final updated = purchase.copyWith(
        isStockReceived: true,
        documentStatus: DocumentStatus.issued,
        updatedAt: now,
      );
      await purchaseRepository.savePurchase(updated);

      await auditRepository.logAction(
        AuditLog(
          id: const Uuid().v4(),
          action: 'confirm_stock_receipt',
          documentType: 'purchase_invoice',
          documentId: purchase.id,
          description:
              'Confirmed stock receipt for purchase ${purchase.purchaseNumber}',
          timestamp: now,
        ),
      );

      emit(
        PurchaseOperationSuccess(
          'Stock receipt confirmed and inventory updated',
          purchase: updated,
        ),
      );
      await loadPurchases();
      return true;
    } catch (e) {
      emit(PurchasesError(e.toString()));
      return false;
    }
  }

  /// Processes a return of goods to the supplier.
  /// Strictly validates available stock before decrementing!
  Future<bool> recordPurchaseReturn({
    required String purchaseId,
    required String productId,
    required double returnQuantity,
    required String reason,
    double refundAmount = 0.0,
    bool isCashRefund = false,
  }) async {
    if (returnQuantity <= 0) {
      emit(const PurchasesError('Return quantity must be greater than zero.'));
      return false;
    }

    emit(PurchasesLoading());
    try {
      final purchase = await purchaseRepository.getPurchaseById(purchaseId);
      if (purchase == null) {
        emit(const PurchasesError('Purchase not found.'));
        return false;
      }

      // Validate available sellable stock
      if (productRepository != null) {
        final prod = await productRepository!.getProductById(productId);
        if (prod != null &&
            prod.trackInventory &&
            prod.stockQuantity < returnQuantity) {
          emit(
            PurchasesError(
              'Available stock (${prod.stockQuantity}) is insufficient to return $returnQuantity units.',
            ),
          );
          return false;
        }

        // Reduce stock
        await productRepository!.adjustStock(
          productId,
          delta: -returnQuantity,
          reason:
              'Supplier return for purchase ${purchase.purchaseNumber}: $reason',
        );
      }

      final now = DateTime.now();

      // If credit adjustment, reduce remaining payable on purchase
      if (!isCashRefund && refundAmount > 0) {
        final newRemaining = (purchase.remainingPayable - refundAmount).clamp(
          0.0,
          double.infinity,
        );
        final updatedPurchase = purchase.copyWith(
          remainingPayable: newRemaining,
          paymentStatus: newRemaining == 0.0 && purchase.amountPaid > 0
              ? PaymentStatus.fullyPaid
              : purchase.paymentStatus,
          updatedAt: now,
        );
        await purchaseRepository.savePurchase(updatedPurchase);
      }

      await auditRepository.logAction(
        AuditLog(
          id: const Uuid().v4(),
          action: 'purchase_return',
          documentType: 'purchase_invoice',
          documentId: purchase.id,
          description:
              'Processed purchase return of $returnQuantity units for ${purchase.purchaseNumber}: $reason',
          timestamp: now,
        ),
      );

      emit(
        PurchaseOperationSuccess(
          'Purchase return processed and stock adjusted',
          purchase: purchase,
        ),
      );
      await loadPurchases();
      return true;
    } catch (e) {
      emit(PurchasesError(e.toString()));
      return false;
    }
  }

  /// Records subsequent payment towards a partially paid or unpaid purchase.
  Future<bool> recordSupplierPayment({
    required String purchaseId,
    required double amount,
    required PaymentMethod method,
    String notes = '',
  }) async {
    if (amount <= 0) {
      emit(const PurchasesError('Payment amount must be greater than zero.'));
      return false;
    }

    emit(PurchasesLoading());
    try {
      final purchase = await purchaseRepository.getPurchaseById(purchaseId);
      if (purchase == null) {
        emit(const PurchasesError('Purchase not found.'));
        return false;
      }

      if (amount > purchase.remainingPayable) {
        emit(
          PurchasesError(
            'Payment amount ($amount) exceeds remaining payable (${purchase.remainingPayable}).',
          ),
        );
        return false;
      }

      final now = DateTime.now();
      if (paymentRepository != null) {
        final paymentId = const Uuid().v4();
        final payment = Payment(
          id: paymentId,
          amount: amount,
          currency: purchase.currency,
          paymentDate: now,
          method: method,
          partyId: purchase.supplierId,
          partyName: purchase.supplierName,
          isCustomerPayment: false,
          referenceNumber: purchase.purchaseNumber,
          notes: notes.isNotEmpty
              ? notes
              : 'Supplier payment: ${purchase.purchaseNumber}',
          allocations: [
            PaymentAllocation(
              id: const Uuid().v4(),
              paymentId: paymentId,
              invoiceId: purchase.id,
              invoiceNumber: purchase.purchaseNumber,
              amount: amount,
              allocatedAt: now,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        );
        await paymentRepository!.savePayment(payment);
      } else {
        await purchaseRepository.recordPaymentOnPurchase(
          purchaseId: purchaseId,
          paymentAmount: amount,
        );
      }

      final updated =
          await purchaseRepository.getPurchaseById(purchaseId) ?? purchase;
      await auditRepository.logAction(
        AuditLog(
          id: const Uuid().v4(),
          action: 'supplier_payment',
          documentType: 'purchase_invoice',
          documentId: purchase.id,
          description:
              'Recorded supplier payment of $amount ${purchase.currency} for ${purchase.purchaseNumber}',
          timestamp: now,
        ),
      );

      emit(
        PurchaseOperationSuccess(
          'Supplier payment recorded successfully',
          purchase: updated,
        ),
      );
      await loadPurchases();
      return true;
    } catch (e) {
      emit(PurchasesError(e.toString()));
      return false;
    }
  }

  /// Cancels an issued or draft purchase, reversing stock movements safely and ensuring no dependent payments exist.
  Future<bool> cancelPurchase(String purchaseId, String reason) async {
    if (reason.trim().isEmpty) {
      emit(const PurchasesError('Cancellation reason is required.'));
      return false;
    }

    emit(PurchasesLoading());
    try {
      final purchase = await purchaseRepository.getPurchaseById(purchaseId);
      if (purchase == null) {
        emit(const PurchasesError('Purchase not found.'));
        return false;
      }
      if (purchase.isCancelled) {
        emit(
          PurchaseOperationSuccess(
            'Purchase is already cancelled.',
            purchase: purchase,
          ),
        );
        return true;
      }

      // 1. Dependency check: Cannot cancel purchase with recorded payments
      if (paymentRepository != null) {
        final payments = await paymentRepository!.getPaymentsForInvoice(
          purchaseId,
        );
        if (payments.isNotEmpty || purchase.amountPaid > 0) {
          emit(
            const PurchasesError(
              'لا يمكن إلغاء فاتورة مشتريات مسجل عليها مدفوعات. يجب تسوية أو استرداد المدفوعات أولاً.',
            ),
          );
          return false;
        }
      }

      // 2. Inventory check & reversal: If stock was received, reverse stock
      if (purchase.isStockReceived && productRepository != null) {
        // First verify that sufficient stock exists to reverse
        for (final item in purchase.items) {
          if (item.productId != null && item.productId!.isNotEmpty) {
            final prod = await productRepository!.getProductById(
              item.productId!,
            );
            if (prod != null &&
                prod.trackInventory &&
                prod.stockQuantity < item.quantity) {
              emit(
                PurchasesError(
                  'المخزون الحالي (${prod.stockQuantity}) غير كافٍ لعكس استلام المشتريات (${item.quantity}). قد تكون البضاعة بيعت.',
                ),
              );
              return false;
            }
          }
        }

        // Deduct received stock
        for (final item in purchase.items) {
          if (item.productId != null && item.productId!.isNotEmpty) {
            await productRepository!.adjustStock(
              item.productId!,
              delta: -item.quantity,
              reason: 'Purchase cancelled: ${purchase.purchaseNumber}',
            );
          }
        }
      }

      // 3. Mark purchase as cancelled
      await purchaseRepository.cancelPurchase(purchaseId, reason.trim());
      final updated = await purchaseRepository.getPurchaseById(purchaseId);

      // 4. Audit log
      await auditRepository.logAction(
        AuditLog(
          id: const Uuid().v4(),
          action: 'cancel_purchase',
          documentType: 'purchase_invoice',
          documentId: purchaseId,
          description:
              'Cancelled purchase ${purchase.purchaseNumber} with reason: $reason',
          timestamp: DateTime.now(),
        ),
      );

      emit(
        PurchaseOperationSuccess(
          'تم إلغاء فاتورة المشتريات بنجاح وعكس المخزون',
          purchase: updated,
        ),
      );
      await loadPurchases();
      return true;
    } catch (e) {
      emit(PurchasesError(e.toString()));
      return false;
    }
  }
}
