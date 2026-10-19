import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/audit/domain/entities/audit_log.dart';
import 'package:fatoura/features/audit/domain/repositories/audit_repository.dart';

class AuditRepositoryImpl implements AuditRepository {
  final HiveDatabase database;

  AuditRepositoryImpl(this.database);

  @override
  Future<void> logAction(AuditLog log) async {
    final box = database.auditLogsBox;
    await box.put(log.id, log.toMap());
  }

  @override
  Future<List<AuditLog>> getLogs({
    String? documentType,
    String? documentId,
    int limit = 50,
  }) async {
    final box = database.auditLogsBox;
    final results = <AuditLog>[];

    for (final key in box.keys) {
      final map = box.get(key);
      if (map != null) {
        final log = AuditLog.fromMap(Map<String, dynamic>.from(map));
        if (documentType != null && log.documentType != documentType) {
          continue;
        }
        if (documentId != null && log.documentId != documentId) {
          continue;
        }
        results.add(log);
      }
    }

    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }
}
