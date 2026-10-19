import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/backup/backup_service.dart';
import 'core/settings/app_settings_cubit.dart';
import 'core/storage/hive_database.dart';
import 'core/storage/sequence_manager.dart';
import 'features/audit/data/repositories/audit_repository_impl.dart';
import 'features/audit/domain/repositories/audit_repository.dart';
import 'features/invoices/data/repositories/invoice_repository_impl.dart';
import 'features/invoices/domain/repositories/invoice_repository.dart';
import 'features/parties/data/repositories/party_repository_impl.dart';
import 'features/parties/domain/repositories/party_repository.dart';
import 'features/payments/data/repositories/payment_repository_impl.dart';
import 'features/payments/domain/repositories/payment_repository.dart';
import 'features/products/data/repositories/product_repository_impl.dart';
import 'features/products/domain/repositories/product_repository.dart';
import 'features/purchases/data/repositories/purchase_repository_impl.dart';
import 'features/purchases/domain/repositories/purchase_repository.dart';
import 'features/returns/data/repositories/sales_return_repository_impl.dart';
import 'features/returns/domain/repositories/sales_return_repository.dart';
import 'features/shop_setup/data/repositories/shop_profile_repository_impl.dart';
import 'features/shop_setup/domain/repositories/shop_profile_repository.dart';

class AppDependencies {
  final SharedPreferences sharedPreferences;
  final HiveDatabase hiveDatabase;
  final SequenceManager sequenceManager;
  final BackupService backupService;

  final ShopProfileRepository shopProfileRepository;
  final PartyRepository partyRepository;
  final ProductRepository productRepository;
  final InvoiceRepository invoiceRepository;
  final PaymentRepository paymentRepository;
  final SalesReturnRepository returnRepository;
  final PurchaseRepository purchaseRepository;
  final AuditRepository auditRepository;

  final AppSettingsCubit appSettingsCubit;

  AppDependencies({
    required this.sharedPreferences,
    required this.hiveDatabase,
    required this.sequenceManager,
    required this.backupService,
    required this.shopProfileRepository,
    required this.partyRepository,
    required this.productRepository,
    required this.invoiceRepository,
    required this.paymentRepository,
    required this.returnRepository,
    required this.purchaseRepository,
    required this.auditRepository,
    required this.appSettingsCubit,
  });
}

Future<AppDependencies> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // 2. Hive Database
  final hiveDatabase = HiveDatabase.instance;
  await hiveDatabase.init();

  // 3. Infrastructure
  final sequenceManager = SequenceManager(hiveDatabase);
  final backupService = BackupService(hiveDatabase);

  // 4. Repositories
  final shopProfileRepository = ShopProfileRepositoryImpl(hiveDatabase);
  final partyRepository = PartyRepositoryImpl(hiveDatabase);
  final productRepository = ProductRepositoryImpl(hiveDatabase);
  final invoiceRepository = InvoiceRepositoryImpl(hiveDatabase);
  final auditRepository = AuditRepositoryImpl(hiveDatabase);
  final paymentRepository = PaymentRepositoryImpl(
    database: hiveDatabase,
    invoiceRepository: invoiceRepository,
  );
  final returnRepository = SalesReturnRepositoryImpl(
    database: hiveDatabase,
    invoiceRepository: invoiceRepository,
    productRepository: productRepository,
  );
  final purchaseRepository = PurchaseRepositoryImpl(hiveDatabase);

  // 5. Settings Cubit
  final appSettingsCubit = AppSettingsCubit(prefs);

  return AppDependencies(
    sharedPreferences: prefs,
    hiveDatabase: hiveDatabase,
    sequenceManager: sequenceManager,
    backupService: backupService,
    shopProfileRepository: shopProfileRepository,
    partyRepository: partyRepository,
    productRepository: productRepository,
    invoiceRepository: invoiceRepository,
    paymentRepository: paymentRepository,
    returnRepository: returnRepository,
    purchaseRepository: purchaseRepository,
    auditRepository: auditRepository,
    appSettingsCubit: appSettingsCubit,
  );
}
