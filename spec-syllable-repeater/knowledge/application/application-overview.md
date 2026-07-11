// AI-Generate
# application-overview

## 應用邊界

Syllable Repeater 是純本機、單人 macOS App。Flutter UI 負責工作流與互動，Domain 負責業務規則，Infra 負責 sidecar/DB/檔案/Keychain/HTTP adapter。專案沒有自家伺服器與 REST Controller；唯一遠端呼叫是使用者自帶 key 的 OpenAI Responses API 文字翻譯。

## 主要呼叫鏈

| 流程 | 入口 | 核心鏈路 | 主要產出 |
|------|------|----------|----------|
| 匯入分析 | `ImportScreen` | `AnalysisController` → `InfraAnalysisRunner` → `AnalysisPipeline` → FFmpeg/demucs/whisper/CMUdict | `AlignmentResult`、PCM、waveform peaks |
| 校正 | `EditorScreen` | `EditorController` → `AlignmentEngine.updateSyllableBoundary` | 更新後音節切點 |
| 練習 | `PracticeScreen` | `PracticeEngine.buildSteps/renderStep` | 原始 PCM 切片播放 |
| 匯出 | `ExportScreen` | `PracticeExporter` → FFmpeg mp3 | 單步或合併 mp3 |
| 錄音比對 | `PracticeRecording` | record adapter → `RecordingComparator` | rhythm/intonation delta、overlay |
| 課件/進度 | `LibraryScreen` / `ProgressSettingsScreen` | `LessonPackEngine` / `ProgressEngine` / Drift repository | `.abopack`、`.aboprogress`、SRS 狀態 |
| AI 翻譯 | `AISettingsService` | `AIService` → Keychain + OpenAI Responses | 可選 AI translation；manual 優先 |
| 發布 | release scripts | staging gate → Flutter release build → unsigned zip | x86_64 `.app` 與 `.zip.sha256` |

## 例外與降級

- sidecar timeout/crash/exit 非 0：回傳 DomainException，不拖垮 App。
- demucs 缺件或失敗：降級使用原音。
- pitch 抽不到：`pitchAvailable=false`，其他韻律資料照常。
- AI provider 失敗：手動譯文仍可用，credential 不洩漏。
- release sidecar 缺件或授權不合：build/prepare/zip gate fail-closed。

## 發布型態

v1 release 是 Intel x86_64、未簽章 macOS zip。Release build 走 bundled sidecar path，不能依賴開發機 `/usr/local/bin/ffmpeg`。使用者端安裝方式由 `release/README-unsigned-macos.md` 說明。
