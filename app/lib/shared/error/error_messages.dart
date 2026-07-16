// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

class ErrorPresentation {
  const ErrorPresentation({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;
}

abstract final class ErrorMessages {
  static const Map<String, ErrorPresentation> _presentations = {
    ErrorCodes.unsupportedFormat: ErrorPresentation(
      title: '音檔格式不支援',
      message: '請選擇 mp3、wav、m4a 或 flac 音檔。',
      icon: Icons.audio_file_outlined,
    ),
    ErrorCodes.fileTooLong: ErrorPresentation(
      title: '音檔超過上限',
      message: '目前每次匯入以 10 分鐘內為限。',
      icon: Icons.timer_off_outlined,
    ),
    ErrorCodes.decodeFailed: ErrorPresentation(
      title: '解碼失敗',
      message: '請確認音檔可播放，或重新選擇音檔再試一次。',
      icon: Icons.sync_problem_outlined,
    ),
    ErrorCodes.transcribeFailed: ErrorPresentation(
      title: '辨識失敗',
      message: '語音辨識未完成，可保留目前資料後重試辨識階段。',
      icon: Icons.record_voice_over_outlined,
    ),
    ErrorCodes.separateFailed: ErrorPresentation(
      title: '人聲分離失敗',
      message: '可跳過人聲分離改用原音重試，或稍後再試。',
      icon: Icons.multitrack_audio_outlined,
    ),
    ErrorCodes.sidecarCrashed: ErrorPresentation(
      title: '分析工具中斷',
      message: '外部分析工具意外中止，可以保留目前資料後重試。',
      icon: Icons.report_problem_outlined,
    ),
    ErrorCodes.sidecarTimeout: ErrorPresentation(
      title: '分析逾時',
      message: '請重試，或稍後到設定調高 sidecar 逾時時間。',
      icon: Icons.hourglass_disabled_outlined,
    ),
    ErrorCodes.analysisInProgress: ErrorPresentation(
      title: '分析仍在進行',
      message: '目前匯入按鈕已鎖定，請等待這次分析完成。',
      icon: Icons.pending_actions_outlined,
    ),
    ErrorCodes.boundaryInvalid: ErrorPresentation(
      title: '邊界不可跨越',
      message: '音節邊界不能跨過相鄰音節，已回到原位置。',
      icon: Icons.timeline_outlined,
    ),
    ErrorCodes.repeatNOutOfRange: ErrorPresentation(
      title: '重複次數超出範圍',
      message: '重複播放次數需介於 1 到 10。',
      icon: Icons.repeat_outlined,
    ),
    ErrorCodes.exportDestUnwritable: ErrorPresentation(
      title: '無法寫入匯出位置',
      message: '請換一個可寫入的資料夾後重試。',
      icon: Icons.folder_off_outlined,
    ),
    ErrorCodes.exportInProgress: ErrorPresentation(
      title: '匯出仍在進行',
      message: '請等待目前匯出完成，再開始新的匯出。',
      icon: Icons.ios_share_outlined,
    ),
    ErrorCodes.recordingTooShort: ErrorPresentation(
      title: '錄音太短',
      message: '請重錄，錄音至少需要 0.2 秒。',
      icon: Icons.mic_none_outlined,
    ),
    ErrorCodes.micPermissionDenied: ErrorPresentation(
      title: '麥克風權限未開啟',
      message: '請到系統設定開啟麥克風權限。',
      icon: Icons.mic_off_outlined,
    ),
    ErrorCodes.packCorrupted: ErrorPresentation(
      title: '課件檔案損毀',
      message: '這個課件無法安全開啟，未載入任何部分資料。',
      icon: Icons.inventory_2_outlined,
    ),
    ErrorCodes.progressCorrupted: ErrorPresentation(
      title: '進度檔案損毀',
      message: '進度匯入未套用任何變更。',
      icon: Icons.restore_page_outlined,
    ),
    ErrorCodes.aiKeyMissing: ErrorPresentation(
      title: '尚未設定 AI key',
      message: '翻譯功能會停用，但手動譯文仍可使用。',
      icon: Icons.key_off_outlined,
    ),
    ErrorCodes.aiCallFailed: ErrorPresentation(
      title: '翻譯服務暫時無法使用',
      message: '請稍後再試；手動譯文路徑不受影響。',
      icon: Icons.translate_outlined,
    ),
    ErrorCodes.archiveRestoreExpired: ErrorPresentation(
      title: '恢復期限已過',
      message: '這份封存已超過可恢復期限。',
      icon: Icons.event_busy_outlined,
    ),
    ErrorCodes.languageUnsupported: ErrorPresentation(
      title: '語言不支援',
      message: '這個語言缺少可用的辨識引擎或音節切分器。',
      icon: Icons.language_outlined,
    ),
    ErrorCodes.labelCorrupted: ErrorPresentation(
      title: '標籤檔損毀',
      message: '標籤檔損毀，未載入任何內容。',
      icon: Icons.label_off_outlined,
    ),
    ErrorCodes.labelFingerprintMismatch: ErrorPresentation(
      title: '標籤檔不相符',
      message: '此標籤檔屬於另一個音檔，請重新選擇。',
      icon: Icons.link_off_outlined,
    ),
    ErrorCodes.segmentTooClose: ErrorPresentation(
      title: '段落標籤線太近',
      message: '距離相鄰標籤線太近，至少需要 0.5 秒。',
      icon: Icons.view_timeline_outlined,
    ),
    ErrorCodes.boundaryTooClose: ErrorPresentation(
      title: '音節切點太近',
      message: '距離相鄰切點太近，至少需要 50 毫秒。',
      icon: Icons.compare_arrows_outlined,
    ),
    ErrorCodes.syllableMinCount: ErrorPresentation(
      title: '至少保留一個音節',
      message: '至少須保留 1 個音節。',
      icon: Icons.format_list_numbered_outlined,
    ),
    ErrorCodes.blockConfigOutOfRange: ErrorPresentation(
      title: '練習塊設定超出範圍',
      message: '重複次數須為 1–10；靜音倍數須為 0–5。',
      icon: Icons.tune_outlined,
    ),
  };

  static ErrorPresentation fromCode(String code) =>
      _presentations[code] ??
      const ErrorPresentation(
        title: '發生未知錯誤',
        message: '請保留目前資料後重試。',
        icon: Icons.error_outline,
      );

  static int get mappedCodeCount => _presentations.length;
}
