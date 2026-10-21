import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/precision/currency_formatter.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
import 'package:fatoura/core/settings/app_settings_cubit.dart';
import 'package:fatoura/core/theme/app_colors.dart';
import 'package:fatoura/features/parties/domain/entities/party.dart';
import 'package:fatoura/features/parties/presentation/cubit/parties_cubit.dart';

import 'party_detail_page.dart';

class PartiesPage extends StatefulWidget {
  const PartiesPage({super.key});

  @override
  State<PartiesPage> createState() => _PartiesPageState();
}

class _PartiesPageState extends State<PartiesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  StreamSubscription<AppSettingsState>? _settingsSubscription;
  String? _balanceCurrency;
  int _lastRequestedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabControllerChange);
    final settingsCubit = context.read<AppSettingsCubit>();
    _balanceCurrency = settingsCubit.state.defaultCurrency;
    _settingsSubscription = settingsCubit.stream.listen((settings) {
      if (!mounted || settings.defaultCurrency == _balanceCurrency) return;
      _balanceCurrency = settings.defaultCurrency;
      _loadData();
    });
    _loadData();
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabControllerChange() {
    if (_tabController.indexIsChanging) return;
    final index = _tabController.index;
    if (index == _lastRequestedTabIndex) return;
    _lastRequestedTabIndex = index;
    _loadData();
  }

  void _loadData() {
    final query = _searchController.text.trim();
    final currency = context.read<AppSettingsCubit>().state.defaultCurrency;
    final partiesCubit = context.read<PartiesCubit>();
    if (_tabController.index == 0) {
      partiesCubit.loadCustomers(query: query, currency: currency);
    } else {
      partiesCubit.loadSuppliers(query: query, currency: currency);
    }
  }

  void _showAddEditPartyDialog(
    BuildContext context, {
    Party? existingParty,
    bool isCustomerTab = true,
  }) {
    final l10n = AppLocalizations.of(context);
    final defaultCurrency = context
        .read<AppSettingsCubit>()
        .state
        .defaultCurrency;
    final nameCtrl = TextEditingController(text: existingParty?.name ?? '');
    final phoneCtrl = TextEditingController(text: existingParty?.phone ?? '');
    final addressCtrl = TextEditingController(
      text: existingParty?.address ?? '',
    );
    final emailCtrl = TextEditingController(text: existingParty?.email ?? '');
    final notesCtrl = TextEditingController(text: existingParty?.notes ?? '');
    final openingCtrl = TextEditingController(
      text: existingParty != null
          ? (isCustomerTab
                    ? existingParty.openingReceivable
                    : existingParty.openingPayable)
                .toString()
          : '0.0',
    );

    bool isCustomer = existingParty?.isCustomer ?? isCustomerTab;
    bool isSupplier = existingParty?.isSupplier ?? !isCustomerTab;
    final openingCurrency = existingParty != null
        ? (isCustomerTab
              ? existingParty.openingReceivableCurrency
              : existingParty.openingPayableCurrency)
        : defaultCurrency;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existingParty != null
                ? l10n.editBtn
                : (isCustomerTab
                      ? l10n.actionAddCustomer
                      : l10n.actionAddSupplier),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: l10n.nameLabel),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: l10n.phoneLabel),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  decoration: InputDecoration(labelText: l10n.addressLabel),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: l10n.emailLabel),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: openingCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '${l10n.openingBalanceLabel} ($openingCurrency)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(labelText: l10n.notesLabel),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: Text(l10n.customerLabel),
                  value: isCustomer,
                  onChanged: (val) =>
                      setDialogState(() => isCustomer = val ?? false),
                ),
                CheckboxListTile(
                  title: Text(l10n.supplierLabel),
                  value: isSupplier,
                  onChanged: (val) =>
                      setDialogState(() => isSupplier = val ?? false),
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

                final opening = double.tryParse(openingCtrl.text.trim()) ?? 0.0;

                context.read<PartiesCubit>().saveParty(
                  id: existingParty?.id,
                  name: name,
                  phone: phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                  isCustomer: isCustomer,
                  isSupplier: isSupplier,
                  openingReceivable: isCustomer ? opening : 0.0,
                  openingReceivableCurrency:
                      existingParty?.openingReceivableCurrency ??
                      defaultCurrency,
                  openingPayable: isSupplier ? opening : 0.0,
                  openingPayableCurrency:
                      existingParty?.openingPayableCurrency ??
                      defaultCurrency,
                );
                Navigator.pop(ctx);
                _loadData();
              },
              child: Text(l10n.saveBtn),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.navCustomers} / ${l10n.navSuppliers}'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(
              text: l10n.navCustomers,
              icon: const Icon(Icons.person_outline),
            ),
            Tab(
              text: l10n.navSuppliers,
              icon: const Icon(Icons.business_outlined),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditPartyDialog(
              context,
              isCustomerTab: _tabController.index == 0,
            ),
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
                          _loadData();
                        },
                      )
                    : null,
              ),
              onChanged: (_) => _loadData(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCustomersTab(context),
                  _buildSuppliersTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomersTab(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currency = context.watch<AppSettingsCubit>().state.defaultCurrency;

    return BlocBuilder<PartiesCubit, PartiesState>(
      builder: (context, state) {
        if (state is PartiesLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is CustomersLoaded) {
          final customers = state.customers;
          if (customers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 56,
                    color: AppColors.textSecondaryLight,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.noDataFound,
                    style: const TextStyle(color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
            );
          }

          final isDark = Theme.of(context).brightness == Brightness.dark;

          return ListView.separated(
            itemCount: customers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final c = customers[index];
              final balance = state.balances[c.id] ?? 0.0;

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2838)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    c.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: -0.2,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: Text(
                    c.phone.isNotEmpty
                        ? c.phone
                        : (c.address.isNotEmpty ? c.address : '-'),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(
                          balance,
                          currency: currency,
                          isArabic: l10n.isArabic,
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.2,
                          color: balance > 0
                              ? AppColors.warningMuted
                              : AppColors.successMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.currentBalanceLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PartyDetailPage(party: c, isCustomer: true),
                      ),
                    ).then((_) => _loadData());
                  },
                ),
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSuppliersTab(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currency = context.watch<AppSettingsCubit>().state.defaultCurrency;

    return BlocBuilder<PartiesCubit, PartiesState>(
      builder: (context, state) {
        if (state is PartiesLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is SuppliersLoaded) {
          final suppliers = state.suppliers;
          if (suppliers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.business_outlined,
                    size: 56,
                    color: AppColors.textSecondaryLight,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.noDataFound,
                    style: const TextStyle(color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
            );
          }

          final isDark = Theme.of(context).brightness == Brightness.dark;

          return ListView.separated(
            itemCount: suppliers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final s = suppliers[index];
              final balance = state.balances[s.id] ?? 0.0;

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF221A33)
                          : const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.business_outlined,
                      color: AppColors.secondary,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    s.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: -0.2,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: Text(
                    s.phone.isNotEmpty
                        ? s.phone
                        : (s.address.isNotEmpty ? s.address : '-'),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(
                          balance,
                          currency: currency,
                          isArabic: l10n.isArabic,
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.2,
                          color: balance > 0
                              ? AppColors.errorMuted
                              : AppColors.successMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.currentBalanceLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PartyDetailPage(party: s, isCustomer: false),
                      ),
                    ).then((_) => _loadData());
                  },
                ),
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
