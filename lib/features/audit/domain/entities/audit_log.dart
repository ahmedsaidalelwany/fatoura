import 'package:equatable/equatable.dart';

class AuditLog extends Equatable {
  final String id;
  final String action;
  final String documentType;
  final String documentId;
  final String description;
  final String actor;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const AuditLog({
    required this.id,
    required this.action,
    required this.documentType,
    required this.documentId,
    required this.description,
    this.actor = 'Local User',
    required this.timestamp,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action': action,
      'documentType': documentType,
      'documentId': documentId,
      'description': description,
      'actor': actor,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] as String? ?? '',
      action: map['action'] as String? ?? '',
      documentType: map['documentType'] as String? ?? '',
      documentId: map['documentId'] as String? ?? '',
      description: map['description'] as String? ?? '',
      actor: map['actor'] as String? ?? 'Local User',
      timestamp:
          DateTime.tryParse(map['timestamp'] as String? ?? '') ??
          DateTime.now(),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  @override
  List<Object?> get props => [id, action, documentType, documentId, timestamp];
}
