import 'package:fatoura/features/audit/domain/entities/audit_log.dart';

abstract class AuditRepository {
  Future<void> logAction(AuditLog log);
  Future<List<AuditLog>> getLogs({
    String? documentType,
    String? documentId,
    int limit = 50,
  });
}
