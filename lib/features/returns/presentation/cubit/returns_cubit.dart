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
import 'package:fatoura/features/returns/domain/entities/sales_return.dart';
import 'package:fatoura/features/returns/domain/repositories/sales_return_repository.dart';

abstract class ReturnsState extends Equatable {
  const ReturnsState();
  @override
  List<Object?> get props => [];
}

class ReturnsInitial extends ReturnsState {}

class ReturnsLoading extends ReturnsState {}

class ReturnsLoaded extends ReturnsState {
  final List<SalesReturn> returns;

  const ReturnsLoaded(this.returns);

  @override
  List<Object?> get props => [returns];
}

class ReturnOperationSuccess extends ReturnsState {
  final String message;
  final SalesReturn? salesReturn;

  const ReturnOperationSuccess(this.message, {this.salesReturn});

  @override
  List<Object?> get props => [message, salesReturn];
}

class ReturnsError extends ReturnsState {
  final String message;

  const ReturnsError(this.message);

  @override
  List<Object?> get props => [message];
}

class ReturnsCubit extends Cubit<ReturnsState> {
  final SalesReturnRepository returnRepository;
  final InvoiceRepository invoiceRepository;
  final SequenceManager sequenceManager;
  final AuditRepository auditRepository;

  ReturnsCubit({
    required this.returnRepository,
    required this.invoiceRepository,
    required this.sequenceManager,
    required this.auditRepository,
  }) : super(ReturnsInitial());

  Future<void> loadReturns({
    String? originalInvoiceId,
    String? customerId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    emit(ReturnsLoading());
    try {
      final list = await returnRepository.getReturns(
        originalInvoiceId: originalInvoiceId,
        customerId: customerId,
        fromDate: fromDate,
        toDate: toDate,
      );
      emit(ReturnsLoaded(list));
    } catch (e) {
      emit(ReturnsError(e.toString()));
    }
  }

  Future<bool> createReturn({
    required String originalInvoiceId,
    required List<({InvoiceItem invoiceItem, double returnedQuantity})>
    itemsToReturn,
    required String returnReason,
    RefundMethod refundMethod = RefundMethod.cash,
    String notes = '',
  }) async {
    if (itemsToReturn.isEmpty) {
      emit(const ReturnsError('Must select at least one item to return.'));
      return false;
    }
    if (returnReason.trim().isEmpty) {
      emit(const ReturnsError('Return reason is required.'));
      return false;
    }

    emit(ReturnsLoading());
    try {
      final invoice = await invoiceRepository.getInvoiceById(originalInvoiceId);
      if (invoice == null) {
        emit(const ReturnsError('Original invoice not found.'));
        return false;
      }
      if (invoice.isCancelled) {
        emit(
          const ReturnsError(
            'Cannot process returns against a cancelled invoice.',
          ),
        );
        return false;
      }

      final returnItems = <SalesReturnItem>[];
      var totalRefund = 0.0;

      for (final itemReq in itemsToReturn) {
        if (itemReq.returnedQuantity <= 0) continue;

        // Verify remaining returnable quantity
        final alreadyReturned = await returnRepository
            .getReturnedQuantityForItem(itemReq.invoiceItem.id);
        final maxReturnable = itemReq.invoiceItem.quantity - alreadyReturned;

        if (itemReq.returnedQuantity > maxReturnable + 0.0001) {
          emit(
            ReturnsError(
              'Cannot return ${itemReq.returnedQuantity} of "${itemReq.invoiceItem.description}". Max returnable: $maxReturnable',
            ),
          );
          return false;
        }

        // Authoritative proportional refund calculation
        final refundMoney = FinancialCalculator.calculateReturnRefundAmount(
          returnedQuantity: Decimal.parse(itemReq.returnedQuantity.toString()),
          originalSoldQuantity: Decimal.parse(
            itemReq.invoiceItem.quantity.toString(),
          ),
          originalLineTotal: Money.fromNum(
            itemReq.invoiceItem.lineTotal,
            invoice.currency,
          ),
          originalInvoiceSubtotal: Money.fromNum(
            invoice.subtotal,
            invoice.currency,
          ),
          originalInvoiceFinalTotal: Money.fromNum(
            invoice.finalTotal,
            invoice.currency,
          ),
        );

        final itemRefund = refundMoney.toDouble();
        totalRefund += itemRefund;

        returnItems.add(
          SalesReturnItem(
            id: const Uuid().v4(),
            invoiceItemId: itemReq.invoiceItem.id,
            description: itemReq.invoiceItem.description,
            returnedQuantity: itemReq.returnedQuantity,
            unitPrice: itemReq.invoiceItem.unitPrice,
            refundAmount: itemRefund,
          ),
        );
      }

      final now = DateTime.now();
      final returnNumber = await sequenceManager.getNextReturnNumber(now);
      final returnId = const Uuid().v4();

      final salesReturn = SalesReturn(
        id: returnId,
        returnNumber: returnNumber,
        returnDate: now,
        originalInvoiceId: invoice.id,
        originalInvoiceNumber: invoice.invoiceNumber,
        customerId: invoice.customerId,
        customerName: invoice.customerName,
        items: returnItems,
        totalRefundAmount: totalRefund,
        returnReason: returnReason.trim(),
        refundMethod: refundMethod,
        notes: notes.trim(),
        currency: invoice.currency,
        createdAt: now,
        updatedAt: now,
      );

      await returnRepository.saveReturn(salesReturn);

      await auditRepository.logAction(
        AuditLog(
          id: const Uuid().v4(),
          action: 'create_return',
          documentType: 'sales_return',
          documentId: salesReturn.id,
          description:
              'Processed return ${salesReturn.returnNumber} for invoice ${invoice.invoiceNumber}. Refund: $totalRefund ${invoice.currency}',
          timestamp: now,
        ),
      );

      emit(
        ReturnOperationSuccess(
          'Return processed successfully',
          salesReturn: salesReturn,
        ),
      );
      await loadReturns();
      return true;
    } catch (e) {
      emit(ReturnsError(e.toString()));
      return false;
    }
  }
}
