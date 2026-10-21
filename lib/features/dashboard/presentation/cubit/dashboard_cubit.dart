import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/invoices/domain/repositories/invoice_repository.dart';
import 'package:fatoura/features/parties/domain/repositories/party_repository.dart';
import 'package:fatoura/features/payments/domain/repositories/payment_repository.dart';
import 'package:fatoura/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:fatoura/features/returns/domain/entities/sales_return.dart';
import 'package:fatoura/features/returns/domain/repositories/sales_return_repository.dart';

class DailySalePoint extends Equatable {
  final DateTime date;
  final double amount;

  const DailySalePoint({required this.date, required this.amount});

  @override
  List<Object?> get props => [date, amount];
}

class DashboardData extends Equatable {
  final double totalSales; // Net sales (gross sales - total returns)
  final double grossSales;
  final double totalReturns;
  final double totalCollected;
  final double customerDebts;
  final double supplierPayables;
  final double totalPurchases;
  final List<Invoice> recentInvoices;
  final List<DailySalePoint> salesTrend;
  final String currency;

  const DashboardData({
    required this.totalSales,
    this.grossSales = 0.0,
    this.totalReturns = 0.0,
    required this.totalCollected,
    required this.customerDebts,
    required this.supplierPayables,
    required this.totalPurchases,
    required this.recentInvoices,
    required this.salesTrend,
    required this.currency,
  });

  @override
  List<Object?> get props => [
    totalSales,
    grossSales,
    totalReturns,
    totalCollected,
    customerDebts,
    supplierPayables,
    totalPurchases,
    recentInvoices,
    salesTrend,
    currency,
  ];
}

abstract class DashboardState extends Equatable {
  const DashboardState();
  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final DashboardData data;

  const DashboardLoaded(this.data);

  @override
  List<Object?> get props => [data];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}

class DashboardCubit extends Cubit<DashboardState> {
  final InvoiceRepository invoiceRepository;
  final PurchaseRepository purchaseRepository;
  final PaymentRepository paymentRepository;
  final PartyRepository partyRepository;
  final SalesReturnRepository? returnRepository;

  DashboardCubit({
    required this.invoiceRepository,
    required this.purchaseRepository,
    required this.paymentRepository,
    required this.partyRepository,
    this.returnRepository,
  }) : super(DashboardInitial());

  Future<void> loadDashboardMetrics([String defaultCurrency = 'EGP']) async {
    emit(DashboardLoading());
    try {
      // 1. Fetch issued sales invoices filtered by current currency
      final invoices = await invoiceRepository.getInvoices();
      final activeInvoices = invoices
          .where((i) => i.isIssued && i.currency == defaultCurrency)
          .toList();

      var grossSales = 0.0;
      var totalReceivables = 0.0;
      for (final inv in activeInvoices) {
        grossSales += inv.finalTotal;
        totalReceivables += inv.remainingBalance;
      }

      // 2. Fetch returns in the selected currency for consistent net metrics.
      final allReturns = returnRepository == null
          ? <SalesReturn>[]
          : await returnRepository!.getReturns();
      final currencyReturns = allReturns
          .where((ret) => ret.currency == defaultCurrency)
          .toList();
      final totalReturns = currencyReturns.fold(
        0.0,
        (sum, ret) => sum + ret.totalRefundAmount,
      );
      final netSales = (grossSales - totalReturns) > 0.0
          ? (grossSales - totalReturns)
          : 0.0;

      // 3. Fetch customer payments filtered by currency
      final payments = await paymentRepository.getPayments(
        isCustomerPayment: true,
      );
      final totalCollected = payments
          .where((p) => p.currency == defaultCurrency)
          .fold(0.0, (sum, p) => sum + p.amount);

      // 4. Fetch purchases filtered by currency
      final purchases = await purchaseRepository.getPurchases();
      final activePurchases = purchases
          .where(
            (p) =>
                p.documentStatus == DocumentStatus.issued &&
                p.currency == defaultCurrency,
          )
          .toList();
      var totalPurchases = 0.0;
      var totalPayables = 0.0;
      for (final pur in activePurchases) {
        totalPurchases += pur.finalTotal;
        totalPayables += pur.remainingPayable;
      }

      // 5. Sales Trend (Last 7 Days) for current currency
      final now = DateTime.now();
      final trendPoints = <DailySalePoint>[];
      for (int i = 6; i >= 0; i--) {
        final day = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: i));
        final nextDay = day.add(const Duration(days: 1));

        final daySales = activeInvoices
            .where(
              (inv) =>
                  inv.issueDate.isAfter(
                    day.subtract(const Duration(seconds: 1)),
                  ) &&
                  inv.issueDate.isBefore(nextDay),
            )
            .fold(0.0, (sum, inv) => sum + inv.finalTotal);
        final dayReturns = currencyReturns
            .where(
              (ret) =>
                  ret.returnDate.isAfter(
                    day.subtract(const Duration(seconds: 1)),
                  ) &&
                  ret.returnDate.isBefore(nextDay),
            )
            .fold(0.0, (sum, ret) => sum + ret.totalRefundAmount);

        trendPoints.add(
          DailySalePoint(date: day, amount: daySales - dayReturns),
        );
      }

      final recent = invoices
          .where((i) => i.currency == defaultCurrency)
          .take(5)
          .toList();

      emit(
        DashboardLoaded(
          DashboardData(
            totalSales: netSales,
            grossSales: grossSales,
            totalReturns: totalReturns,
            totalCollected: totalCollected,
            customerDebts: totalReceivables,
            supplierPayables: totalPayables,
            totalPurchases: totalPurchases,
            recentInvoices: recent,
            salesTrend: trendPoints,
            currency: defaultCurrency,
          ),
        ),
      );
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }
}
