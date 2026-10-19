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
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 48,
                      height: 48,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.appName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    l10n.appTagline,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: Text(l10n.navDashboard),
              selected: _currentIndex == 0,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(l10n.navInvoices),
              selected: _currentIndex == 1,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart_outlined),
              title: Text(l10n.navPurchases),
              selected: _currentIndex == 2,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: Text(l10n.navCustomers),
              selected: _currentIndex == 3,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(l10n.navProducts),
              selected: _currentIndex == 4,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 4);
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_return_outlined),
              title: Text(l10n.navReturns),
              selected: _currentIndex == 5,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 5);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: Text(l10n.navReports),
              selected: _currentIndex == 6,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 6);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: Text(l10n.navBackup),
              selected: _currentIndex == 7,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 7);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(l10n.navSettings),
              selected: _currentIndex == 8,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 8);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.verified_outlined, color: AppColors.primary),
              title: Text(l10n.isArabic ? 'عن فاتورة' : 'About Fatoura'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.code_outlined, color: AppColors.primary),
              title: Text(l10n.isArabic ? 'معلومات المطور' : 'Developer Information'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeveloperInfoPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex >= 4 ? 4 : _currentIndex,
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
            label: l10n.allLabel,
          ),
        ],
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.isArabic;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined,
                      color: AppColors.primary),
                  title: Text(l10n.navProducts),
                  selected: _currentIndex == 4,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _currentIndex = 4);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.assignment_return_outlined,
                      color: AppColors.primary),
                  title: Text(l10n.navReturns),
                  selected: _currentIndex == 5,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _currentIndex = 5);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bar_chart_outlined,
                      color: AppColors.primary),
                  title: Text(l10n.navReports),
                  selected: _currentIndex == 6,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _currentIndex = 6);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_sync_outlined,
                      color: AppColors.primary),
                  title: Text(l10n.navBackup),
                  selected: _currentIndex == 7,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _currentIndex = 7);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined,
                      color: AppColors.primary),
                  title: Text(l10n.navSettings),
                  selected: _currentIndex == 8,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _currentIndex = 8);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.verified_outlined,
                      color: AppColors.primary),
                  title: Text(isAr ? 'عن فاتورة' : 'About Fatoura'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.code_outlined,
                      color: AppColors.primary),
                  title: Text(
                    isAr ? 'معلومات المطور' : 'Developer Information',
                  ),
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
        );
      },
    );
  }
}
