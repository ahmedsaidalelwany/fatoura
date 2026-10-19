import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
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
  @override
  void initState() {
    super.initState();
    context.read<DashboardCubit>().loadDashboardMetrics();
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
                context.read<DashboardCubit>().loadDashboardMetrics(),
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
                        context.read<DashboardCubit>().loadDashboardMetrics(),
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
                  context.read<DashboardCubit>().loadDashboardMetrics(),
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
                              final dateStr = DateFormat('yyyy/MM/dd')
                                  .format(invoice.issueDate);
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: invoice.isCancelled
                                        ? AppColors.errorBackground
                                        : AppColors.infoBackground,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    invoice.isCancelled
                                        ? Icons.cancel_outlined
                                        : Icons.receipt_long,
                                    color: invoice.isCancelled
                                        ? AppColors.error
                                        : AppColors.primary,
                                  ),
                                ),
                                title: Text(
                                  invoice.invoiceNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${invoice.customerName.isNotEmpty ? invoice.customerName : l10n.cashCustomer} • $dateStr',
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${invoice.finalTotal.toStringAsFixed(2)} ${invoice.currency}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: invoice.isCancelled
                                            ? AppColors.error
                                            : AppColors.textPrimaryLight,
                                      ),
                                    ),
                                    Text(
                                      invoice.isCancelled
                                          ? l10n.statusCancelled
                                          : invoice.remainingBalance == 0
                                          ? l10n.paymentStatusPaid
                                          : l10n.paymentStatusPartial,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: invoice.isCancelled
                                            ? AppColors.error
                                            : invoice.remainingBalance == 0
                                            ? AppColors.success
                                            : AppColors.warning,
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
                                    cubit.loadDashboardMetrics();
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
                title: l10n.dashboardTotalSales,
                value: '${data.totalSales.toStringAsFixed(2)} ${data.currency}',
                icon: Icons.trending_up,
                color: AppColors.primary,
                bgColor: const Color(0xFFEFF6FF),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: l10n.dashboardCollected,
                value:
                    '${data.totalCollected.toStringAsFixed(2)} ${data.currency}',
                icon: Icons.check_circle_outline,
                color: AppColors.success,
                bgColor: AppColors.successBackground,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: l10n.dashboardReceivables,
                value:
                    '${data.customerDebts.toStringAsFixed(2)} ${data.currency}',
                icon: Icons.access_time,
                color: AppColors.warning,
                bgColor: AppColors.warningBackground,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: l10n.dashboardPayables,
                value:
                    '${data.supplierPayables.toStringAsFixed(2)} ${data.currency}',
                icon: Icons.outbox,
                color: AppColors.error,
                bgColor: AppColors.errorBackground,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: l10n.dashboardTotalPurchases,
                value:
                    '${data.totalPurchases.toStringAsFixed(2)} ${data.currency}',
                icon: Icons.shopping_bag_outlined,
                color: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF5F3FF),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
        ActionChip(
          avatar: const Icon(Icons.add, size: 16),
          label: Text(l10n.actionNewInvoice),
          onPressed: () {
            final cubit = context.read<DashboardCubit>();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateInvoicePage()),
            ).then((_) {
              cubit.loadDashboardMetrics();
            });
          },
        ),
        ActionChip(
          avatar: const Icon(Icons.person_add_outlined, size: 16),
          label: Text(l10n.actionAddCustomer),
          onPressed: () => _showAddPartyDialog(context, true),
        ),
        ActionChip(
          avatar: const Icon(Icons.add_shopping_cart, size: 16),
          label: Text(l10n.actionNewPurchase),
          onPressed: () {
            final cubit = context.read<DashboardCubit>();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatePurchasePage()),
            ).then((_) {
              cubit.loadDashboardMetrics();
            });
          },
        ),
        ActionChip(
          avatar: const Icon(Icons.business_outlined, size: 16),
          label: Text(l10n.actionAddSupplier),
          onPressed: () => _showAddPartyDialog(context, false),
        ),
      ],
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
        final barWidth = (constraints.maxWidth / points.length) * 0.5;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: points.map((p) {
            final ratio = maxVal > 0
                ? (p.amount / maxVal).clamp(0.05, 1.0)
                : 0.05;
            final dayName = DateFormat('E').format(p.date);

            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (p.amount > 0)
                  Text(
                    p.amount.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  width: barWidth.clamp(16.0, 36.0),
                  height: (constraints.maxHeight - 36) * ratio,
                  decoration: BoxDecoration(
                    color: p.amount > 0
                        ? AppColors.primary
                        : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dayName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}
