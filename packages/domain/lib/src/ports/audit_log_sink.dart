// AI-Generate
import '../model/audit_log.dart';

/// #22 Audit Log 的 Domain port；infra 可落到 Drift `audit_log`。
abstract interface class AuditLogSink {
  Future<void> appendAuditLog(AuditLogEntry entry);
}
