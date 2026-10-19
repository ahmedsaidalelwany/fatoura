import 'dart:io';

import 'package:fatoura/core/backup/backup_service.dart';
import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/parties/data/repositories/party_repository_impl.dart';
import 'package:fatoura/features/parties/domain/entities/party.dart';
import 'package:fatoura/features/shop_setup/data/repositories/shop_profile_repository_impl.dart';
import 'package:fatoura/features/shop_setup/domain/entities/shop_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late HiveDatabase db;
  late BackupService backupService;
  late ShopProfileRepositoryImpl shopRepo;
  late PartyRepositoryImpl partyRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fatoura_backup_test_');
    db = HiveDatabase.instance;
    await db.init(customPath: tempDir.path);

    backupService = BackupService(db);
    shopRepo = ShopProfileRepositoryImpl(db);
    partyRepo = PartyRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'Creates verified backup, detects tampering, and safely restores',
    () async {
      // 1. Seed data
      await shopRepo.saveProfile(
        ShopProfile(
          id: 'shop_001',
          name: 'متجر القاهرة التقني',
          businessType: 'إلكترونيات',
          defaultCurrency: 'EGP',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await partyRepo.saveParty(
        Party(
          id: 'cust_001',
          name: 'سالم الكعبي',
          phone: '0501234567',
          isCustomer: true,
          isSupplier: false,
          openingReceivable: 120.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 2. Export backup
      final backup = await backupService.createBackup();
      expect(backup.success, isTrue);
      expect(backup.backupJson, isNotNull);
      expect(backup.checksum, isNotNull);

      // 3. Validation of genuine backup
      final val1 = backupService.validateBackup(backup.backupJson!);
      expect(val1.isValid, isTrue);

      // 4. Tampering test: modify 1 character inside tables without updating checksum
      final tamperedJson = backup.backupJson!.replaceFirst(
        'متجر الرياض التقني',
        'متجر الرياض المزور',
      );
      final valTampered = backupService.validateBackup(tamperedJson);
      expect(valTampered.isValid, isFalse);
      expect(valTampered.error, contains('Integrity check failed'));

      // 5. Clear live database to simulate clean state
      await db.clearAll();
      final profileAfterClear = await shopRepo.getProfile();
      expect(profileAfterClear, isNull);

      // 6. Restore genuine backup
      final restoreRes = await backupService.restoreBackup(backup.backupJson!);
      expect(restoreRes.success, isTrue);

      // 7. Verify restored records
      final restoredProfile = await shopRepo.getProfile();
      expect(restoredProfile, isNotNull);
      expect(restoredProfile!.name, 'متجر الرياض التقني');

      final restoredParty = await partyRepo.getPartyById('cust_001');
      expect(restoredParty, isNotNull);
      expect(restoredParty!.name, 'سالم الكعبي');
      expect(restoredParty.openingReceivable, 120.0);
    },
  );
}
