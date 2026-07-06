// AI-Generate

/// 本機自審用操作紀錄（hard-limits-matrix #22）。
///
/// 不保存 API key、音訊、錄音路徑或檔案路徑；metadata 只放非敏感摘要。
class AuditLogEntry {
  final DateTime occurredAt;
  final String actor;
  final String action;
  final String targetType;
  final String? targetId;
  final Map<String, String> metadata;

  AuditLogEntry({
    required this.occurredAt,
    required this.actor,
    required this.action,
    required this.targetType,
    this.targetId,
    Map<String, String> metadata = const {},
  }) : metadata = Map.unmodifiable(metadata) {
    _requireNotBlank(actor, 'AuditLogEntry.actor');
    _requireNotBlank(action, 'AuditLogEntry.action');
    _requireNotBlank(targetType, 'AuditLogEntry.targetType');
    if (targetId != null) {
      _rejectSensitive(targetId!, 'AuditLogEntry.targetId');
    }
    for (final entry in metadata.entries) {
      _requireNotBlank(entry.key, 'AuditLogEntry.metadata.key');
      _rejectSensitive(entry.key, 'AuditLogEntry.metadata.key');
      _rejectSensitive(entry.value, 'AuditLogEntry.metadata.${entry.key}');
    }
  }

  static const String localActor = 'local-user';
}

void _requireNotBlank(String value, String fieldName) {
  if (value.trim().isEmpty) {
    throw ArgumentError('$fieldName 不可空白');
  }
}

void _rejectSensitive(String value, String fieldName) {
  final lowered = value.toLowerCase();
  const blockedTokens = [
    'api_key',
    'apikey',
    'secret',
    'password',
    'credential',
    'audio/',
    'recording',
    '/users/',
    '/tmp/',
  ];
  if (blockedTokens.any(lowered.contains)) {
    throw ArgumentError('$fieldName 不可含敏感資訊');
  }
}
