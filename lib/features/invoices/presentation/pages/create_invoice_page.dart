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
import 'package:fatoura/features/shop_setup/presentation/cubit/shop_setup_cubit.dart';
import 'package:fatoura/features/invoices/presentation/cubit/invoices_cubit.dart';

enum CustomerMode { walkIn, existing, newCustomer }

enum InvoicePaymentMode { fullyPaid, partiallyPaid, unpaid }

class _EditableItem {
  String? productId;
  final TextEditingController descCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  bool isService;

  _EditableItem({
    this.productId,
    String description = '',
    String quantity = '1',
    String unitPrice = '0.0',
    this.isService = false,
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

  InvoiceTemplate _template = InvoiceTemplate.product;
  CustomerMode _customerMode = CustomerMode.walkIn;
  Party? _selectedCustomer;
  String? _selectedCustomerId;
  final _items = <_EditableItem>[];

  DiscountType _discountType = DiscountType.fixed;
  final _discountController = TextEditingController(text: '0.0');
  final _taxRateController = TextEditingController(text: '0.0');
  final _notesController = TextEditingController();

  InvoicePaymentMode _paymentMode = InvoicePaymentMode.fullyPaid;
  final _paidAmountController = TextEditingController();
  PaymentMethod _paymentMethod = PaymentMethod.cash;

  String _currency = 'EGP';

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
    _paidAmountController.dispose();
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
          isService: product != null
              ? !product.trackInventory
              : (_template == InvoiceTemplate.service),
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

  void _addOrIncrementProduct(Product product) {
    final l10n = AppLocalizations.of(context);
    if (product.trackInventory && product.stockQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isArabic
                ? 'تنبيه: المنتج (${product.name}) غير متوفر حالياً في المخزن (المتاح: 0).'
                : 'Warning: Product (${product.name}) is out of stock (Available: 0).',
          ),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final existingIdx = _items.indexWhere((it) => it.productId == product.id);
    if (existingIdx != -1) {
      final currentQty =
          double.tryParse(_items[existingIdx].qtyCtrl.text.trim()) ?? 1.0;
      _items[existingIdx].qtyCtrl.text = (currentQty + 1).toString();
      setState(() {});
    } else {
      if (_items.length == 1 &&
          _items[0].descCtrl.text.trim().isEmpty &&
          _items[0].productId == null) {
        _items[0].productId = product.id;
        _items[0].descCtrl.text = product.name;
        _items[0].qtyCtrl.text = '1';
        _items[0].priceCtrl.text = product.defaultUnitPrice.toString();
        _items[0].isService = !product.trackInventory;
        setState(() {});
      } else {
        _addItem(product);
      }
    }
  }

  void _showBarcodeScannerDialog() {
    final l10n = AppLocalizations.of(context);
    final barcodeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.qr_code_scanner, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(l10n.scanBarcodeBtn),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.isArabic
                  ? 'قم بمسح الباركود باستخدام القارئ (HID) أو اكتب الرمز واضغط إدخال:'
                  : 'Scan barcode with barcode scanner or enter code and press Enter:',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: barcodeCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.barcodeLabel,
                prefixIcon: const Icon(Icons.qr_code),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () async {
                    final code = barcodeCtrl.text.trim();
                    if (code.isNotEmpty) {
                      Navigator.pop(ctx);
                      await _lookupAndAddBarcode(code);
                    }
                  },
                ),
              ),
              onSubmitted: (code) async {
                final trimmed = code.trim();
                if (trimmed.isNotEmpty) {
                  Navigator.pop(ctx);
                  await _lookupAndAddBarcode(trimmed);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancelBtn),
          ),
        ],
      ),
    );
  }

  Future<void> _lookupAndAddBarcode(String code) async {
    final l10n = AppLocalizations.of(context);
    final product = await context.read<ProductsCubit>().findByBarcode(code);
    if (!mounted) return;

    if (product != null) {
      _addOrIncrementProduct(product);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isArabic
                ? 'تمت إضافة: ${product.name}'
                : 'Added: ${product.name}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.productNotFound} ($code)'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showProductCatalogDialog() {
    final l10n = AppLocalizations.of(context);
    final currency = _currency;

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
                                        if (p.trackInventory)
                                          '${l10n.stockQuantityLabel}: ${p.stockQuantity}',
                                      ].join(' • '),
                                    ),
                                    trailing: Text(
                                      CurrencyFormatter.format(
                                        p.defaultUnitPrice,
                                        currency: currency,
                                        isArabic: l10n.isArabic,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _addOrIncrementProduct(p);
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

  void _showNewCustomerSheet([BuildContext? callerContext]) {
    final ctx = callerContext ?? context;
    final l10n = AppLocalizations.of(ctx);
    final messenger = ScaffoldMessenger.of(ctx);
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final openBalCtrl = TextEditingController();
    final modalFormKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: modalFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.actionAddCustomer,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.nameLabel,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? l10n.setupRequiredField
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: l10n.phoneLabel,
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addrCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.addressLabel,
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: openBalCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: '${l10n.openingBalanceLabel} ($_currency)',
                      prefixIcon: const Icon(Icons.account_balance_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (!modalFormKey.currentState!.validate()) return;
                      final newId = const Uuid().v4();
                      final now = DateTime.now();
                      final openBal =
                          double.tryParse(openBalCtrl.text.trim()) ?? 0.0;

                      await context.read<PartiesCubit>().saveParty(
                        id: newId,
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        address: addrCtrl.text.trim(),
                        isCustomer: true,
                        isSupplier: false,
                        openingReceivable: openBal,
                      );

                      final newParty = Party(
                        id: newId,
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        address: addrCtrl.text.trim(),
                        isCustomer: true,
                        openingReceivable: openBal,
                        createdAt: now,
                        updatedAt: now,
                      );

                      if (!mounted) return;
                      setState(() {
                        _selectedCustomerId = newId;
                        _selectedCustomer = newParty;
                        _customerMode = CustomerMode.existing;
                      });
                      if (sheetCtx.mounted) {
                        Navigator.pop(sheetCtx);
                      }
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.isArabic
                                ? 'تمت إضافة واختيار العميل: ${newParty.name}'
                                : 'Customer added and selected: ${newParty.name}',
                          ),
                        ),
                      );
                    },
                    child: Text(
                      l10n.isArabic
                          ? 'حفظ واختيار العميل'
                          : 'Save & Select Customer',
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _submit({required bool isDraft}) {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);

    if (_customerMode == CustomerMode.existing &&
        (_selectedCustomerId == null || _selectedCustomer == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isArabic
                ? 'يرجى اختيار العميل من القائمة.'
                : 'Please select a customer from the list.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!isDraft &&
        _customerMode == CustomerMode.walkIn &&
        _paymentMode != InvoicePaymentMode.fullyPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isArabic
                ? 'لا يمكن تسجيل مبيعات آجلة أو غير مسددة بالكامل لعميل نقدي عابر. يرجى اختيار عميل مسجل أو تسجيل عميل جديد.'
                : 'Credit or partial payment is not allowed for walk-in customers. Please select or add a customer.',
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
            bool isService,
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
          isService: item.isService,
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

    PaymentStatus initialPaymentStatus = PaymentStatus.unpaid;
    double initialPaidAmount = 0.0;
    if (!isDraft) {
      final totals = _calculateCurrentTotals();
      final finalTotalVal = totals.finalTotal.toDouble();
      if (_paymentMode == InvoicePaymentMode.fullyPaid) {
        initialPaymentStatus = PaymentStatus.fullyPaid;
        initialPaidAmount = finalTotalVal;
      } else if (_paymentMode == InvoicePaymentMode.partiallyPaid) {
        initialPaymentStatus = PaymentStatus.partiallyPaid;
        initialPaidAmount =
            double.tryParse(_paidAmountController.text.trim()) ?? 0.0;
        if (initialPaidAmount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.isArabic
                    ? 'يرجى إدخال المبلغ المستلم'
                    : 'Please enter the received amount',
              ),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
      } else {
        initialPaymentStatus = PaymentStatus.unpaid;
        initialPaidAmount = 0.0;
      }
    }

    context.read<InvoicesCubit>().createInvoice(
      customerId: _selectedCustomerId,
      customerName:
          _selectedCustomer?.name ??
          (_customerMode == CustomerMode.walkIn ? l10n.walkInCustomer : ''),
      customerPhone: _selectedCustomer?.phone ?? '',
      customerAddress: _selectedCustomer?.address ?? '',
      rawItems: rawItems,
      discountType: _discountType,
      discountValue: discountVal,
      taxRate: taxRateVal,
      notes: _notesController.text.trim(),
      isDraft: isDraft,
      initialPaymentStatus: initialPaymentStatus,
      initialPaidAmount: initialPaidAmount,
      initialPaymentMethod: _paymentMethod,
      template: _template,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final totals = _calculateCurrentTotals();
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  // Invoice Template Selection Card
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
                                Icons.design_services_outlined,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.isArabic
                                    ? 'نوع وتصميم الفاتورة'
                                    : 'Invoice Design Template',
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
                                  Icons.inventory_2_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  l10n.isArabic
                                      ? 'فاتورة منتجات (بضائع)'
                                      : 'Product Invoice',
                                ),
                                selected: _template == InvoiceTemplate.product,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _template = InvoiceTemplate.product;
                                      for (final it in _items) {
                                        if (it.productId == null) {
                                          it.isService = false;
                                        }
                                      }
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                avatar: const Icon(
                                  Icons.build_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  l10n.isArabic
                                      ? 'فاتورة خدمات (أتعاب/استشارات)'
                                      : 'Service Invoice',
                                ),
                                selected: _template == InvoiceTemplate.service,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _template = InvoiceTemplate.service;
                                      for (final it in _items) {
                                        it.isService = true;
                                      }
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                avatar: const Icon(
                                  Icons.layers_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  l10n.isArabic
                                      ? 'فاتورة مختلطة (منتجات وخدمات)'
                                      : 'Mixed Invoice',
                                ),
                                selected: _template == InvoiceTemplate.mixed,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _template = InvoiceTemplate.mixed;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Customer Selection Card
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
                                Icons.person_outline,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.customerTypeLabel,
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
                                  Icons.storefront_outlined,
                                  size: 16,
                                ),
                                label: Text(l10n.walkInCustomer),
                                selected: _customerMode == CustomerMode.walkIn,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _customerMode = CustomerMode.walkIn;
                                      _selectedCustomer = null;
                                      _selectedCustomerId = null;
                                      _paymentMode =
                                          InvoicePaymentMode.fullyPaid;
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                avatar: const Icon(
                                  Icons.people_outline,
                                  size: 16,
                                ),
                                label: Text(l10n.existingCustomer),
                                selected:
                                    _customerMode == CustomerMode.existing,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _customerMode = CustomerMode.existing;
                                    });
                                  }
                                },
                              ),
                              ActionChip(
                                avatar: const Icon(
                                  Icons.person_add_alt_1_outlined,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                label: Text(l10n.newCustomer),
                                onPressed: () => _showNewCustomerSheet(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_customerMode == CustomerMode.walkIn) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryMuted.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusSmall,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n.walkInCustomerSubtitle,
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
                            ),
                          ] else if (_customerMode ==
                              CustomerMode.existing) ...[
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
                                              ? 'جاري تحميل قائمة العملاء...'
                                              : 'Loading customers...',
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
                                              .loadCustomers(),
                                          child: Text(
                                            l10n.isArabic
                                                ? 'إعادة المحاولة'
                                                : 'Retry',
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                List<Party> rawCustomers = [];
                                if (state is CustomersLoaded) {
                                  rawCustomers = state.customers;
                                }

                                final uniqueCustomers = <String, Party>{};
                                for (final c in rawCustomers) {
                                  if (c.id.isNotEmpty &&
                                      !uniqueCustomers.containsKey(c.id)) {
                                    uniqueCustomers[c.id] = c;
                                  }
                                }
                                final customers = uniqueCustomers.values.toList();

                                final bool isSelectionInList =
                                    _selectedCustomerId != null &&
                                    uniqueCustomers.containsKey(
                                      _selectedCustomerId,
                                    );

                                if (_selectedCustomerId != null &&
                                    !isSelectionInList &&
                                    state is CustomersLoaded) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted &&
                                        _selectedCustomerId != null &&
                                        !uniqueCustomers.containsKey(
                                          _selectedCustomerId,
                                        )) {
                                      setState(() {
                                        _selectedCustomerId = null;
                                        _selectedCustomer = null;
                                      });
                                    }
                                  });
                                }

                                if (isSelectionInList) {
                                  final fresh =
                                      uniqueCustomers[_selectedCustomerId]!;
                                  if (_selectedCustomer != fresh) {
                                    _selectedCustomer = fresh;
                                  }
                                }

                                final effectiveSelectedId = isSelectionInList
                                    ? _selectedCustomerId
                                    : null;

                                if (customers.isEmpty) {
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
                                          Icons.people_outline,
                                          size: 20,
                                          color:
                                              AppColors.textSecondaryLight,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            l10n.isArabic
                                                ? 'لا يوجد عملاء مسجلين حالياً. انقر على "+" لإضافة عميل جديد.'
                                                : 'No customers found. Click "+" to add a new customer.',
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

                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    DropdownButtonFormField<String?>(
                                      key: ValueKey(effectiveSelectedId),
                                      initialValue: effectiveSelectedId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: l10n.customerLabel,
                                        prefixIcon: const Icon(
                                          Icons.person_search_outlined,
                                        ),
                                      ),
                                      hint: Text(
                                        l10n.isArabic
                                            ? 'اختر العميل من القائمة...'
                                            : 'Select customer...',
                                      ),
                                      items: customers.map((c) {
                                        return DropdownMenuItem<String>(
                                          value: c.id,
                                          child: Text(
                                            c.phone.isNotEmpty
                                                ? '${c.name} (${c.phone})'
                                                : c.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (newId) {
                                        setState(() {
                                          _selectedCustomerId = newId;
                                          _selectedCustomer = newId != null
                                              ? uniqueCustomers[newId]
                                              : null;
                                        });
                                      },
                                    ),
                                    if (_selectedCustomer != null) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(
                                            AppDimensions.radiusSmall,
                                          ),
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .dividerColor
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.account_circle_outlined,
                                              size: 18,
                                              color: AppColors.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${_selectedCustomer!.name}${_selectedCustomer!.phone.isNotEmpty ? ' • ${_selectedCustomer!.phone}' : ''}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            if (_selectedCustomer!
                                                    .openingReceivable >
                                                0)
                                              Text(
                                                '${l10n.openingBalanceLabel}: ${CurrencyFormatter.format(_selectedCustomer!.openingReceivable, currency: _currency, isArabic: l10n.isArabic)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.error,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Line Items Section
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
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Text(
                                l10n.itemsSection,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton.filledTonal(
                                    icon: const Icon(
                                      Icons.qr_code_scanner,
                                      size: 20,
                                    ),
                                    tooltip: l10n.scanBarcodeBtn,
                                    onPressed: _showBarcodeScannerDialog,
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    icon: const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 20,
                                    ),
                                    tooltip: l10n.selectProductBtn,
                                    onPressed: _showProductCatalogDialog,
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add, size: 18),
                                    label: Text(l10n.addItemBtn),
                                    onPressed: () => _addItem(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 8),

                          // Dynamic Items list
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
                                      FilterChip(
                                        visualDensity: VisualDensity.compact,
                                        avatar: Icon(
                                          item.isService
                                              ? Icons.build_circle_outlined
                                              : Icons.inventory_2_outlined,
                                          size: 14,
                                          color: item.isService
                                              ? AppColors.primary
                                              : null,
                                        ),
                                        label: Text(
                                          item.isService
                                              ? l10n.serviceItemLabel
                                              : (l10n.isArabic
                                                    ? 'منتج ملموس (مخزون)'
                                                    : 'Tangible Product (Stock)'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: item.isService
                                                ? AppColors.primary
                                                : null,
                                            fontWeight: item.isService
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        selected: item.isService,
                                        onSelected: (val) {
                                          setState(() => item.isService = val);
                                        },
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

                  // Discounts and Taxes
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
                                flex: 3,
                                child: DropdownButtonFormField<DiscountType>(
                                  initialValue: _discountType,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: l10n.discountLabel,
                                    isDense: true,
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: DiscountType.fixed,
                                      child: Text(
                                        l10n.discountTypeFixed,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: DiscountType.percentage,
                                      child: Text(
                                        l10n.discountTypePercent,
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _taxRateController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n.taxRateLabel,
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
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

                  // Payment & Settlement Card
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
                                    _paymentMode ==
                                    InvoicePaymentMode.fullyPaid,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _paymentMode =
                                          InvoicePaymentMode.fullyPaid;
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
                                    _paymentMode ==
                                    InvoicePaymentMode.partiallyPaid,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _paymentMode =
                                          InvoicePaymentMode.partiallyPaid;
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
                                    _paymentMode == InvoicePaymentMode.unpaid,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _paymentMode = InvoicePaymentMode.unpaid;
                                      _paidAmountController.clear();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          if (_paymentMode ==
                              InvoicePaymentMode.partiallyPaid) ...[
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                          '${l10n.amountReceivedLabel} ($_currency)',
                                      prefixIcon: const Icon(
                                        Icons.paid_outlined,
                                      ),
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    validator: (v) {
                                      if (_paymentMode ==
                                          InvoicePaymentMode.partiallyPaid) {
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
                          if (_paymentMode != InvoicePaymentMode.unpaid) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<PaymentMethod>(
                              key: ValueKey(_paymentMethod),
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
                                if (val != null) {
                                  setState(() => _paymentMethod = val);
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Live Summary Box
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
                            context: context,
                            label: l10n.subtotalLabel,
                            value:
                                '${totals.subtotal.toStringAsFixed(2)} $_currency',
                          ),
                          if (totals.discountAmount.isPositive)
                            _buildSummaryLine(
                              context: context,
                              label: l10n.discountLabel,
                              value:
                                  '-${totals.discountAmount.toStringAsFixed(2)} $_currency',
                              color: AppColors.errorMuted,
                            ),
                          if (totals.taxAmount.isPositive) ...[
                            _buildSummaryLine(
                              context: context,
                              label: l10n.taxableBaseLabel,
                              value:
                                  '${totals.taxableBase.toStringAsFixed(2)} $_currency',
                            ),
                            _buildSummaryLine(
                              context: context,
                              label: l10n.taxAmountLabel,
                              value:
                                  '+${totals.taxAmount.toStringAsFixed(2)} $_currency',
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(
                              color: Theme.of(context).dividerColor,
                              thickness: 0.8,
                            ),
                          ),
                          _buildSummaryLine(
                            context: context,
                            label: l10n.finalTotalLabel,
                            value:
                                '${totals.finalTotal.toStringAsFixed(2)} $_currency',
                            isBold: true,
                            fontSize: 18,
                            color: AppColors.primary,
                          ),
                          if (_paymentMode ==
                              InvoicePaymentMode.partiallyPaid) ...[
                            _buildSummaryLine(
                              context: context,
                              label: l10n.amountReceivedLabel,
                              value:
                                  '${(double.tryParse(_paidAmountController.text.trim()) ?? 0.0).toStringAsFixed(2)} $_currency',
                              color: AppColors.success,
                            ),
                            _buildSummaryLine(
                              context: context,
                              label: l10n.remainingBalanceLabel,
                              value:
                                  '${(totals.finalTotal.toDouble() - (double.tryParse(_paidAmountController.text.trim()) ?? 0.0)).clamp(0.0, double.infinity).toStringAsFixed(2)} $_currency',
                              color: AppColors.error,
                              isBold: true,
                            ),
                          ] else if (_paymentMode ==
                              InvoicePaymentMode.unpaid) ...[
                            _buildSummaryLine(
                              context: context,
                              label: l10n.remainingBalanceLabel,
                              value:
                                  '${totals.finalTotal.toStringAsFixed(2)} $_currency',
                              color: AppColors.error,
                              isBold: true,
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

  Widget _buildSummaryLine({
    required BuildContext context,
    required String label,
    required String value,
    bool isBold = false,
    double fontSize = 14,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              letterSpacing: -0.2,
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
