import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:fatoura/core/storage/hive_database.dart';

class BackupResult {
  final bool success;
  final String? message;
  final String? backupJson;
  final String? checksum;

  BackupResult({
    required this.success,
    this.message,
    this.backupJson,
    this.checksum,
  });
}

class RestoreValidationResult {
  final bool isValid;
  final String? error;
  final Map<String, dynamic>? data;

  RestoreValidationResult({required this.isValid, this.error, this.data});
}

class BackupService {
  final HiveDatabase database;

  BackupService(this.database);

  static const int currentSchemaVersion = 1;

  /// Creates a complete JSON backup with metadata, timestamp, and SHA-256 integrity hash
  Future<BackupResult> createBackup() async {
    try {
      final exportData = await database.exportAllData();
      final tablesJson = jsonEncode(exportData['tables']);
      final checksum = sha256.convert(utf8.encode(tablesJson)).toString();

      final fullBackup = <String, dynamic>{
        'app': 'Fatoura',
        'schemaVersion': currentSchemaVersion,
        'createdAt': DateTime.now().toIso8601String(),
        'checksum': checksum,
        'data': exportData,
      };

      final jsonString = jsonEncode(fullBackup);
      return BackupResult(
        success: true,
        backupJson: jsonString,
        checksum: checksum,
        message: 'Backup generated successfully',
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Failed to create backup: $e',
      );
    }
  }

  /// Validates a backup string before applying it
  RestoreValidationResult validateBackup(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>?;
      if (decoded == null) {
        return RestoreValidationResult(
          isValid: false,
          error: 'Empty or invalid JSON',
        );
      }

      if (decoded['app'] != 'Fatoura') {
        return RestoreValidationResult(
          isValid: false,
          error: 'Unsupported backup archive: app identifier is not Fatoura',
        );
      }

      final schemaVersion = decoded['schemaVersion'] as int?;
      if (schemaVersion == null || schemaVersion > currentSchemaVersion) {
        return RestoreValidationResult(
          isValid: false,
          error:
              'Incompatible schema version: $schemaVersion (supported: <= $currentSchemaVersion)',
        );
      }

      final checksum = decoded['checksum'] as String?;
      final data = decoded['data'] as Map<String, dynamic>?;
      if (data == null || data['tables'] == null) {
        return RestoreValidationResult(
          isValid: false,
          error: 'Backup payload is missing tables data',
        );
      }

      final tablesJson = jsonEncode(data['tables']);
      final calculatedChecksum = sha256
          .convert(utf8.encode(tablesJson))
          .toString();

      if (checksum != null && checksum != calculatedChecksum) {
        return RestoreValidationResult(
          isValid: false,
          error: 'Integrity check failed: checksum mismatch (corrupted data)',
        );
      }

      return RestoreValidationResult(isValid: true, data: data);
    } catch (e) {
      return RestoreValidationResult(
        isValid: false,
        error: 'JSON parsing failed: $e',
      );
    }
  }

  /// Restores verified backup into live database with a pre-restore rollback snapshot
  Future<BackupResult> restoreBackup(String rawJson) async {
    final validation = validateBackup(rawJson);
    if (!validation.isValid || validation.data == null) {
      return BackupResult(
        success: false,
        message: validation.error ?? 'Validation failed',
      );
    }

    // 1. Take safety snapshot of current live state
    Map<String, dynamic>? rollbackSnapshot;
    try {
      rollbackSnapshot = await database.exportAllData();
    } catch (_) {
      // In case export fails on an empty db
    }

    // 2. Perform restoration
    try {
      await database.restoreAllData(validation.data!);
      return BackupResult(success: true, message: 'Data restored successfully');
    } catch (e) {
      // Rollback if something failed
      if (rollbackSnapshot != null) {
        try {
          await database.restoreAllData(rollbackSnapshot);
        } catch (_) {}
      }
      return BackupResult(
        success: false,
        message: 'Restoration failed and rolled back: $e',
      );
    }
  }
}
