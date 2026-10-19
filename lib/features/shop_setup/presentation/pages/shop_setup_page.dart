import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/precision/currency.dart';
import 'package:fatoura/core/precision/currency_formatter.dart';
import 'package:fatoura/core/theme/app_colors.dart';
import 'package:fatoura/core/widgets/app_scaffold.dart';
import 'package:fatoura/features/shop_setup/presentation/cubit/shop_setup_cubit.dart';

class ShopSetupPage extends StatefulWidget {
  final bool isInitialSetup;

  const ShopSetupPage({super.key, this.isInitialSetup = true});

  @override
  State<ShopSetupPage> createState() => _ShopSetupPageState();
}

class _ShopSetupPageState extends State<ShopSetupPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _taxRateController = TextEditingController(text: '15.0');

  String _selectedCurrency = AppCurrencies.defaultCurrency;
  bool _taxEnabled = false;

  final List<String> _currencies = AppCurrencies.supportedCurrencyCodes;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<ShopSetupCubit>();
    if (cubit.state is ShopSetupLoaded) {
      final profile = (cubit.state as ShopSetupLoaded).profile;
      if (profile != null) {
        _nameController.text = profile.name;
        _typeController.text = profile.businessType;
        _phoneController.text = profile.phone;
        _addressController.text = profile.address;
        _taxNumberController.text = profile.taxNumber;
        _taxRateController.text = profile.defaultTaxRate.toString();
        _selectedCurrency = profile.defaultCurrency;
        _taxEnabled = profile.defaultTaxEnabled;
      }
    } else {
      cubit.loadProfile();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _taxNumberController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<ShopSetupCubit>().saveProfile(
        name: _nameController.text,
        businessType: _typeController.text,
        phone: _phoneController.text,
        address: _addressController.text,
        defaultCurrency: _selectedCurrency,
        taxNumber: _taxNumberController.text,
        defaultTaxEnabled: _taxEnabled,
        defaultTaxRate: double.tryParse(_taxRateController.text) ?? 15.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocConsumer<ShopSetupCubit, ShopSetupState>(
      listener: (context, state) {
        if (state is ShopSetupSuccess) {
          if (widget.isInitialSetup) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AppScaffold()),
            );
          } else {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l10n.successMsg)));
            Navigator.of(context).pop();
          }
        } else if (state is ShopSetupError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        } else if (state is ShopSetupLoaded && state.profile != null) {
          final p = state.profile!;
          _nameController.text = p.name;
          _typeController.text = p.businessType;
          _phoneController.text = p.phone;
          _addressController.text = p.address;
          _taxNumberController.text = p.taxNumber;
          _taxRateController.text = p.defaultTaxRate.toString();
          setState(() {
            _selectedCurrency = p.defaultCurrency;
            _taxEnabled = p.defaultTaxEnabled;
          });
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.setupTitle),
            automaticallyImplyLeading: !widget.isInitialSetup,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 72,
                            height: 72,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.setupTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.setupSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Shop Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: l10n.shopNameLabel,
                          prefixIcon: const Icon(Icons.storefront_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? l10n.setupRequiredField
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Business Type
                      TextFormField(
                        controller: _typeController,
                        decoration: InputDecoration(
                          labelText: l10n.shopTypeLabel,
                          prefixIcon: const Icon(Icons.business_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? l10n.setupRequiredField
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Phone Number
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: l10n.shopPhoneLabel,
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Address
                      TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          labelText: l10n.shopAddressLabel,
                          prefixIcon: const Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Default Currency Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: _currencies.contains(_selectedCurrency)
                            ? _selectedCurrency
                            : AppCurrencies.defaultCurrency,
                        decoration: InputDecoration(
                          labelText: l10n.defaultCurrencyLabel,
                          prefixIcon: const Icon(Icons.attach_money_outlined),
                        ),
                        items: _currencies
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  CurrencyFormatter.getLocalizedDisplayName(
                                    c,
                                    isArabic: l10n.isArabic,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCurrency = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Tax Number
                      TextFormField(
                        controller: _taxNumberController,
                        decoration: InputDecoration(
                          labelText: l10n.taxNumberLabel,
                          prefixIcon: const Icon(Icons.tag_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Default Tax Toggle
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.taxEnabledLabel),
                        value: _taxEnabled,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) => setState(() => _taxEnabled = val),
                      ),

                      if (_taxEnabled) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _taxRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.taxRateLabel,
                            prefixIcon: const Icon(Icons.percent_outlined),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      ElevatedButton(
                        onPressed: state is ShopSetupLoading ? null : _submit,
                        child: state is ShopSetupLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.isInitialSetup
                                    ? l10n.completeSetupBtn
                                    : l10n.saveBtn,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
