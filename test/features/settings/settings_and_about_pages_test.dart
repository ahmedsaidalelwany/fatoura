import 'package:fatoura/core/constants/developer_config.dart';
import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/settings/app_settings_cubit.dart';
import 'package:fatoura/features/settings/presentation/pages/about_page.dart';
import 'package:fatoura/features/settings/presentation/pages/developer_info_page.dart';
import 'package:fatoura/features/settings/presentation/pages/settings_page.dart';
import 'package:fatoura/features/shop_setup/domain/entities/shop_profile.dart';
import 'package:fatoura/features/shop_setup/domain/repositories/shop_profile_repository.dart';
import 'package:fatoura/features/shop_setup/presentation/cubit/shop_setup_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeShopProfileRepository implements ShopProfileRepository {
  ShopProfile? _profile;

  FakeShopProfileRepository([this._profile]);

  @override
  Future<ShopProfile?> getProfile() async => _profile;

  @override
  Future<void> saveProfile(ShopProfile profile) async {
    _profile = profile;
  }

  @override
  Future<bool> hasCompletedSetup() async => _profile != null;
}

void main() {
  late AppSettingsCubit appSettingsCubit;
  late ShopSetupCubit shopSetupCubit;
  late FakeShopProfileRepository shopRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'app_default_currency': 'EGP',
      'app_language': 'ar',
      'app_theme_mode': 'system',
    });
    final prefs = await SharedPreferences.getInstance();
    appSettingsCubit = AppSettingsCubit(prefs);

    final now = DateTime.now();
    shopRepo = FakeShopProfileRepository(
      ShopProfile(
        id: 'shop_001',
        name: 'متجر فاتورة التجريبي',
        businessType: 'تجارة تجزئة',
        phone: '01012345678',
        address: 'القاهرة، مصر',
        defaultCurrency: 'EGP',
        taxNumber: '123456789',
        createdAt: now,
        updatedAt: now,
      ),
    );
    shopSetupCubit = ShopSetupCubit(shopRepo);
  });

  Widget buildTestableWidget(Widget child, {Locale locale = const Locale('ar')}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AppSettingsCubit>.value(value: appSettingsCubit),
        BlocProvider<ShopSetupCubit>.value(value: shopSetupCubit),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ar'),
          Locale('en'),
        ],
        home: child,
      ),
    );
  }

  group('AboutPage Widget Tests', () {
    testWidgets('Renders app identity, local privacy notice, and capabilities', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const AboutPage()));
      await tester.pumpAndSettle();

      // Check app title and version badge
      expect(find.text('عن فاتورة'), findsOneWidget);
      expect(find.text('فاتورة'), findsOneWidget);
      expect(find.textContaining('1.0.0+1'), findsOneWidget);

      // Check local-first offline privacy section
      expect(find.text('الخصوصية أولاً ومحلية البيانات'), findsOneWidget);

      // Check key capabilities
      expect(find.text('دقة مالية متناهية (الجنيه والقرش)'), findsOneWidget);
      expect(find.text('إصدار الفواتير وطباعتها'), findsOneWidget);
    });
  });

  group('DeveloperInfoPage Widget Tests', () {
    testWidgets('Renders honest unconfigured or configured state and technical architecture', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const DeveloperInfoPage()));
      await tester.pumpAndSettle();

      expect(find.text(DeveloperConfig.developerName), findsOneWidget);

      // Verify engineering specifications are displayed honestly
      expect(find.text('البنية الهندسية والتكنولوجيا'), findsOneWidget);
      expect(find.text(DeveloperConfig.framework), findsOneWidget);
      expect(find.text(DeveloperConfig.databaseEngine), findsOneWidget);
      expect(find.text(DeveloperConfig.precisionEngine), findsOneWidget);
      expect(find.text(DeveloperConfig.targetPlatforms), findsOneWidget);
    });
  });

  group('SettingsPage Widget Tests', () {
    testWidgets('Renders shop profile snapshot, currency preferences, and navigation links', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(const SettingsPage()));
      await tester.pumpAndSettle();

      // Verify Shop Profile section
      expect(find.text('متجر فاتورة التجريبي'), findsOneWidget);
      expect(find.text('01012345678'), findsOneWidget);

      // Verify Currency & Financial section
      expect(find.text('تفضيلات العملة والمالية'), findsOneWidget);
      expect(find.text('العملة الافتراضية للمتجر'), findsOneWidget);

      // Verify About & Developer navigation tiles
      await tester.scrollUntilVisible(find.text('عن تطبيق فاتورة'), 200);
      expect(find.text('عن تطبيق فاتورة'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('معلومات المطور والتقنية'), 200);
      expect(find.text('معلومات المطور والتقنية'), findsOneWidget);
    });
  });
}
