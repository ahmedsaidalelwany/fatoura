import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:fatoura/features/audit/domain/entities/audit_log.dart';
import 'package:fatoura/features/audit/domain/repositories/audit_repository.dart';
import 'package:fatoura/features/invoices/domain/repositories/invoice_repository.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';
import 'package:fatoura/features/payments/domain/repositories/payment_repository.dart';

abstract class PaymentsState extends Equatable {
  const PaymentsState();
  @override
  List<Object?> get props => [];
}

class PaymentsInitial extends PaymentsState {}

class PaymentsLoading extends PaymentsState {}

class PaymentsLoaded extends PaymentsState {
  final List<Payment> payments;

  const PaymentsLoaded(this.payments);

  @override
  List<Object?> get props => [payments];
}

class PaymentOperationSuccess extends PaymentsState {
  final String message;

  const PaymentOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class PaymentsError extends PaymentsState {
  final String message;

  const PaymentsError(this.message);

  @override
  List<Object?> get props => [message];
}

class PaymentsCubit extends Cubit<PaymentsState> {
  final PaymentRepository paymentRepository;
  final InvoiceRepository invoiceRepository;
  final AuditRepository auditRepository;

  PaymentsCubit({
    required this.paymentRepository,
    required this.invoiceRepository,
    required this.auditRepository,
  }) : super(PaymentsInitial());

  Future<void> loadPayments({
    String? partyId,
    bool? isCustomerPayment,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    emit(PaymentsLoading());
    try {
      final list = await paymentRepository.getPayments(
        partyId: partyId,
        isCustomerPayment: isCustomerPayment,
        fromDate: fromDate,
        toDate: toDate,
      );
      emit(PaymentsLoaded(list));
    } catch (e) {
      emit(PaymentsError(e.toString()));
    }
  }

  Future<bool> recordPayment({
    required double amount,
    required PaymentMethod method,
    String? partyId,
    String partyName = '',
    bool isCustomerPayment = true,
    String? invoiceId,
    String invoiceNumber = '',
    String referenceNumber = '',
    String notes = '',
    String currency = 'EGP',
  }) async {
    if (amount <= 0.0) {
      emit(const PaymentsError('Payment amount must be greater than zero.'));
      return false;
    }

    emit(PaymentsLoading());
    try {
      final paymentId = const Uuid().v4();
      final now = DateTime.now();

      final allocations = <PaymentAllocation>[];
      if (invoiceId != null && invoiceId.isNotEmpty) {
        // Prevent unintended overpayment
        if (isCustomerPayment) {
          final invoice = await invoiceRepository.getInvoiceById(invoiceId);
          if (invoice == null) {
            emit(const PaymentsError('Invoice not found.'));
            return false;
          }
          if (amount > invoice.remainingBalance + 0.001) {
            emit(
              PaymentsError(
                'Payment amount ($amount $currency) exceeds remaining balance (${invoice.remainingBalance} $currency).',
              ),
            );
            return false;
          }
        }

        allocations.add(
          PaymentAllocation(
            id: const Uuid().v4(),
            paymentId: paymentId,
            invoiceId: invoiceId,
            invoiceNumber: invoiceNumber,
            amount: amount,
            allocatedAt: now,
          ),
        );
      }

      final payment = Payment(
        id: paymentId,
        amount: amount,
        currency: currency,
        paymentDate: now,
        method: method,
        partyId: partyId,
        partyName: partyName.trim(),
        isCustomerPayment: isCustomerPayment,
        referenceNumber: referenceNumber.trim(),
        notes: notes.trim(),
        allocations: allocations,
        createdAt: now,
        updatedAt: now,
      );

      await paymentRepository.savePayment(payment);

      await auditRepository.logAction(
        AuditLog(
          id: const Uuid().v4(),
          action: 'record_payment',
          documentType: 'payment',
          documentId: payment.id,
          description:
              'Recorded payment of $amount $currency via ${method.name}',
          timestamp: now,
        ),
      );

      emit(const PaymentOperationSuccess('Payment recorded successfully'));
      await loadPayments(isCustomerPayment: isCustomerPayment);
      return true;
    } catch (e) {
      emit(PaymentsError(e.toString()));
      return false;
    }
  }
}
