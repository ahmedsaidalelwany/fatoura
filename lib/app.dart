import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'bootstrap.dart';
import 'core/localization/app_localizations.dart';
import 'core/settings/app_settings_cubit.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_scaffold.dart';
import 'features/backup/presentation/cubit/backup_cubit.dart';
import 'features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'features/invoices/presentation/cubit/invoices_cubit.dart';
import 'features/parties/presentation/cubit/parties_cubit.dart';
import 'features/payments/presentation/cubit/payments_cubit.dart';
import 'features/products/presentation/cubit/products_cubit.dart';
import 'features/purchases/presentation/cubit/purchases_cubit.dart';
import 'features/returns/presentation/cubit/returns_cubit.dart';
import 'features/reports/presentation/cubit/reports_cubit.dart';
import 'features/shop_setup/presentation/cubit/shop_setup_cubit.dart';
import 'features/shop_setup/presentation/pages/shop_setup_page.dart';

class FatouraApp extends StatelessWidget {
  final AppDependencies dependencies;

  const FatouraApp({super.key, required this.dependencies});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: dependencies.shopProfileRepository),
        RepositoryProvider.value(value: dependencies.partyRepository),
        RepositoryProvider.value(value: dependencies.productRepository),
        RepositoryProvider.value(value: dependencies.invoiceRepository),
        RepositoryProvider.value(value: dependencies.paymentRepository),
        RepositoryProvider.value(value: dependencies.returnRepository),
        RepositoryProvider.value(value: dependencies.purchaseRepository),
        RepositoryProvider.value(value: dependencies.auditRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: dependencies.appSettingsCubit),
          BlocProvider(
            create: (_) =>
                ShopSetupCubit(dependencies.shopProfileRepository)
                  ..loadProfile(),
          ),
          BlocProvider(
            create: (_) => DashboardCubit(
              invoiceRepository: dependencies.invoiceRepository,
              purchaseRepository: dependencies.purchaseRepository,
              paymentRepository: dependencies.paymentRepository,
              partyRepository: dependencies.partyRepository,
            ),
          ),
          BlocProvider(
            create: (_) => InvoicesCubit(
              invoiceRepository: dependencies.invoiceRepository,
              shopProfileRepository: dependencies.shopProfileRepository,
              sequenceManager: dependencies.sequenceManager,
              auditRepository: dependencies.auditRepository,
            ),
          ),
          BlocProvider(
            create: (_) => PaymentsCubit(
              paymentRepository: dependencies.paymentRepository,
              invoiceRepository: dependencies.invoiceRepository,
              auditRepository: dependencies.auditRepository,
            ),
          ),
          BlocProvider(
            create: (_) => PartiesCubit(dependencies.partyRepository),
          ),
          BlocProvider(
            create: (_) => ProductsCubit(dependencies.productRepository),
          ),
          BlocProvider(
            create: (_) => PurchasesCubit(
              purchaseRepository: dependencies.purchaseRepository,
              shopProfileRepository: dependencies.shopProfileRepository,
              sequenceManager: dependencies.sequenceManager,
              auditRepository: dependencies.auditRepository,
            ),
          ),
          BlocProvider(
            create: (_) => ReturnsCubit(
              returnRepository: dependencies.returnRepository,
              invoiceRepository: dependencies.invoiceRepository,
              sequenceManager: dependencies.sequenceManager,
              auditRepository: dependencies.auditRepository,
            ),
          ),
          BlocProvider(
            create: (_) => ReportsCubit(
              invoiceRepository: dependencies.invoiceRepository,
              purchaseRepository: dependencies.purchaseRepository,
              paymentRepository: dependencies.paymentRepository,
              returnRepository: dependencies.returnRepository,
              partyRepository: dependencies.partyRepository,
            ),
          ),
          BlocProvider(create: (_) => BackupCubit(dependencies.backupService)),
        ],
        child: BlocBuilder<AppSettingsCubit, AppSettingsState>(
          builder: (context, settingsState) {
            return MaterialApp(
              title: 'فاتورة - Fatoura',
              debugShowCheckedModeBanner: false,
              themeMode: settingsState.themeMode,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              locale: settingsState.locale,
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: FutureBuilder<bool>(
                future: dependencies.shopProfileRepository.hasCompletedSetup(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final hasCompleted = snapshot.data ?? false;
                  if (hasCompleted) {
                    return const AppScaffold();
                  }
                  return const ShopSetupPage(isInitialSetup: true);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
