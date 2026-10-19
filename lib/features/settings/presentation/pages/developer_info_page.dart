import 'package:flutter/material.dart';

import 'package:fatoura/core/constants/developer_config.dart';
import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
import 'package:fatoura/core/theme/app_colors.dart';

class DeveloperInfoPage extends StatelessWidget {
  const DeveloperInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.isArabic;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'معلومات المطور' : 'Developer Information'),
      ),
      body: ResponsiveContentContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: ListView(
          children: [
            // Status Card (Configured vs Honest Unconfigured State)
            if (DeveloperConfig.isConfigured)
              _buildConfiguredCard(isAr)
            else
              _buildUnconfiguredCard(isAr),

            const SizedBox(height: 20),

            // Technical Architecture & Specifications
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
                      children: [
                        const Icon(Icons.memory, color: AppColors.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          isAr
                              ? 'البنية الهندسية والتكنولوجيا'
                              : 'Technical Architecture & Stack',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSpecRow(
                      isAr ? 'التطبيق' : 'Application',
                      DeveloperConfig.appName,
                    ),
                    const Divider(height: 16),
                    _buildSpecRow(
                      isAr ? 'إصدار البرنامج' : 'App Version',
                      DeveloperConfig.appVersion,
                    ),
                    const Divider(height: 16),
                    _buildSpecRow(
                      isAr ? 'بيئة التطوير' : 'Framework',
                      DeveloperConfig.framework,
                    ),
                    const Divider(height: 16),
                    _buildSpecRow(
                      isAr ? 'النمط المعماري' : 'Architecture',
                      DeveloperConfig.architecture,
                    ),
                    const Divider(height: 16),
                    _buildSpecRow(
                      isAr ? 'محرك قاعدة البيانات' : 'Database Engine',
                      DeveloperConfig.databaseEngine,
                    ),
                    const Divider(height: 16),
                    _buildSpecRow(
                      isAr ? 'محرك الدقة المالية' : 'Precision Engine',
                      DeveloperConfig.precisionEngine,
                    ),
                    const Divider(height: 16),
                    _buildSpecRow(
                      isAr ? 'المنصات المستهدفة' : 'Target Platforms',
                      DeveloperConfig.targetPlatforms,
                    ),
                    const Divider(height: 16),
                    _buildSpecRow(
                      isAr ? 'الترخيص' : 'License',
                      DeveloperConfig.license,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // How to configure developer information card
            Card(
              elevation: 0,
              color: Colors.blue.withValues(alpha: 0.04),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.blue.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isAr ? 'تخصيص معلومات الناشر' : 'Configuring Publisher Details',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAr
                          ? 'يمكن لمطوري وموزعي النظام تهيئة اسم المطور، البريد الإلكتروني للدعم، ورابط الموقع الإلكتروني من خلال تعديل ملف التكوين Authoritative Config:'
                          : 'Developers and white-label distributors can configure official developer name, support email, and website links in the configuration source:',
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const SelectableText(
                        'lib/core/constants/developer_config.dart',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnconfiguredCard(bool isAr) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_off_outlined,
                size: 40,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isAr
                  ? DeveloperConfig.unconfiguredTitleAr
                  : DeveloperConfig.unconfiguredTitleEn,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isAr
                    ? DeveloperConfig.unconfiguredMessageAr
                    : DeveloperConfig.unconfiguredMessageEn,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isAr
                  ? DeveloperConfig.unconfiguredSubtitleAr
                  : DeveloperConfig.unconfiguredSubtitleEn,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfiguredCard(bool isAr) {
    return Card(
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
              isAr ? 'الناشر / المطور' : 'Publisher / Developer',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildSpecRow(
              isAr ? 'الاسم' : 'Name',
              DeveloperConfig.developerName,
            ),
            if (DeveloperConfig.developerEmail.isNotEmpty) ...[
              const Divider(height: 16),
              _buildSpecRow(
                isAr ? 'البريد الإلكتروني' : 'Email',
                DeveloperConfig.developerEmail,
              ),
            ],
            if (DeveloperConfig.developerTelegram.isNotEmpty) ...[
              const Divider(height: 16),
              _buildSpecRow(
                isAr ? 'تيليجرام' : 'Telegram',
                DeveloperConfig.developerTelegram,
              ),
            ],
            if (DeveloperConfig.developerWebsite.isNotEmpty) ...[
              const Divider(height: 16),
              _buildSpecRow(
                isAr ? 'الموقع الإلكتروني' : 'Website',
                DeveloperConfig.developerWebsite,
              ),
            ],
            if (DeveloperConfig.githubUrl.isNotEmpty) ...[
              const Divider(height: 16),
              _buildSpecRow(
                isAr ? 'المستودع البرمجي' : 'Repository',
                DeveloperConfig.githubUrl,
              ),
            ],
            if (DeveloperConfig.supportContact.isNotEmpty &&
                DeveloperConfig.supportContact !=
                    DeveloperConfig.developerTelegram) ...[
              const Divider(height: 16),
              _buildSpecRow(
                isAr ? 'قناة الدعم' : 'Support Contact',
                DeveloperConfig.supportContact,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
