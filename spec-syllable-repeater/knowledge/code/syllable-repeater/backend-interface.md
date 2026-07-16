// AI-Generate
# backend-interface

> 介面來源：Dart 原始碼掃描。此專案無伺服器、無 Controller、無自家 HTTP API；以下列出本機 App 內部契約與外部 provider/sidecar 邊界，供後續 archive 追溯。

## 介面統計概要

| 類型 | 數量 | 說明 |
|---|---:|---|
| HTTP Controller / REST API | 0 | macOS 本機桌面 App，不啟動伺服器 |
| 遠端 HTTPS provider | 1 | OpenAI Responses API，僅文字翻譯 |
| Domain ports | 12 | 副作用透過 ports 注入（v1.1 新增 5 個） |
| Sidecar CLI wrappers | 5 | FFmpeg/ffprobe/whisper.cpp/demucs.cpp/ffmpeg mp3 |
| Drift repository adapter | 3 | Progress／LabelRegistry／Settings（v1.1 新增 2 個） |
| Release packaging contracts | 3 | artifact acquisition、sidecar staging、unsigned zip |

## 遠端 HTTPS provider

### OpenAI Responses API

| 方法 | URL | 介面說明 |
|---|---|---|
| POST | `https://api.openai.com/v1/responses` | `OpenAiResponsesClient.translate` 送出文字翻譯請求，解析 `output_text` 或 `output[].content[].text` |

## Domain ports

| 契約 | 實作位置 | 說明 |
|---|---|---|
| `AiClient.translate` | `app/lib/shared/infra/openai_responses_client.dart` | AI provider HTTP adapter |
| `SecureStore.read/write/delete` | `app/lib/shared/infra/keychain_secure_store.dart` | macOS Keychain credential 儲存 |
| `ProgressRepository` | `packages/infra/lib/src/db/drift_progress_repository.dart` | lesson/SRS/attempt/settings/audit log 持久化（含 transcriptDisplayModes） |
| `TranscriberEngine`（v1.1） | `packages/infra/lib/src/sidecar/whisper_transcriber.dart` | ASR port：transcribe＋segment；契約無 URL 欄位（D7 型別層排除線上 ASR） |
| `Syllabifier`（v1.1） | `packages/domain/lib/src/alignment/english_syllabifier.dart` | 音節切分 port；v1.1 僅英文實作 |
| `LabelRegistryRepository`（v1.1） | `packages/infra/lib/src/db/drift_label_registry_repository.dart` | 指紋→`.abolabel` 路徑索引 findByFingerprint/upsert |
| `SettingsService`（v1.1） | `packages/infra/lib/src/db/drift_settings_service.dart` | 每 Lesson transcriptDisplayMode 讀寫 |
| `AudioImportReader`（v1.1） | `packages/infra/lib/src/analysis/dart_io_audio_import_reader.dart` | 逐 byte 讀取＋格式/時長驗證，唯一 ready 事件（M15） |
| `FileIo` | `packages/infra/lib/src/file_io_impl.dart` | 原子檔案寫入、temp 清理 |
| `RecordingAudioSource` | `packages/infra/lib/src/practice/recording_audio_source.dart` | 讀取暫存錄音 PCM 供比對 |
| `WaveformPeaksCache` | `packages/infra/lib/src/analysis/file_waveform_peaks_cache.dart` | waveform peaks 檔案快取 |
| `Clock` | `packages/infra/lib/src/clock_impl.dart` | 可注入時間來源 |

## Sidecar CLI contracts

| Wrapper | CLI/輸入 | 輸出/說明 |
|---|---|---|
| `FfmpegDecoder.decode` | `ffmpeg -i <in> -f s16le -ar 44100 -ac 1 -` | 解碼為 mono PCM；錯誤映射 `ERR_DECODE_FAILED`/sidecar codes |
| `FfprobeDurationProbe.durationMs` | `ffprobe` | 取得音檔 duration；匯入前檢查用 |
| `WhisperCppTranscriber.transcribe/segment` | `whisper-cli <16k wav> --model small.en --output-json` | 詞級時間戳 JSON → `Word` list；v1.1 另讀 segment offsets → `Segment` list（段落切段） |
| `DemucsSeparator.separate` | `demucs.cpp.main <model-file> <input-audio> <out-dir>` | 讀 `target_3_vocals.wav`；缺件時可降級原音；v1.1 改由原始匯入檔直接準備 44.1kHz stereo 輸入 |
| `PracticeExporter.exportMp3` | `ffmpeg` stdin WAV → mp3 | 練習步驟/合併匯出 |

## Riverpod provider entrypoints

| Provider/入口 | 位置 | 說明 |
|---|---|---|
| `analysisRunnerProvider` | `app/lib/features/import_analysis/analysis_controller.dart` | 匯入分析 workflow 的 infra runner（預設為 PreviewAnalysisRunner，正式入口由 main 覆蓋為 InfraAnalysisRunner） |
| `labelingEngineProvider`（v1.1） | `app/lib/features/labeling/labeling_controller.dart` | Domain `SegmentEngine` 注入點（經 `segment_engine_factory`） |
| `pendingSegmentProvider`（v1.1） | `app/lib/shared/pending_segment.dart` | 段落→單句單槽交接（僅 metadata） |
| `transcriptSettingsServiceProvider`（v1.1） | `app/lib/features/practice/practice_controller.dart` | DriftSettingsService 注入點（顯示模式） |
| `progressRepositoryProvider` | `app/lib/features/progress/progress_service.dart` | Drift repository 注入點 |
| `aiSettingsServiceProvider` | `app/lib/features/progress/ai_settings_service.dart` | Keychain + OpenAI adapter 注入點 |
| `practiceRecorderProvider` | `app/lib/features/practice/practice_recording.dart` | 錄音 adapter 注入點（audio_session 錄播協調） |
| `appShellSelectedIndexProvider` | `app/lib/shared/navigation.dart` | NavigationRail/流程跳轉狀態（含段落標籤項） |

## 非業務入口

| 項目 | 說明 |
|---|---|
| `main()` | Flutter app 啟動，依 `SidecarPaths.current()` 決定 dev/bundled sidecar 接線 |
| Drift generated code | `app_database.g.dart` 為 codegen 產物，不作為業務介面 |

## Release packaging contracts

| 契約 | 位置 | 說明 |
|---|---|---|
| Artifact acquisition gate | `scripts/fetch_sidecar_artifacts.py` | manifest 工件必須具備 HTTPS URL、SHA-256、授權/連結資訊；拒絕 CERT/TLS 降級、GPL/AGPL、non-commercial、LGPL static |
| Sidecar staging gate | `scripts/prepare_release_sidecars.py` + `copy_release_sidecars.sh` | Release build 前檢查 FFmpeg/ffprobe shared LGPL、必要 binaries/models/data 與 Mach-O 依賴 |
| Unsigned zip gate | `scripts/make_release_zip.py` | 檢查 release `.app` 與 bundled sidecar 必要檔後，產 `SyllableRepeater-macos-x86_64-unsigned.zip` 與 `.sha256` |
