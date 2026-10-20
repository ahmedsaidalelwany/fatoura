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
                            isExpanded: true,
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
                            isExpanded: true,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      letterSpacing: -0.2,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    '${l10n.currentBalanceLabel}: ${data.totalNet.toStringAsFixed(2)} ${data.currency}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.2,
                      color: data.totalNet > 0
                          ? AppColors.warningMuted
                          : AppColors.successMuted,
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
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            subtitle: Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  entry.debit > 0
                                      ? '+${entry.debit.toStringAsFixed(2)}'
                                      : '-${entry.credit.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    letterSpacing: -0.2,
                                    color: entry.debit > 0
                                        ? AppColors.errorMuted
                                        : AppColors.successMuted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'الرصيد: ${entry.runningBalance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: -0.2,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                if (data.totalCollected > 0)
                  Text(
                    '${l10n.dashboardCollected}: ${data.totalCollected.toStringAsFixed(2)} ${data.currency}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: -0.2,
                      color: AppColors.successMuted,
                    ),
                  ),
                if (data.totalRefunded > 0)
                  Text(
                    'المسترد: ${data.totalRefunded.toStringAsFixed(2)} ${data.currency}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: -0.2,
                      color: AppColors.errorMuted,
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
                            title: Text(
                              inv.invoiceNumber,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            subtitle: Text(
                              DateFormat('yyyy/MM/dd').format(inv.issueDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            trailing: Text(
                              '${inv.finalTotal.toStringAsFixed(2)} ${inv.currency}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: -0.2,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          );
                        } else if (data.purchases.isNotEmpty) {
                          final pur = data.purchases[index];
                          return ListTile(
                            title: Text(
                              pur.purchaseNumber,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            subtitle: Text(
                              '${pur.supplierName} • ${DateFormat('yyyy/MM/dd').format(pur.issueDate)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            trailing: Text(
                              '${pur.finalTotal.toStringAsFixed(2)} ${pur.currency}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: -0.2,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          );
                        } else {
                          final ret = data.returns[index];
                          return ListTile(
                            title: Text(
                              ret.returnNumber,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            subtitle: Text(
                              '${ret.customerName} • ${DateFormat('yyyy/MM/dd').format(ret.returnDate)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            trailing: Text(
                              '${ret.totalRefundAmount.toStringAsFixed(2)} ${ret.currency}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: -0.2,
                                color: AppColors.errorMuted,
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
