import 'dart:io';

import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/core/storage/sequence_manager.dart';
import 'package:fatoura/features/audit/data/repositories/audit_repository_impl.dart';
import 'package:fatoura/features/invoices/data/repositories/invoice_repository_impl.dart';
import 'package:fatoura/features/invoices/presentation/cubit/invoices_cubit.dart';
import 'package:fatoura/features/invoices/presentation/pages/create_invoice_page.dart';
import 'package:fatoura/features/parties/data/repositories/party_repository_impl.dart';
import 'package:fatoura/features/parties/domain/entities/party.dart';
import 'package:fatoura/features/parties/presentation/cubit/parties_cubit.dart';
import 'package:fatoura/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:fatoura/features/products/data/repositories/product_repository_impl.dart';
import 'package:fatoura/features/products/presentation/cubit/products_cubit.dart';
import 'package:fatoura/features/shop_setup/data/repositories/shop_profile_repository_impl.dart';
import 'package:fatoura/features/shop_setup/domain/entities/shop_profile.dart';
import 'package:fatoura/features/shop_setup/presentation/cubit/shop_setup_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveDatabase db;
  late PartyRepositoryImpl partyRepo;
  late ShopProfileRepositoryImpl shopRepo;
  late ProductRepositoryImpl productRepo;
  late InvoiceRepositoryImpl invoiceRepo;
  late PaymentRepositoryImpl paymentRepo;
  late AuditRepositoryImpl auditRepo;
  late SequenceManager sequenceManager;

  late PartiesCubit partiesCubit;
  late ProductsCubit productsCubit;
  late ShopSetupCubit shopSetupCubit;
  late InvoicesCubit invoicesCubit;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'fatoura_party_dropdown_test_',
    );
    db = HiveDatabase.instance;
    await db.init(customPath: tempDir.path);

    partyRepo = PartyRepositoryImpl(db);
    shopRepo = ShopProfileRepositoryImpl(db);
    productRepo = ProductRepositoryImpl(db);
    invoiceRepo = InvoiceRepositoryImpl(db);
    auditRepo = AuditRepositoryImpl(db);
    sequenceManager = SequenceManager(db);
    paymentRepo = PaymentRepositoryImpl(
      database: db,
      invoiceRepository: invoiceRepo,
    );

    final now = DateTime.now();
    await shopRepo.saveProfile(
      ShopProfile(
        id: 'shop_001',
        name: 'متجر التجربة',
        businessType: 'تجارة تجزئة',
        defaultCurrency: 'EGP',
        createdAt: now,
        updatedAt: now,
      ),
    );

    partiesCubit = PartiesCubit(partyRepo);
    productsCubit = ProductsCubit(productRepo);
    shopSetupCubit = ShopSetupCubit(shopRepo)..loadProfile();
    invoicesCubit = InvoicesCubit(
      invoiceRepository: invoiceRepo,
      shopProfileRepository: shopRepo,
      sequenceManager: sequenceManager,
      auditRepository: auditRepo,
      productRepository: productRepo,
      paymentRepository: paymentRepo,
    );
  });

  tearDown(() async {
    await partiesCubit.close();
    await productsCubit.close();
    await shopSetupCubit.close();
    await invoicesCubit.close();
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget buildTestApp() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PartiesCubit>.value(value: partiesCubit),
        BlocProvider<ProductsCubit>.value(value: productsCubit),
        BlocProvider<ShopSetupCubit>.value(value: shopSetupCubit),
        BlocProvider<InvoicesCubit>.value(value: invoicesCubit),
      ],
      child: const MaterialApp(
        locale: Locale('ar'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('ar'), Locale('en')],
        home: CreateInvoicePage(),
      ),
    );
  }

  group('Part A — Dropdown Crash & Party Selection Regression Tests', () {
    testWidgets('1. A valid selected Party renders correctly in existing customer mode', (
      tester,
    ) async {
      final now = DateTime.now();
      final p1 = Party(
        id: 'cust_01',
        name: 'محمد عبد الله',
        phone: '01012345678',
        isCustomer: true,
        createdAt: now,
        updatedAt: now,
      );
      await tester.runAsync(() async {
        await partyRepo.saveParty(p1);
        await partiesCubit.loadCustomers();
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Switch to Existing Customer mode
      final existingChip = find.text('عميل مسجل');
      expect(existingChip, findsOneWidget);
      await tester.tap(existingChip);
      await tester.pumpAndSettle();

      // Verify dropdown is present
      final dropdownFinder = find.byType(DropdownButtonFormField<String?>);
      expect(dropdownFinder, findsOneWidget);

      // Open dropdown and select the customer
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      final customerItem = find.text('محمد عبد الله (01012345678)').last;
      expect(customerItem, findsOneWidget);
      await tester.tap(customerItem);
      await tester.pumpAndSettle();

      // Verify customer info card is rendered without errors
      expect(find.text('محمد عبد الله • 01012345678'), findsOneWidget);
    });

    testWidgets('2. A selected Party missing from latest list does not crash the page', (
      tester,
    ) async {
      final now = DateTime.now();
      final p1 = Party(
        id: 'cust_missing',
        name: 'عميل سيتم حذفه',
        isCustomer: true,
        createdAt: now,
        updatedAt: now,
      );
      await tester.runAsync(() async {
        await partyRepo.saveParty(p1);
        await partiesCubit.loadCustomers();
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Select existing customer
      await tester.tap(find.text('عميل مسجل'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('عميل سيتم حذفه').last);
      await tester.pumpAndSettle();

      // Now archive the customer and refresh the list
      await tester.runAsync(() async {
        await partyRepo.archiveParty('cust_missing');
        await partiesCubit.loadCustomers();
      });
      await tester.pumpAndSettle();

      // Crucial assertion: no AssertionError thrown!
      expect(tester.takeException(), isNull);
      // Empty state or hint rendered safely
      expect(find.byType(CreateInvoicePage), findsOneWidget);
    });

    testWidgets('3. Duplicate Party IDs are handled safely without duplicate dropdown values', (
      tester,
    ) async {
      final now = DateTime.now();
      final p1 = Party(
        id: 'dup_id_1',
        name: 'عميل مكرر أ',
        isCustomer: true,
        createdAt: now,
        updatedAt: now,
      );
      final p1Duplicate = Party(
        id: 'dup_id_1',
        name: 'عميل مكرر ب',
        isCustomer: true,
        createdAt: now.add(const Duration(seconds: 1)),
        updatedAt: now.add(const Duration(seconds: 1)),
      );

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('عميل مسجل'));
      await tester.pumpAndSettle();

      // Emit state containing duplicate IDs after initial mount to test widget resilience
      partiesCubit.emit(
        CustomersLoaded(
          customers: [p1, p1Duplicate],
          balances: const {'dup_id_1': 0.0},
        ),
      );
      await tester.pumpAndSettle();

      // Opening the dropdown must NOT throw "Either zero or 2 or more DropdownMenuItems were detected with same value"
      final dropdown = find.byType(DropdownButtonFormField<String?>);
      expect(dropdown, findsOneWidget);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Loading, empty, and error states render gracefully', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('عميل مسجل'));
      await tester.pumpAndSettle();

      // Test Empty State
      partiesCubit.emit(
        const CustomersLoaded(customers: [], balances: {}),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('لا يوجد عملاء مسجلين حالياً'),
        findsOneWidget,
      );

      // Test Loading State
      partiesCubit.emit(PartiesLoading());
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('جاري تحميل قائمة العملاء...'), findsOneWidget);

      // Test Error State
      partiesCubit.emit(const PartiesError('تعذر جلب البيانات'));
      await tester.pumpAndSettle();
      expect(find.text('تعذر جلب البيانات'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('5. Refreshing the Party list preserves a valid selection', (
      tester,
    ) async {
      final now = DateTime.now();
      final targetId = 'f42b327b-6dda-4092-a1cd-0d8950f42d48';
      final p1 = Party(
        id: targetId,
        name: 'محمد',
        isCustomer: true,
        openingReceivable: 50.0,
        createdAt: now,
        updatedAt: now,
      );
      await tester.runAsync(() async {
        await partyRepo.saveParty(p1);
        await partiesCubit.loadCustomers();
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Select existing customer
      await tester.tap(find.text('عميل مسجل'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('محمد').last);
      await tester.pumpAndSettle();

      expect(find.text('محمد'), findsWidgets);

      // Simulate external update modifying updatedAt
      final p1Updated = p1.copyWith(
        phone: '01234567890',
        updatedAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      await tester.runAsync(() async {
        await partyRepo.saveParty(p1Updated);
        await partiesCubit.loadCustomers();
      });
      await tester.pumpAndSettle();

      // Verify no assertion error was thrown and customer selection is preserved
      expect(tester.takeException(), isNull);
      expect(find.text('محمد • 01234567890'), findsOneWidget);
    });

    testWidgets('6. Quick Add Customer flow does not trigger reported runtime exception', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Switch to Existing Customer mode
      await tester.tap(find.text('عميل مسجل'));
      await tester.pumpAndSettle();

      // Tap quick add customer action chip
      final addCustomerBtn = find.byType(ActionChip);
      expect(addCustomerBtn, findsOneWidget);
      await tester.tap(addCustomerBtn);
      await tester.pumpAndSettle();

      // Fill modal form with name "محمد"
      final nameField = find.widgetWithText(TextField, 'الاسم *');
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'محمد');
      await tester.pumpAndSettle();

      // Tap "حفظ واختيار العميل"
      final saveBtn = find.text('حفظ واختيار العميل');
      expect(saveBtn, findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(saveBtn);
        await partiesCubit.stream.firstWhere((s) => s is CustomersLoaded);
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Crucial: exactly matches the user crash scenario
      // Must NOT throw "There should be exactly one item with [DropdownButton]'s value: Party(...)"
      expect(tester.takeException(), isNull);
      expect(find.text('محمد'), findsWidgets);
    });
  });
}
