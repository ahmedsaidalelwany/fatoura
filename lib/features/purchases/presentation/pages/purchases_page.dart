import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
import 'package:fatoura/core/theme/app_colors.dart';
import 'package:fatoura/features/purchases/presentation/cubit/purchases_cubit.dart';

import 'create_purchase_page.dart';

class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});

  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<PurchasesCubit>().loadPurchases();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    context.read<PurchasesCubit>().loadPurchases(
      query: _searchController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navPurchases),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.actionNewPurchase,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreatePurchasePage()),
              ).then((_) => _onSearch());
            },
          ),
        ],
      ),
      body: ResponsiveContentContainer(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch();
                        },
                      )
                    : null,
              ),
              onChanged: (_) => _onSearch(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BlocBuilder<PurchasesCubit, PurchasesState>(
                builder: (context, state) {
                  if (state is PurchasesLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is PurchasesLoaded) {
                    final purchases = state.purchases;
                    if (purchases.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.shopping_bag_outlined,
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
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: Text(l10n.actionNewPurchase),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CreatePurchasePage(),
                                  ),
                                ).then((_) => _onSearch());
                              },
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: purchases.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final pur = purchases[index];
                        final dateStr = DateFormat('yyyy/MM/dd')
                            .format(pur.issueDate);

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F3FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_bag,
                                    color: Color(0xFF8B5CF6),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pur.purchaseNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${l10n.supplierLabel}: ${pur.supplierName} • $dateStr',
                                        style: const TextStyle(
                                          color: AppColors.textSecondaryLight,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${pur.finalTotal.toStringAsFixed(2)} ${pur.currency}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (pur.remainingPayable > 0)
                                      Text(
                                        '${l10n.remainingBalanceLabel}: ${pur.remainingPayable.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.error,
                                        ),
                                      ),
                                  ],
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
          ],
        ),
      ),
    );
  }
}
