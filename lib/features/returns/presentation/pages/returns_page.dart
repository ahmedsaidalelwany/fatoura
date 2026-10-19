import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/precision/currency_formatter.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
import 'package:fatoura/core/theme/app_colors.dart';
import 'package:fatoura/features/returns/presentation/cubit/returns_cubit.dart';

class ReturnsPage extends StatefulWidget {
  const ReturnsPage({super.key});

  @override
  State<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends State<ReturnsPage> {
  @override
  void initState() {
    super.initState();
    context.read<ReturnsCubit>().loadReturns();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navReturns)),
      body: ResponsiveContentContainer(
        padding: const EdgeInsets.all(16.0),
        child: BlocBuilder<ReturnsCubit, ReturnsState>(
          builder: (context, state) {
            if (state is ReturnsLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ReturnsLoaded) {
              final returns = state.returns;
              if (returns.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_return_outlined,
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
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: returns.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final ret = returns[index];
                  final dateStr = DateFormat('yyyy/MM/dd HH:mm')
                      .format(ret.returnDate);

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                ret.returnNumber,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  letterSpacing: -0.2,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(
                                  ret.totalRefundAmount,
                                  currency: ret.currency,
                                  isArabic: l10n.isArabic,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: -0.2,
                                  color: AppColors.errorMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${l10n.originalInvoiceLabel}: ${ret.originalInvoiceNumber} • ${ret.customerName.isNotEmpty ? ret.customerName : l10n.cashCustomer}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textSecondaryDark.withOpacity(0.8) : AppColors.textSecondaryLight.withOpacity(0.8),
                            ),
                          ),
                          if (ret.returnReason.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${l10n.returnReasonLabel}: ${ret.returnReason}',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                          const Divider(height: 16),
                          ...ret.items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${item.description} (x${item.returnedQuantity})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(
                                      item.refundAmount,
                                      currency: ret.currency,
                                      isArabic: l10n.isArabic,
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
    );
  }
}
