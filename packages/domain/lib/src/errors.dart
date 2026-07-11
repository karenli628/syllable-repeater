// AI-Generate
/// Domain 統一錯誤與錯誤碼總表（backend-design.md §3.2.8）。
/// 前端以 code 對照處理策略（frontend-design.md 功能點 8）；新增錯誤碼必須同步兩處文件。
class DomainException implements Exception {
  final String code;
  final String message;

  const DomainException(this.code, this.message);

  @override
  String toString() => 'DomainException($code): $message';
}

/// 錯誤碼常數——與 backend-design.md §3.2.8 一一對應（19 碼）。
abstract final class ErrorCodes {
  static const unsupportedFormat = 'ERR_UNSUPPORTED_FORMAT';
  static const fileTooLong = 'ERR_FILE_TOO_LONG';
  static const decodeFailed = 'ERR_DECODE_FAILED';
  static const transcribeFailed = 'ERR_TRANSCRIBE_FAILED';
  static const separateFailed = 'ERR_SEPARATE_FAILED';
  static const sidecarCrashed = 'ERR_SIDECAR_CRASHED';
  static const sidecarTimeout = 'ERR_SIDECAR_TIMEOUT';
  static const analysisInProgress = 'ERR_ANALYSIS_IN_PROGRESS';
  static const boundaryInvalid = 'ERR_BOUNDARY_INVALID';
  static const repeatNOutOfRange = 'ERR_REPEATN_OUT_OF_RANGE';
  static const exportDestUnwritable = 'ERR_EXPORT_DEST_UNWRITABLE';
  static const exportInProgress = 'ERR_EXPORT_IN_PROGRESS';
  static const recordingTooShort = 'ERR_RECORDING_TOO_SHORT';
  static const micPermissionDenied = 'ERR_MIC_PERMISSION_DENIED';
  static const packCorrupted = 'ERR_PACK_CORRUPTED';
  static const progressCorrupted = 'ERR_PROGRESS_CORRUPTED';
  static const aiKeyMissing = 'ERR_AI_KEY_MISSING';
  static const aiCallFailed = 'ERR_AI_CALL_FAILED';
  static const archiveRestoreExpired = 'ERR_ARCHIVE_RESTORE_EXPIRED';
}
