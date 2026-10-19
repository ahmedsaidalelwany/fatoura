import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/pdf/invoice_pdf_generator.dart';
import 'package:fatoura/core/precision/currency_formatter.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
import 'package:fatoura/core/theme/app_colors.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/invoices/domain/repositories/invoice_repository.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';
import 'package:fatoura/features/payments/presentation/cubit/payments_cubit.dart';
import 'package:fatoura/features/returns/presentation/pages/create_return_page.dart';
import 'package:fatoura/features/invoices/presentation/cubit/invoices_cubit.dart';

class InvoiceDetailPage extends StatefulWidget {
  final String invoiceId;

  const InvoiceDetailPage({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  Invoice? _invoice;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() => _isLoading = true);
    final repo = context.read<InvoiceRepository>();
    final inv = await repo.getInvoiceById(widget.invoiceId);
    if (mounted) {
      setState(() {
        _invoice = inv;
        _isLoading = false;
      });
      if (inv != null) {
        context.read<PaymentsCubit>().loadPayments(partyId: inv.customerId);
      }
    }
  }

  void _showRecordPaymentDialog() {
    if (_invoice == null) return;
    final l10n = AppLocalizations.of(context);
    final amountCtrl = TextEditingController(
      text: _invoice!.remainingBalance.toStringAsFixed(2),
    );
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    PaymentMethod method = PaymentMethod.cash;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.actionRecordPayment),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${l10n.remainingBalanceLabel}: ${CurrencyFormatter.format(_invoice!.remainingBalance, currency: _invoice!.currency, isArabic: l10n.isArabic)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.paymentAmountLabel,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PaymentMethod>(
                  initialValue: method,
                  decoration: InputDecoration(
                    labelText: l10n.paymentMethodLabel,
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
                  controller: refCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.paymentReferenceLabel,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
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
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (amount <= 0.0) return;

                final messenger = ScaffoldMessenger.of(context);
                final paymentsCubit = context.read<PaymentsCubit>();
                final inv = _invoice!;
                final ref = refCtrl.text.trim();
                final notes = notesCtrl.text.trim();

                Navigator.pop(ctx);
                final success = await paymentsCubit.recordPayment(
                  amount: amount,
                  method: method,
                  partyId: inv.customerId,
                  partyName: inv.customerName,
                  isCustomerPayment: true,
                  invoiceId: inv.id,
                  invoiceNumber: inv.invoiceNumber,
                  referenceNumber: ref,
                  notes: notes,
                  currency: inv.currency,
                );

                if (success && mounted) {
                  _loadInvoice();
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.successMsg)),
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

  void _showCancelDialog() {
    if (_invoice == null) return;
    final l10n = AppLocalizations.of(context);
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelInvoiceTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.cancelInvoiceWarning,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.cancelReasonLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.closeBtn),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              if (reasonCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                await context.read<InvoicesCubit>().cancelInvoice(
                  _invoice!.id,
                  reasonCtrl.text.trim(),
                );
                _loadInvoice();
              }
            },
            child: Text(l10n.confirmCancelBtn),
          ),
        ],
      ),
    );
  }

  Future<void> _previewOrPrintPdf({bool isArabic = true}) async {
    if (_invoice == null) return;
    final pdfBytes = await InvoicePdfGenerator.generateInvoicePdf(
      invoice: _invoice!,
      isArabic: isArabic,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: '${_invoice!.invoiceNumber}.pdf',
    );
  }

  Future<void> _shareInvoicePdf({bool isArabic = true}) async {
    if (_invoice == null) return;
    final pdfBytes = await InvoicePdfGenerator.generateInvoicePdf(
      invoice: _invoice!,
      isArabic: isArabic,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '${_invoice!.invoiceNumber}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_invoice == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.noDataFound)),
      );
    }

    final invoice = _invoice!;
    final dateStr = DateFormat('yyyy/MM/dd HH:mm').format(invoice.issueDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(invoice.invoiceNumber),
        actions: [
          // Print / Preview PDF
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: l10n.previewPdfBtn,
            onPressed: () => _previewOrPrintPdf(isArabic: l10n.isArabic),
          ),
          // Share PDF
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: l10n.shareDocumentBtn,
            onPressed: () => _shareInvoicePdf(isArabic: l10n.isArabic),
          ),
        ],
      ),
      body: ResponsiveContentContainer(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invoice.shopName.isNotEmpty
                                    ? invoice.shopName
                                    : l10n.appName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: AppColors.primary,
                                ),
                              ),
                              if (invoice.shopPhone.isNotEmpty)
                                Text(
                                  invoice.shopPhone,
                                  style: const TextStyle(
                                    color: AppColors.textSecondaryLight,
                                    fontSize: 12,
                                  ),
                                ),
                              if (invoice.shopAddress.isNotEmpty)
                                Text(
                                  invoice.shopAddress,
                                  style: const TextStyle(
                                    color: AppColors.textSecondaryLight,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          _buildStatusBadge(context, invoice),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${l10n.invoiceDate}: $dateStr',
                            style: const TextStyle(fontSize: 13),
                          ),
                          Text(
                            '${l10n.customerLabel}: ${invoice.customerName.isNotEmpty ? invoice.customerName : l10n.cashCustomer}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (invoice.isCancelled &&
                          invoice.cancellationReason != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.errorBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${l10n.cancelReasonLabel}: ${invoice.cancellationReason}',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Items Breakdown Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.itemsSection,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const Divider(),
                      ...invoice.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  item.description,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${item.quantity} × ${item.unitPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondaryLight,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(
                                  item.lineTotal,
                                  currency: invoice.currency,
                                  isArabic: l10n.isArabic,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Financial Totals Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildRow(
                        l10n.subtotalLabel,
                        CurrencyFormatter.format(
                          invoice.subtotal,
                          currency: invoice.currency,
                          isArabic: l10n.isArabic,
                        ),
                      ),
                      if (invoice.discountAmount > 0)
                        _buildRow(
                          l10n.discountLabel,
                          '-${CurrencyFormatter.format(invoice.discountAmount, currency: invoice.currency, isArabic: l10n.isArabic)}',
                          color: AppColors.error,
                        ),
                      if (invoice.taxAmount > 0) ...[
                        _buildRow(
                          l10n.taxableBaseLabel,
                          CurrencyFormatter.format(
                            invoice.taxableBase,
                            currency: invoice.currency,
                            isArabic: l10n.isArabic,
                          ),
                        ),
                        _buildRow(
                          '${l10n.taxAmountLabel} (${invoice.taxRate}%)',
                          '+${CurrencyFormatter.format(invoice.taxAmount, currency: invoice.currency, isArabic: l10n.isArabic)}',
                        ),
                      ],
                      const Divider(thickness: 1.5),
                      _buildRow(
                        l10n.finalTotalLabel,
                        CurrencyFormatter.format(
                          invoice.finalTotal,
                          currency: invoice.currency,
                          isArabic: l10n.isArabic,
                        ),
                        isBold: true,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                      _buildRow(
                        l10n.amountPaidLabel,
                        CurrencyFormatter.format(
                          invoice.totalPaid,
                          currency: invoice.currency,
                          isArabic: l10n.isArabic,
                        ),
                        color: AppColors.success,
                      ),
                      _buildRow(
                        l10n.remainingBalanceLabel,
                        CurrencyFormatter.format(
                          invoice.remainingBalance,
                          currency: invoice.currency,
                          isArabic: l10n.isArabic,
                        ),
                        isBold: true,
                        color: invoice.remainingBalance > 0
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              if (!invoice.isCancelled) ...[
                Row(
                  children: [
                    if (invoice.remainingBalance > 0) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.payment),
                          label: Text(l10n.actionRecordPayment),
                          onPressed: _showRecordPaymentDialog,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.assignment_return_outlined),
                        label: Text(l10n.actionNewReturn),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CreateReturnPage(originalInvoice: invoice),
                            ),
                          ).then((_) => _loadInvoice());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: AppColors.error,
                  ),
                  label: Text(
                    l10n.cancelInvoiceTitle,
                    style: const TextStyle(color: AppColors.error),
                  ),
                  onPressed: _showCancelDialog,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 13,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
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

  Widget _buildStatusBadge(BuildContext context, Invoice invoice) {
    final l10n = AppLocalizations.of(context);
    final String label;
    final Color color;
    final Color bg;

    if (invoice.isCancelled) {
      label = l10n.statusCancelled;
      color = AppColors.error;
      bg = AppColors.errorBackground;
    } else if (invoice.remainingBalance == 0) {
      label = l10n.paymentStatusPaid;
      color = AppColors.success;
      bg = AppColors.successBackground;
    } else if (invoice.totalPaid > 0) {
      label = l10n.paymentStatusPartial;
      color = AppColors.warning;
      bg = AppColors.warningBackground;
    } else {
      label = l10n.paymentStatusUnpaid;
      color = AppColors.primary;
      bg = const Color(0xFFEFF6FF);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
