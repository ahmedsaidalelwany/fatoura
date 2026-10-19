import 'package:flutter/material.dart';

import 'package:fatoura/core/constants/developer_config.dart';
import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
import 'package:fatoura/core/theme/app_colors.dart';
import 'developer_info_page.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.isArabic;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'عن فاتورة' : 'About Fatoura'),
      ),
      body: ResponsiveContentContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: ListView(
          children: [
            // Header: Logo & Identity
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.primary,
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
                    isAr ? 'فاتورة' : 'Fatoura',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DeveloperConfig.appName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${isAr ? "الإصدار" : "Version"} ${DeveloperConfig.appVersion}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Product Philosophy & Privacy Card
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
                        const Icon(Icons.shield_outlined,
                            color: AppColors.success, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          isAr
                              ? 'الخصوصية أولاً ومحلية البيانات'
                              : 'Local-First & Offline Privacy',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isAr
                          ? 'يعمل تطبيق فاتورة بشكل مستقل ومحلي بالكامل دون الحاجة لأي خوادم سحابية أو اشتراكات شهرية. جميع بيانات متجرك، فواتيرك، وحسابات عملائك ومورديك محفوظة فقط على جهازك وتخضع لسيطرتك التامة.'
                          : 'Fatoura operates completely offline-first with zero mandatory cloud accounts or monthly subscriptions. All your business documents, balances, and records reside exclusively on your local device under your complete control.',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Capabilities Checklist
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
                      isAr ? 'القدرات والمميزات' : 'Key Capabilities',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      icon: Icons.receipt_long_outlined,
                      title: isAr
                          ? 'إصدار الفواتير وطباعتها'
                          : 'Invoice Issuance & PDF Printing',
                      subtitle: isAr
                          ? 'إنشاء فواتير نقدية وآجلة مع دعم تصدير ملفات PDF الجاهزة للطباعة والحرارية.'
                          : 'Create cash and credit sales with high-quality printable and thermal PDFs.',
                    ),
                    _buildFeatureItem(
                      icon: Icons.calculate_outlined,
                      title: isAr
                          ? 'دقة مالية متناهية (الجنيه والقرش)'
                          : 'Exact Precision (EGP & Piastres)',
                      subtitle: isAr
                          ? 'حسابات مالية دقيقة مبنية على الأعداد العشرية المحددة دون أخطاء الفاصلة العائمة.'
                          : 'Deterministic decimal financial calculations avoiding floating-point inaccuracies.',
                    ),
                    _buildFeatureItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: isAr
                          ? 'حسابات العملاء والموردين والديون'
                          : 'Customer & Supplier Accounts',
                      subtitle: isAr
                          ? 'متابعة الأرصدة، تسديد المدفوعات، وتوليد كشوف حساب تفصيلية بحركة القيود.'
                          : 'Real-time balance tracking, multi-invoice allocations, and statement generation.',
                    ),
                    _buildFeatureItem(
                      icon: Icons.assignment_return_outlined,
                      title: isAr
                          ? 'إدارة المرتجعات والمشتريات'
                          : 'Sales Returns & Purchases',
                      subtitle: isAr
                          ? 'تسجيل فواتير المشتريات وإرجاع أصناف المبيعات واسترداد المبالغ نقدياً أو على الحساب.'
                          : 'Track procurement invoices and issue partial or full item returns securely.',
                    ),
                    _buildFeatureItem(
                      icon: Icons.backup_outlined,
                      title: isAr
                          ? 'النسخ الاحتياطي والاستعادة الذاتية'
                          : 'Self-Contained Backup & Restore',
                      subtitle: isAr
                          ? 'تصدير نسخة احتياطية كاملة بصيغة JSON واستعادتها بسهولة عند تبديل الجهاز.'
                          : 'Export complete JSON snapshots and restore them seamlessly across devices.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Platforms & Tech specs
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
                      isAr ? 'المنصات المدعومة' : 'Supported Platforms',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.android, color: Color(0xFF3DDC84)),
                        const SizedBox(width: 8),
                        Text(
                          isAr
                              ? 'أندرويد (الهواتف والأجهزة اللوحية)'
                              : 'Android (Phones & Tablets)',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.desktop_windows,
                            color: Color(0xFF0078D4)),
                        const SizedBox(width: 8),
                        Text(
                          isAr
                              ? 'ويندوز (الحواسيب المكتبية والمحمولة)'
                              : 'Windows Desktop (10 & 11)',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Navigation to Developer Info
            ListTile(
              tileColor: Colors.grey.withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              leading: const Icon(Icons.code_outlined, color: AppColors.primary),
              title: Text(
                isAr ? 'معلومات المطور والتقنية' : 'Developer & Technical Info',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                isAr
                    ? 'عرض التفاصيل التقنية ومعلومات الناشر'
                    : 'View engineering architecture and publisher details',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeveloperInfoPage()),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
