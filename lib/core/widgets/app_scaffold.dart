import 'package:flutter/material.dart';

import 'package:fatoura/features/backup/presentation/pages/backup_page.dart';
import 'package:fatoura/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:fatoura/features/invoices/presentation/pages/invoices_list_page.dart';
import 'package:fatoura/features/parties/presentation/pages/parties_page.dart';
import 'package:fatoura/features/products/presentation/pages/products_page.dart';
import 'package:fatoura/features/purchases/presentation/pages/purchases_page.dart';
import 'package:fatoura/features/reports/presentation/pages/reports_page.dart';
import 'package:fatoura/features/returns/presentation/pages/returns_page.dart';
import 'package:fatoura/features/settings/presentation/pages/about_page.dart';
import 'package:fatoura/features/settings/presentation/pages/developer_info_page.dart';
import 'package:fatoura/features/settings/presentation/pages/settings_page.dart';
import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/responsive/responsive_layout.dart';
import 'package:fatoura/core/theme/app_colors.dart';

class AppScaffold extends StatefulWidget {
  final int initialIndex;

  const AppScaffold({super.key, this.initialIndex = 0});

  @override
  State<AppScaffold> createState() => AppScaffoldState();
}

class AppScaffoldState extends State<AppScaffold> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void navigateToTab(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  final List<Widget> _pages = const [
    DashboardPage(),
    InvoicesListPage(),
    PurchasesPage(),
    PartiesPage(),
    ProductsPage(),
    ReturnsPage(),
    ReportsPage(),
    BackupPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDesktopOrTablet = ResponsiveLayout.isWide(context);

    if (isDesktopOrTablet) {
      return Scaffold(
        body: Row(
          children: [
            LayoutBuilder(
              builder: (context, constraint) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraint.maxHeight),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        selectedIndex: _currentIndex,
                        onDestinationSelected: (idx) =>
                            setState(() => _currentIndex = idx),
                        labelType: NavigationRailLabelType.all,
                        leading: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 44,
                                  height: 44,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.appName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        destinations: [
                          NavigationRailDestination(
                            icon: const Icon(Icons.dashboard_outlined),
                            selectedIcon: const Icon(Icons.dashboard),
                            label: Text(l10n.navDashboard),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.receipt_long_outlined),
                            selectedIcon: const Icon(Icons.receipt_long),
                            label: Text(l10n.navInvoices),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.shopping_cart_outlined),
                            selectedIcon: const Icon(Icons.shopping_cart),
                            label: Text(l10n.navPurchases),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.people_outline),
                            selectedIcon: const Icon(Icons.people),
                            label: Text(l10n.navCustomers),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.inventory_2_outlined),
                            selectedIcon: const Icon(Icons.inventory_2),
                            label: Text(l10n.navProducts),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.assignment_return_outlined),
                            selectedIcon: const Icon(Icons.assignment_return),
                            label: Text(l10n.navReturns),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.bar_chart_outlined),
                            selectedIcon: const Icon(Icons.bar_chart),
                            label: Text(l10n.navReports),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.cloud_sync_outlined),
                            selectedIcon: const Icon(Icons.cloud_sync),
                            label: Text(l10n.navBackup),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.settings_outlined),
                            selectedIcon: const Icon(Icons.settings),
                            label: Text(l10n.navSettings),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: _pages),
            ),
          ],
        ),
      );
    }

    // Mobile Layout: Bottom navigation for primary 5 actions + drawer for secondary
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final dividerColor = Theme.of(context).dividerColor;

    return Scaffold(
      drawer: Drawer(
        backgroundColor: surfaceColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                border: Border(bottom: BorderSide(color: dividerColor, width: 0.8)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 48,
                      height: 48,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.appName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.appTagline,
                          style: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildDrawerTile(
              context: context,
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard,
              title: l10n.navDashboard,
              selected: _currentIndex == 0,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
            ),
            _buildDrawerTile(
              context: context,
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long,
              title: l10n.navInvoices,
              selected: _currentIndex == 1,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 1);
              },
            ),
            _buildDrawerTile(
              context: context,
              icon: Icons.shopping_cart_outlined,
              activeIcon: Icons.shopping_cart,
              title: l10n.navPurchases,
              selected: _currentIndex == 2,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 2);
              },
            ),
            _buildDrawerTile(
              context: context,
              icon: Icons.people_outline,
              activeIcon: Icons.people,
              title: l10n.navCustomers,
              selected: _currentIndex == 3,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 3);
              },
            ),
            _buildDrawerTile(
              context: context,
              icon: Icons.inventory_2_outlined,
              activeIcon: Icons.inventory_2,
              title: l10n.navProducts,
              selected: _currentIndex == 4,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 4);
              },
            ),
            _buildDrawerTile(
              context: context,
              icon: Icons.assignment_return_outlined,
              activeIcon: Icons.assignment_return,
              title: l10n.navReturns,
              selected: _currentIndex == 5,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 5);
              },
            ),
            _buildDrawerTile(
              context: context,
              icon: Icons.bar_chart_outlined,
              activeIcon: Icons.bar_chart,
              title: l10n.navReports,
              selected: _currentIndex == 6,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 6);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(color: dividerColor, thickness: 0.8),
            ),
            _buildDrawerTile(
              context: context,
              icon: Icons.cloud_sync_outlined,
              activeIcon: Icons.cloud_sync,
              title: l10n.navBackup,
              selected: _currentIndex == 7,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 7);
              },
            ),
            _buildDrawerTile(
              context: context,
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
              title: l10n.navSettings,
              selected: _currentIndex == 8,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 8);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(color: dividerColor, thickness: 0.8),
            ),
            _buildDrawerTile(
              context: context,
              icon: Icons.verified_outlined,
              activeIcon: Icons.verified,
              title: l10n.isArabic ? 'عن فاتورة' : 'About Fatoura',
              selected: false,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutPage()),
                );
              },
            ),
            _buildDrawerTile(
              context: context,
              icon: Icons.code_outlined,
              activeIcon: Icons.code,
              title: l10n.isArabic ? 'معلومات المطور' : 'Developer Information',
              selected: false,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeveloperInfoPage()),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(
            top: BorderSide(color: dividerColor, width: 0.8),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex >= 4 ? 4 : _currentIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          onTap: (idx) {
            if (idx == 4) {
              _showMoreMenu(context);
            } else {
              setState(() => _currentIndex = idx);
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard_outlined),
              activeIcon: const Icon(Icons.dashboard),
              label: l10n.navDashboard,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.receipt_long_outlined),
              activeIcon: const Icon(Icons.receipt_long),
              label: l10n.navInvoices,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.shopping_cart_outlined),
              activeIcon: const Icon(Icons.shopping_cart),
              label: l10n.navPurchases,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.people_outline),
              activeIcon: const Icon(Icons.people),
              label: l10n.navCustomers,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.more_horiz),
              activeIcon: const Icon(Icons.more_horiz),
              label: l10n.allLabel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected
            ? primaryColor.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  size: 22,
                  color: selected
                      ? primaryColor
                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? primaryColor
                          : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.isArabic;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMoreMenuItem(
                    ctx: ctx,
                    icon: Icons.inventory_2_outlined,
                    iconBg: const Color(0xFF5856D6),
                    title: l10n.navProducts,
                    isSelected: _currentIndex == 4,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _currentIndex = 4);
                    },
                  ),
                  _buildMoreMenuItem(
                    ctx: ctx,
                    icon: Icons.assignment_return_outlined,
                    iconBg: const Color(0xFFFF9500),
                    title: l10n.navReturns,
                    isSelected: _currentIndex == 5,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _currentIndex = 5);
                    },
                  ),
                  _buildMoreMenuItem(
                    ctx: ctx,
                    icon: Icons.bar_chart_outlined,
                    iconBg: const Color(0xFF34C759),
                    title: l10n.navReports,
                    isSelected: _currentIndex == 6,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _currentIndex = 6);
                    },
                  ),
                  _buildMoreMenuItem(
                    ctx: ctx,
                    icon: Icons.cloud_sync_outlined,
                    iconBg: const Color(0xFF007AFF),
                    title: l10n.navBackup,
                    isSelected: _currentIndex == 7,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _currentIndex = 7);
                    },
                  ),
                  _buildMoreMenuItem(
                    ctx: ctx,
                    icon: Icons.settings_outlined,
                    iconBg: const Color(0xFF8E8E93),
                    title: l10n.navSettings,
                    isSelected: _currentIndex == 8,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _currentIndex = 8);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Divider(
                      color: Theme.of(context).dividerColor,
                      thickness: 0.8,
                    ),
                  ),
                  _buildMoreMenuItem(
                    ctx: ctx,
                    icon: Icons.verified_outlined,
                    iconBg: AppColors.primary,
                    title: isAr ? 'عن فاتورة' : 'About Fatoura',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutPage()),
                      );
                    },
                  ),
                  _buildMoreMenuItem(
                    ctx: ctx,
                    icon: Icons.code_outlined,
                    iconBg: const Color(0xFF32ADE6),
                    title: isAr ? 'معلومات المطور' : 'Developer Information',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(ctx);
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
          ),
        );
      },
    );
  }

  Widget _buildMoreMenuItem({
    required BuildContext ctx,
    required IconData icon,
    required Color iconBg,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: iconBg.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: iconBg, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 18,
        color: Colors.black26,
      ),
      onTap: onTap,
    );
  }
}
