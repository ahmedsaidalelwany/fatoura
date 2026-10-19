import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fatoura/core/constants/developer_config.dart';
import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/precision/currency.dart';
import 'package:fatoura/core/precision/currency_formatter.dart';
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
                      title: isAr ? 'ملف المتجر والنشاط' : 'Shop & Business Profile',
                    ),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: AppColors.borderLight),
                        borderRadius: BorderRadius.circular(12),
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
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (profile?.businessType.isNotEmpty ==
                                          true) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          profile!.businessType,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondaryLight,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(80, 36),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                  ),
                                  icon: const Icon(Icons.edit_outlined, size: 16),
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
                                      context
                                          .read<ShopSetupCubit>()
                                          .loadProfile();
                                    });
                                  },
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                              isAr ? 'رقم الهاتف' : 'Phone',
                              profile?.phone.isNotEmpty == true
                                  ? profile!.phone
                                  : (isAr ? 'غير محدد' : 'Not set'),
                            ),
                            const SizedBox(height: 6),
                            _buildInfoRow(
                              isAr ? 'العنوان' : 'Address',
                              profile?.address.isNotEmpty == true
                                  ? profile!.address
                                  : (isAr ? 'غير محدد' : 'Not set'),
                            ),
                            const SizedBox(height: 6),
                            _buildInfoRow(
                              isAr ? 'الرقم الضريبي' : 'Tax Number',
                              profile?.taxNumber.isNotEmpty == true
                                  ? profile!.taxNumber
                                  : (isAr ? 'غير مسجل' : 'None'),
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
                    ),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: AppColors.borderLight),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAr ? 'العملة الافتراضية للمتجر' : 'Default Shop Currency',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isAr
                                  ? 'تطبق العملة المختارة على المستندات الجديدة. المستندات السابقة تحتفظ بعملتها التاريخية.'
                                  : 'Selected currency applies to new documents. Historical documents preserve their saved currency.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: appSettings.defaultCurrency,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.monetization_on_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
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
                                          defaultTaxEnabled:
                                              profile.defaultTaxEnabled,
                                          defaultTaxRate:
                                              profile.defaultTaxRate,
                                        );
                                  }
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Text(
                              l10n.settingsInvoicePrefix,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.numberingRuleDesc,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight,
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
                    ),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: AppColors.borderLight),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<ThemeMode>(
                            title: Text(l10n.themeSystem),
                            secondary: const Icon(Icons.brightness_auto_outlined),
                            value: ThemeMode.system,
                            groupValue: appSettings.themeMode,
                            onChanged: (mode) {
                              if (mode != null) {
                                context
                                    .read<AppSettingsCubit>()
                                    .setThemeMode(mode);
                              }
                            },
                          ),
                          RadioListTile<ThemeMode>(
                            title: Text(l10n.themeLight),
                            secondary: const Icon(Icons.light_mode_outlined),
                            value: ThemeMode.light,
                            groupValue: appSettings.themeMode,
                            onChanged: (mode) {
                              if (mode != null) {
                                context
                                    .read<AppSettingsCubit>()
                                    .setThemeMode(mode);
                              }
                            },
                          ),
                          RadioListTile<ThemeMode>(
                            title: Text(l10n.themeDark),
                            secondary: const Icon(Icons.dark_mode_outlined),
                            value: ThemeMode.dark,
                            groupValue: appSettings.themeMode,
                            onChanged: (mode) {
                              if (mode != null) {
                                context
                                    .read<AppSettingsCubit>()
                                    .setThemeMode(mode);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section D: Language
                    _buildSectionHeader(
                      icon: Icons.language_outlined,
                      title: isAr ? 'اللغة' : 'Language',
                    ),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: AppColors.borderLight),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text('العربية (Arabic)'),
                            secondary: const Text(
                              'ع',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            value: 'ar',
                            groupValue: appSettings.locale.languageCode,
                            onChanged: (val) {
                              if (val != null) {
                                context
                                    .read<AppSettingsCubit>()
                                    .setLocale(Locale(val));
                              }
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('English (الإنجليزية)'),
                            secondary: const Text(
                              'En',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            value: 'en',
                            groupValue: appSettings.locale.languageCode,
                            onChanged: (val) {
                              if (val != null) {
                                context
                                    .read<AppSettingsCubit>()
                                    .setLocale(Locale(val));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section E: Backup & Data
                    _buildSectionHeader(
                      icon: Icons.cloud_sync_outlined,
                      title: isAr ? 'النسخ الاحتياطي والبيانات' : 'Backup & Data',
                    ),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: AppColors.borderLight),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.backup_outlined,
                            color: AppColors.primary),
                        title: Text(l10n.navBackup),
                        subtitle: Text(
                          isAr
                              ? 'تصدير نسخة احتياطية كاملة أو استعادة بيانات متجرك'
                              : 'Export full JSON backup or restore shop data',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
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
                    ),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: AppColors.borderLight),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.verified_outlined,
                                color: AppColors.primary),
                            title: Text(isAr ? 'عن تطبيق فاتورة' : 'About Fatoura'),
                            subtitle: Text(
                              isAr
                                  ? 'رؤية التطبيق، الميزات، والخصوصية المحلية'
                                  : 'App vision, capabilities, and offline privacy',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AboutPage(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.code_outlined,
                                color: AppColors.primary),
                            title: Text(
                              isAr ? 'معلومات المطور والتقنية' : 'Developer Information',
                            ),
                            subtitle: Text(
                              isAr
                                  ? 'معلومات الناشر والهندسة البرمجية للتطبيق'
                                  : 'Publisher info and engineering architecture',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right),
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.appTagline,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight,
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0, right: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondaryLight,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
