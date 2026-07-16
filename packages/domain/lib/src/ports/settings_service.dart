// AI-Generate
import '../model/settings.dart';

/// 每 Lesson 顯示偏好持久化 port（backend-design.md §3.2.6 介面 34）。
///
/// 實作必須以 `.aboprogress` 的 `progress.transcriptDisplayModes` 為快照
/// 權威來源，不得把偏好寫進 `.abopack`。
abstract interface class SettingsService {
  Future<TranscriptDisplayMode> getTranscriptMode(String lessonId);

  Future<void> setTranscriptMode(
    String lessonId,
    TranscriptDisplayMode mode,
  );
}
