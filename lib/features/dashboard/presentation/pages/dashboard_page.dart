import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/precision/currency_formatter.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
import 'package:fatoura/core/settings/app_settings_cubit.dart';
import 'package:fatoura/core/theme/app_colors.dart';
import 'package:fatoura/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:fatoura/features/invoices/presentation/pages/create_invoice_page.dart';
import 'package:fatoura/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:fatoura/features/parties/presentation/cubit/parties_cubit.dart';
import 'package:fatoura/features/purchases/presentation/pages/create_purchase_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  StreamSubscription<AppSettingsState>? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    final settingsCubit = context.read<AppSettingsCubit>();
    context.read<DashboardCubit>().loadDashboardMetrics(
      settingsCubit.state.defaultCurrency,
    );
    _settingsSubscription = settingsCubit.stream.listen((settings) {
      if (mounted) {
        context.read<DashboardCubit>().loadDashboardMetrics(
          settings.defaultCurrency,
        );
      }
    });
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardMetrics() {
    final currency = context.read<AppSettingsCubit>().state.defaultCurrency;
    return context.read<DashboardCubit>().loadDashboardMetrics(currency);
  }

  void _showAddPartyDialog(BuildContext context, bool isCustomer) {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isCustomer ? l10n.actionAddCustomer : l10n.actionAddSupplier,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: l10n.nameLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: InputDecoration(labelText: l10n.phoneLabel),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              decoration: InputDecoration(labelText: l10n.addressLabel),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancelBtn),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                context.read<PartiesCubit>().saveParty(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  isCustomer: isCustomer,
                  isSupplier: !isCustomer,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l10n.successMsg)));
              }
            },
            child: Text(l10n.saveBtn),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navDashboard),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                _loadDashboardMetrics(),
          ),
        ],
      ),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is DashboardError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 12),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        _loadDashboardMetrics(),
                    child: Text(l10n.applyFilterBtn),
                  ),
                ],
              ),
            );
          }
          if (state is DashboardLoaded) {
            final data = state.data;

            return RefreshIndicator(
              onRefresh: () =>
                  _loadDashboardMetrics(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: ResponsiveContentContainer(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Financial Metrics Grid
                      _buildMetricsGrid(context, data),
                      const SizedBox(height: 24),

                      // Quick Action Buttons
                      Text(
                        l10n.dashboardQuickActions,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildQuickActionsRow(context),
                      const SizedBox(height: 24),

                      // Sales Trend Visual Chart
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.dashboardSalesTrend,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 160,
                                child: _buildSalesTrendChart(
                                  data.salesTrend,
                                  data.currency,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Recent Invoices Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.dashboardRecentActivity,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (data.recentInvoices.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Center(
                              child: Text(
                                l10n.dashboardNoActivity,
                                style: const TextStyle(
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Card(
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: data.recentInvoices.length,
                            separatorBuilder: (context, index) =>
                                const Divider(),
                            itemBuilder: (context, index) {
                              final invoice = data.recentInvoices[index];
                              final isDark =
                                  Theme.of(context).brightness ==
                                  Brightness.dark;
                              final dateStr = DateFormat('yyyy/MM/dd')
                                  .format(invoice.issueDate);

                              final Color statusColor;
                              final Color statusBg;
                              final String statusLabel;

                              if (invoice.isCancelled) {
                                statusColor = AppColors.errorMuted;
                                statusBg = isDark
                                    ? AppColors.errorBackgroundDark
                                    : AppColors.errorBackground;
                                statusLabel = l10n.statusCancelled;
                              } else if (invoice.remainingBalance == 0) {
                                statusColor = AppColors.successMuted;
                                statusBg = isDark
                                    ? AppColors.successBackgroundDark
                                    : AppColors.successBackground;
                                statusLabel = l10n.paymentStatusPaid;
                              } else {
                                statusColor = AppColors.warningMuted;
                                statusBg = isDark
                                    ? AppColors.warningBackgroundDark
                                    : AppColors.warningBackground;
                                statusLabel = l10n.paymentStatusPartial;
                              }

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                leading: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: invoice.isCancelled
                                        ? (isDark
                                              ? AppColors.errorBackgroundDark
                                              : AppColors.errorBackground)
                                        : (isDark
                                              ? AppColors.infoBackgroundDark
                                              : AppColors.infoBackground),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    invoice.isCancelled
                                        ? Icons.cancel_outlined
                                        : Icons.receipt_long,
                                    color: invoice.isCancelled
                                        ? AppColors.errorMuted
                                        : AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  invoice.invoiceNumber,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                  ),
                                ),
                                subtitle: Text(
                                  '${invoice.customerName.isNotEmpty ? invoice.customerName : l10n.cashCustomer} • $dateStr',
                                  style: TextStyle(
                                    fontSize: 13,
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
                                      CurrencyFormatter.format(
                                        invoice.finalTotal,
                                        currency: invoice.currency,
                                        isArabic: l10n.isArabic,
                                      ),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                        color: invoice.isCancelled
                                            ? AppColors.errorMuted
                                            : (isDark
                                                  ? AppColors.textPrimaryDark
                                                  : AppColors.textPrimaryLight),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  final cubit = context.read<DashboardCubit>();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => InvoiceDetailPage(
                                        invoiceId: invoice.id,
                                      ),
                                    ),
                                  ).then((_) {
                                    _loadDashboardMetrics();
                                  });
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, DashboardData data) {
    final l10n = AppLocalizations.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);

    int crossAxisCount = 2;
    if (isDesktop) {
      crossAxisCount = 5;
    } else if (isTablet) {
      crossAxisCount = 3;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth - (crossAxisCount - 1) * 12) / crossAxisCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                context: context,
                title: l10n.dashboardTotalSales,
                value: CurrencyFormatter.format(
                  data.totalSales,
                  currency: data.currency,
                  isArabic: l10n.isArabic,
                ),
                icon: Icons.trending_up,
                color: AppColors.primary,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                context: context,
                title: l10n.dashboardCollected,
                value: CurrencyFormatter.format(
                  data.totalCollected,
                  currency: data.currency,
                  isArabic: l10n.isArabic,
                ),
                icon: Icons.check_circle_outline,
                color: AppColors.successMuted,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                context: context,
                title: l10n.dashboardReceivables,
                value: CurrencyFormatter.format(
                  data.customerDebts,
                  currency: data.currency,
                  isArabic: l10n.isArabic,
                ),
                icon: Icons.access_time,
                color: AppColors.warningMuted,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                context: context,
                title: l10n.dashboardPayables,
                value: CurrencyFormatter.format(
                  data.supplierPayables,
                  currency: data.currency,
                  isArabic: l10n.isArabic,
                ),
                icon: Icons.outbox,
                color: AppColors.errorMuted,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                context: context,
                title: l10n.dashboardTotalPurchases,
                value: CurrencyFormatter.format(
                  data.totalPurchases,
                  currency: data.currency,
                  isArabic: l10n.isArabic,
                ),
                icon: Icons.shopping_bag_outlined,
                color: AppColors.secondary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildCupertinoActionChip(
          context: context,
          icon: Icons.add,
          label: l10n.actionNewInvoice,
          isPrimary: true,
          onPressed: () {
            final cubit = context.read<DashboardCubit>();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateInvoicePage()),
            ).then((_) {
              _loadDashboardMetrics();
            });
          },
        ),
        _buildCupertinoActionChip(
          context: context,
          icon: Icons.person_add_outlined,
          label: l10n.actionAddCustomer,
          onPressed: () => _showAddPartyDialog(context, true),
        ),
        _buildCupertinoActionChip(
          context: context,
          icon: Icons.add_shopping_cart,
          label: l10n.actionNewPurchase,
          onPressed: () {
            final cubit = context.read<DashboardCubit>();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatePurchasePage()),
            ).then((_) {
              _loadDashboardMetrics();
            });
          },
        ),
        _buildCupertinoActionChip(
          context: context,
          icon: Icons.business_outlined,
          label: l10n.actionAddSupplier,
          onPressed: () => _showAddPartyDialog(context, false),
        ),
      ],
    );
  }

  Widget _buildCupertinoActionChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isPrimary
          ? AppColors.primary
          : (isDark
                ? AppColors.darkSurfaceSubtle
                : AppColors.lightSurfaceSubtle),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isPrimary
                ? null
                : Border.all(color: Theme.of(context).dividerColor, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isPrimary
                    ? Colors.white
                    : (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isPrimary
                      ? Colors.white
                      : (isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesTrendChart(List<DailySalePoint> points, String currency) {
    if (points.isEmpty) return const SizedBox.shrink();

    final maxVal = points.fold(
      1.0,
      (max, p) => p.amount > max ? p.amount : max,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = (constraints.maxWidth / points.length) * 0.45;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: points.map((p) {
            final ratio = maxVal > 0
                ? (p.amount / maxVal).clamp(0.04, 1.0)
                : 0.04;
            final dayName = DateFormat('E').format(p.date);

            return SizedBox(
              height: constraints.maxHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 16,
                    child: Center(
                      child: Text(
                        p.amount > 0 ? p.amount.toStringAsFixed(0) : '',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: barWidth.clamp(14.0, 32.0),
                        height: ((constraints.maxHeight - 48) * ratio).clamp(
                          6.0,
                          (constraints.maxHeight - 48).clamp(
                            6.0,
                            double.infinity,
                          ),
                        ),
                        decoration: BoxDecoration(
                          color: p.amount > 0
                              ? AppColors.primary
                              : (isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightSurfaceSubtle),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 16,
                    child: Center(
                      child: Text(
                        dayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
