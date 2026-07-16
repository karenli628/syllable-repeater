// AI-Generate

/// 練習頁字稿／譯文顯示模式（backend-design.md §3.1.1、§3.2.6 介面 34）。
enum TranscriptDisplayMode {
  transcript('transcript'),
  transcriptWithTranslation('transcriptWithTranslation'),
  translationOnly('translationOnly'),
  hidden('hidden');

  const TranscriptDisplayMode(this.value);

  final String value;

  static TranscriptDisplayMode fromJson(String value) {
    for (final mode in values) {
      if (mode.value == value) {
        return mode;
      }
    }
    throw FormatException('未知 TranscriptDisplayMode: $value');
  }
}

/// 練習提醒設定（backend-design.md §3.2.6 介面 19 / Q9）。
class ReminderConfig {
  static const defaults = ReminderConfig(
    minutesPerSession: 15,
    failCapPerSession: 5,
    dailySessions: 2,
  );

  final int minutesPerSession;
  final int failCapPerSession;
  final int dailySessions;

  const ReminderConfig({
    required this.minutesPerSession,
    required this.failCapPerSession,
    required this.dailySessions,
  })  : assert(minutesPerSession > 0),
        assert(failCapPerSession > 0),
        assert(dailySessions > 0);
}

/// Sidecar 執行設定；目前 v1 僅開放逾時秒數，預設對齊 SidecarRunner 120s。
class SidecarConfig {
  static const defaults = SidecarConfig(timeoutSeconds: 120);

  final int timeoutSeconds;

  const SidecarConfig({required this.timeoutSeconds})
      : assert(timeoutSeconds > 0);
}
