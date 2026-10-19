import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/precision/currency_formatter.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
import 'package:fatoura/core/settings/app_settings_cubit.dart';
import 'package:fatoura/core/theme/app_colors.dart';
import 'package:fatoura/features/products/domain/entities/product.dart';
import 'package:fatoura/features/products/presentation/cubit/products_cubit.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ProductsCubit>().loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditProductDialog(BuildContext context, [Product? existing]) {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final skuCtrl = TextEditingController(text: existing?.sku ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.defaultUnitPrice.toString() : '0.0',
    );
    final catCtrl = TextEditingController(text: existing?.category ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing != null ? l10n.editBtn : l10n.addProductBtn),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l10n.itemDescription),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: skuCtrl,
                decoration: InputDecoration(labelText: l10n.skuLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l10n.defaultPriceLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: catCtrl,
                decoration: InputDecoration(labelText: l10n.categoryLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(labelText: l10n.notesLabel),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancelBtn),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;

              context.read<ProductsCubit>().saveProduct(
                id: existing?.id,
                name: name,
                sku: skuCtrl.text.trim(),
                description: descCtrl.text.trim(),
                defaultUnitPrice: price,
                category: catCtrl.text.trim(),
              );
              Navigator.pop(ctx);
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
    final currency = context.watch<AppSettingsCubit>().state.defaultCurrency;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.productCatalogTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.addProductBtn,
            onPressed: () => _showAddEditProductDialog(context),
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
                          context.read<ProductsCubit>().loadProducts();
                        },
                      )
                    : null,
              ),
              onChanged: (q) =>
                  context.read<ProductsCubit>().loadProducts(query: q.trim()),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BlocBuilder<ProductsCubit, ProductsState>(
                builder: (context, state) {
                  if (state is ProductsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is ProductsLoaded) {
                    final products = state.products;
                    if (products.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
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
                              label: Text(l10n.addProductBtn),
                              onPressed: () =>
                                  _showAddEditProductDialog(context),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final p = products[index];
                        return Card(
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.inventory_2,
                                color: AppColors.primary,
                              ),
                            ),
                            title: Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              p.sku.isNotEmpty
                                  ? 'SKU: ${p.sku} • ${p.category}'
                                  : (p.category.isNotEmpty ? p.category : '-'),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  CurrencyFormatter.format(
                                    p.defaultUnitPrice,
                                    currency: currency,
                                    isArabic: l10n.isArabic,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.primary,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () =>
                                      _showAddEditProductDialog(context, p),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.archive_outlined,
                                    color: AppColors.error,
                                  ),
                                  onPressed: () => context
                                      .read<ProductsCubit>()
                                      .archiveProduct(p.id),
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
