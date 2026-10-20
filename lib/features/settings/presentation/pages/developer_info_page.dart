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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr ? 'معلومات المطور والتقنية' : 'Developer & Architecture',
        ),
      ),
      body: ResponsiveContentContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: ListView(
          children: [
            // Developer Identity Card
            _buildDeveloperCard(isAr, isDark, context),

            const SizedBox(height: 20),

            // Technical Architecture & Specifications
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 0.8,
                ),
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.memory,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isAr
                              ? 'البنية الهندسية والتكنولوجيا'
                              : 'Technical Architecture & Stack',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSpecRow(
                      isAr ? 'التطبيق' : 'Application',
                      DeveloperConfig.appName,
                      isDark,
                    ),
                    const Divider(height: 16, thickness: 0.8),
                    _buildSpecRow(
                      isAr ? 'إصدار البرنامج' : 'App Version',
                      DeveloperConfig.appVersion,
                      isDark,
                    ),
                    const Divider(height: 16, thickness: 0.8),
                    _buildSpecRow(
                      isAr ? 'بيئة التطوير' : 'Framework',
                      DeveloperConfig.framework,
                      isDark,
                    ),
                    const Divider(height: 16, thickness: 0.8),
                    _buildSpecRow(
                      isAr ? 'النمط المعماري' : 'Architecture',
                      DeveloperConfig.architecture,
                      isDark,
                    ),
                    const Divider(height: 16, thickness: 0.8),
                    _buildSpecRow(
                      isAr ? 'محرك قاعدة البيانات' : 'Database Engine',
                      DeveloperConfig.databaseEngine,
                      isDark,
                    ),
                    const Divider(height: 16, thickness: 0.8),
                    _buildSpecRow(
                      isAr ? 'محرك الدقة المالية' : 'Precision Engine',
                      DeveloperConfig.precisionEngine,
                      isDark,
                    ),
                    const Divider(height: 16, thickness: 0.8),
                    _buildSpecRow(
                      isAr ? 'المنصات المستهدفة' : 'Target Platforms',
                      DeveloperConfig.targetPlatforms,
                      isDark,
                    ),
                    const Divider(height: 16, thickness: 0.8),
                    _buildSpecRow(
                      isAr ? 'الترخيص' : 'License',
                      DeveloperConfig.license,
                      isDark,
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

  Widget _buildDeveloperCard(bool isAr, bool isDark, BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor, width: 0.8),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isAr ? 'المطور المعتمد' : 'Developer & Author',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSpecRow(
              isAr ? 'الاسم' : 'Name',
              DeveloperConfig.developerName,
              isDark,
            ),
            if (DeveloperConfig.developerEmail.isNotEmpty) ...[
              const Divider(height: 16, thickness: 0.8),
              _buildSpecRow(
                isAr ? 'البريد الإلكتروني' : 'Email',
                DeveloperConfig.developerEmail,
                isDark,
              ),
            ],
            if (DeveloperConfig.developerTelegram.isNotEmpty) ...[
              const Divider(height: 16, thickness: 0.8),
              _buildSpecRow(
                isAr ? 'تيليجرام' : 'Telegram',
                DeveloperConfig.developerTelegram,
                isDark,
              ),
            ],
            if (DeveloperConfig.githubUrl.isNotEmpty) ...[
              const Divider(height: 16, thickness: 0.8),
              _buildSpecRow(
                isAr ? 'المستودع البرمجي' : 'Repository',
                DeveloperConfig.githubUrl,
                isDark,
              ),
            ],
            const Divider(height: 16, thickness: 0.8),
            _buildSpecRow(
              isAr ? 'الترخيص القانوني' : 'Software License',
              DeveloperConfig.license,
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(width: 16),
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
