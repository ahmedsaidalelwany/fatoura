import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/precision/currency_formatter.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
import 'package:fatoura/core/theme/app_colors.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';
import 'package:fatoura/features/purchases/domain/entities/purchase_invoice.dart';
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

  void _showConfirmReceiptDialog(PurchaseInvoice pur) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(l10n.isArabic ? 'تأكيد استلام البضاعة' : 'Confirm Stock Receipt'),
          ],
        ),
        content: Text(
          l10n.isArabic
              ? 'هل تؤكد استلام جميع أصناف أمر الشراء (${pur.purchaseNumber}) وإضافتها إلى المخزون وتحديث أسعار التكلفة؟'
              : 'Do you confirm receipt of all items for purchase (${pur.purchaseNumber}) to increment inventory and update costs?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancelBtn),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context
                  .read<PurchasesCubit>()
                  .confirmStockReceipt(pur.id);
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n.isArabic
                          ? 'تم استلام البضاعة وتحديث المخزون بنجاح'
                          : 'Stock received and inventory updated',
                    ),
                  ),
                );
              }
            },
            child: Text(l10n.isArabic ? 'تأكيد واستلام' : 'Confirm & Receive'),
          ),
        ],
      ),
    );
  }

  void _showRecordPaymentDialog(PurchaseInvoice pur) {
    final l10n = AppLocalizations.of(context);
    final amountCtrl = TextEditingController(
      text: pur.remainingPayable.toStringAsFixed(2),
    );
    final notesCtrl = TextEditingController();
    PaymentMethod method = PaymentMethod.cash;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.isArabic ? 'تسجيل دفعة للمورد' : 'Record Supplier Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.supplierLabel}: ${pur.supplierName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.remainingBalanceLabel}: ${CurrencyFormatter.format(pur.remainingPayable, currency: pur.currency, isArabic: l10n.isArabic)}',
                  style: const TextStyle(color: AppColors.errorMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${l10n.isArabic ? 'المبلغ المدفوع' : 'Amount'} (${pur.currency})',
                    prefixIcon: const Icon(Icons.paid_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PaymentMethod>(
                  value: method,
                  decoration: InputDecoration(
                    labelText: l10n.paymentMethodLabel,
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
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
                    if (val != null) setDialogState(() => method = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.notesLabel,
                  ),
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
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (amount <= 0 || amount > pur.remainingPayable) return;
                Navigator.pop(ctx);
                final success = await context
                    .read<PurchasesCubit>()
                    .recordSupplierPayment(
                      purchaseId: pur.id,
                      amount: amount,
                      method: method,
                      notes: notesCtrl.text.trim(),
                    );
                if (mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.isArabic
                            ? 'تم تسجيل الدفعة للمورد بنجاح'
                            : 'Supplier payment recorded successfully',
                      ),
                    ),
                  );
                }
              },
              child: Text(l10n.saveBtn),
            ),
          ],
        ),
      ),
    );
  }

  void _showPurchaseReturnDialog(PurchaseInvoice pur) {
    final l10n = AppLocalizations.of(context);
    if (pur.items.isEmpty) return;

    PurchaseInvoiceItem selectedItem = pur.items.first;
    final qtyCtrl = TextEditingController(text: '1');
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.isArabic ? 'تسجيل مرتجع مشتريات' : 'Record Purchase Return'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<PurchaseInvoiceItem>(
                  value: selectedItem,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.isArabic ? 'الصنف المرتجع' : 'Returned Item',
                  ),
                  items: pur.items.map((it) {
                    return DropdownMenuItem(
                      value: it,
                      child: Text(
                        '${it.description} (${l10n.isArabic ? 'الكمية المشتراة' : 'Qty'}: ${it.quantity})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedItem = val;
                        qtyCtrl.text = val.quantity.toString();
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.isArabic ? 'كمية المرتجع' : 'Return Quantity',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.isArabic ? 'سبب الإرجاع' : 'Return Reason',
                  ),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
                if (qty <= 0) return;
                Navigator.pop(ctx);
                final refundAmount = qty * selectedItem.unitPrice;
                final success = await context
                    .read<PurchasesCubit>()
                    .recordPurchaseReturn(
                      purchaseId: pur.id,
                      productId: selectedItem.productId ?? '',
                      returnQuantity: qty,
                      reason: reasonCtrl.text.trim().isNotEmpty
                          ? reasonCtrl.text.trim()
                          : (l10n.isArabic ? 'مرتجع مشتريات' : 'Purchase return'),
                      refundAmount: refundAmount,
                    );
                if (mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.isArabic
                            ? 'تم خصم كمية المرتجع من المخزون بنجاح'
                            : 'Return recorded and stock adjusted',
                      ),
                    ),
                  );
                }
              },
              child: Text(l10n.isArabic ? 'تأكيد الإرجاع' : 'Confirm Return'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
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
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                            side: BorderSide(
                              color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF221A33)
                                            : const Color(0xFFF5F3FF),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.shopping_bag_outlined,
                                        color: AppColors.secondary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pur.purchaseNumber,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              letterSpacing: -0.2,
                                              color: isDark
                                                  ? AppColors.textPrimaryDark
                                                  : AppColors.textPrimaryLight,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${l10n.supplierLabel}: ${pur.supplierName} • $dateStr',
                                            style: TextStyle(
                                              color: isDark
                                                  ? AppColors.textSecondaryDark
                                                  : AppColors.textSecondaryLight,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          CurrencyFormatter.format(
                                            pur.finalTotal,
                                            currency: pur.currency,
                                            isArabic: l10n.isArabic,
                                          ),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            letterSpacing: -0.2,
                                            color: isDark
                                                ? AppColors.textPrimaryDark
                                                : AppColors.textPrimaryLight,
                                          ),
                                        ),
                                        if (pur.remainingPayable > 0)
                                          Text(
                                            '${l10n.remainingBalanceLabel}: ${CurrencyFormatter.format(pur.remainingPayable, currency: pur.currency, isArabic: l10n.isArabic)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.errorMuted,
                                            ),
                                          ),
                                      ],
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 20),
                                      onSelected: (action) {
                                        if (action == 'confirm_stock') {
                                          _showConfirmReceiptDialog(pur);
                                        } else if (action == 'pay') {
                                          _showRecordPaymentDialog(pur);
                                        } else if (action == 'return') {
                                          _showPurchaseReturnDialog(pur);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        if (!pur.isStockReceived)
                                          PopupMenuItem(
                                            value: 'confirm_stock',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                                                const SizedBox(width: 8),
                                                Text(l10n.isArabic ? 'تأكيد استلام المخزون' : 'Confirm Stock Receipt'),
                                              ],
                                            ),
                                          ),
                                        if (pur.remainingPayable > 0)
                                          PopupMenuItem(
                                            value: 'pay',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.payment, color: AppColors.primary, size: 18),
                                                const SizedBox(width: 8),
                                                Text(l10n.isArabic ? 'تسجيل دفعة للمورد' : 'Record Supplier Payment'),
                                              ],
                                            ),
                                          ),
                                        if (!pur.isDraft && pur.isStockReceived)
                                          PopupMenuItem(
                                            value: 'return',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.assignment_return_outlined, color: AppColors.error, size: 18),
                                                const SizedBox(width: 8),
                                                Text(l10n.isArabic ? 'مرتجع مشتريات' : 'Purchase Return'),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    // Stock receipt badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: pur.isStockReceived
                                            ? AppColors.successBackground
                                            : AppColors.warningBackground,
                                        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                                        border: Border.all(
                                          color: pur.isStockReceived
                                              ? AppColors.success
                                              : AppColors.warning,
                                          width: 0.6,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            pur.isStockReceived ? Icons.inventory : Icons.pending_actions,
                                            size: 11,
                                            color: pur.isStockReceived ? AppColors.success : AppColors.warning,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            pur.isStockReceived
                                                ? (l10n.isArabic ? 'مستلم بالمخزون' : 'Stock Received')
                                                : (l10n.isArabic ? 'في انتظار الاستلام' : 'Pending Receipt'),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: pur.isStockReceived ? AppColors.success : AppColors.warning,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Payment status badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: pur.remainingPayable == 0
                                            ? AppColors.successBackground
                                            : (pur.amountPaid > 0 ? AppColors.warningBackground : AppColors.errorBackground),
                                        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                                        border: Border.all(
                                          color: pur.remainingPayable == 0
                                              ? AppColors.success
                                              : (pur.amountPaid > 0 ? AppColors.warning : AppColors.error),
                                          width: 0.6,
                                        ),
                                      ),
                                      child: Text(
                                        pur.remainingPayable == 0
                                            ? (l10n.isArabic ? 'مسددة بالكامل' : 'Fully Paid')
                                            : (pur.amountPaid > 0
                                                ? (l10n.isArabic ? 'مسددة جزئياً' : 'Partially Paid')
                                                : (l10n.isArabic ? 'غير مسددة' : 'Unpaid')),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: pur.remainingPayable == 0
                                              ? AppColors.success
                                              : (pur.amountPaid > 0 ? AppColors.warning : AppColors.error),
                                        ),
                                      ),
                                    ),
                                    if (pur.isDraft)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.infoBackground,
                                          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                                        ),
                                        child: Text(
                                          l10n.isArabic ? 'مسودة' : 'Draft',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
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
