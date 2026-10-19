import 'dart:io';

import 'package:fatoura/app.dart';
import 'package:fatoura/bootstrap.dart';
import 'package:fatoura/core/backup/backup_service.dart';
import 'package:fatoura/core/settings/app_settings_cubit.dart';
import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/core/storage/sequence_manager.dart';
import 'package:fatoura/features/audit/data/repositories/audit_repository_impl.dart';
import 'package:fatoura/features/invoices/data/repositories/invoice_repository_impl.dart';
import 'package:fatoura/features/parties/data/repositories/party_repository_impl.dart';
import 'package:fatoura/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:fatoura/features/products/data/repositories/product_repository_impl.dart';
import 'package:fatoura/features/purchases/data/repositories/purchase_repository_impl.dart';
import 'package:fatoura/features/returns/data/repositories/sales_return_repository_impl.dart';
import 'package:fatoura/features/shop_setup/data/repositories/shop_profile_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Fatoura app boots into ShopSetupPage on first launch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    late Directory tempDir;
    final db = HiveDatabase.instance;
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp('fatoura_app_test_');
      await db.init(customPath: tempDir.path);
    });

    final seq = SequenceManager(db);
    final backup = BackupService(db);
    final shopRepo = ShopProfileRepositoryImpl(db);
    final partyRepo = PartyRepositoryImpl(db);
    final prodRepo = ProductRepositoryImpl(db);
    final invRepo = InvoiceRepositoryImpl(db);
    final payRepo = PaymentRepositoryImpl(
      database: db,
      invoiceRepository: invRepo,
    );
    final retRepo = SalesReturnRepositoryImpl(
      database: db,
      invoiceRepository: invRepo,
    );
    final purRepo = PurchaseRepositoryImpl(db);
    final auditRepo = AuditRepositoryImpl(db);
    final settingsCubit = AppSettingsCubit(prefs);

    final deps = AppDependencies(
      sharedPreferences: prefs,
      hiveDatabase: db,
      sequenceManager: seq,
      backupService: backup,
      shopProfileRepository: shopRepo,
      partyRepository: partyRepo,
      productRepository: prodRepo,
      invoiceRepository: invRepo,
      paymentRepository: payRepo,
      returnRepository: retRepo,
      purchaseRepository: purRepo,
      auditRepository: auditRepo,
      appSettingsCubit: settingsCubit,
    );

    await tester.pumpWidget(FatouraApp(dependencies: deps));
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify first run setup page is rendered with Fatoura branding
    expect(find.text('إعداد المتجر والنشاط'), findsWidgets);

    await tester.runAsync(() async {
      await db.close();
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });
  });
}
