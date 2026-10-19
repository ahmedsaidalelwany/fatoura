import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
import 'package:fatoura/core/theme/app_colors.dart';
import 'package:fatoura/features/parties/domain/entities/party.dart';
import 'package:fatoura/features/parties/presentation/cubit/parties_cubit.dart';
import 'package:fatoura/features/purchases/presentation/cubit/purchases_cubit.dart';

class _PurchaseItemRow {
  final TextEditingController descCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  _PurchaseItemRow()
    : descCtrl = TextEditingController(),
      qtyCtrl = TextEditingController(text: '1'),
      priceCtrl = TextEditingController(text: '0.0');

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
  final _items = <_PurchaseItemRow>[];

  final _discountController = TextEditingController(text: '0.0');
  final _taxRateController = TextEditingController(text: '0.0');
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<PartiesCubit>().loadSuppliers();
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
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(_PurchaseItemRow()));
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        final removed = _items.removeAt(index);
        removed.dispose();
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);

    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.setupRequiredField),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final rawItems =
        <({String description, double quantity, double unitPrice})>[];
    for (final item in _items) {
      final desc = item.descCtrl.text.trim();
      final qty = double.tryParse(item.qtyCtrl.text.trim()) ?? 1.0;
      final price = double.tryParse(item.priceCtrl.text.trim()) ?? 0.0;
      if (desc.isNotEmpty && qty > 0) {
        rawItems.add((description: desc, quantity: qty, unitPrice: price));
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

    context.read<PurchasesCubit>().createPurchase(
      supplierId: _selectedSupplier!.id,
      supplierName: _selectedSupplier!.name,
      supplierPhone: _selectedSupplier!.phone,
      rawItems: rawItems,
      discountValue: discountVal,
      taxRate: taxRateVal,
      notes: _notesController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.supplierLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          BlocBuilder<PartiesCubit, PartiesState>(
                            builder: (context, state) {
                              List<Party> suppliers = [];
                              if (state is SuppliersLoaded) {
                                suppliers = state.suppliers;
                              }
                              return DropdownButtonFormField<Party?>(
                                initialValue: _selectedSupplier,
                                decoration: InputDecoration(
                                  labelText: l10n.supplierLabel,
                                  prefixIcon: const Icon(
                                    Icons.business_outlined,
                                  ),
                                ),
                                items: suppliers
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text('${s.name} (${s.phone})'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedSupplier = val),
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
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.add),
                                label: Text(l10n.addItemBtn),
                                onPressed: _addItem,
                              ),
                            ],
                          ),
                          const Divider(),
                          ..._items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: TextFormField(
                                      controller: item.descCtrl,
                                      decoration: InputDecoration(
                                        labelText: l10n.itemDescription,
                                        isDense: true,
                                      ),
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

                  // Notes & Discounts
                  Card(
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
                  const SizedBox(height: 24),

                  ElevatedButton(onPressed: _submit, child: Text(l10n.saveBtn)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
