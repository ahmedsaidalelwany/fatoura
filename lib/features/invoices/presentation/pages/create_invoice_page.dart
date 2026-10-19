import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/precision/financial_calculator.dart';
import 'package:fatoura/core/precision/money.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
import 'package:fatoura/core/theme/app_colors.dart';
import 'package:fatoura/features/parties/domain/entities/party.dart';
import 'package:fatoura/features/parties/presentation/cubit/parties_cubit.dart';
import 'package:fatoura/features/products/domain/entities/product.dart';
import 'package:fatoura/features/products/presentation/cubit/products_cubit.dart';
import 'package:fatoura/features/shop_setup/presentation/cubit/shop_setup_cubit.dart';
import 'package:fatoura/features/invoices/presentation/cubit/invoices_cubit.dart';

class _EditableItem {
  String? productId;
  final TextEditingController descCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  _EditableItem({
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

class CreateInvoicePage extends StatefulWidget {
  const CreateInvoicePage({super.key});

  @override
  State<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends State<CreateInvoicePage> {
  final _formKey = GlobalKey<FormState>();

  Party? _selectedCustomer;
  final _items = <_EditableItem>[];

  DiscountType _discountType = DiscountType.fixed;
  final _discountController = TextEditingController(text: '0.0');
  final _taxRateController = TextEditingController(text: '0.0');
  final _notesController = TextEditingController();

  String _currency = 'SAR';

  @override
  void initState() {
    super.initState();
    // Preload customers and products
    context.read<PartiesCubit>().loadCustomers();
    context.read<ProductsCubit>().loadProducts();

    // Check shop profile for default tax and currency
    final shopState = context.read<ShopSetupCubit>().state;
    if (shopState is ShopSetupLoaded && shopState.profile != null) {
      final p = shopState.profile!;
      _currency = p.defaultCurrency;
      if (p.defaultTaxEnabled) {
        _taxRateController.text = p.defaultTaxRate.toString();
      }
    }

    // Start with 1 blank item
    _addItem();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _discountController.dispose();
    _taxRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addItem([Product? product]) {
    setState(() {
      _items.add(
        _EditableItem(
          productId: product?.id,
          description: product?.name ?? '',
          quantity: '1',
          unitPrice: product?.defaultUnitPrice.toString() ?? '0.0',
        ),
      );
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        final item = _items.removeAt(index);
        item.dispose();
      });
    }
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
      discountType: _discountType,
      discountValue: discountVal,
      taxRatePercent: taxRateVal,
      currency: _currency,
    );
  }

  void _submit({required bool isDraft}) {
    if (!_formKey.currentState!.validate()) return;

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
      final l10n = AppLocalizations.of(context);
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

    context.read<InvoicesCubit>().createInvoice(
      customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer?.name ?? '',
      customerPhone: _selectedCustomer?.phone ?? '',
      customerAddress: _selectedCustomer?.address ?? '',
      rawItems: rawItems,
      discountType: _discountType,
      discountValue: discountVal,
      taxRate: taxRateVal,
      notes: _notesController.text.trim(),
      isDraft: isDraft,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final totals = _calculateCurrentTotals();

    return BlocListener<InvoicesCubit, InvoicesState>(
      listener: (context, state) {
        if (state is InvoiceOperationSuccess) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
          Navigator.pop(context);
        } else if (state is InvoicesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.actionNewInvoice)),
        body: ResponsiveContentContainer(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Customer Selection Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.customerLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          BlocBuilder<PartiesCubit, PartiesState>(
                            builder: (context, state) {
                              List<Party> customers = [];
                              if (state is CustomersLoaded) {
                                customers = state.customers;
                              }
                              return DropdownButtonFormField<Party?>(
                                initialValue: _selectedCustomer,
                                decoration: InputDecoration(
                                  labelText: l10n.customerLabel,
                                  prefixIcon: const Icon(Icons.person_outline),
                                ),
                                hint: Text(l10n.cashCustomer),
                                items: [
                                  DropdownMenuItem<Party?>(
                                    value: null,
                                    child: Text(l10n.cashCustomer),
                                  ),
                                  ...customers.map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text('${c.name} (${c.phone})'),
                                    ),
                                  ),
                                ],
                                onChanged: (val) =>
                                    setState(() => _selectedCustomer = val),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Line Items Section
                  Card(
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
                              TextButton.icon(
                                icon: const Icon(Icons.add),
                                label: Text(l10n.addItemBtn),
                                onPressed: () => _addItem(),
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 8),

                          // Dynamic Items list
                          ..._items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 4,
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
                                    flex: 2,
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
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Discounts and Taxes
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<DiscountType>(
                                  initialValue: _discountType,
                                  decoration: InputDecoration(
                                    labelText: l10n.discountLabel,
                                    isDense: true,
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: DiscountType.fixed,
                                      child: Text(l10n.discountTypeFixed),
                                    ),
                                    DropdownMenuItem(
                                      value: DiscountType.percentage,
                                      child: Text(l10n.discountTypePercent),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _discountType = val);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _discountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: l10n.discountValue,
                                    isDense: true,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
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

                  // Live Summary Box
                  Card(
                    color: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 1.2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildSummaryLine(
                            l10n.subtotalLabel,
                            '${totals.subtotal.toStringAsFixed(2)} $_currency',
                          ),
                          if (totals.discountAmount.isPositive)
                            _buildSummaryLine(
                              l10n.discountLabel,
                              '-${totals.discountAmount.toStringAsFixed(2)} $_currency',
                              color: AppColors.error,
                            ),
                          if (totals.taxAmount.isPositive) ...[
                            _buildSummaryLine(
                              l10n.taxableBaseLabel,
                              '${totals.taxableBase.toStringAsFixed(2)} $_currency',
                            ),
                            _buildSummaryLine(
                              l10n.taxAmountLabel,
                              '+${totals.taxAmount.toStringAsFixed(2)} $_currency',
                            ),
                          ],
                          const Divider(thickness: 1.5),
                          _buildSummaryLine(
                            l10n.finalTotalLabel,
                            '${totals.finalTotal.toStringAsFixed(2)} $_currency',
                            isBold: true,
                            fontSize: 18,
                            color: AppColors.primary,
                          ),
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
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _submit(isDraft: false),
                          child: Text(l10n.issueInvoiceBtn),
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

  Widget _buildSummaryLine(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 14,
    Color? color,
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
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
