import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/precision/currency_formatter.dart';
import 'package:fatoura/core/precision/financial_calculator.dart';
import 'package:fatoura/core/precision/money.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
import 'package:fatoura/core/theme/app_colors.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/parties/domain/entities/party.dart';
import 'package:fatoura/features/parties/presentation/cubit/parties_cubit.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';
import 'package:fatoura/features/products/domain/entities/product.dart';
import 'package:fatoura/features/products/presentation/cubit/products_cubit.dart';
import 'package:fatoura/features/purchases/presentation/cubit/purchases_cubit.dart';
import 'package:fatoura/features/shop_setup/presentation/cubit/shop_setup_cubit.dart';

class _PurchaseItemRow {
  String? productId;
  final TextEditingController descCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  _PurchaseItemRow({
    this.productId,
    String description = '',
    String quantity = '1',
    String unitPrice = '0.0',
  }) : descCtrl = TextEditingController(text: description),
       qtyCtrl = TextEditingController(text: quantity),
       priceCtrl = TextEditingController(text: unitPrice);

  void dispose() {
    descCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class CreatePurchasePage extends StatefulWidget {
  const CreatePurchasePage({super.key});

  @override
  State<CreatePurchasePage> createState() => _CreatePurchasePageState();
}

class _CreatePurchasePageState extends State<CreatePurchasePage> {
  final _formKey = GlobalKey<FormState>();

  Party? _selectedSupplier;
  String? _selectedSupplierId;
  final _items = <_PurchaseItemRow>[];

  final _discountController = TextEditingController(text: '0.0');
  final _taxRateController = TextEditingController(text: '0.0');
  final _notesController = TextEditingController();

  PaymentStatus _paymentStatus = PaymentStatus.fullyPaid;
  final _paidAmountController = TextEditingController();
  PaymentMethod _paymentMethod = PaymentMethod.cash;

  String _currency = 'EGP';

  @override
  void initState() {
    super.initState();
    context.read<PartiesCubit>().loadSuppliers();
    context.read<ProductsCubit>().loadProducts();

    final shopState = context.read<ShopSetupCubit>().state;
    if (shopState is ShopSetupLoaded && shopState.profile != null) {
      final p = shopState.profile!;
      _currency = p.defaultCurrency;
      if (p.defaultTaxEnabled) {
        _taxRateController.text = p.defaultTaxRate.toString();
      }
    }

    _addItem();
  }

  @override
  void dispose() {
    for (final i in _items) {
      i.dispose();
    }
    _discountController.dispose();
    _taxRateController.dispose();
    _notesController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  void _addItem([Product? product]) {
    setState(() {
      _items.add(
        _PurchaseItemRow(
          productId: product?.id,
          description: product?.name ?? '',
          quantity: '1',
          unitPrice: product?.costPrice.toString() ?? '0.0',
        ),
      );
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        final removed = _items.removeAt(index);
        removed.dispose();
      });
    }
  }

  void _showProductCatalogSheet(int itemIndex) {
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) {
            return BlocBuilder<ProductsCubit, ProductsState>(
              builder: (context, state) {
                List<Product> products = [];
                if (state is ProductsLoaded) {
                  products = state.products
                      .where((p) => !p.isArchived)
                      .toList();
                }

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.selectProductBtn,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: products.isEmpty
                            ? Center(child: Text(l10n.noDataFound))
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: products.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (ctx, idx) {
                                  final p = products[idx];
                                  return ListTile(
                                    title: Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      [
                                        if (p.barcode.isNotEmpty)
                                          'Barcode: ${p.barcode}',
                                        if (p.sku.isNotEmpty) 'SKU: ${p.sku}',
                                        '${l10n.stockQuantityLabel}: ${p.stockQuantity}',
                                      ].join(' • '),
                                    ),
                                    trailing: Text(
                                      CurrencyFormatter.format(
                                        p.costPrice > 0
                                            ? p.costPrice
                                            : p.defaultUnitPrice,
                                        currency: _currency,
                                        isArabic: l10n.isArabic,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      setState(() {
                                        _items[itemIndex].productId = p.id;
                                        _items[itemIndex].descCtrl.text =
                                            p.name;
                                        if (p.costPrice > 0) {
                                          _items[itemIndex].priceCtrl.text = p
                                              .costPrice
                                              .toString();
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showCreateNewProductDialog(int itemIndex) {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(
      text: _items[itemIndex].descCtrl.text.trim(),
    );
    final skuCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController();
    final costCtrl = TextEditingController(
      text: _items[itemIndex].priceCtrl.text.trim(),
    );
    final sellPriceCtrl = TextEditingController();
    final modalFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.actionAddProduct),
        content: Form(
          key: modalFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: '${l10n.nameLabel} *'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? l10n.setupRequiredField
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: barcodeCtrl,
                  decoration: InputDecoration(labelText: l10n.barcodeLabel),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: skuCtrl,
                  decoration: InputDecoration(labelText: l10n.skuLabel),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: costCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '${l10n.costPriceLabel} ($_currency)',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: sellPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '${l10n.sellingPriceLabel} * ($_currency)',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? l10n.setupRequiredField
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancelBtn),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!modalFormKey.currentState!.validate()) return;
              final newId = const Uuid().v4();
              final now = DateTime.now();
              final costVal = double.tryParse(costCtrl.text.trim()) ?? 0.0;
              final sellVal =
                  double.tryParse(sellPriceCtrl.text.trim()) ?? costVal;

              final newProd = Product(
                id: newId,
                name: nameCtrl.text.trim(),
                sku: skuCtrl.text.trim(),
                barcode: barcodeCtrl.text.trim(),
                costPrice: costVal,
                defaultUnitPrice: sellVal,
                trackInventory: true,
                stockQuantity: 0.0,
                createdAt: now,
                updatedAt: now,
              );

              await context.read<ProductsCubit>().saveProduct(
                id: newProd.id,
                name: newProd.name,
                sku: newProd.sku,
                barcode: newProd.barcode,
                defaultUnitPrice: newProd.defaultUnitPrice,
                costPrice: newProd.costPrice,
                trackInventory: true,
              );

              if (mounted) {
                setState(() {
                  _items[itemIndex].productId = newProd.id;
                  _items[itemIndex].descCtrl.text = newProd.name;
                  _items[itemIndex].priceCtrl.text = costVal.toString();
                });
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n.isArabic
                          ? 'تم حفظ وربط المنتج الجديد: ${newProd.name}'
                          : 'New product created and linked: ${newProd.name}',
                    ),
                  ),
                );
              }
            },
            child: Text(l10n.saveBtn),
          ),
        ],
      ),
    );
  }

  InvoiceCalculationResult _calculateCurrentTotals() {
    final raw = <({Decimal quantity, Money unitPrice})>[];
    for (final item in _items) {
      final qty = Decimal.tryParse(item.qtyCtrl.text.trim()) ?? Decimal.zero;
      final price =
          Decimal.tryParse(item.priceCtrl.text.trim()) ?? Decimal.zero;
      raw.add((quantity: qty, unitPrice: Money.fromDecimal(price, _currency)));
    }

    final discountVal =
        Decimal.tryParse(_discountController.text.trim()) ?? Decimal.zero;
    final taxRateVal =
        Decimal.tryParse(_taxRateController.text.trim()) ?? Decimal.zero;

    return FinancialCalculator.calculateInvoice(
      rawItems: raw,
      discountType: DiscountType.fixed,
      discountValue: discountVal,
      taxRatePercent: taxRateVal,
      currency: _currency,
    );
  }

  void _submit({required bool isDraft}) {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);

    if (_selectedSupplierId == null || _selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isArabic
                ? 'يرجى اختيار المورد من القائمة'
                : 'Please select a supplier from the list',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final rawItems =
        <
          ({
            String? productId,
            String description,
            double quantity,
            double unitPrice,
          })
        >[];
    for (final item in _items) {
      final desc = item.descCtrl.text.trim();
      final qty = double.tryParse(item.qtyCtrl.text.trim()) ?? 1.0;
      final price = double.tryParse(item.priceCtrl.text.trim()) ?? 0.0;
      if (desc.isNotEmpty && qty > 0) {
        rawItems.add((
          productId: item.productId,
          description: desc,
          quantity: qty,
          unitPrice: price,
        ));
      }
    }

    if (rawItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.setupRequiredField),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final discountVal = double.tryParse(_discountController.text.trim()) ?? 0.0;
    final taxRateVal = double.tryParse(_taxRateController.text.trim()) ?? 0.0;

    double initialPaidAmount = 0.0;
    if (!isDraft) {
      final totals = _calculateCurrentTotals();
      final finalTotalVal = totals.finalTotal.toDouble();
      if (_paymentStatus == PaymentStatus.fullyPaid) {
        initialPaidAmount = finalTotalVal;
      } else if (_paymentStatus == PaymentStatus.partiallyPaid) {
        initialPaidAmount =
            double.tryParse(_paidAmountController.text.trim()) ?? 0.0;
        if (initialPaidAmount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.isArabic
                    ? 'يرجى إدخال المبلغ المسدد للمورد'
                    : 'Please enter the amount paid',
              ),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
      } else {
        initialPaidAmount = 0.0;
      }
    }

    context.read<PurchasesCubit>().createPurchase(
      supplierId: _selectedSupplierId!,
      supplierName: _selectedSupplier!.name,
      supplierPhone: _selectedSupplier!.phone,
      rawItems: rawItems,
      discountType: DiscountType.fixed,
      discountValue: discountVal,
      taxRate: taxRateVal,
      notes: _notesController.text.trim(),
      isDraft: isDraft,
      initialPaymentStatus: isDraft ? PaymentStatus.unpaid : _paymentStatus,
      initialPaidAmount: initialPaidAmount,
      initialPaymentMethod: _paymentMethod,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totals = _calculateCurrentTotals();

    return BlocListener<PurchasesCubit, PurchasesState>(
      listener: (context, state) {
        if (state is PurchaseOperationSuccess) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
          Navigator.pop(context);
        } else if (state is PurchasesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.actionNewPurchase)),
        body: ResponsiveContentContainer(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Supplier Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusCard,
                      ),
                      side: BorderSide(
                        color: Theme.of(context).dividerColor
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.business_outlined,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.supplierLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          BlocBuilder<PartiesCubit, PartiesState>(
                            builder: (context, state) {
                              if (state is PartiesLoading) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12.0,
                                    horizontal: 4.0,
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        l10n.isArabic
                                            ? 'جاري تحميل قائمة الموردين...'
                                            : 'Loading suppliers...',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? AppColors.textSecondaryDark
                                              : AppColors.textSecondaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              if (state is PartiesError) {
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusSmall,
                                    ),
                                    border: Border.all(
                                      color: AppColors.error.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        size: 18,
                                        color: AppColors.error,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          state.message,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.error,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => context
                                            .read<PartiesCubit>()
                                            .loadSuppliers(),
                                        child: Text(
                                          l10n.isArabic ? 'إعادة المحاولة' : 'Retry',
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              List<Party> rawSuppliers = [];
                              if (state is SuppliersLoaded) {
                                rawSuppliers = state.suppliers;
                              }

                              final uniqueSuppliers = <String, Party>{};
                              for (final s in rawSuppliers) {
                                if (s.id.isNotEmpty &&
                                    !uniqueSuppliers.containsKey(s.id)) {
                                  uniqueSuppliers[s.id] = s;
                                }
                              }
                              final suppliers = uniqueSuppliers.values.toList();

                              final bool isSelectionInList =
                                  _selectedSupplierId != null &&
                                  uniqueSuppliers.containsKey(
                                    _selectedSupplierId,
                                  );

                              if (_selectedSupplierId != null &&
                                  !isSelectionInList &&
                                  state is SuppliersLoaded) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted &&
                                      _selectedSupplierId != null &&
                                      !uniqueSuppliers.containsKey(
                                        _selectedSupplierId,
                                      )) {
                                    setState(() {
                                      _selectedSupplierId = null;
                                      _selectedSupplier = null;
                                    });
                                  }
                                });
                              }

                              if (isSelectionInList) {
                                final fresh =
                                    uniqueSuppliers[_selectedSupplierId]!;
                                if (_selectedSupplier != fresh) {
                                  _selectedSupplier = fresh;
                                }
                              }

                              final effectiveSelectedId = isSelectionInList
                                  ? _selectedSupplierId
                                  : null;

                              if (suppliers.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusSmall,
                                    ),
                                    border: Border.all(
                                      color: Theme.of(context).dividerColor
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.business_outlined,
                                        size: 20,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          l10n.isArabic
                                              ? 'لا يوجد موردين مسجلين حالياً.'
                                              : 'No suppliers found.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return DropdownButtonFormField<String?>(
                                key: ValueKey(effectiveSelectedId),
                                initialValue: effectiveSelectedId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: l10n.supplierLabel,
                                  prefixIcon: const Icon(
                                    Icons.business_outlined,
                                  ),
                                ),
                                hint: Text(l10n.selectSupplierBtn),
                                items: suppliers.map((s) {
                                  return DropdownMenuItem<String>(
                                    value: s.id,
                                    child: Text(
                                      s.phone.isNotEmpty
                                          ? '${s.name} (${s.phone})'
                                          : s.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newId) {
                                  setState(() {
                                    _selectedSupplierId = newId;
                                    _selectedSupplier = newId != null
                                        ? uniqueSuppliers[newId]
                                        : null;
                                  });
                                },
                                validator: (v) =>
                                    v == null ? l10n.setupRequiredField : null,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Line Items
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusCard,
                      ),
                      side: BorderSide(
                        color: Theme.of(context).dividerColor
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.itemsSection,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(l10n.addItemBtn),
                                onPressed: () => _addItem(),
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 8),

                          ..._items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;

                            final q =
                                Decimal.tryParse(item.qtyCtrl.text.trim()) ??
                                Decimal.zero;
                            final p =
                                Decimal.tryParse(item.priceCtrl.text.trim()) ??
                                Decimal.zero;
                            final lineTotal = (q * p).toDouble();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurfaceSubtle.withValues(
                                        alpha: 0.5,
                                      )
                                    : AppColors.lightSurfaceSubtle.withValues(
                                        alpha: 0.6,
                                      ),
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusMedium,
                                ),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: TextFormField(
                                          controller: item.descCtrl,
                                          decoration: InputDecoration(
                                            labelText: l10n.itemDescription,
                                            isDense: true,
                                          ),
                                          onChanged: (_) => setState(() {}),
                                          validator: (v) =>
                                              v == null || v.trim().isEmpty
                                              ? l10n.setupRequiredField
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          controller: item.qtyCtrl,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          decoration: InputDecoration(
                                            labelText: l10n.itemQuantity,
                                            isDense: true,
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 3,
                                        child: TextFormField(
                                          controller: item.priceCtrl,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          decoration: InputDecoration(
                                            labelText: l10n.itemUnitPrice,
                                            isDense: true,
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: AppColors.error,
                                        ),
                                        onPressed: _items.length > 1
                                            ? () => _removeItem(idx)
                                            : null,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(
                                          Icons.inventory_2_outlined,
                                          size: 16,
                                        ),
                                        label: Text(
                                          item.productId != null
                                              ? (l10n.isArabic
                                                    ? 'تغيير الصنف'
                                                    : 'Change Product')
                                              : (l10n.isArabic
                                                    ? 'ربط بصنف من الدليل'
                                                    : 'Link from Catalog'),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        onPressed: () =>
                                            _showProductCatalogSheet(idx),
                                      ),
                                      const SizedBox(width: 8),
                                      if (item.productId == null)
                                        TextButton.icon(
                                          icon: const Icon(
                                            Icons.add_box_outlined,
                                            size: 16,
                                          ),
                                          label: Text(
                                            l10n.isArabic
                                                ? '+ تعريف كمنتج جديد'
                                                : '+ Create as Product',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          onPressed: () =>
                                              _showCreateNewProductDialog(idx),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.success.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              AppDimensions.radiusSmall,
                                            ),
                                          ),
                                          child: Text(
                                            l10n.isArabic
                                                ? 'صنف مرتبط بالمخزن'
                                                : 'Linked Catalog Item',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.success,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      const Spacer(),
                                      Text(
                                        CurrencyFormatter.format(
                                          lineTotal,
                                          currency: _currency,
                                          isArabic: l10n.isArabic,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes & Discounts
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusCard,
                      ),
                      side: BorderSide(
                        color: Theme.of(context).dividerColor
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _discountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: l10n.discountLabel,
                                    isDense: true,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _taxRateController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: l10n.taxRateLabel,
                                    isDense: true,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notesController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: l10n.notesLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Supplier Payment State Card (Requirement 6)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusCard,
                      ),
                      side: BorderSide(
                        color: Theme.of(context).dividerColor
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.payments_outlined,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.paymentOptionsTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                avatar: const Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                ),
                                label: Text(l10n.paymentOptionFullyPaid),
                                selected:
                                    _paymentStatus == PaymentStatus.fullyPaid,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _paymentStatus = PaymentStatus.fullyPaid;
                                      _paidAmountController.clear();
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                avatar: const Icon(
                                  Icons.timelapse_outlined,
                                  size: 16,
                                ),
                                label: Text(l10n.paymentOptionPartiallyPaid),
                                selected:
                                    _paymentStatus ==
                                    PaymentStatus.partiallyPaid,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _paymentStatus =
                                          PaymentStatus.partiallyPaid;
                                      if (_paidAmountController.text.isEmpty) {
                                        _paidAmountController.text =
                                            (totals.finalTotal.toDouble() / 2)
                                                .toStringAsFixed(2);
                                      }
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                avatar: const Icon(
                                  Icons.schedule_outlined,
                                  size: 16,
                                ),
                                label: Text(l10n.paymentOptionUnpaid),
                                selected:
                                    _paymentStatus == PaymentStatus.unpaid,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _paymentStatus = PaymentStatus.unpaid;
                                      _paidAmountController.clear();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          if (_paymentStatus ==
                              PaymentStatus.partiallyPaid) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _paidAmountController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText:
                                          '${l10n.isArabic ? "المبلغ المدفوع للمورد" : "Amount Paid to Supplier"} ($_currency)',
                                      prefixIcon: const Icon(
                                        Icons.paid_outlined,
                                      ),
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    validator: (v) {
                                      if (_paymentStatus ==
                                          PaymentStatus.partiallyPaid) {
                                        final parsed = double.tryParse(
                                          v?.trim() ?? '',
                                        );
                                        if (parsed == null || parsed <= 0) {
                                          return l10n.setupRequiredField;
                                        }
                                        if (parsed >=
                                            totals.finalTotal.toDouble()) {
                                          return l10n.errorOverpayment;
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: Builder(
                                    builder: (_) {
                                      final paid =
                                          double.tryParse(
                                            _paidAmountController.text.trim(),
                                          ) ??
                                          0.0;
                                      final remaining =
                                          (totals.finalTotal.toDouble() - paid)
                                              .clamp(0.0, double.infinity);
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l10n.remainingBalanceLabel,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? AppColors.textSecondaryDark
                                                  : AppColors
                                                        .textSecondaryLight,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            CurrencyFormatter.format(
                                              remaining,
                                              currency: _currency,
                                              isArabic: l10n.isArabic,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_paymentStatus != PaymentStatus.unpaid) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<PaymentMethod>(
                              initialValue: _paymentMethod,
                              decoration: InputDecoration(
                                labelText: l10n.paymentMethodLabel,
                                prefixIcon: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                                isDense: true,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: PaymentMethod.cash,
                                  child: Text(l10n.methodCash),
                                ),
                                DropdownMenuItem(
                                  value: PaymentMethod.bank,
                                  child: Text(l10n.methodBank),
                                ),
                                DropdownMenuItem(
                                  value: PaymentMethod.card,
                                  child: Text(l10n.methodCard),
                                ),
                                DropdownMenuItem(
                                  value: PaymentMethod.other,
                                  child: Text(l10n.methodOther),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _paymentMethod = val);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Summary Box
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusCard,
                      ),
                      side: BorderSide(
                        color: Theme.of(context).dividerColor
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildSummaryLine(
                            label: l10n.subtotalLabel,
                            value:
                                '${totals.subtotal.toStringAsFixed(2)} $_currency',
                            isDark: isDark,
                          ),
                          if (totals.taxAmount.isPositive)
                            _buildSummaryLine(
                              label: l10n.taxAmountLabel,
                              value:
                                  '+${totals.taxAmount.toStringAsFixed(2)} $_currency',
                              isDark: isDark,
                            ),
                          const Divider(),
                          _buildSummaryLine(
                            label: l10n.finalTotalLabel,
                            value:
                                '${totals.finalTotal.toStringAsFixed(2)} $_currency',
                            isBold: true,
                            fontSize: 17,
                            color: AppColors.primary,
                            isDark: isDark,
                          ),
                          if (_paymentStatus ==
                              PaymentStatus.partiallyPaid) ...[
                            _buildSummaryLine(
                              label: l10n.isArabic
                                  ? 'المسدد للمورد'
                                  : 'Paid to Supplier',
                              value:
                                  '${(double.tryParse(_paidAmountController.text.trim()) ?? 0.0).toStringAsFixed(2)} $_currency',
                              color: AppColors.success,
                              isDark: isDark,
                            ),
                            _buildSummaryLine(
                              label: l10n.isArabic
                                  ? 'المتبقي للمورد'
                                  : 'Payable to Supplier',
                              value:
                                  '${(totals.finalTotal.toDouble() - (double.tryParse(_paidAmountController.text.trim()) ?? 0.0)).clamp(0.0, double.infinity).toStringAsFixed(2)} $_currency',
                              color: AppColors.error,
                              isBold: true,
                              isDark: isDark,
                            ),
                          ] else if (_paymentStatus ==
                              PaymentStatus.unpaid) ...[
                            _buildSummaryLine(
                              label: l10n.isArabic
                                  ? 'المتبقي للمورد (آجل)'
                                  : 'Outstanding Payable',
                              value:
                                  '${totals.finalTotal.toStringAsFixed(2)} $_currency',
                              color: AppColors.error,
                              isBold: true,
                              isDark: isDark,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _submit(isDraft: true),
                          child: Text(l10n.saveDraftBtn),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _submit(isDraft: false),
                          child: Text(
                            l10n.isArabic
                                ? 'تأكيد واستلام المشتريات'
                                : 'Confirm & Receive Stock',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryLine({
    required String label,
    required String value,
    bool isBold = false,
    double fontSize = 14,
    Color? color,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: isBold
                  ? (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight)
                  : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color:
                  color ??
                  (isBold
                      ? AppColors.primary
                      : (isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight)),
            ),
          ),
        ],
      ),
    );
  }
}
