import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fatoura/core/constants/developer_config.dart';
import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/precision/currency.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
import 'package:fatoura/core/settings/app_settings_cubit.dart';
import 'package:fatoura/core/theme/app_colors.dart';
import 'package:fatoura/features/backup/presentation/pages/backup_page.dart';
import 'package:fatoura/features/shop_setup/presentation/cubit/shop_setup_cubit.dart';
import 'package:fatoura/features/shop_setup/presentation/pages/shop_setup_page.dart';

import 'about_page.dart';
import 'developer_info_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    context.read<ShopSetupCubit>().loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ResponsiveContentContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: BlocBuilder<AppSettingsCubit, AppSettingsState>(
          builder: (context, appSettings) {
            return BlocBuilder<ShopSetupCubit, ShopSetupState>(
              builder: (context, shopState) {
                final profile = shopState is ShopSetupLoaded
                    ? shopState.profile
                    : null;

                return ListView(
                  children: [
                    // Section A: Shop Profile
                    _buildSectionHeader(
                      icon: Icons.storefront_outlined,
                      title: isAr
                          ? 'ملف المتجر والنشاط'
                          : 'Shop & Business Profile',
                      isDark: isDark,
                    ),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile?.name.isNotEmpty == true
                                            ? profile!.name
                                            : (isAr
                                                  ? 'متجر فاتورة'
                                                  : 'Fatoura Shop'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (profile?.businessType.isNotEmpty ==
                                          true) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          profile!.businessType,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(80, 34),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 15,
                                  ),
                                  label: Text(isAr ? 'تعديل' : 'Edit'),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ShopSetupPage(
                                          isInitialSetup: false,
                                        ),
                                      ),
                                    ).then((_) {
                                      if (context.mounted) {
                                        context
                                            .read<ShopSetupCubit>()
                                            .loadProfile();
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            const Divider(height: 24, thickness: 0.8),
                            _buildInfoRow(
                              isAr ? 'رقم الهاتف' : 'Phone',
                              profile?.phone.isNotEmpty == true
                                  ? profile!.phone
                                  : (isAr ? 'غير محدد' : 'Not set'),
                              isDark,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              isAr ? 'العنوان' : 'Address',
                              profile?.address.isNotEmpty == true
                                  ? profile!.address
                                  : (isAr ? 'غير محدد' : 'Not set'),
                              isDark,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              isAr ? 'الرقم الضريبي' : 'Tax Number',
                              profile?.taxNumber.isNotEmpty == true
                                  ? profile!.taxNumber
                                  : (isAr ? 'غير مسجل' : 'None'),
                              isDark,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              isAr ? 'شعار المتجر' : 'Shop Logo',
                              profile?.logoPath.isNotEmpty == true
                                  ? (isAr ? 'محدد ✓' : 'Configured ✓')
                                  : (isAr ? 'غير محدد' : 'Not set'),
                              isDark,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              isAr ? 'التوقيع والختم' : 'Signature & Stamp',
                              profile?.signaturePath.isNotEmpty == true
                                  ? (isAr ? 'محدد ✓' : 'Configured ✓')
                                  : (isAr ? 'غير محدد' : 'Not set'),
                              isDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section B: Currency & Financial Preferences
                    _buildSectionHeader(
                      icon: Icons.payments_outlined,
                      title: isAr
                          ? 'تفضيلات العملة والمالية'
                          : 'Currency & Financial Preferences',
                      isDark: isDark,
                    ),
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
                            Text(
                              isAr
                                  ? 'العملة الافتراضية للمتجر'
                                  : 'Default Shop Currency',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isAr
                                  ? 'تطبق العملة المختارة على المستندات الجديدة. المستندات السابقة تحتفظ بعملتها التاريخية.'
                                  : 'Selected currency applies to new documents. Historical documents preserve their saved currency.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: appSettings.defaultCurrency,
                              isExpanded: true,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.monetization_on_outlined,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusControl,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              items: AppCurrencies.supported
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.code,
                                      child: Text(
                                        '${isAr ? c.nameAr : c.nameEn} (${c.code})',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (newCurrency) {
                                if (newCurrency != null) {
                                  context
                                      .read<AppSettingsCubit>()
                                      .setDefaultCurrency(newCurrency);
                                  // Also sync shop profile currency if available
                                  if (profile != null) {
                                    context.read<ShopSetupCubit>().saveProfile(
                                      name: profile.name,
                                      businessType: profile.businessType,
                                      phone: profile.phone,
                                      address: profile.address,
                                      defaultCurrency: newCurrency,
                                      taxNumber: profile.taxNumber,
                                      logoPath: profile.logoPath,
                                      signaturePath: profile.signaturePath,
                                      defaultTaxEnabled:
                                          profile.defaultTaxEnabled,
                                      defaultTaxRate: profile.defaultTaxRate,
                                    );
                                  }
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1, thickness: 0.8),
                            const SizedBox(height: 12),
                            Text(
                              l10n.settingsInvoicePrefix,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.numberingRuleDesc,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section C: Appearance
                    _buildSectionHeader(
                      icon: Icons.palette_outlined,
                      title: isAr ? 'المظهر والسمة' : 'Appearance',
                      isDark: isDark,
                    ),
                    Card(
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusCard,
                        ),
                      ),
                      child: RadioGroup<ThemeMode>(
                        groupValue: appSettings.themeMode,
                        onChanged: (mode) {
                          if (mode != null) {
                            context.read<AppSettingsCubit>().setThemeMode(mode);
                          }
                        },
                        child: Column(
                          children: [
                            RadioListTile<ThemeMode>(
                              title: Text(l10n.themeSystem),
                              secondary: const Icon(
                                Icons.brightness_auto_outlined,
                              ),
                              value: ThemeMode.system,
                            ),
                            const Divider(height: 1, thickness: 0.8),
                            RadioListTile<ThemeMode>(
                              title: Text(l10n.themeLight),
                              secondary: const Icon(Icons.light_mode_outlined),
                              value: ThemeMode.light,
                            ),
                            const Divider(height: 1, thickness: 0.8),
                            RadioListTile<ThemeMode>(
                              title: Text(l10n.themeDark),
                              secondary: const Icon(Icons.dark_mode_outlined),
                              value: ThemeMode.dark,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section D: Language
                    _buildSectionHeader(
                      icon: Icons.language_outlined,
                      title: isAr ? 'اللغة' : 'Language',
                      isDark: isDark,
                    ),
                    Card(
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusCard,
                        ),
                      ),
                      child: RadioGroup<String>(
                        groupValue: appSettings.locale.languageCode,
                        onChanged: (val) {
                          if (val != null) {
                            context.read<AppSettingsCubit>().setLocale(
                              Locale(val),
                            );
                          }
                        },
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              title: const Text('العربية (Arabic)'),
                              secondary: Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'ع',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              value: 'ar',
                            ),
                            const Divider(height: 1, thickness: 0.8),
                            RadioListTile<String>(
                              title: const Text('English (الإنجليزية)'),
                              secondary: Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'En',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              value: 'en',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section E: Backup & Data
                    _buildSectionHeader(
                      icon: Icons.cloud_sync_outlined,
                      title: isAr
                          ? 'النسخ الاحتياطي والبيانات'
                          : 'Backup & Data',
                      isDark: isDark,
                    ),
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
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.backup_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(l10n.navBackup),
                        subtitle: Text(
                          isAr
                              ? 'تصدير نسخة احتياطية كاملة أو استعادة بيانات متجرك'
                              : 'Export full JSON backup or restore shop data',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BackupPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section F & G: About & Developer Information
                    _buildSectionHeader(
                      icon: Icons.info_outline,
                      title: isAr ? 'حول التطبيق' : 'About & Developer',
                      isDark: isDark,
                    ),
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
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.verified_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              isAr ? 'عن تطبيق فاتورة' : 'About Fatoura',
                            ),
                            subtitle: Text(
                              isAr
                                  ? 'رؤية التطبيق، الميزات، والخصوصية المحلية'
                                  : 'App vision, capabilities, and offline privacy',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AboutPage(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1, thickness: 0.8),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.code_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              isAr
                                  ? 'معلومات المطور والتقنية'
                                  : 'Developer Information',
                            ),
                            subtitle: Text(
                              isAr
                                  ? 'معلومات الناشر والهندسة البرمجية للتطبيق'
                                  : 'Publisher info and engineering architecture',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DeveloperInfoPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Footer branding
                    Center(
                      child: Column(
                        children: [
                          Text(
                            '${DeveloperConfig.appName} • ${DeveloperConfig.appVersion}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.appTagline,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8.0,
        left: 4.0,
        right: 4.0,
        top: 4.0,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceSubtleDark
                  : AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
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

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
