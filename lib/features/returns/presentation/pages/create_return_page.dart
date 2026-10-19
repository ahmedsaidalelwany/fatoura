import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/precision/financial_calculator.dart';
import 'package:fatoura/core/precision/money.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
import 'package:fatoura/core/theme/app_colors.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/returns/domain/entities/sales_return.dart';
import 'package:fatoura/features/returns/domain/repositories/sales_return_repository.dart';
import 'package:fatoura/features/returns/presentation/cubit/returns_cubit.dart';

class CreateReturnPage extends StatefulWidget {
  final Invoice originalInvoice;

  const CreateReturnPage({super.key, required this.originalInvoice});

  @override
  State<CreateReturnPage> createState() => _CreateReturnPageState();
}

class _CreateReturnPageState extends State<CreateReturnPage> {
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  RefundMethod _refundMethod = RefundMethod.cash;

  final Map<String, TextEditingController> _returnQtyControllers = {};
  final Map<String, double> _maxReturnable = {};
  bool _isLoadingLimits = true;

  @override
  void initState() {
    super.initState();
    _loadLimits();
  }

  Future<void> _loadLimits() async {
    final returnRepo = context.read<SalesReturnRepository>();
    for (final item in widget.originalInvoice.items) {
      final returned = await returnRepo.getReturnedQuantityForItem(item.id);
      final max = (item.quantity - returned) > 0
          ? (item.quantity - returned)
          : 0.0;
      _maxReturnable[item.id] = max;
      _returnQtyControllers[item.id] = TextEditingController(text: '0');
    }
    if (mounted) {
      setState(() => _isLoadingLimits = false);
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    for (final ctrl in _returnQtyControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  double _calculateEstimatedRefund() {
    var totalRefund = 0.0;
    final inv = widget.originalInvoice;

    for (final item in inv.items) {
      final ctrl = _returnQtyControllers[item.id];
      if (ctrl != null) {
        final qty = double.tryParse(ctrl.text.trim()) ?? 0.0;
        if (qty > 0) {
          final refund = FinancialCalculator.calculateReturnRefundAmount(
            returnedQuantity: Decimal.parse(qty.toString()),
            originalSoldQuantity: Decimal.parse(item.quantity.toString()),
            originalLineTotal: Money.fromNum(item.lineTotal, inv.currency),
            originalInvoiceSubtotal: Money.fromNum(inv.subtotal, inv.currency),
            originalInvoiceFinalTotal: Money.fromNum(
              inv.finalTotal,
              inv.currency,
            ),
          );
          totalRefund += refund.toDouble();
        }
      }
    }
    return totalRefund;
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.setupRequiredField),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final itemsToReturn =
        <({InvoiceItem invoiceItem, double returnedQuantity})>[];
    for (final item in widget.originalInvoice.items) {
      final ctrl = _returnQtyControllers[item.id];
      if (ctrl != null) {
        final qty = double.tryParse(ctrl.text.trim()) ?? 0.0;
        if (qty > 0) {
          itemsToReturn.add((invoiceItem: item, returnedQuantity: qty));
        }
      }
    }

    if (itemsToReturn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.setupRequiredField),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    context.read<ReturnsCubit>().createReturn(
      originalInvoiceId: widget.originalInvoice.id,
      itemsToReturn: itemsToReturn,
      returnReason: reason,
      refundMethod: _refundMethod,
      notes: _notesController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inv = widget.originalInvoice;

    return BlocListener<ReturnsCubit, ReturnsState>(
      listener: (context, state) {
        if (state is ReturnOperationSuccess) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
          Navigator.pop(context);
        } else if (state is ReturnsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.returnTitle)),
        body: _isLoadingLimits
            ? const Center(child: CircularProgressIndicator())
            : ResponsiveContentContainer(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header reference card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${l10n.originalInvoiceLabel}: ${inv.invoiceNumber}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${l10n.customerLabel}: ${inv.customerName.isNotEmpty ? inv.customerName : l10n.cashCustomer}',
                                style: const TextStyle(
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Returnable items
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
                              ...inv.items.map((item) {
                                final max = _maxReturnable[item.id] ?? 0.0;
                                final ctrl = _returnQtyControllers[item.id];

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.description,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '${l10n.maxReturnableQty}: $max / ${item.quantity}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors
                                                    .textSecondaryLight,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          controller: ctrl,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          decoration: InputDecoration(
                                            labelText: l10n.returnQtyLabel,
                                            isDense: true,
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
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

                      // Refund Method & Reason
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              DropdownButtonFormField<RefundMethod>(
                                initialValue: _refundMethod,
                                decoration: InputDecoration(
                                  labelText: l10n.refundMethodLabel,
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: RefundMethod.cash,
                                    child: Text(l10n.refundCash),
                                  ),
                                  DropdownMenuItem(
                                    value: RefundMethod.credit,
                                    child: Text(l10n.refundCredit),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _refundMethod = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _reasonController,
                                decoration: InputDecoration(
                                  labelText: l10n.returnReasonLabel,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _notesController,
                                decoration: InputDecoration(
                                  labelText: l10n.notesLabel,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Total Refund Preview
                      Card(
                        color: AppColors.errorBackground,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.calculatedRefundAmount,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_calculateEstimatedRefund().toStringAsFixed(2)} ${inv.currency}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: _submit,
                        child: Text(l10n.confirmReturnBtn),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
