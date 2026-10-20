import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/precision/currency.dart';
import 'package:fatoura/core/precision/currency_formatter.dart';
import 'package:fatoura/core/theme/app_colors.dart';
import 'package:fatoura/core/widgets/app_scaffold.dart';
import 'package:fatoura/features/shop_setup/domain/entities/shop_profile.dart';
import 'package:fatoura/features/shop_setup/presentation/cubit/shop_setup_cubit.dart';

/// Stable internal identifiers for business types.
/// Never store translated display strings — only these stable codes.
class BusinessType {
  static const String product = 'product';
  static const String service = 'service';
  static const String mixed = 'mixed';

  static const List<String> all = [product, service, mixed];

  /// Returns the localized display label for a business type code.
  static String label(String typeCode, {required bool isArabic}) {
    switch (typeCode) {
      case product:
        return isArabic ? 'بيع المنتجات' : 'Products';
      case service:
        return isArabic ? 'تقديم الخدمات' : 'Services';
      case mixed:
        return isArabic
            ? 'بيع المنتجات وتقديم الخدمات'
            : 'Products and Services';
      default:
        return typeCode;
    }
  }

  /// Returns a short description to guide the user during setup.
  static String description(String typeCode, {required bool isArabic}) {
    switch (typeCode) {
      case product:
        return isArabic
            ? 'متجر أو شركة تبيع بضائع ومنتجات مادية مع إدارة المخزون.'
            : 'A store or company selling physical goods with inventory tracking.';
      case service:
        return isArabic
            ? 'نشاط يقدم خدمات للعملاء دون الحاجة لإدارة مخزون فعلي.'
            : 'A business providing services to clients without physical inventory.';
      case mixed:
        return isArabic
            ? 'نشاط يجمع بين بيع المنتجات وتقديم الخدمات في نفس الفاتورة.'
            : 'A business selling both products and services, sometimes in the same invoice.';
      default:
        return '';
    }
  }

  /// Returns a safe backward-compatible default for existing installations.
  /// Preserves existing product-oriented behavior.
  static String compatibleDefault(String? stored) {
    if (stored == null || stored.trim().isEmpty) return product;
    // Migrate old free-text entries to the closest stable type
    if (all.contains(stored)) return stored;
    // Heuristic migration for common free-text values
    final lower = stored.toLowerCase();
    if (lower.contains('service') || lower.contains('خدم')) return service;
    if (lower.contains('mixed') ||
        lower.contains('مختلط') ||
        lower.contains('متنوع')) {
      return mixed;
    }
    // Default to product for any unrecognized previous value
    return product;
  }
}

class ShopSetupPage extends StatefulWidget {
  final bool isInitialSetup;

  const ShopSetupPage({super.key, this.isInitialSetup = true});

  @override
  State<ShopSetupPage> createState() => _ShopSetupPageState();
}

class _ShopSetupPageState extends State<ShopSetupPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _taxRateController = TextEditingController(text: '15.0');

  String _selectedCurrency = AppCurrencies.defaultCurrency;
  String _selectedBusinessType = BusinessType.product;
  bool _taxEnabled = false;
  String _logoPath = '';
  String _signaturePath = '';

  final List<String> _currencies = AppCurrencies.supportedCurrencyCodes;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<ShopSetupCubit>();
    if (cubit.state is ShopSetupLoaded) {
      final profile = (cubit.state as ShopSetupLoaded).profile;
      if (profile != null) {
        _populateFromProfile(profile);
      }
    } else {
      cubit.loadProfile();
    }
  }

  void _populateFromProfile(ShopProfile profile) {
    _nameController.text = profile.name;
    _phoneController.text = profile.phone;
    _addressController.text = profile.address;
    _taxNumberController.text = profile.taxNumber;
    _taxRateController.text = profile.defaultTaxRate.toString();
    _selectedCurrency = profile.defaultCurrency;
    _taxEnabled = profile.defaultTaxEnabled;
    _logoPath = profile.logoPath;
    _signaturePath = profile.signaturePath;
    // Migrate any old free-text business type value to a stable code
    _selectedBusinessType = BusinessType.compatibleDefault(
      profile.businessType,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _taxNumberController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (file != null && file.path != null) {
        final originalPath = file.path!;
        final appDir = await getApplicationDocumentsDirectory();
        final ext = p.extension(originalPath);
        final targetPath = p.join(appDir.path, 'shop_logo$ext');
        await File(originalPath).copy(targetPath);
        setState(() => _logoPath = targetPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickSignature() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (file != null && file.path != null) {
        final originalPath = file.path!;
        final appDir = await getApplicationDocumentsDirectory();
        final ext = p.extension(originalPath);
        final targetPath = p.join(appDir.path, 'shop_signature$ext');
        await File(originalPath).copy(targetPath);
        setState(() => _signaturePath = targetPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<ShopSetupCubit>().saveProfile(
        name: _nameController.text,
        businessType: _selectedBusinessType, // Always a stable code
        phone: _phoneController.text,
        address: _addressController.text,
        defaultCurrency: _selectedCurrency,
        taxNumber: _taxNumberController.text,
        defaultTaxEnabled: _taxEnabled,
        defaultTaxRate: double.tryParse(_taxRateController.text) ?? 15.0,
        logoPath: _logoPath,
        signaturePath: _signaturePath,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.isArabic;

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
          _populateFromProfile(state.profile!);
          setState(() {});
        }
      },
      builder: (context, state) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.setupTitle),
            automaticallyImplyLeading: !widget.isInitialSetup,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 32.0,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.surfaceSubtleDark
                                    : AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusCard,
                                ),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                  width: 0.8,
                                ),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child:
                                    (_logoPath.isNotEmpty &&
                                        File(_logoPath).existsSync())
                                    ? Image.file(
                                        File(_logoPath),
                                        fit: BoxFit.contain,
                                      )
                                    : Image.asset(
                                        'assets/images/logo.png',
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.receipt_long,
                                                    color: Colors.white,
                                                    size: 36,
                                                  ),
                                                ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.image_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    _logoPath.isEmpty
                                        ? l10n.pickLogoBtn
                                        : l10n.changeLogoBtn,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: _pickLogo,
                                ),
                                if (_logoPath.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                      color: AppColors.error,
                                    ),
                                    label: Text(
                                      l10n.removeLogoBtn,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.error,
                                      ),
                                    ),
                                    onPressed: () =>
                                        setState(() => _logoPath = ''),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.setupTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.setupSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 28),

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

                      // Business Type — structured dropdown instead of free text
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.shopTypeLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...BusinessType.all.map((type) {
                            final isSelected = _selectedBusinessType == type;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedBusinessType = type),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Theme.of(context).dividerColor,
                                    width: isSelected ? 1.5 : 0.8,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusControl,
                                  ),
                                  color: isSelected
                                      ? AppColors.primary.withValues(
                                          alpha: 0.08,
                                        )
                                      : (isDark
                                            ? AppColors.surfaceSubtleDark
                                            : AppColors.surfaceSubtle),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            BusinessType.label(
                                              type,
                                              isArabic: isAr,
                                            ),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            BusinessType.description(
                                              type,
                                              isArabic: isAr,
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? AppColors.textSecondaryDark
                                                  : AppColors
                                                        .textSecondaryLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
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
                        isExpanded: true,
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

                      const SizedBox(height: 24),

                      // Electronic Signature & Stamp Section
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 0.8,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusCard,
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
                                    Icons.draw_outlined,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.shopSignatureLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.isArabic
                                    ? 'أضف صورة التوقيع الإلكتروني أو ختم المنشأة ليظهر أسفل الفواتير المطبوعة'
                                    : 'Add an electronic signature or official stamp image to appear on printed invoices',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_signaturePath.isNotEmpty &&
                                  File(_signaturePath).existsSync()) ...[
                                Center(
                                  child: Container(
                                    height: 70,
                                    width: 180,
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.surfaceSubtleDark
                                          : AppColors.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusControl,
                                      ),
                                      border: Border.all(
                                        color: Theme.of(context).dividerColor,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Image.file(
                                      File(_signaturePath),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: Text(l10n.changeSignatureBtn),
                                      onPressed: _pickSignature,
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                        color: AppColors.error,
                                      ),
                                      label: Text(
                                        l10n.removeSignatureBtn,
                                        style: const TextStyle(
                                          color: AppColors.error,
                                        ),
                                      ),
                                      onPressed: () =>
                                          setState(() => _signaturePath = ''),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.file_upload_outlined,
                                    size: 18,
                                  ),
                                  label: Text(l10n.pickSignatureBtn),
                                  onPressed: _pickSignature,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusControl,
                            ),
                          ),
                        ),
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
