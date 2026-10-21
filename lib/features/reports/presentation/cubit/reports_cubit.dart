import 'package:decimal/decimal.dart';
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
  final Map<String, double> totalsByCurrency;
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
    this.totalsByCurrency = const {},
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
    totalsByCurrency,
    invoices,
    purchases,
    payments,
    returns,
    statementEntries,
    selectedParty,
    currency,
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
          final totalsByCurr = <String, Decimal>{};
          for (final inv in active) {
            final prev = totalsByCurr[inv.currency] ?? Decimal.zero;
            totalsByCurr[inv.currency] =
                prev + Decimal.parse(inv.finalTotal.toString());
          }

          final returns = await returnRepository.getReturns(
            fromDate: start,
            toDate: end,
          );
          final returnsByCurr = <String, Decimal>{};
          for (final ret in returns) {
            final previous = returnsByCurr[ret.currency] ?? Decimal.zero;
            returnsByCurr[ret.currency] =
                previous + Decimal.parse(ret.totalRefundAmount.toString());
          }

          // A missing total in the selected currency is zero. Never fall back
          // to another currency and label its amount with the selected code.
          final gross = (totalsByCurr[defaultCurrency] ?? Decimal.zero)
              .toDouble();
          final refunded = (returnsByCurr[defaultCurrency] ?? Decimal.zero)
              .toDouble();
          final paid = active
              .where((i) => i.currency == defaultCurrency)
              .fold(0.0, (sum, i) => sum + i.totalPaid);

          emit(
            ReportsLoaded(
              ReportData(
                type: type,
                fromDate: start,
                toDate: end,
                totalGross: gross,
                totalNet: gross - refunded,
                totalCollected: paid,
                totalRefunded: refunded,
                totalsByCurrency: totalsByCurr.map(
                  (k, v) => MapEntry(k, v.toDouble()),
                ),
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
          final totalsByCurr = <String, Decimal>{};
          for (final inv in all) {
            final prev = totalsByCurr[inv.currency] ?? Decimal.zero;
            totalsByCurr[inv.currency] =
                prev + Decimal.parse(inv.finalTotal.toString());
          }
          final gross = (totalsByCurr[defaultCurrency] ?? Decimal.zero)
              .toDouble();

          emit(
            ReportsLoaded(
              ReportData(
                type: type,
                fromDate: start,
                toDate: end,
                totalGross: gross,
                totalsByCurrency: totalsByCurr.map(
                  (k, v) => MapEntry(k, v.toDouble()),
                ),
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
          final totalsByCurr = <String, Decimal>{};
          for (final pur in active) {
            final prev = totalsByCurr[pur.currency] ?? Decimal.zero;
            totalsByCurr[pur.currency] =
                prev + Decimal.parse(pur.finalTotal.toString());
          }
          final gross = (totalsByCurr[defaultCurrency] ?? Decimal.zero)
              .toDouble();
          final paid = active
              .where((p) => p.currency == defaultCurrency)
              .fold(0.0, (sum, p) => sum + p.amountPaid);

          emit(
            ReportsLoaded(
              ReportData(
                type: type,
                fromDate: start,
                toDate: end,
                totalGross: gross,
                totalCollected: paid,
                totalsByCurrency: totalsByCurr.map(
                  (k, v) => MapEntry(k, v.toDouble()),
                ),
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
          final refundedByCurrency = <String, Decimal>{};
          for (final ret in returns) {
            final previous = refundedByCurrency[ret.currency] ?? Decimal.zero;
            refundedByCurrency[ret.currency] =
                previous + Decimal.parse(ret.totalRefundAmount.toString());
          }
          final refunded = (refundedByCurrency[defaultCurrency] ?? Decimal.zero)
              .toDouble();

          emit(
            ReportsLoaded(
              ReportData(
                type: type,
                fromDate: start,
                toDate: end,
                totalRefunded: refunded,
                totalsByCurrency: refundedByCurrency.map(
                  (currency, amount) => MapEntry(currency, amount.toDouble()),
                ),
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

          // Collect all transactions into raw entries
          final rawEntries =
              <
                ({
                  DateTime date,
                  String documentType,
                  String documentNumber,
                  double debit,
                  double credit,
                  String notes,
                })
              >[];

          for (final inv in invoices) {
            rawEntries.add((
              date: inv.issueDate,
              documentType: 'Sales Invoice',
              documentNumber: inv.invoiceNumber,
              debit: inv.finalTotal,
              credit: 0.0,
              notes: inv.notes,
            ));
          }

          for (final pay in payments) {
            rawEntries.add((
              date: pay.paymentDate,
              documentType: 'Payment Received',
              documentNumber: pay.referenceNumber.isNotEmpty
                  ? pay.referenceNumber
                  : (pay.id.length >= 8 ? pay.id.substring(0, 8) : pay.id),
              debit: 0.0,
              credit: pay.amount,
              notes: pay.notes,
            ));
          }

          for (final ret in returns) {
            // Financial rule: Only non-cash refunds reduce receivable debt balance.
            // Cash refunds return cash to the customer immediately without reducing customer's debt.
            final isCredit = ret.refundMethod == RefundMethod.credit;
            if (isCredit) {
              rawEntries.add((
                date: ret.returnDate,
                documentType: 'Sales Return',
                documentNumber: ret.returnNumber,
                debit: 0.0,
                credit: ret.totalRefundAmount,
                notes: ret.notes,
              ));
            }
          }

          // Sort entries chronologically ASCENDING
          rawEntries.sort((a, b) => a.date.compareTo(b.date));

          final entries = <StatementEntry>[];
          var runningDecimal = Decimal.parse(
            party.openingReceivable.toString(),
          );

          for (final item in rawEntries) {
            final debitDecimal = Decimal.parse(item.debit.toString());
            final creditDecimal = Decimal.parse(item.credit.toString());
            runningDecimal = runningDecimal + debitDecimal - creditDecimal;

            entries.add(
              StatementEntry(
                date: item.date,
                documentType: item.documentType,
                documentNumber: item.documentNumber,
                debit: item.debit,
                credit: item.credit,
                runningBalance: runningDecimal.toDouble(),
                notes: item.notes,
              ),
            );
          }

          emit(
            ReportsLoaded(
              ReportData(
                type: type,
                fromDate: start,
                toDate: end,
                totalNet: runningDecimal.toDouble(),
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

          final rawEntries =
              <
                ({
                  DateTime date,
                  String documentType,
                  String documentNumber,
                  double debit,
                  double credit,
                  String notes,
                })
              >[];

          for (final pur in purchases) {
            rawEntries.add((
              date: pur.issueDate,
              documentType: 'Purchase Bill',
              documentNumber: pur.purchaseNumber,
              debit: pur.finalTotal,
              credit: 0.0,
              notes: pur.notes,
            ));
          }

          for (final pay in payments) {
            rawEntries.add((
              date: pay.paymentDate,
              documentType: 'Supplier Payment',
              documentNumber: pay.referenceNumber.isNotEmpty
                  ? pay.referenceNumber
                  : (pay.id.length >= 8 ? pay.id.substring(0, 8) : pay.id),
              debit: 0.0,
              credit: pay.amount,
              notes: pay.notes,
            ));
          }

          // Sort chronologically ASCENDING
          rawEntries.sort((a, b) => a.date.compareTo(b.date));

          final entries = <StatementEntry>[];
          var runningDecimal = Decimal.parse(party.openingPayable.toString());

          for (final item in rawEntries) {
            final debitDecimal = Decimal.parse(item.debit.toString());
            final creditDecimal = Decimal.parse(item.credit.toString());
            runningDecimal = runningDecimal + debitDecimal - creditDecimal;

            entries.add(
              StatementEntry(
                date: item.date,
                documentType: item.documentType,
                documentNumber: item.documentNumber,
                debit: item.debit,
                credit: item.credit,
                runningBalance: runningDecimal.toDouble(),
                notes: item.notes,
              ),
            );
          }

          emit(
            ReportsLoaded(
              ReportData(
                type: type,
                fromDate: start,
                toDate: end,
                totalNet: runningDecimal.toDouble(),
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

          final debtsByCurr = <String, Decimal>{};
          for (final i in allInvoices) {
            final prev = debtsByCurr[i.currency] ?? Decimal.zero;
            debtsByCurr[i.currency] =
                prev + Decimal.parse(i.remainingBalance.toString());
          }

          final payablesByCurr = <String, Decimal>{};
          for (final p in allPurchases) {
            final prev = payablesByCurr[p.currency] ?? Decimal.zero;
            payablesByCurr[p.currency] =
                prev + Decimal.parse(p.remainingPayable.toString());
          }

          final totalDebts = (debtsByCurr[defaultCurrency] ?? Decimal.zero)
              .toDouble();
          final totalPayables =
              (payablesByCurr[defaultCurrency] ?? Decimal.zero).toDouble();
          final totalColl = allPayments
              .where(
                (p) => p.isCustomerPayment && p.currency == defaultCurrency,
              )
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
                totalsByCurrency: debtsByCurr.map(
                  (k, v) => MapEntry(k, v.toDouble()),
                ),
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
