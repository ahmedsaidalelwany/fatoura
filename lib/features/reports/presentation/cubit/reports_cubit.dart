import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/invoices/domain/repositories/invoice_repository.dart';
import 'package:fatoura/features/parties/domain/entities/party.dart';
import 'package:fatoura/features/parties/domain/repositories/party_repository.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';
import 'package:fatoura/features/payments/domain/repositories/payment_repository.dart';
import 'package:fatoura/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:fatoura/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:fatoura/features/returns/domain/entities/sales_return.dart';
import 'package:fatoura/features/returns/domain/repositories/sales_return_repository.dart';

enum ReportType {
  periodSales,
  collectionsAndDebts,
  customerDebts,
  supplierPayables,
  purchases,
  returnsAndRefunds,
  cancelledInvoices,
  customerStatement,
  supplierStatement,
}

class StatementEntry extends Equatable {
  final DateTime date;
  final String documentType; // 'Invoice', 'Payment', 'Return', 'Purchase'
  final String documentNumber;
  final double debit; // Increases what is owed
  final double credit; // Decreases what is owed
  final double runningBalance;
  final String notes;

  const StatementEntry({
    required this.date,
    required this.documentType,
    required this.documentNumber,
    required this.debit,
    required this.credit,
    required this.runningBalance,
    this.notes = '',
  });

  @override
  List<Object?> get props => [
    date,
    documentNumber,
    debit,
    credit,
    runningBalance,
  ];
}

class ReportData extends Equatable {
  final ReportType type;
  final DateTime fromDate;
  final DateTime toDate;
  final double totalGross;
  final double totalNet;
  final double totalCollected;
  final double totalRefunded;
  final List<Invoice> invoices;
  final List<PurchaseInvoice> purchases;
  final List<Payment> payments;
  final List<SalesReturn> returns;
  final List<StatementEntry> statementEntries;
  final Party? selectedParty;
  final String currency;

  const ReportData({
    required this.type,
    required this.fromDate,
    required this.toDate,
    this.totalGross = 0.0,
    this.totalNet = 0.0,
    this.totalCollected = 0.0,
    this.totalRefunded = 0.0,
    this.invoices = const [],
    this.purchases = const [],
    this.payments = const [],
    this.returns = const [],
    this.statementEntries = const [],
    this.selectedParty,
    this.currency = 'EGP',
  });

  @override
  List<Object?> get props => [
    type,
    fromDate,
    toDate,
    totalGross,
    totalNet,
    totalCollected,
    totalRefunded,
    invoices,
    purchases,
    payments,
    returns,
    statementEntries,
    selectedParty,
  ];
}

abstract class ReportsState extends Equatable {
  const ReportsState();
  @override
  List<Object?> get props => [];
}

class ReportsInitial extends ReportsState {}

class ReportsLoading extends ReportsState {}

class ReportsLoaded extends ReportsState {
  final ReportData data;

  const ReportsLoaded(this.data);

  @override
  List<Object?> get props => [data];
}

class ReportsError extends ReportsState {
  final String message;

  const ReportsError(this.message);

  @override
  List<Object?> get props => [message];
}

class ReportsCubit extends Cubit<ReportsState> {
  final InvoiceRepository invoiceRepository;
  final PurchaseRepository purchaseRepository;
  final PaymentRepository paymentRepository;
  final SalesReturnRepository returnRepository;
  final PartyRepository partyRepository;

  ReportsCubit({
    required this.invoiceRepository,
    required this.purchaseRepository,
    required this.paymentRepository,
    required this.returnRepository,
    required this.partyRepository,
  }) : super(ReportsInitial());

  Future<void> generateReport({
    required ReportType type,
    required DateTime fromDate,
    required DateTime toDate,
    String? partyId,
    String defaultCurrency = 'EGP',
  }) async {
    emit(ReportsLoading());
    try {
      final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final end = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);

      switch (type) {
        case ReportType.periodSales:
          final all = await invoiceRepository.getInvoices(
            fromDate: start,
            toDate: end,
          );
          final active = all.where((i) => i.isIssued).toList();
          final gross = active.fold(0.0, (sum, i) => sum + i.finalTotal);
          final paid = active.fold(0.0, (sum, i) => sum + i.totalPaid);

          emit(
            ReportsLoaded(
              ReportData(
                type: type,
                fromDate: start,
                toDate: end,
                totalGross: gross,
                totalNet: gross,
                totalCollected: paid,
                invoices: active,
                currency: defaultCurrency,
              ),
            ),
          );
          break;

        case ReportType.cancelledInvoices:
          final all = await invoiceRepository.getInvoices(
            documentStatus: DocumentStatus.cancelled,
            fromDate: start,
            toDate: end,
          );
          final gross = all.fold(0.0, (sum, i) => sum + i.finalTotal);

          emit(
            ReportsLoaded(
              ReportData(
                type: type,
                fromDate: start,
                toDate: end,
                totalGross: gross,
                invoices: all,
                currency: defaultCurrency,
              ),
            ),
          );
          break;

        case ReportType.purchases:
          final all = await purchaseRepository.getPurchases(
            fromDate: start,
            toDate: end,
          );
          final active = all
              .where((p) => p.documentStatus == DocumentStatus.issued)
              .toList();
          final gross = active.fold(0.0, (sum, p) => sum + p.finalTotal);
          final paid = active.fold(0.0, (sum, p) => sum + p.amountPaid);

          emit(
            ReportsLoaded(
              ReportData(
                type: type,
                fromDate: start,
                toDate: end,
                totalGross: gross,
                totalCollected: paid,
                purchases: active,
                currency: defaultCurrency,
              ),
            ),
          );
          break;

        case ReportType.returnsAndRefunds:
          final returns = await returnRepository.getReturns(
            fromDate: start,
            toDate: end,
          );
          final refunded = returns.fold(
            0.0,
            (sum, r) => sum + r.totalRefundAmount,
          );

          emit(
            ReportsLoaded(
              ReportData(
                type: type,
                fromDate: start,
                toDate: end,
                totalRefunded: refunded,
                returns: returns,
                currency: defaultCurrency,
              ),
            ),
          );
          break;

        case ReportType.customerStatement:
          if (partyId == null) {
            emit(
              const ReportsError(
                'Customer must be selected for customer statement.',
              ),
            );
            return;
          }
          final party = await partyRepository.getPartyById(partyId);
          if (party == null) {
            emit(const ReportsError('Selected customer not found.'));
            return;
          }

          final invoices = await invoiceRepository.getInvoices(
            customerId: partyId,
            documentStatus: DocumentStatus.issued,
          );
          final payments = await paymentRepository.getPayments(
            partyId: partyId,
            isCustomerPayment: true,
          );
          final returns = await returnRepository.getReturns(
            customerId: partyId,
          );

          final entries = <StatementEntry>[];
          var running = party.openingReceivable;

          // 1. Invoices (Debit)
          for (final inv in invoices) {
            running += inv.finalTotal;
            entries.add(
              StatementEntry(
                date: inv.issueDate,
                documentType: 'Sales Invoice',
                documentNumber: inv.invoiceNumber,
                debit: inv.finalTotal,
                credit: 0.0,
                runningBalance: running,
              ),
            );
          }

          // 2. Payments (Credit)
          for (final pay in payments) {
            running -= pay.amount;
            entries.add(
              StatementEntry(
                date: pay.paymentDate,
                documentType: 'Payment Received',
                documentNumber: pay.referenceNumber.isNotEmpty
                    ? pay.referenceNumber
                    : pay.id.substring(0, 8),
                debit: 0.0,
                credit: pay.amount,
                runningBalance: running,
              ),
            );
          }

          // 3. Returns (Credit)
          for (final ret in returns) {
            running -= ret.totalRefundAmount;
            entries.add(
              StatementEntry(
                date: ret.returnDate,
                documentType: 'Sales Return',
                documentNumber: ret.returnNumber,
                debit: 0.0,
                credit: ret.totalRefundAmount,
                runningBalance: running,
              ),
            );
          }

          // Sort entries by date
          entries.sort((a, b) => a.date.compareTo(b.date));

          emit(
            ReportsLoaded(
              ReportData(
                type: type,
                fromDate: start,
                toDate: end,
                totalNet: running,
                statementEntries: entries,
                selectedParty: party,
                currency: defaultCurrency,
              ),
            ),
          );
          break;

        case ReportType.supplierStatement:
          if (partyId == null) {
            emit(
              const ReportsError(
                'Supplier must be selected for supplier statement.',
              ),
            );
            return;
          }
          final party = await partyRepository.getPartyById(partyId);
          if (party == null) {
            emit(const ReportsError('Selected supplier not found.'));
            return;
          }

          final purchases = await purchaseRepository.getPurchases(
            supplierId: partyId,
            documentStatus: DocumentStatus.issued,
          );
          final payments = await paymentRepository.getPayments(
            partyId: partyId,
            isCustomerPayment: false,
          );

          final entries = <StatementEntry>[];
          var running = party.openingPayable;

          for (final pur in purchases) {
            running += pur.finalTotal;
            entries.add(
              StatementEntry(
                date: pur.issueDate,
                documentType: 'Purchase Bill',
                documentNumber: pur.purchaseNumber,
                debit: pur.finalTotal,
                credit: 0.0,
                runningBalance: running,
              ),
            );
          }

          for (final pay in payments) {
            running -= pay.amount;
            entries.add(
              StatementEntry(
                date: pay.paymentDate,
                documentType: 'Supplier Payment',
                documentNumber: pay.referenceNumber.isNotEmpty
                    ? pay.referenceNumber
                    : pay.id.substring(0, 8),
                debit: 0.0,
                credit: pay.amount,
                runningBalance: running,
              ),
            );
          }

          entries.sort((a, b) => a.date.compareTo(b.date));

          emit(
            ReportsLoaded(
              ReportData(
                type: type,
                fromDate: start,
                toDate: end,
                totalNet: running,
                statementEntries: entries,
                selectedParty: party,
                currency: defaultCurrency,
              ),
            ),
          );
          break;

        case ReportType.collectionsAndDebts:
        case ReportType.customerDebts:
        case ReportType.supplierPayables:
          final allInvoices = await invoiceRepository.getInvoices(
            documentStatus: DocumentStatus.issued,
          );
          final allPurchases = await purchaseRepository.getPurchases(
            documentStatus: DocumentStatus.issued,
          );
          final allPayments = await paymentRepository.getPayments(
            fromDate: start,
            toDate: end,
          );

          final totalDebts = allInvoices.fold(
            0.0,
            (sum, i) => sum + i.remainingBalance,
          );
          final totalPayables = allPurchases.fold(
            0.0,
            (sum, p) => sum + p.remainingPayable,
          );
          final totalColl = allPayments
              .where((p) => p.isCustomerPayment)
              .fold(0.0, (sum, p) => sum + p.amount);

          emit(
            ReportsLoaded(
              ReportData(
                type: type,
                fromDate: start,
                toDate: end,
                totalGross: totalDebts,
                totalNet: totalPayables,
                totalCollected: totalColl,
                invoices: allInvoices,
                purchases: allPurchases,
                payments: allPayments,
                currency: defaultCurrency,
              ),
            ),
          );
          break;
      }
    } catch (e) {
      emit(ReportsError(e.toString()));
    }
  }
}
