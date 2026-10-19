import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/precision/currency_formatter.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
import 'package:fatoura/core/theme/app_colors.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/invoices/presentation/cubit/invoices_cubit.dart';

import 'create_invoice_page.dart';
import 'invoice_detail_page.dart';

class InvoicesListPage extends StatefulWidget {
  const InvoicesListPage({super.key});

  @override
  State<InvoicesListPage> createState() => _InvoicesListPageState();
}

class _InvoicesListPageState extends State<InvoicesListPage> {
  final _searchController = TextEditingController();
  DocumentStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    context.read<InvoicesCubit>().loadInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    context.read<InvoicesCubit>().loadInvoices(
      query: _searchController.text.trim(),
      documentStatus: _selectedStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navInvoices),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.actionNewInvoice,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateInvoicePage()),
              ).then((_) => _onFilterChanged());
            },
          ),
        ],
      ),
      body: ResponsiveContentContainer(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search and Status Filter Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onFilterChanged();
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => _onFilterChanged(),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: AppDimensions.buttonHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                      width: 0.8,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DocumentStatus?>(
                      value: _selectedStatus,
                      hint: Text(
                        l10n.allLabel,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.allLabel)),
                        DropdownMenuItem(
                          value: DocumentStatus.issued,
                          child: Text(l10n.statusIssued),
                        ),
                        DropdownMenuItem(
                          value: DocumentStatus.draft,
                          child: Text(l10n.statusDraft),
                        ),
                        DropdownMenuItem(
                          value: DocumentStatus.cancelled,
                          child: Text(l10n.statusCancelled),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedStatus = val);
                        _onFilterChanged();
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Invoices List
            Expanded(
              child: BlocBuilder<InvoicesCubit, InvoicesState>(
                builder: (context, state) {
                  if (state is InvoicesLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is InvoicesError) {
                    return Center(child: Text(state.message));
                  }
                  if (state is InvoicesLoaded) {
                    final invoices = state.invoices;
                    if (invoices.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_outlined,
                              size: 56,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.noDataFound,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(l10n.actionNewInvoice),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CreateInvoicePage(),
                                  ),
                                ).then((_) => _onFilterChanged());
                              },
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: invoices.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final invoice = invoices[index];
                        final dateStr = DateFormat('yyyy/MM/dd HH:mm')
                            .format(invoice.issueDate);

                        return Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      InvoiceDetailPage(invoiceId: invoice.id),
                                ),
                              ).then((_) => _onFilterChanged());
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: invoice.isCancelled
                                          ? (isDark ? AppColors.errorBackgroundDark : AppColors.errorBackground)
                                          : invoice.remainingBalance == 0
                                          ? (isDark ? AppColors.successBackgroundDark : AppColors.successBackground)
                                          : (isDark ? AppColors.infoBackgroundDark : AppColors.infoBackground),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      invoice.isCancelled
                                          ? Icons.cancel_outlined
                                          : Icons.receipt_long,
                                      color: invoice.isCancelled
                                          ? AppColors.errorMuted
                                          : invoice.remainingBalance == 0
                                          ? AppColors.successMuted
                                          : AppColors.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              invoice.invoiceNumber,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                                letterSpacing: -0.2,
                                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                              ),
                                            ),
                                            _buildStatusBadge(context, invoice),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          invoice.customerName.isNotEmpty
                                              ? invoice.customerName
                                              : l10n.cashCustomer,
                                          style: TextStyle(
                                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          dateStr,
                                          style: TextStyle(
                                            color: isDark ? AppColors.textSecondaryDark.withOpacity(0.8) : AppColors.textSecondaryLight.withOpacity(0.8),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyFormatter.format(
                                          invoice.finalTotal,
                                          currency: invoice.currency,
                                          isArabic: l10n.isArabic,
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          letterSpacing: -0.2,
                                          color: invoice.isCancelled
                                              ? AppColors.errorMuted
                                              : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                                        ),
                                      ),
                                      if (!invoice.isCancelled &&
                                          invoice.remainingBalance > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            '${l10n.remainingBalanceLabel}: ${CurrencyFormatter.format(invoice.remainingBalance, currency: invoice.currency, isArabic: l10n.isArabic)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.warningMuted,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
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

  Widget _buildStatusBadge(BuildContext context, Invoice invoice) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String label;
    final Color color;
    final Color bg;

    if (invoice.isCancelled) {
      label = l10n.statusCancelled;
      color = AppColors.errorMuted;
      bg = isDark ? AppColors.errorBackgroundDark : AppColors.errorBackground;
    } else if (invoice.isDraft) {
      label = l10n.statusDraft;
      color = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
      bg = isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle;
    } else if (invoice.remainingBalance == 0) {
      label = l10n.paymentStatusPaid;
      color = AppColors.successMuted;
      bg = isDark ? AppColors.successBackgroundDark : AppColors.successBackground;
    } else if (invoice.totalPaid > 0) {
      label = l10n.paymentStatusPartial;
      color = AppColors.warningMuted;
      bg = isDark ? AppColors.warningBackgroundDark : AppColors.warningBackground;
    } else {
      label = l10n.paymentStatusUnpaid;
      color = AppColors.primary;
      bg = isDark ? AppColors.infoBackgroundDark : AppColors.infoBackground;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
