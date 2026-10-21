import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/precision/currency_formatter.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
import 'package:fatoura/core/settings/app_settings_cubit.dart';
import 'package:fatoura/core/theme/app_colors.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/invoices/domain/repositories/invoice_repository.dart';
import 'package:fatoura/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:fatoura/features/parties/domain/entities/party.dart';
import 'package:fatoura/features/parties/domain/repositories/party_repository.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';
import 'package:fatoura/features/payments/domain/repositories/payment_repository.dart';
import 'package:fatoura/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:fatoura/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:fatoura/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:fatoura/features/reports/presentation/pages/reports_page.dart';
import 'package:fatoura/features/parties/presentation/cubit/parties_cubit.dart';

class PartyDetailPage extends StatefulWidget {
  final Party party;
  final bool isCustomer;

  const PartyDetailPage({
    super.key,
    required this.party,
    required this.isCustomer,
  });

  @override
  State<PartyDetailPage> createState() => _PartyDetailPageState();
}

class _PartyDetailPageState extends State<PartyDetailPage> {
  double _balance = 0.0;
  List<Invoice> _invoices = [];
  List<PurchaseInvoice> _purchases = [];
  List<Payment> _payments = [];
  bool _isLoading = true;
  String _loadedCurrency = 'EGP';
  StreamSubscription<AppSettingsState>? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    final settingsCubit = context.read<AppSettingsCubit>();
    _loadedCurrency = settingsCubit.state.defaultCurrency;
    _settingsSubscription = settingsCubit.stream.listen((settings) {
      if (!mounted || settings.defaultCurrency == _loadedCurrency) return;
      _loadedCurrency = settings.defaultCurrency;
      _loadHistory();
    });
    _loadHistory();
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final partyRepo = context.read<PartyRepository>();
    final paymentRepo = context.read<PaymentRepository>();
    final invRepo = context.read<InvoiceRepository>();
    final purRepo = context.read<PurchaseRepository>();

    if (widget.isCustomer) {
      final currency = _loadedCurrency;
      final bal = await partyRepo.getCustomerReceivableBalance(
        widget.party.id,
        currency: currency,
      );
      final invs = (await invRepo.getInvoices(customerId: widget.party.id))
          .where((invoice) => invoice.currency == currency)
          .toList();
      final pays = (await paymentRepo.getPayments(
        partyId: widget.party.id,
        isCustomerPayment: true,
      )).where((payment) => payment.currency == currency).toList();

      if (mounted) {
        setState(() {
          _balance = bal;
          _invoices = invs;
          _payments = pays;
          _isLoading = false;
        });
      }
    } else {
      final currency = _loadedCurrency;
      final bal = await partyRepo.getSupplierPayableBalance(
        widget.party.id,
        currency: currency,
      );
      final purs = (await purRepo.getPurchases(supplierId: widget.party.id))
          .where((purchase) => purchase.currency == currency)
          .toList();
      final pays = (await paymentRepo.getPayments(
        partyId: widget.party.id,
        isCustomerPayment: false,
      )).where((payment) => payment.currency == currency).toList();

      if (mounted) {
        setState(() {
          _balance = bal;
          _purchases = purs;
          _payments = pays;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currency = context.watch<AppSettingsCubit>().state.defaultCurrency;
    final party = widget.party;

    return Scaffold(
      appBar: AppBar(
        title: Text(party.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: l10n.statementTitle,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportsPage(
                    initialReportType: widget.isCustomer
                        ? ReportType.customerStatement
                        : ReportType.supplierStatement,
                    initialPartyId: party.id,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: l10n.deleteBtn,
            onPressed: () async {
              final cubit = context.read<PartiesCubit>();
              final navigator = Navigator.of(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.deleteBtn),
                  content: Text(l10n.cancelInvoiceWarning),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l10n.cancelBtn),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l10n.deleteBtn),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await cubit.archiveParty(party.id, widget.isCustomer);
                navigator.pop();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveContentContainer(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Card
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
                                  party.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _balance > 0
                                        ? AppColors.warningBackground
                                        : AppColors.successBackground,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${l10n.currentBalanceLabel}: ${CurrencyFormatter.format(_balance, currency: currency, isArabic: l10n.isArabic)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _balance > 0
                                          ? AppColors.warning
                                          : AppColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            if (party.phone.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.phone,
                                      size: 16,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(party.phone),
                                  ],
                                ),
                              ),
                            if (party.address.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(party.address),
                                  ],
                                ),
                              ),
                            if (party.email.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.email,
                                      size: 16,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(party.email),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Documents List
                    Text(
                      widget.isCustomer ? l10n.navInvoices : l10n.navPurchases,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (widget.isCustomer) ...[
                      if (_invoices.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(child: Text(l10n.noDataFound)),
                          ),
                        )
                      else
                        ..._invoices.map(
                          (inv) => Card(
                            child: ListTile(
                              title: Text(
                                inv.invoiceNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                DateFormat('yyyy/MM/dd').format(inv.issueDate),
                              ),
                              trailing: Text(
                                '${inv.finalTotal.toStringAsFixed(2)} ${inv.currency}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        InvoiceDetailPage(invoiceId: inv.id),
                                  ),
                                ).then((_) => _loadHistory());
                              },
                            ),
                          ),
                        ),
                    ] else ...[
                      if (_purchases.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(child: Text(l10n.noDataFound)),
                          ),
                        )
                      else
                        ..._purchases.map(
                          (pur) => Card(
                            child: ListTile(
                              title: Text(
                                pur.purchaseNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                DateFormat('yyyy/MM/dd').format(pur.issueDate),
                              ),
                              trailing: Text(
                                '${pur.finalTotal.toStringAsFixed(2)} ${pur.currency}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],

                    const SizedBox(height: 24),
                    // Payments List
                    Text(
                      l10n.paymentHistoryTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_payments.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(child: Text(l10n.noDataFound)),
                        ),
                      )
                    else
                      ..._payments.map(
                        (pay) => Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.payment,
                              color: AppColors.success,
                            ),
                            title: Text(
                              '${pay.amount.toStringAsFixed(2)} ${pay.currency}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${DateFormat('yyyy/MM/dd').format(pay.paymentDate)} • ${pay.method.name}',
                            ),
                            trailing: Text(pay.referenceNumber),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
