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
                      const Icon(
                        Icons.assignment_return_outlined,
                        size: 56,
                        color: AppColors.textSecondaryLight,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.noDataFound,
                        style: const TextStyle(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: returns.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(
                                  ret.totalRefundAmount,
                                  currency: ret.currency,
                                  isArabic: l10n.isArabic,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${l10n.originalInvoiceLabel}: ${ret.originalInvoiceNumber} • ${ret.customerName.isNotEmpty ? ret.customerName : l10n.cashCustomer}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          if (ret.returnReason.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${l10n.returnReasonLabel}: ${ret.returnReason}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
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
                                  ),
                                  Text(
                                    CurrencyFormatter.format(
                                      item.refundAmount,
                                      currency: ret.currency,
                                      isArabic: l10n.isArabic,
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
