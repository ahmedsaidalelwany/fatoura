import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
import 'package:fatoura/core/theme/app_colors.dart';
import 'package:fatoura/features/parties/domain/entities/party.dart';
import 'package:fatoura/features/parties/presentation/cubit/parties_cubit.dart';
import 'package:fatoura/features/reports/presentation/cubit/reports_cubit.dart';

class ReportsPage extends StatefulWidget {
  final ReportType? initialReportType;
  final String? initialPartyId;

  const ReportsPage({super.key, this.initialReportType, this.initialPartyId});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late ReportType _selectedReport;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  String? _selectedPartyId;

  @override
  void initState() {
    super.initState();
    _selectedReport = widget.initialReportType ?? ReportType.periodSales;
    _selectedPartyId = widget.initialPartyId;

    context.read<PartiesCubit>().loadCustomers();
    context.read<PartiesCubit>().loadSuppliers();

    _generate();
  }

  void _generate() {
    context.read<ReportsCubit>().generateReport(
      type: _selectedReport,
      fromDate: _fromDate,
      toDate: _toDate,
      partyId: _selectedPartyId,
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _generate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateRangeStr =
        '${DateFormat('yyyy/MM/dd').format(_fromDate)} - ${DateFormat('yyyy/MM/dd').format(_toDate)}';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navReports)),
      body: ResponsiveContentContainer(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Controls Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Report Type selector
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<ReportType>(
                            initialValue: _selectedReport,
                            decoration: InputDecoration(
                              labelText: l10n.navReports,
                              isDense: true,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: ReportType.periodSales,
                                child: Text(l10n.reportPeriodSales),
                              ),
                              DropdownMenuItem(
                                value: ReportType.purchases,
                                child: Text(l10n.reportPurchases),
                              ),
                              DropdownMenuItem(
                                value: ReportType.collectionsAndDebts,
                                child: Text(l10n.reportCollections),
                              ),
                              DropdownMenuItem(
                                value: ReportType.returnsAndRefunds,
                                child: Text(l10n.reportReturns),
                              ),
                              DropdownMenuItem(
                                value: ReportType.cancelledInvoices,
                                child: Text(l10n.reportCancelled),
                              ),
                              DropdownMenuItem(
                                value: ReportType.customerStatement,
                                child: Text('${l10n.statementTitle} (عميل)'),
                              ),
                              DropdownMenuItem(
                                value: ReportType.supplierStatement,
                                child: Text('${l10n.statementTitle} (مورد)'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedReport = val);
                                _generate();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Date picker button
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.date_range, size: 16),
                            label: Text(
                              dateRangeStr,
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: _pickDateRange,
                          ),
                        ),
                      ],
                    ),
                    if (_selectedReport == ReportType.customerStatement ||
                        _selectedReport == ReportType.supplierStatement) ...[
                      const SizedBox(height: 12),
                      BlocBuilder<PartiesCubit, PartiesState>(
                        builder: (context, state) {
                          List<Party> parties = [];
                          if (_selectedReport == ReportType.customerStatement &&
                              state is CustomersLoaded) {
                            parties = state.customers;
                          } else if (_selectedReport ==
                                  ReportType.supplierStatement &&
                              state is SuppliersLoaded) {
                            parties = state.suppliers;
                          }

                          return DropdownButtonFormField<String?>(
                            initialValue: _selectedPartyId,
                            decoration: InputDecoration(
                              labelText:
                                  _selectedReport ==
                                      ReportType.customerStatement
                                  ? l10n.customerLabel
                                  : l10n.supplierLabel,
                              isDense: true,
                            ),
                            items: parties
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p.id,
                                    child: Text(p.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() => _selectedPartyId = val);
                              _generate();
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Report Output
            Expanded(
              child: BlocBuilder<ReportsCubit, ReportsState>(
                builder: (context, state) {
                  if (state is ReportsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is ReportsError) {
                    return Center(child: Text(state.message));
                  }
                  if (state is ReportsLoaded) {
                    final data = state.data;
                    return _buildReportContent(context, data);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent(BuildContext context, ReportData data) {
    final l10n = AppLocalizations.of(context);

    if (data.type == ReportType.customerStatement ||
        data.type == ReportType.supplierStatement) {
      // Ledger Statement Table
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l10n.statementTitle}: ${data.selectedParty?.name ?? ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${l10n.currentBalanceLabel}: ${data.totalNet.toStringAsFixed(2)} ${data.currency}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: data.totalNet > 0
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: data.statementEntries.isEmpty
                    ? Center(child: Text(l10n.noDataFound))
                    : ListView.separated(
                        itemCount: data.statementEntries.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final entry = data.statementEntries[index];
                          final dateStr = DateFormat('yyyy/MM/dd')
                              .format(entry.date);

                          return ListTile(
                            title: Text(
                              '${entry.documentType} #${entry.documentNumber}',
                            ),
                            subtitle: Text(dateStr),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  entry.debit > 0
                                      ? '+${entry.debit.toStringAsFixed(2)}'
                                      : '-${entry.credit.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: entry.debit > 0
                                        ? AppColors.error
                                        : AppColors.success,
                                  ),
                                ),
                                Text(
                                  'الرصيد: ${entry.runningBalance.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    }

    // Period Invoices / Purchases Report
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${l10n.dashboardTotalSales}: ${data.totalGross.toStringAsFixed(2)} ${data.currency}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (data.totalCollected > 0)
                  Text(
                    '${l10n.dashboardCollected}: ${data.totalCollected.toStringAsFixed(2)} ${data.currency}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                if (data.totalRefunded > 0)
                  Text(
                    'المسترد: ${data.totalRefunded.toStringAsFixed(2)} ${data.currency}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child:
                  (data.invoices.isEmpty &&
                      data.purchases.isEmpty &&
                      data.returns.isEmpty)
                  ? Center(child: Text(l10n.noDataFound))
                  : ListView.separated(
                      itemCount: data.invoices.isNotEmpty
                          ? data.invoices.length
                          : (data.purchases.isNotEmpty
                                ? data.purchases.length
                                : data.returns.length),
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        if (data.invoices.isNotEmpty) {
                          final inv = data.invoices[index];
                          return ListTile(
                            title: Text(inv.invoiceNumber),
                            subtitle: Text(
                              DateFormat('yyyy/MM/dd').format(inv.issueDate),
                            ),
                            trailing: Text(
                              '${inv.finalTotal.toStringAsFixed(2)} ${inv.currency}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        } else if (data.purchases.isNotEmpty) {
                          final pur = data.purchases[index];
                          return ListTile(
                            title: Text(pur.purchaseNumber),
                            subtitle: Text(
                              '${pur.supplierName} • ${DateFormat('yyyy/MM/dd').format(pur.issueDate)}',
                            ),
                            trailing: Text(
                              '${pur.finalTotal.toStringAsFixed(2)} ${pur.currency}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        } else {
                          final ret = data.returns[index];
                          return ListTile(
                            title: Text(ret.returnNumber),
                            subtitle: Text(
                              '${ret.customerName} • ${DateFormat('yyyy/MM/dd').format(ret.returnDate)}',
                            ),
                            trailing: Text(
                              '${ret.totalRefundAmount.toStringAsFixed(2)} ${ret.currency}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                          );
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
