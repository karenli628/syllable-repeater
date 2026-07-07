# 執行日誌 — Syllable Repeater macOS v1 實作

> 對應任務清單：`task-split.md`；任務狀態流轉 Pending → InProgress → Done / Failed。

## 執行概覽

- **開始時間**：2026-07-04（本 session）
- **目前切片**：S1a（後端 3.1–3.5 與 8.1 本地 CI-ready 防線已完成；前端 FP0/FP2 於 2026-07-05 收尾：真 `AnalysisPipeline` 注入、`FfprobeDurationProbe` 前置時長檢查、`PipelineCheckpoint` 分階段重試、done 導向 editor 最小殼、`shared/player/player_bar.dart` 皆落地；S1a 全切片 code 面已可宣告完成，真 e2e demo 待使用者手動 `flutter run -d macos` 驗收；`hard-guardrails matrix` 仍待補）
- **環境**：macOS 14（Darwin 23.1.0）／Intel i5-8259U／Homebrew ✅／Xcode CLT ✅／完整 Xcode ❌（Flutter macOS 建置階段才需要，屆時須使用者自 App Store 安裝）

## 環境安裝紀錄

| 項目 | 狀態 | 備註 |
|------|------|------|
| Dart SDK | ✅ 3.12.2（brew，dart-lang/dart tap 已 trust） | PATH：`/usr/local/opt/dart/libexec/bin` |
| Flutter SDK | ✅ 3.44.4 stable（Homebrew） | `flutter create --platforms=macos --project-name syllable_repeater_app app` 已建立 `app/`；Android SDK 缺失屬目前 Non-scope；完整 Xcode/CocoaPods 仍可能阻塞 macOS plugin/build |
| FFmpeg | ✅ 8.1.2（brew）**僅限開發測試** | **brew 為 GPL build，不得隨 App 發布；發布須依任務 2.1 改用 LGPL build（M9）** |
| cmake / whisper.cpp / demucs.cpp | cmake ✅ 4.3.4；whisper.cpp ✅（`.local-tools` dev build）；demucs.cpp 未安裝 | whisper `small.en` 已下載；Intel Mac 開發期使用 16k WAV＋`--no-gpu`；demucs.cpp LICENSE 未核對（S1c 前必核） |
| 完整 Xcode | 未安裝 | 任務 9.1 前需使用者自行安裝（App Store，~12GB） |

## 任務執行記錄

### Task 1.1 建立 Dart workspace 三包骨架
- **狀態**：Done（`dart pub get` 解析 70 依賴成功）
- **產物**：`pubspec.yaml`（workspace 根）、`analysis_options.yaml`、`.gitignore`、`packages/domain/`（pubspec、domain.dart、errors.dart、model/、ports/）、`packages/infra/`（pubspec、infra.dart）
- **備註**：`app/`（Flutter macOS）已建立並加入 workspace。**風險註記（C9）**：儲存庫路徑含空白（`vibercoding project/syllable repeater`），純 Dart 無礙；Flutter macOS 建置對含空白路徑偶有工具鏈問題，屆時若踩到再評估搬移或 symlink。

### Task 1.2 Drift schema V1
- **狀態**：Done（build_runner 產碼成功；結構測試 6 項全過）
- **產物**：`packages/infra/lib/src/db/app_database.dart`（五表＋索引＋表名覆寫）、`lib/db/schema/V1__create_all.sql`、`V2__alter_placeholder.sql`
- **確認紀錄**：schema 屬 `[必須確認]`，已由使用者核可 task-split（OQ-3，2026-07-04）
- **防線**：attempt 表無音訊欄位（CT-10 結構防線）；practice_group 無逾期/失敗欄位（M7 結構防線）——皆有結構測試

### Task 1.3 FileIO 抽象＋macOS 實作
- **狀態**：Done（4 測試全過：原子性/唯讀失敗不留半成品/clearTemp/覆寫）
- **產物**：`packages/domain/lib/src/ports/file_io.dart`（抽象）、`packages/infra/lib/src/file_io_impl.dart`（AtomicFileIo：同目錄 temp→rename、失敗清殘、clearTemp）
- **測試**：`packages/infra/test/file_io_test.dart`（原子性、唯讀目錄失敗不留半成品、clearTemp）

### Task 1.4 Clock 抽象
- **狀態**：Done
- **產物**：`packages/domain/lib/src/ports/clock.dart`、`packages/infra/lib/src/clock_impl.dart`（SystemClock＋FixedClock 供 CT-08）

### Task 2.1 整備 x86_64 sidecar 二進位
- **狀態**：InProgress（部分：dev 用 brew FFmpeg 就緒；whisper.cpp/demucs.cpp 與 LGPL 發布版未辦）
- **備註**：`[需要回報]` — 開發期先以 brew ffmpeg 供整合測試（**GPL build，不得隨 App 發布**；LGPL build 於發布前處理）。whisper.cpp/demucs.cpp 延至 S1a/S1c。**demucs.cpp（sevagh）LICENSE 尚未逐字核對，S1c 前必核（backend-design §5.1-8）。**

### Task 2.2 SidecarRunner
- **狀態**：Done（M4 五情境測試全過：正常/非零/kill -9/逾時/spawn 失敗）
- **產物**：`packages/infra/lib/src/sidecar/sidecar_runner.dart`（Process.start 隔離、逾時 SIGKILL 回收、spawn 失敗映射、二進位 stdout 收集）
- **測試（M4 核心，先測後寫）**：`test/sidecar_runner_test.dart`——正常/非零/kill -9/逾時/執行檔不存在 五情境（CT-04、AT-01-04 單元層）

### Task 2.3 FFmpeg 解碼契約
- **狀態**：Done（假 Runner 7 情境＋真 FFmpeg 整合 demo 全過）
- **產物**：`packages/infra/lib/src/sidecar/ffmpeg_decoder.dart`（s16le/44.1kHz/mono 契約、格式白名單、10 分鐘上限、錯誤碼映射）
- **測試**：`test/ffmpeg_decoder_test.dart`（假 Runner：7 情境含 Q8 邊界兩側）＋ `test/ffmpeg_integration_test.dart`（真 ffmpeg S0 demo，未安裝時 skip）

### Task 3.1 CMUdict 載入與單字音節數查詢＋母音團 fallback
- **狀態**：Done
- **產物**：`packages/domain/lib/src/alignment/alignment_engine.dart`、`packages/infra/lib/src/alignment/cmudict_loader.dart`、`.local-tools/cmudict/cmudict.dict`、`.local-tools/cmudict/LICENSE`
- **備註**：CMUdict lines parser、正式 CMUdict 檔案 loader、音節數查詢、內建 S1a 測試詞、母音團 fallback＋needsReview 均已完成；CMUdict 檔案與授權保留於 `.local-tools/` 開發目錄，不進版控。
- **測試**：`alignment_engine_test.dart`：CMUdict lines 載入、`blorptastic` 查無字 fallback 為 3 音節且全數 `needsReview`；`cmudict_loader_test.dart`：正式檔案 loader 與授權檔存在性。

### Task 3.2 whisper.cpp 轉寫/對齊契約
- **狀態**：Done
- **工具**：`cmake 4.3.4`、whisper.cpp shallow clone/build 於 `.local-tools/whisper.cpp`；模型：`ggml-small.en.bin`（使用者指定僅 small）
- **產物**：`packages/infra/lib/src/sidecar/whisper_transcriber.dart`、`packages/infra/test/whisper_transcriber_test.dart`
- **實測**：`step up your coding skills to a new level.mp3` 初跑（mp3+Metal）輸出異常 `JO�identsidents`；改用 FFmpeg 轉 `16k mono wav` 並加 `--no-gpu` 後，small.en 正確辨識 `Step up your coding skills to a new level.`，總耗時約 3.48s。
- **JSON 契約**：使用 `-oj -ojf` 產生 full JSON，parser 以 tokens offsets 合併成 `Word(text/startMs/endMs/index)`；標點與特殊 token 忽略。
- **本機輸出**：`.local-tools/s1a/step_up_small_cpu.json`（已由 `.gitignore` 排除，不進版控）
- **測試**：infra `dart test` 28/28 ✅（含 whisper JSON parser/runner wrapper、CMUdict loader）

### Task 3.3 音節切分演算法與 AlignmentResult
- **狀態**：Done
- **產物**：`packages/domain/lib/src/model/word.dart`、`syllable.dart`、`alignment_result.dart`、`alignment_engine.dart`
- **驗證**：金標準句 `She has excellent communication skills` 切出 11 音節；`excellent`／`communication` 內部等比例切分並標 `needsReview`；使用者提供測試句 `step up your coding skills to a new level` 亦切出 11 音節；所有時間區間單調遞增互不重疊。

### Task 3.4 AnalysisPipeline 編排
- **狀態**：Done
- **產物**：`packages/domain/lib/src/analysis/analysis_pipeline.dart`（`ImportRequest`、`AnalysisStage`、`AnalysisEvent`、解碼/轉寫/可選分離 ports、重入鎖）、`packages/domain/test/analysis_pipeline_test.dart`、`packages/infra/lib/src/analysis/analysis_pipeline_adapters.dart`、`packages/infra/test/analysis_pipeline_adapters_test.dart`、`packages/infra/test/analysis_pipeline_integration_test.dart`、`packages/infra/dart_test.yaml`
- **實作重點**：Domain 只依賴抽象 port，維持 M5 純 Dart；infra adapter 依 `pitfall_whisper_small_intel需16k_cpu.md` 固定走 FFmpeg 轉 16k mono WAV，再呼叫 `WhisperCppTranscriber(noGpu: true)`；pipeline 依序回報 decoding / separating / transcribing / syllabifying / done / failed，重入時回 `ERR_ANALYSIS_IN_PROGRESS`。
- **驗證**：domain fake port 測試涵蓋事件順序、waveform peaks、重入鎖、轉寫失敗保留已解碼 PCM；infra adapter 測試驗證 FFmpeg `-ar 16000 -ac 1` 與 whisper 指令；sidecar 整合測試以使用者提供 `step up your coding skills to a new level.mp3` 跑完整 pipeline，輸出 11 音節與 32 個 peaks。

### Task 3.5 waveform peaks 計算
- **狀態**：Done
- **產物**：`packages/domain/lib/src/analysis/waveform_peaks.dart`
- **驗證**：bucket min/max 正規化測試通過（供前端 CustomPainter 快取）。

### Task 8.1 Domain 純 Dart CI-ready 防線
- **狀態**：Done（本地防線完成；GitHub Actions / 遠端 CI 待 git repo 決策後再接）
- **產物**：`packages/domain/test/domain_purity_test.dart`
- **防線**：`packages/domain/lib/**` 掃描 import/export，拒絕 `dart:io`、`dart:ffi`、`dart:html`、`dart:js`、`package:flutter/`、`package:infra/` 與 sidecar 實作路徑；`packages/domain/pubspec.yaml` 掃描正式依賴，拒絕 Flutter、infra 與 sidecar 依賴。
- **驗證**：domain `dart test` 15/15 ✅，其中 8.1 測試涵蓋目前檔案掃描與 AT-09-02 違規匯入範例（`package:flutter/material.dart`、`package:infra/infra.dart`、`dart:io`、`../sidecar/sidecar_runner.dart`）。

### Frontend FP0/FP2 起手版（App shell＋ImportAnalysis preview）
- **狀態**：Done（S1a Frontend FP0/FP2 全項目完成——見下方「Frontend FP0/FP2 收尾」）
- **產物**：`app/lib/main.dart`、`app/lib/shell/app_shell.dart`、`app/lib/shared/tokens.dart`、`app/lib/shared/empty_state.dart`、`app/lib/shared/error/error_messages.dart`、`app/lib/features/import_analysis/analysis_controller.dart`、`app/lib/features/import_analysis/import_screen.dart`、`app/lib/features/import_analysis/widgets/staged_progress.dart`、`app/test/widget_test.dart`
- **依賴**：`flutter_riverpod ^3.3.2`、`desktop_drop ^0.7.1`、`file_selector ^1.1.0`、`domain`/`infra` path deps；`flutter_lints` 降為 `^5.0.0` 以配合 workspace 既有 `lints ^5.x`。
- **完成內容**：`ProviderScope`、Material 3 theme、NavigationRail shell、最小視窗 1100×700、17/17 錯誤碼映射、拖放/選檔/字稿/separateVocals UI、`Stream<AnalysisEvent>` 階段化進度、preview runner 產出 11 音節結果預覽。

### Frontend FP0/FP2 收尾（真 pipeline 注入＋checkpoint＋editor 導向）
- **狀態**：Done
- **產物（新增）**：
  - `app/lib/shared/infra/sidecar_paths.dart`（開發期 sidecar 本機路徑；env var 可覆寫；`missingPaths()` 檢查）
  - `app/lib/shared/infra/infra_analysis_runner.dart`（實作 `AnalysisRunner`，組裝 `FfmpegDecoder`＋`FfmpegTranscriptionAudioPreparer`＋`WhisperCppTranscriber(noGpu:true)`＋`AlignmentEngine(CmuDictLoader)`）
  - `app/lib/shared/navigation.dart`（`appShellSelectedIndexProvider`＋`AppSection` 列舉；索引改為 `sectionIndex` 以避開 `Enum.index` 衝突）
  - `app/lib/features/editor/editor_screen.dart`（S1a 收尾用最小殼：音節列表＋needsReview 徽章）
  - `app/lib/shared/player/player_bar.dart`（idle/loading/playing 三態元件；真播放邏輯留 S2）
  - `packages/infra/lib/src/sidecar/ffprobe_duration.dart`（`AudioDurationProbe` 抽象＋`FfprobeDurationProbe` 實作，>10 分鐘擋在 pipeline 之前）
  - `packages/infra/test/ffprobe_duration_test.dart`（9 情境：白名單/exit≠0/kill/timeout/spawn/non-number/>10min/success/10min 邊界）
  - `app/test/shared/player_bar_test.dart`（三態＋回呼驗證）
- **產物（修改）**：
  - `packages/domain/lib/src/analysis/analysis_pipeline.dart`：新增 `PipelineCheckpoint`；`analyze(request, {resume})` 支援跳過已完成階段；`failed` 事件攜帶 checkpoint（AT-01-04 落地）
  - `packages/domain/test/analysis_pipeline_test.dart`：+3 checkpoint tests（failed 帶 checkpoint、resume decodedPcm、resume words）
  - `packages/infra/lib/infra.dart`：export `ffprobe_duration.dart`
  - `app/lib/main.dart`：讀 `SidecarPaths.dev()`，就緒時覆寫 `analysisRunnerProvider`＋`audioDurationProbeProvider`
  - `app/lib/features/import_analysis/analysis_controller.dart`：`selectAudioPath` 改 async 觸發 probe；state 加 `lastCheckpoint`＋`canRetryStage`；新增 `retryStage()` 走 resume；`AnalysisRunner` 介面加 `resume` 參數；`PreviewAnalysisRunner` 對應更新
  - `app/lib/features/import_analysis/widgets/staged_progress.dart`：改 `ConsumerWidget`；失敗態顯示「重試此階段」按鈕（僅 `canRetryStage` 為 true 時）；完成態顯示「進入編輯器」切 tab
  - `app/lib/features/import_analysis/import_screen.dart`：`selectAudioPath` 呼叫改 `unawaited`；符合 async 語意
  - `app/lib/shell/app_shell.dart`：改 `ConsumerWidget`；tab index 由 provider 掌控；editor 位置置入 `EditorScreen()`
- **驗證**：見下方「輕量門檻紀錄 — S1a Frontend FP0/FP2 收尾」；真 e2e demo（`flutter run -d macos` 匯入 `step up your coding skills to a new level.mp3` → 11 音節→切 editor）待使用者在裝有完整 Xcode 的機器手動跑，本 session 無 Xcode 無法跑 macOS build。
- **待補**：`hard-guardrails matrix`（將接續 `hard-guardrails` skill 補）。

## 問題記錄

- 2026-07-05：Dart SDK 3.12.2（macOS x64）在本工具 sandbox 內執行 `dart format` / `dart analyze` / `dart test` 會於 `runtime/vm/cpuinfo_macos.cc:42` crash；同指令改用非 sandbox 後可正常執行。後續本機 Dart 驗證若再遇同錯，優先以非 sandbox 執行，不要誤判為程式碼失敗。
- 2026-07-05：Flutter CLI 在 sandbox 內會因寫 `/usr/local/share/flutter/bin/cache` 被擋；Flutter/Dart 前端驗證需非 sandbox 執行。Flutter 指令不要並行，避免 startup lock 互等。
- 2026-07-05：`hard-guardrails matrix` 尚未建立。這是流程治理缺口，review/archive 前必補；目前沒有自動檢查會擋。

## 檔案清單（新增/修改）

- 新增：workspace 根 3 檔＋domain/infra 多檔（見上各任務產物）
- S1a 新增/修改：domain model 3 檔、alignment engine 1 檔、waveform peaks 1 檔、AnalysisPipeline 1 檔、whisper transcriber 1 檔、pipeline infra adapter 1 檔、alignment/whisper/pipeline 測試與整合測試、`packages/domain/test/domain_purity_test.dart`、`domain.dart`/`infra.dart` export、`packages/infra/dart_test.yaml`、`.gitignore`
- 前端起手新增/修改：root `pubspec.yaml` 納入 `app` workspace；`app/pubspec.yaml` 新增 Riverpod/desktop_drop/file_selector 與 domain/infra path deps；`app/lib/main.dart`、`app/lib/shell/`、`app/lib/shared/`、`app/lib/features/import_analysis/`、`app/test/widget_test.dart`；Dart workspace lockfile 集中於根 `pubspec.lock`。
- 前端收尾新增：`app/lib/shared/infra/sidecar_paths.dart`、`app/lib/shared/infra/infra_analysis_runner.dart`、`app/lib/shared/navigation.dart`、`app/lib/shared/player/player_bar.dart`、`app/lib/features/editor/editor_screen.dart`、`packages/infra/lib/src/sidecar/ffprobe_duration.dart`、`packages/infra/test/ffprobe_duration_test.dart`、`app/test/shared/player_bar_test.dart`、`app/test/e2e_pipeline_test.dart`（真檔 e2e）
- 前端收尾修改：`packages/domain/lib/src/analysis/analysis_pipeline.dart`（+ PipelineCheckpoint、resume 參數）、`packages/domain/test/analysis_pipeline_test.dart`（+3 checkpoint tests）、`packages/infra/lib/infra.dart`（export ffprobe）、`app/lib/main.dart`（sidecar paths overrides）、`app/lib/features/import_analysis/analysis_controller.dart`（async selectAudioPath、retryStage、lastCheckpoint、AnalysisRunner resume 參數）、`app/lib/features/import_analysis/widgets/staged_progress.dart`（ConsumerWidget、重試按鈕、進入編輯器按鈕）、`app/lib/features/import_analysis/import_screen.dart`（unawaited 對齊 async 呼叫；`_ImportPanel` 包 `SingleChildScrollView` 修 done 態按鈕出現後 Column overflow 64px）、`app/lib/shell/app_shell.dart`（ConsumerWidget、EditorScreen 掛載、tab index via provider）
- 修改：既有 `FfmpegDecoder` 實作 `AnalysisAudioDecoder` port；任務文件同步 3.1/3.4 與前端 FP0/FP2 兩項狀態。

## 輕量門檻紀錄（編譯階段）— S0 批次

- 後端：`dart pub get`（workspace）✅ → `dart run build_runner build`（infra，Drift 產碼 23 輸出）✅ → `dart analyze` **No issues found** ✅ → `dart test`：domain 5/5 ✅、infra 23/23 ✅（含真 FFmpeg 整合測試：1 秒 WAV → durationMs≈1000，S0 demo 標準）
- 前端：本批次無前端變更（Flutter 尚未安裝），建置闸門不適用
- 失敗分類：無失敗
- **結論：輕量門檻透過**。涵蓋任務：1.1–1.4、2.2、2.3（2.1 部分完成，保持 InProgress）

## 輕量門檻紀錄（編譯階段）— S1a 純 Dart 第一批

- 後端：`dart analyze` **No issues found** ✅ → domain `dart test` 9/9 ✅ → infra `dart test` 28/28 ✅
- 前端：本批次無前端變更（Flutter 尚未安裝），建置闸門不適用
- **結論：輕量門檻透過**。涵蓋任務：3.1、3.2、3.3、3.5；3.4 AnalysisPipeline 尚未實作。

## 輕量門檻紀錄（編譯階段）— S1a AnalysisPipeline

- 後端：`dart format`（本次修改 Dart 檔）✅ → `dart analyze` **No issues found** ✅ → domain `dart test` 12/12 ✅ → infra `dart test` 31/31 ✅
- 整合 demo：infra sidecar 測試以使用者音檔 `step up your coding skills to a new level.mp3` 跑完整 3.4 pipeline，FFmpeg → 16k mono WAV → whisper.cpp small.en `--no-gpu` → CMUdict/AlignmentEngine → 11 音節＋waveform peaks ✅
- 前端：本批次無前端變更（Flutter 尚未安裝），建置闸門不適用
- 備註：Dart 驗證指令須非 sandbox 執行（見問題記錄）；`packages/infra/dart_test.yaml` 已補 `sidecar` tag，測試輸出無未註冊 tag warning。
- **結論：輕量門檻透過**。涵蓋任務：3.4；當時後端 3.1–3.5 已完成，但 S1a 全切片仍待 8.1 防線與前端 FP2。

## 輕量門檻紀錄（編譯階段）— S1a 8.1 Domain purity

- 後端：`dart format packages/domain/test/domain_purity_test.dart` ✅ → `dart analyze` **No issues found** ✅ → domain `dart test` 15/15 ✅
- 防線證據：`domain_purity_test.dart` 會掃描 `packages/domain/lib/**` 的 import/export 與 `packages/domain/pubspec.yaml`，並以 AT-09-02 違規匯入範例驗證檢查器本身能擋 Flutter / infra / `dart:io` / sidecar 實作路徑。
- 前端：本批次無前端變更（Flutter 尚未安裝），建置闸門不適用
- 備註：本次 `dart format` 在 sandbox 內重現 `runtime/vm/cpuinfo_macos.cc:42` crash，依既有 project memory 改用非 sandbox 完成格式化、分析與測試。
- **結論：輕量門檻透過**。涵蓋任務：8.1；S1a 全切片仍需前端 FP0/FP2 才能宣告完成。

## 輕量門檻紀錄（編譯階段）— S1a Frontend FP0/FP2 起手版

- 依賴：`flutter pub get`（workspace root）✅；Pub workspace 將 stray `app/pubspec.lock` / `app/.dart_tool/package_config.json` 移除，根 `pubspec.lock` 作為集中 lockfile。
- 前端：`dart format app/lib app/test` ✅（sandbox 內先重現 `cpuinfo_macos.cc:42`，非 sandbox 成功）→ `flutter analyze` **No issues found** ✅ → `cd app && flutter test` 2/2 ✅
- 修正紀錄：第一次 widget test 抓到拖放區內容在最小視窗下 overflow 32px；已將拖放區高度調整為 230 後重測全綠。
- 失敗分類：root 直接跑 `flutter test` 會因根目錄無 `test/` 報 `Test directory "test" not found.`；正確前端測試位置為 `app/`。
- **結論：輕量門檻透過**。涵蓋：FP0/FP2 起手版、17/17 錯誤碼映射；S1a 全切片仍需真 pipeline 注入與 FP2 剩餘驗收項。

## 輕量門檻紀錄（編譯階段）— S1a Frontend FP0/FP2 收尾

- 依賴：`flutter pub get`（workspace root）✅（`dart pub get` 因 workspace 含 flutter member 無法直接跑，需使用 `flutter pub get`／`flutter test <path>`）
- 後端（純 Dart）：`flutter test packages/domain/test` 18/18 ✅（含新增 3 個 checkpoint tests）；`flutter test packages/infra/test` 39/39 ✅（含新增 9 個 `FfprobeDurationProbe` tests；1 skip 為既有 sidecar tag 過濾）
- 前端：`flutter analyze` **No issues found** ✅ → `cd app && flutter test` 5/5 ✅（widget_test 2 個＋player_bar_test 2 個＋e2e_pipeline_test 1 個）
- 分析修正：
  - `Override` 型別需 `import 'package:flutter_riverpod/misc.dart' show Override;`（Riverpod 3.x 沒有從 flutter_riverpod 主匯出 Override）
  - `AppSection.index` 與 `Enum.index` 衝突→改名 `sectionIndex`
  - `sidecar_paths.dart` 原用 `package:path/path.dart` 但 app 未宣告 dep→改用字串拼接
  - `StateProvider` 屬 Riverpod 3.x legacy→改用 `NotifierProvider` + `AppShellSelectedIndex.select(index)`
- 失敗分類：無失敗
- **結論：輕量門檻透過**。涵蓋任務：FP0（App 殼、shared/player 最小殼）、FP2（真 pipeline 注入、10 分鐘時長前置檢查、分階段 checkpoint 重試、done→editor 導向最小殼）、Domain `PipelineCheckpoint`／`analyze(resume:)`、Infra `FfprobeDurationProbe`。S1a 切片 code 面完成。

## Task S1b（波形校正編輯器）— 2026-07-06

### Task 3.6 updateSyllableBoundary（domain 介面 2）
- **狀態**：Done
- **產物**：`packages/domain/lib/src/alignment/alignment_engine.dart` 新增 `updateSyllableBoundary` + `BoundaryUpdateResult`；`packages/domain/test/alignment_boundary_test.dart`（8 情境）
- **實作重點**：開區間驗證（`prev.startMs < newPositionMs < next.endMs`）→違反拋 `DomainException(ERR_BOUNDARY_INVALID)`；呼叫 3.7 zero-crossing 吸附後 clamp 回開區間；只重建被改邊界左右兩音節（needsReview=false），其餘保原 immutable syllable 實例
- **驗證（AT-02-*）**：AT-02-02（越前一音節起點拒絕）、AT-02-05（等於後一音節 endMs 閉端拒絕）、AT-02-01（吸附 ±10ms 內、needsReview=false）、boundaryIndex 越界 ArgumentError；相鄰音節端點嚴格相接（M2 語意）

### Task 3.7 零交越吸附
- **狀態**：Done
- **產物**：`packages/domain/lib/src/alignment/zero_crossing.dart`（`findNearestZeroCrossingMs` 純函式＋常數 `kZeroCrossingSearchWindowMs=10`）
- **實作重點**：對稱搜尋 ≤±10ms（±441 sample @44.1kHz）；判定 `sample[i-1]` 與 `sample[i]` 變號或前為 0；找不到回原 targetMs（不吸附）；上下邊界 clamp 不 crash
- **常數共用**：`kZeroCrossingSearchWindowMs` 亦供 S2 task 4.4 `renderStep` 端點 ≤10ms fade 收尾複用（backend-design §0.1 M1）

### Task FP0/FP3 peaks 快取
- **狀態**：Done
- **產物**：`packages/domain/lib/src/ports/waveform_peaks_cache.dart`（port 抽象）；`packages/infra/lib/src/analysis/file_waveform_peaks_cache.dart`（走 `AtomicFileIo` 存 `<dir>/waveform-<key>.json`，schemaVersion=1）；`packages/infra/test/file_waveform_peaks_cache_test.dart`（5 情境）
- **實作重點**：M5 domain 純度——port 在 domain、實作在 infra；key sanitize 只保 `[a-zA-Z0-9_-]`（避免斜線逃出目錄）；schemaVersion 不符/毀損檔一律當 miss，不擋 UI

### Task FP3 前端（WaveformCanvas + EditorController + EditorScreen）
- **狀態**：Done
- **產物**：
  - `app/lib/features/editor/editor_controller.dart`（Riverpod Notifier）
  - `app/lib/features/editor/widgets/waveform_canvas.dart`（CustomPaint + RepaintBoundary）
  - `app/lib/features/editor/editor_screen.dart`（改造：Focus.onKeyEvent 綁 ⌘/^Z undo；SnackBar 顯示 error；試聽 stub）
  - `app/test/editor/editor_controller_test.dart`（7 情境）＋`app/test/editor/waveform_canvas_test.dart`（3 情境）
- **實作重點**：
  - `EditorController` 監聽 `analysisControllerProvider` done→`loadFrom(result.syllables)`；state 內 undoStack 為 `List<List<Syllable>>` 每筆為完整快照；`dragEnd(Pcm?)` 接受 nullable pcm（測試易注入 fake、無 pcm 時清拖動不動 syllables）
  - `WaveformCanvas` `hitToleranceDp=12`；`onPanDown` 命中→onDragStart；`onPanUpdate` 依 `draggingBoundaryIndex` 為 non-null 才 fire；拖動預覽線用 `tertiary` 高亮突出
  - `EditorScreen` `Focus + onKeyEvent` 綁 macOS ⌘Z / 其他 ^Z 走 undo；試聽 SyllableChip 點擊顯示「S2 接入」SnackBar
- **驗證（AT-02-*）**：AT-02-01（吸附落點）、AT-02-02/05（回彈＋SnackBar）、AT-02-03（連續拖動只送最終值）、AT-02-04（undo 從堆疊 pop）；`e2e_pipeline_test.dart` 同步更新（改讀 editor controller state 驗 11 音節）

## Task S1c（demucs.cpp 分離契約接入）— 2026-07-06

### OQ-2 授權核對（M9 CT-09 前置，hard-guardrails matrix #12 進度）
- **狀態**：Done
- **結果**：sevagh/demucs.cpp = **MIT License, Copyright (c) 2023 Sevag H**（透過 WebFetch `https://raw.githubusercontent.com/sevagh/demucs.cpp/main/LICENSE`），無 non-commercial／share-alike 條款；主依賴 Eigen = **MPL-2.0**（檔案級 copyleft、不傳染主程式）；皆通過 M9 白名單。決策記入 memory `decision_demucs_cpp_selected_mit_licence`。

### Task 3.8 domain 端 port（S1a 已就緒）＋infra adapter（本輪）
- **狀態**：Done
- **產物（新增）**：
  - `packages/infra/lib/src/sidecar/demucs_separator.dart`（`DemucsCppVocalSeparator implements AnalysisVocalSeparator`）
  - `packages/infra/test/demucs_separator_test.dart`（7 情境：exit≠0／kill -9／timeout／spawn／vocals.wav 未生成／成功 CLI+decoder 讀回／workDir sanitize）
  - `packages/infra/test/demucs_integration_test.dart`（`@Tags(['sidecar'])`；缺 demucs 二進位/模型即 `markTestSkipped`）
- **產物（修改）**：`packages/infra/lib/infra.dart`（export demucs_separator）

### Task S1c-1/5 SidecarPaths 擴充＋條件性注入
- **狀態**：Done
- **產物（修改）**：
  - `app/lib/shared/infra/sidecar_paths.dart`：加 `demucsCliPath`／`demucsModelDir`（env `DEMUCS_CLI_PATH`／`DEMUCS_MODEL_DIR` 覆寫，fallback `.local-tools/demucs.cpp/build/bin/demucs.cpp`／`.local-tools/demucs.cpp/ggml-model-htdemucs`）；`missingPaths()` 不納入 demucs；新增 `demucsAvailable()` bool
  - `app/lib/shared/infra/infra_analysis_runner.dart`：`paths.demucsAvailable()` 條件性建 `DemucsCppVocalSeparator` 注入 pipeline；未就緒時 `vocalSeparator: null`，pipeline 內 `if (vocalSeparator != null)` 走 null 分支自動降級（backend-design §5 第 704 行、M4）
  - `app/lib/main.dart`：新增 `demucsReadyProvider.overrideWithValue(paths.demucsAvailable())` 無條件覆寫（供 UI 讀）
  - `app/lib/features/import_analysis/analysis_controller.dart`：新增 `demucsReadyProvider`（預設 false，widget test 無覆寫即等同「未就緒」）

### Task S1c-6 UI「demucs 未就緒」提示
- **狀態**：Done
- **產物（修改）**：`app/lib/features/import_analysis/import_screen.dart`：`separateVocals` Row 內加 `Consumer(demucsReadyProvider)`——當就緒=false 且勾了 separateVocals 才顯示 `Icons.info_outline` + Tooltip「demucs 未就緒；勾選仍會分析，但將降級使用原音（backend-design M4）」
- **產物（新增）**：`app/test/features/import_analysis/import_screen_demucs_hint_test.dart`（3 情境：ready → 勾了不顯示／未 ready + 未勾不顯示／未 ready + 勾了顯示 tooltip 且訊息含「demucs 未就緒」）

## 輕量門檻紀錄（編譯階段）— S1c

- 後端（純 Dart）：`flutter test packages/domain/test` **29/29 ✅**（既有；本輪未動 domain）；`flutter test packages/infra/test` **51/51 ✅**（+7 demucs adapter；1 skip 既有 sidecar + 1 skip demucs integration 未安裝）
- 前端：`flutter analyze` **No issues found** ✅ → `cd app && flutter test` **18/18 ✅**（+3 demucs hint）
- 分析修正：①`fake` closure 內部引用同名 `final` 變數 → 改 `late _FakeRunner fake` 兩步宣告；②widget test `pumpAndSettle` 撞 Checkbox splash animation timeout → 改 `pump() + pump(300ms)`；③unused import
- 失敗分類：無失敗
- **結論：輕量門檻透過**。涵蓋任務：3.8（demucs 契約接入）＋SidecarPaths 擴充＋UI 未就緒提示；demucs.cpp 真整合測試待使用者本機 build＋htdemucs 模型下載後自動變綠。

## 輕量門檻紀錄（編譯階段）— S1b

- 後端（純 Dart）：`flutter test packages/domain/test` **29/29 ✅**（+8：boundary 7 + zero-crossing 4；含既有 21）；`flutter test packages/infra/test` **44/44 ✅**（+5：peaks cache 5；1 skip 為既有 sidecar tag）
- 前端：`flutter analyze` **No issues found** ✅ → `cd app && flutter test` **15/15 ✅**（+10：editor controller 7 + waveform canvas 3；含既有 5）
- 失敗分類：無失敗（過程中兩處臨時 fail：①`file_waveform_peaks_cache_test` 局部變數命名 lint→改 `makeCache`；②`waveform_canvas_test` 邊界拖動 `onPanUpdate` 依 `draggingBoundaryIndex` 需 stateful host 模擬 controller wire up；③`e2e_pipeline_test` 舊斷言 `#1`/`#11` 為 EditorScreen 最小殼版標籤，本輪 chip 化改讀 controller state；均已修正）
- **結論：輕量門檻透過**。涵蓋任務：3.6／3.7／FP3 三卡（WaveformCanvas＋邊界校正流程＋試聽 stub）；S1b 切片 code 面完成。

## Task S2（PracticeEngine + FP4 播放）— 2026-07-06

### Task 4.1/4.2 buildSteps（CT-02）
- **狀態**：Done（TDD-red → green）
- **紅測試紀錄**：先新增 `packages/domain/test/practice_build_steps_test.dart`，`flutter test packages/domain/test` 於 `PracticeStep`／`PracticeEngine` 尚未存在時如預期編譯失敗（S2-1）。
- **產物**：`packages/domain/lib/src/model/practice_step.dart`、`packages/domain/lib/src/practice/practice_engine.dart`、`packages/domain/lib/domain.dart` export。
- **實作重點**：`buildSteps(syllables, repeatN)` 純函式；repeatN 1–10 越界回 `ERR_REPEATN_OUT_OF_RANGE`；第 n 步＝句尾倒數 n 個音節；`sourceRanges` 僅存原音 `TimeRange`；相鄰區間合併；`totalDurationMs = sourceRanges duration sum × repeatN`。
- **驗證**：金標準句 11 步、第 2 步 `tion skills`（不退回 `communication skills`）、第 11 步整句、5 音節句 5 步、repeatN 3→5 只改 duration 不改 sourceRanges、repeatN 0/11 拒絕。

### Task 4.3/4.4 renderStep（CT-01）
- **狀態**：Done（TDD-red → green）
- **紅測試紀錄**：先在 `practice_build_steps_test.dart` 加 renderStep CT-01 測試，`flutter test packages/domain/test` 於 `renderStep` method 尚未存在時如預期編譯失敗（S2-3）。
- **產物**：`PracticeEngine.renderStep(PracticeStep step, Pcm originalPcm)`。
- **實作重點**：唯一資料來源為 `originalPcm`；逐段 copy `step.sourceRanges` 對應 sample，再串接；每段端點以 `findNearestZeroCrossingMs`/`kZeroCrossingSearchWindowMs` 判斷，找不到精準 zero-crossing 時只做 ≤10ms 線性 fade。沒有生成/合成音訊路徑。
- **驗證**：AT-03-02 第 1 步 `skills` 區間輸出逐 sample 來自原 PCM；多段 sourceRanges 依序串接且內部 sample 不可生成或重算（端點 ≤10ms fade 差異除外）。

### Task S2-5 WAV encoder
- **狀態**：Done
- **產物**：`packages/domain/lib/src/practice/wav_encoder.dart`、`packages/domain/test/wav_encoder_test.dart`、`domain.dart` export。
- **實作重點**：純 Dart `encodeWav(Pcm)` 產生 RIFF/WAVE 16-bit mono little-endian bytes；Domain 不碰檔案、不依賴播放器、不破壞 M5。
- **驗證**：測試直接核對 `RIFF`/`WAVE`/`fmt ` / `data` header、byteRate/blockAlign/bitsPerSample 與 sample little-endian bytes；空 PCM 仍產生合法 44 bytes header。

### Task 4.7 單音節試聽支援
- **狀態**：Done
- **產物**：`PracticeEngine.singleSyllableStep(Syllable)`；`app/lib/features/editor/editor_screen.dart` 的 syllable chip 從 SnackBar stub 改為真 `practicePlayerProvider.playStep(... repeatN: 1)`。
- **驗證**：domain helper 測試確保只引用該音節原始 `TimeRange`；widget test `Editor syllable chip 呼叫 4.7 單音節播放` 以 fake player 驗證 repeatN=1 且 step 只含該音節。

### FP4 PracticeScreen 步驟導航與播放
- **狀態**：Done（播放部分；錄音比對/難度結算屬 S5/S6 Non-scope）
- **產物（新增）**：
  - `app/lib/features/practice/practice_player.dart`：`PracticePlayback`/`PracticeAudioBackend` 抽象、`JustAudioPracticeBackend`（`AudioSource.uri(Uri.file(path))`）、`PracticePlayer`（renderStep→repeatN 預串接→encodeWav→`<temp>/syllable_repeater_steps/step-<hash>.wav`→播放）。
  - `app/lib/features/practice/practice_controller.dart`：Riverpod Notifier，state = `{steps,currentIndex,repeatN,playStatus,decodedPcm,error}`；監聽 editor syllables 與 analysis decoded PCM；`selectStep` 先 stop；`setRepeatN` 重建 steps；`play/stop` 串接 fake-able player。
  - `app/lib/features/practice/practice_screen.dart`：StepNavigator（ChoiceChip）、repeatN +/-（1–10）、PlayerBar（開始/停止、loading/playing/idle）。
  - `app/test/practice/practice_player_test.dart`、`practice_controller_test.dart`、`practice_screen_test.dart`。
- **產物（修改）**：
  - `app/pubspec.yaml` + root `pubspec.lock`：新增 `just_audio: ^0.10.6`（pub.dev 2026-07-06 查得最新穩定 0.10.6，支援 macOS/file playback）。
  - `app/macos/Flutter/GeneratedPluginRegistrant.swift`：`flutter pub get` 自動註冊 `audio_session`／`just_audio` macOS plugin。
  - `app/lib/shell/app_shell.dart`：練習 tab 由 placeholder 改 `PracticeScreen()`。
  - `app/lib/features/editor/editor_screen.dart`：單音節 chip 走 4.7 真播放；無 decoded PCM 時顯示「尚無可播放的原音 PCM」。
- **實作重點**：使用者拍板的「寫檔→just_audio 播檔」已落地；播放器快取檔 hash 由 step/sourceRanges/repeatN/PCM 基本特徵生成；測試以 fake playback 避免啟動平台播放器；未關 macOS App Sandbox（M9 前置仍保留）。
- **驗證**：controller test 覆蓋 5 步建構、repeatN 3→5、repeatN 越界、切步先 stop、play 呼叫 fake player、無 PCM 錯誤；widget test 覆蓋 PracticeScreen 導航/repeatN/播放與 editor chip 單音節播放。

## 輕量門檻紀錄（編譯階段）— S2 PracticeEngine + FP4 播放

- 後端（純 Dart）：`flutter test packages/domain/test` **39/39 ✅**（+10：buildSteps/renderStep/singleSyllableStep/WAV encoder；CT-01/CT-02 已落地）；`flutter test packages/infra/test` **51/51 ✅**（2 skip：whisper/demucs 本機 sidecar 未裝）
- 前端：`flutter analyze` **No issues found** ✅ → `cd app && flutter test` **27/27 ✅**（+9：practice player/controller/screen/editor chip）
- 依賴：`flutter pub get` ✅；新增 `just_audio 0.10.6` 及其轉移依賴。macOS App Sandbox 未變更，真 App UI demo 仍依 S1a 決策 waive 到 M9。
- Guardrails：`python3 scripts/check_guardrails.py ...` **預期不通過**，仍有 5 條 `REJECTED_NEEDS_IMPLEMENTATION`（#9/#22/#23/#31/#34），pre-push 會繼續擋遠端推送；本輪未宣告 review/archive。
- 失敗分類：無程式碼失敗；工具環境重現兩個既知問題：①sandbox 內 Flutter CLI 寫 SDK cache 被擋，改非 sandbox 執行；②sandbox 內 Dart format 仍可見 `cpuinfo_macos.cc:42`，改非 sandbox 執行。
- **結論：輕量門檻透過**。涵蓋任務：4.1、4.2、4.3、4.4、4.7、FP4 播放部分；4.5/4.6 匯出與 FP4 錄音比對仍為後續切片。

## Task S3（PracticeEngine exportStep/exportMerged + FP5 匯出）— 2026-07-06

### Task 4.5 匯出靜音規則測試（CT-03）
- **狀態**：Done（TDD-red → green）
- **紅測試紀錄**：先新增 `packages/domain/test/practice_export_test.dart`，`flutter test packages/domain/test/practice_export_test.dart` 於 `PracticeEngine.renderMergedExport` 尚未存在時如預期編譯失敗（S3-1）。
- **驗證情境**：`thank you very much`、N=3、全 5 步合併，`silenceGapsMs = [1200, 1800, 2400, 3000]`；單步合併成功且無尾端靜音。對應 REQ-04 AT-04-02/03/06、CT-03/M3。

### Task 4.6 exportStep/exportMerged
- **狀態**：Done
- **產物（新增）**：
  - `packages/domain/lib/src/practice/practice_export_audio.dart`：純 domain 匯出音訊組裝結果（`pcm`、`totalDurationMs`、`silenceGapsMs`）。
  - `packages/infra/lib/src/practice/practice_exporter.dart`：`PracticeExporter` + `PracticeExportResult`，負責 FFmpeg MP3 encode、temp WAV、atomic write、同 destPath 重入鎖。
  - `packages/infra/test/practice_exporter_test.dart`：fake runner/fileIo 覆蓋 MP3 bytes 寫入、`silenceGapsMs`、`ERR_EXPORT_IN_PROGRESS`、`ERR_EXPORT_DEST_UNWRITABLE`。
- **產物（修改）**：
  - `packages/domain/lib/src/practice/practice_engine.dart`：新增 `renderExportStep` / `renderMergedExport`；重複次數由 `PracticeStep.totalDurationMs / sourceRanges duration` 推回；段落間以 sample count 插入前一步 totalDurationMs 的 zero samples；末步後不補靜音。
  - `packages/domain/lib/domain.dart`：export `practice_export_audio.dart`。
  - `packages/infra/lib/infra.dart`：export `practice_exporter.dart`。
- **分層決策**：backend-design 介面 5/6 描述含 FFmpeg 與檔案寫入，但 M5/domain purity 禁止 `packages/domain` 依賴 `dart:io`/Process/infra。實作採 domain 純 PCM 組裝 + infra exporter adapter，保留設計意圖且不破壞 M5。
- **驗證**：domain test 驗 M3/CT-03；infra test 驗 FFmpeg runner args 帶 `libmp3lame` 與 `-f mp3 -`、temp input 會刪除、目的地不可寫映射 `ERR_EXPORT_DEST_UNWRITABLE`、同 destPath 進行中重入映射 `ERR_EXPORT_IN_PROGRESS`。

### FP5 匯出對話框
- **狀態**：Done
- **產物（新增）**：
  - `app/lib/features/export/export_dialog.dart`：`PracticeExportDialog`、`PracticeExportService` provider、`ExportSaveLocationPicker` provider、Finder reveal provider。UI 支援步驟 checkbox、macOS save dialog、匯出進度、完成路徑、總長、`silenceGapsMs` 與「在 Finder 顯示」。
  - `app/test/export/export_dialog_test.dart`：4 情境：未勾選任何步驟時匯出 disabled；多步匯出成功顯示總長與 silence gaps；目的地不可寫錯誤就地顯示且保留勾選；匯出中顯示進度且按鈕 disabled。
- **產物（修改）**：
  - `app/lib/features/practice/practice_screen.dart`：Header 加「匯出」按鈕；只有 `decodedPcm` 存在時可開啟 FP5 dialog。
- **Non-scope 保留**：未做匯出歷史紀錄；未做錄音比對（S5）；未做難度結算（S6）；未更動 macOS App Sandbox（M9 前置仍保留）。

## 輕量門檻紀錄（編譯階段）— S3 PracticeEngine export + FP5 匯出

- 格式化：`dart format packages/domain/lib/src/practice/practice_engine.dart packages/domain/lib/src/practice/practice_export_audio.dart packages/domain/lib/domain.dart packages/domain/test/practice_export_test.dart packages/infra/lib/src/practice/practice_exporter.dart packages/infra/lib/infra.dart packages/infra/test/practice_exporter_test.dart app/lib/features/export/export_dialog.dart app/lib/features/practice/practice_screen.dart app/test/export/export_dialog_test.dart` ✅
- 分析：`flutter analyze` **No issues found** ✅
- 後端（純 Dart）：`flutter test packages/domain/test` **41/41 ✅**（+2：S3 CT-03 export assembly）；`flutter test packages/infra/test` **55/55 ✅**（2 skip：whisper/demucs 本機 sidecar 未裝；+4 PracticeExporter tests）
- 前端：`cd app && flutter test` **31/31 ✅**（+4 FP5 export dialog tests）
- Guardrails：`python3 scripts/check_guardrails.py ...` 仍預期不通過，剩餘 5 條 `REJECTED_NEEDS_IMPLEMENTATION`（#9/#22/#23/#31/#34）；pre-push 仍不得繞過。
- 失敗分類：無程式碼失敗；第一次 `cd app && flutter test ...` 在 sandbox 內因 Flutter CLI 寫 `/usr/local/share/flutter/bin/cache` 被擋，依既有 workflow 改非 sandbox 執行後通過。
- **結論：輕量門檻透過**。涵蓋任務：4.5、4.6、FP5；S3 code 面完成。S4（ProsodyAnalyzer）、S5（錄音比對）、S6（難度結算/進度）仍未開始。

## Task S4（ProsodyAnalyzer + FP3 韻律疊圖）— 2026-07-06

### Task 5.1 rhythm / intensity / 停頓 / stress
- **狀態**：Done（TDD-red 起始於 `ProsodyAnalyzer` 不存在，後續補齊低能量停頓覆蓋）
- **產物（新增）**：
  - `packages/domain/lib/src/model/prosody.dart`：`Prosody` immutable result，欄位對齊 backend-design 介面 7。
  - `packages/domain/lib/src/analysis/prosody_analyzer.dart`：純 domain `ProsodyAnalyzer.analyze(Pcm, List<Syllable>)`。
  - `packages/domain/test/prosody_analyzer_test.dart`：REQ-05 AT-05-01/02/03/04 與 5.1 低能量停頓 intensity 覆蓋。
- **實作重點**：rhythm = 有效音節時長 / 平均有效音節時長；intensity = 固定窗 RMS 曲線；stress = 音節 RMS energy × duration weight。停頓偵測依 backend-design 介面 7 不擴張 `Prosody` 欄位，落在 `intensity[]` 的低能量窗，測試以 voiced→silence→voiced PCM 鎖定 pause windows 近 0。
- **AT-05-03 落點**：`Syllable` constructor 保持 `endMs > startMs` invariant，不為測試放寬 domain model；資料損毀情境以 sample index 換算後無有效樣本的音節標 `NaN` 覆蓋，整體分析不失敗。

### Task 5.2 pitch extraction + 降級
- **狀態**：Done
- **實作重點**：pitch extraction 以 autocorrelation style 實作並封裝於 `ProsodyAnalyzer` 內，未引入 WORLD/CREPE；零 PCM/近似氣音抽不到時回 `pitchAvailable=false`、`pitchContour=null`，rhythm/intensity/stress 照常回傳，不進錯誤態。
- **只讀保證**：測試保存 `pcm.samples` 前後快照，確認 ProsodyAnalyzer 不改寫 PCM；Domain purity test 仍驗證不 import Flutter/infra/sidecar/platform API（M5）。

### FP3 韻律疊圖顯示
- **狀態**：Done
- **產物（新增）**：
  - `app/lib/features/editor/widgets/prosody_overlay.dart`：`ProsodyOverlayControls`，提供「韻律疊圖」Switch 與「音高不可用」徽章。
  - `app/test/editor/editor_screen_prosody_test.dart`：AT-05-02 pitch unavailable 顯示徽章而非 error。
- **產物（修改）**：
  - `app/lib/features/editor/editor_controller.dart`：新增 `prosodyAnalyzerProvider`、`AsyncValue<Prosody>? prosody`、`showProsodyOverlay`；analysis done / dragEnd / undo 後同步重算 prosody。
  - `app/lib/features/editor/editor_screen.dart`：Header 掛韻律疊圖控制，WaveformCanvas 傳入 `Prosody?`，Syllable chip 對 NaN prosody 音節灰化。
  - `app/lib/features/editor/widgets/waveform_canvas.dart`：選擇性繪製 pitch curve、stress markers、invalid/NaN 音節灰底，不改動 hit-test/domain 呼叫職責。
  - `app/test/editor/editor_controller_test.dart`、`waveform_canvas_test.dart`：補 prosody state、overlay toggle、疊圖 smoke/NaN 不 crash。
- **Non-scope 保留**：未做疊圖匯出圖片；未做錄音比對（S5）；未做難度結算（S6）；未更動 macOS App Sandbox（M9 前置仍保留）。

## 輕量門檻紀錄（編譯階段）— S4 ProsodyAnalyzer + FP3 韻律疊圖

- 格式化：`dart format packages/domain/test/prosody_analyzer_test.dart app/lib/features/editor/editor_controller.dart app/lib/features/editor/editor_screen.dart app/lib/features/editor/widgets/waveform_canvas.dart app/lib/features/editor/widgets/prosody_overlay.dart app/test/editor/editor_controller_test.dart app/test/editor/waveform_canvas_test.dart app/test/editor/editor_screen_prosody_test.dart` ✅
- 分析：`flutter analyze` **No issues found** ✅
- 後端（純 Dart）：`flutter test packages/domain/test` **46/46 ✅**（+5 ProsodyAnalyzer tests；含 M5 domain purity）
- Infra：`flutter test packages/infra/test` **55/55 ✅**（2 skip：whisper/demucs 本機 sidecar 未裝）
- 前端：`app/` 內 `flutter test` **35/35 ✅**（+4 editor/prosody tests；e2e pipeline test 本輪通過）
- Guardrails：`python3 scripts/check_guardrails.py ...` 仍預期不通過，剩餘 5 條 `REJECTED_NEEDS_IMPLEMENTATION`（#9/#22/#23/#31/#34）；pre-push 仍不得繞過。
- 失敗分類：S4 局部第一次 editor tests 因 `List.unmodifiable` 未標泛型被推成 `List<dynamic>` 編譯失敗；已改為 `List<Syllable>.unmodifiable(...)` 後全綠。
- **結論：輕量門檻透過**。涵蓋任務：5.1、5.2、FP3 韻律疊圖；S4 code 面完成。S5（錄音比對）、S6（難度結算/進度）仍未開始。

## Task S5（RecordingComparator + FP4 錄音比對）— 2026-07-06

### Task 6.1 RecordingComparator 比對測試（CT-10 / AT-06-02）
- **狀態**：Done（TDD-red → green；red 起始於 `RecordingAudioSource` / `RecordingComparator` 尚未存在）
- **產物（新增）**：
  - `packages/domain/lib/src/model/comparison_result.dart`：`ComparisonResult`、`OverlayData`。
  - `packages/domain/lib/src/ports/recording_audio_source.dart`：`RecordingAudioSource` port，讓 Domain 能要求讀取/刪除錄音但不 import `dart:io`。
  - `packages/domain/lib/src/recording/recording_comparator.dart`：`RecordingComparator.compare(...)`。
  - `packages/domain/test/recording_comparator_test.dart`：成功、過短、decode 失敗、10 秒效能/差異輸出。
- **實作重點**：Domain 依 `PracticeStep` 與整句 `syllables` 驗證 step 來源，再以 `PracticeEngine.renderExportStep(step, originalPcm).pcm` 切出 reference segment；`try/finally` 保證 `audioSource.delete(userRecordingPath)`，成功、`ERR_RECORDING_TOO_SHORT`、`ERR_DECODE_FAILED` 均會刪錄音。

### Task 6.2 DTW 對齊 + overlayData
- **狀態**：Done
- **實作重點**：以 RMS curve 做 rhythm DTW，以 pitch contour 做 intonation DTW；`overlayData` 含 user/reference wave、user/reference pitch 與 `diffRanges`。10 秒錄音測試以降採樣曲線驗證 2 秒內完成；`score` 依需求作為 optional 值回傳，UI 不強依賴。

### Infra FileRecordingAudioSource
- **狀態**：Done
- **產物（新增）**：
  - `packages/infra/lib/src/practice/recording_audio_source.dart`
  - `packages/infra/test/recording_audio_source_test.dart`
- **實作重點**：`FileRecordingAudioSource` 透過 `FileIo.readBytes/delete` 實作 domain port；支援 RIFF/WAVE PCM 16-bit mono decode，格式錯誤映射 `ERR_DECODE_FAILED`，delete 轉交 `FileIo` 供 CT-10 驗證。

### FP4 錄音比對面板與疊圖
- **狀態**：Done
- **產物（新增）**：
  - `app/lib/features/practice/practice_recording.dart`：`PracticeRecorder`、`RecordPracticeRecorder`（record 套件錄 WAV、level stream）、`PracticeComparisonService`。
  - `app/lib/features/practice/widgets/record_panel.dart`：錄音/停止/丟棄、level meter、差異摘要。
  - `app/lib/features/practice/widgets/overlay_chart.dart`：雙波形/音高 overlay 與 diffRanges 標色。
- **產物（修改）**：
  - `app/lib/features/practice/practice_controller.dart`：新增 `PracticeRecordStatus`、`recordingLevel`、`comparison`、`startRecording/stopRecording/cancelRecording`；錄音中 `canPlay=false`；切步時 cancel 錄音並清 comparison。
  - `app/lib/features/practice/practice_screen.dart`：掛入 RecordPanel；錯誤仍走既有 ErrorMessages/SnackBar，`ERR_MIC_PERMISSION_DENIED` 顯示系統設定指引。
  - `app/pubspec.yaml` / root `pubspec.lock`：新增 `record ^7.1.1`；`GeneratedPluginRegistrant.swift` 自動註冊 `record_macos`。
  - `app/macos/Runner/Info.plist`：新增 `NSMicrophoneUsageDescription`。
  - `app/macos/Runner/DebugProfile.entitlements`、`Release.entitlements`：新增 `com.apple.security.device.audio-input=true`；**未修改** `com.apple.security.app-sandbox`。
  - `app/test/practice/practice_controller_test.dart`、`practice_screen_test.dart`：新增 AT-06 controller/widget coverage。
- **實作重點**：`PracticeRecorder` provider 延遲到真正開始錄音才建立 record plugin，避免 `IndexedStack` 隱藏 PracticeScreen 在 widget/e2e test 啟動時就 new `AudioRecorder()` 造成 MissingPluginException；controller 以 `_activeRecorder` 保存已啟動的 recorder，dispose 不讀 Riverpod `ref`。
- **Non-scope 保留**：未建立 Attempt 持久化，因 ProgressEngine / DB attempt 寫入屬 S6；本輪只在 UI state 保留 `ComparisonResult`。未做一鍵開啟 macOS 系統設定，只以明確中文文案指引（符合 AT-06-05「引導設定，App 不崩」最小落點）。

## 輕量門檻紀錄（編譯階段）— S5 RecordingComparator + FP4 錄音比對

- 格式化：`dart format app/lib/features/practice/practice_controller.dart app/lib/features/practice/practice_recording.dart app/lib/features/practice/practice_screen.dart app/lib/features/practice/widgets/record_panel.dart app/lib/features/practice/widgets/overlay_chart.dart app/test/practice/practice_controller_test.dart app/test/practice/practice_screen_test.dart` ✅
- 分析：`flutter analyze` **No issues found** ✅
- 後端（純 Dart）：`flutter test packages/domain/test` **50/50 ✅**（+4 RecordingComparator tests；含 CT-10 錄音刪除斷言、AT-06-02、10 秒 ≤2s）
- Infra：`flutter test packages/infra/test` **58/58 ✅**（2 skip：whisper/demucs 本機 sidecar 未裝；+3 FileRecordingAudioSource tests）
- 前端：`app/` 內 `flutter test` **42/42 ✅**（+7 practice recording controller/widget tests；e2e pipeline test 本輪通過且不再因 record plugin MissingPluginException 失敗）
- Guardrails：`python3 scripts/check_guardrails.py ...` 仍預期不通過，剩餘 5 條 `REJECTED_NEEDS_IMPLEMENTATION`（#9/#22/#23/#31/#34）；pre-push 仍不得繞過。
- 失敗分類：S5 app 全測第一次因 `IndexedStack` 隱藏 PracticeScreen 也 build，`PracticeController.build()` 立即讀 `practiceRecorderProvider`，導致 widget test new `AudioRecorder()` 並拋 `MissingPluginException`；已改為 recorder 延遲初始化，並在 controller tests 以 fake recorder 覆蓋錄音流程。另一次 Riverpod lifecycle 失敗來自 dispose 內 `ref.exists/ref.read`，已改用 `_activeRecorder` 保存 instance，dispose 不碰 ref。
- **結論：輕量門檻透過**。涵蓋任務：6.1、6.2、FP4 錄音比對；S5 code 面完成。S6（LessonPack/AIService/ProgressEngine/難度結算）仍未開始。

## Task S6-1（LessonPackEngine .abopack write/read）— 2026-07-06

### Task 7.1 `.abopack` write/read（REQ-07 / AT-07-01 / AT-07-03 / AT-07-05）
- **狀態**：Done（TDD-red → green；red 起始於 `Lesson` / `LessonPackEngine` / `Translation` / `PracticeConfig` 尚未存在）
- **產物（新增）**：
  - `packages/domain/lib/src/model/lesson.dart`：`Lesson` 聚合，保存 pack 內 `audioRelPath` 與原音 bytes；`recomputeContentHash()` 以原音 bytes + syllables JSON 算 SHA-256。
  - `packages/domain/lib/src/model/translation.dart`：`Translation` 與 `TranslationSource.manual/ai`。
  - `packages/domain/lib/src/model/practice_config.dart`：`PracticeConfig(repeatN)`，守 1..10。
  - `packages/domain/lib/src/pack/lesson_pack_engine.dart`：`LessonPackEngine.write/read`，以 zip + JSON 落地 `.abopack`。
  - `packages/domain/test/lesson_pack_engine_test.dart`：AT-07-01 round-trip、AT-07-03 損毀 zip/缺音訊拒絕、AT-07-05 pack 無 key/無絕對路徑。
- **產物（修改）**：
  - `packages/domain/lib/domain.dart`：export Lesson / Translation / PracticeConfig / LessonPackEngine。
  - `packages/domain/lib/src/model/prosody.dart`：補值相等，支援 pack round-trip 測試。
  - `packages/domain/pubspec.yaml` / root `pubspec.lock`：新增純 Dart `archive ^3.6.1` 與 `crypto ^3.0.7`。
- **實作重點**：`write` 先重算 `contentHash`，manifest 固定 `schemaVersion=1`，pack entry 使用相對路徑（如 `audio/original.wav`），並透過 `FileIo.writeBytesAtomic` 寫入；`read` 先完整解 zip、驗 manifest/schema/audio entry/contentHash，再回傳 `Lesson`，任一結構不符一律 `ERR_PACK_CORRUPTED`，不部分載入。Domain 仍不 import `dart:io`、Flutter、infra 或 sidecar。
- **Non-scope 保留**：未做 AIService/Keychain/翻譯；未做 ProgressEngine / `.aboprogress`；未做授權/防盜欄位（REQ-07 Non-scope 4）；未做前端 FP6 儲存/開啟 UI。

## 輕量門檻紀錄（編譯階段）— S6-1 LessonPackEngine

- 格式化：`dart format packages/domain/lib/src/model/translation.dart packages/domain/lib/src/model/practice_config.dart packages/domain/lib/src/model/lesson.dart packages/domain/lib/src/pack/lesson_pack_engine.dart packages/domain/lib/src/model/prosody.dart packages/domain/lib/domain.dart packages/domain/test/lesson_pack_engine_test.dart` ✅
- TDD-red：`flutter test packages/domain/test/lesson_pack_engine_test.dart` 初始因 `Lesson` / `LessonPackEngine` / `Translation` / `PracticeConfig` 未存在而紅 ✅
- 目標測試：`flutter test packages/domain/test/lesson_pack_engine_test.dart` **4/4 ✅**
- 分析：`flutter analyze` **No issues found** ✅
- 後端（純 Dart）：`flutter test packages/domain/test` **54/54 ✅**（+4 LessonPackEngine tests；含 M5 domain purity 與 AT-07-01/03/05）
- **結論：輕量門檻透過**。涵蓋任務：7.1；S6-1 code 面完成。S6-1 收尾當時，S6-2（AIService + 8.4.3/8.4.4/8.4.5）仍未開始，且 7.2 屬 `[需要回報]`。

## Task S6-2（AIService Domain ports + hard-guardrails #23/#31/#34）— 2026-07-06

### Task 7.2 AIService（Domain 可測部分；REQ-07 / AT-07-02 / AT-07-04 / AT-07-06）
- **狀態**：InProgress（Domain port + fake client tests 完成；真 Keychain adapter / 真 provider HTTP adapter 待外部服務商契約與 key 安全路徑回報核對）
- **TDD-red**：`packages/domain/test/ai_service_test.dart` 初始因 `AIService` / `AiClient` / `SecureStore` / `AiProviderConfig` / `AiRateLimit` 等符號未存在而編譯紅 ✅
- **產物（新增）**：
  - `packages/domain/lib/src/ports/secure_store.dart`：`SecureStore` key/value port；Domain 不碰 Keychain/Flutter。
  - `packages/domain/lib/src/ports/ai_client.dart`：`AiClient` port、`AiProviderConfig`、`AiClientRequest`、`AiClientResponse`。
  - `packages/domain/lib/src/ai/ai_service.dart`：`AIService.configure/translate/mergeTranslation`、`AiRateLimit`。
  - `packages/domain/test/ai_service_test.dart`：7 個測試覆蓋 AT-07-02/04/06 與 #23/#31/#34。
- **產物（修改）**：
  - `packages/domain/lib/domain.dart`：export AIService / ports。
- **實作重點**：`configure` 僅把 credential 寫入 `SecureStore` key `ai.apiKey` 並保存 provider config；`translate` 先驗 key/config、文字與目標語言，接著在外部 client 呼叫前依序執行 prompt injection guard、HTTPS host allowlist、rate limit，最後才呼叫 `AiClient.translate`。外部 client 失敗一律包成 `ERR_AI_CALL_FAILED`，不洩漏原始例外；manual translation 透過 `mergeTranslation` 永遠勝出。
- **Non-scope 保留**：未加入 `http`、未加入 `flutter_secure_storage`、未實作真 provider adapter、未寫 app_settings、未做 FP6 UI；AIService 僅處理文字且不觸碰音訊（REQ-07 §0.1）。

### Task 8.4.3 / 8.4.4 / 8.4.5 hard-guardrails
- **狀態**：Done（Domain AIService 前置防線完成；matrix 以 PARTIAL 追蹤真 infra/app call path 尚待 7.2 後續接線）
- **#23 Rate Limit**：`AiRateLimit(maxRequests, window)` + `_checkRateLimit()`；第 N+1 次回 `ERR_AI_CALL_FAILED（rate-limit）` 且不呼叫 fake client。
- **#31 Network Policy**：`AIService.defaultAllowedHosts = {'api.openai.com','api.anthropic.com'}`；baseUrl 必須為 `https` 且 host 在 allowlist，否則 `ERR_AI_CALL_FAILED（host-blocked）` 且不呼叫 fake client。
- **#34 Prompt Injection Guard**：`ignore previous instructions`、`system:`、`developer:`、`</s>`、`<|system|>`、`<|developer|>` 等樣本 fail-closed，回 `ERR_AI_CALL_FAILED（prompt-injection-review-required）` 且不呼叫 fake client。因目前尚無 UI confirmation flow，Domain 層採保守拒絕。

## 輕量門檻紀錄（編譯階段）— S6-2 AIService Domain guardrails

- 格式化：`dart format packages/domain/lib/src/ports/secure_store.dart packages/domain/lib/src/ports/ai_client.dart packages/domain/lib/src/ai/ai_service.dart packages/domain/lib/domain.dart packages/domain/test/ai_service_test.dart` ✅
- 目標測試：`flutter test packages/domain/test/ai_service_test.dart` **7/7 ✅**
- 後端（純 Dart）：`flutter test packages/domain/test` **61/61 ✅**（+7 AIService tests；含 M5 domain purity 與 #23/#31/#34 不呼叫外部 client 斷言）
- 分析：`flutter analyze` **No issues found** ✅
- Diff 檢查：`git diff --check` ✅
- Guardrails：`python3 scripts/check_guardrails.py ...` 仍預期不通過，但剩餘 `REJECTED_NEEDS_IMPLEMENTATION` 已由 5 條降為 2 條（#9 Branch Protection、#22 Audit Log）；#23/#31/#34 已轉 PARTIAL 並附 Domain 防線與測試證據。
- **結論：輕量門檻透過**。涵蓋任務：7.2 Domain 可測部分、8.4.3、8.4.4、8.4.5；S6-2 code 面的 Domain guardrails 完成。7.2 真 Keychain/provider adapter、#9 Branch Protection、#22 Audit Log 仍未完成。

## Task S6-3（ProgressEngine settle/dueList）— 2026-07-06

### Task 7.3 ProgressEngine 結算與 SRS（REQ-08 / AT-08-01 / AT-08-02 / CT-07）
- **狀態**：Done（Domain 可測部分完成；TDD-red → green）
- **TDD-red**：`packages/domain/test/progress_engine_test.dart` 初始因 `ProgressEngine` / `PracticeGroup` / `SrsState` / `Difficulty` / `ProgressRepository` 等符號未存在而編譯紅 ✅
- **產物（新增）**：
  - `packages/domain/lib/src/model/progress.dart`：`Difficulty`、`GroupStatus`、`StepRange`、`PracticeGroup`、`SrsState`、`DueGroup`、`Attempt`。
  - `packages/domain/lib/src/ports/progress_repository.dart`：ProgressEngine 持久化 port；Domain 不直接依賴 Drift。
  - `packages/domain/lib/src/progress/progress_engine.dart`：`settle` / `dueList`。
  - `packages/domain/test/progress_engine_test.dart`：AT-08-01、AT-08-02/CT-07 與 priority 排序測試。
- **產物（修改）**：
  - `packages/domain/lib/domain.dart`：export ProgressEngine / progress models / repository port。
- **實作重點**：SRS interval 固定 `[0,1,3,7,14,30]`；HARD 縮短一段、NORMAL 前進一段、EASY 前進兩段並 clamp 0..5；`dueList(now)` 只列 `nextDue <= now` 且 `status == ACTIVE`，HARD 最高優先，同級依 nextDue 早者先。M7 跨日零懲罰落在測試：7/5 到期、7/6 開 App 只進 dueList，不寫 SRS / Attempt、不降 interval。
- **Non-scope 保留**：未做 7.4 匯入匯出、7.5 歸檔/恢復、7.6 reminderConfig、#22 Audit Log、FP1/FP7 UI。

## Task S6-4（ProgressEngine exportProgress/importProgress）— 2026-07-06

### Task 7.4 進度匯入匯出（Domain 可測部分；REQ-08 / AT-08-03 / AT-08-04 / AT-08-07 / CT-06）
- **狀態**：InProgress（Domain contract + tests 完成；真 Drift adapter / FP7 MergeSummary UI 尚待後續接線）
- **TDD-red**：`packages/domain/test/progress_import_export_test.dart` 初始因 `ProgressSnapshot`、`ProgressEngine.fileIo`、`exportProgress`、`importProgress` 等符號未存在而編譯紅 ✅
- **產物（新增）**：
  - `packages/domain/lib/src/model/progress_snapshot.dart`：`.aboprogress` 平台中立快照 `ProgressSnapshot` 與 `MergeSummary`。
  - `packages/domain/test/progress_import_export_test.dart`：5 個測試覆蓋 export schema / 隱私掃描、updatedAt 較新覆寫、重複匯入冪等、contentHash 單課 reset、損毀檔不部分套用。
- **產物（修改）**:
  - `packages/domain/lib/src/progress/progress_engine.dart`：新增 `fileIo` 注入、`exportProgress(destPath)`、`importProgress(path)`、全檔驗證與 merge policy。
  - `packages/domain/lib/src/ports/progress_repository.dart`：新增 `loadProgressSnapshot()` / `saveProgressSnapshot()`；`saveProgressSnapshot` 文件明定 infra adapter 必須交易套用。
  - `packages/domain/lib/domain.dart`：export `ProgressSnapshot` / `MergeSummary`。
  - `packages/domain/test/progress_engine_test.dart`：fake repository 補齊新 port 方法，避免 7.3 回歸。
- **實作重點**：`.aboprogress` 採 schemaVersion=1 JSON，透過 `FileIo.writeBytesAtomic/readBytes` 寫檔/讀檔；`importProgress` 先完整 decode + schema + snapshot validation，任何結構錯誤回 `ERR_PROGRESS_CORRUPTED` 且不呼叫保存。Merge 規則：同 profile/course 才可合併；PracticeGroup / SrsState 依 updatedAt 較新覆寫、相等視為 skipped；Attempt 以 id 去重；Lesson contentHash 改變時只 reset 該 Lesson 的 groups/srs/attempts，其他 Lesson 不動。
- **Non-scope 保留**：未做雲端同步；未新增/修改 Drift schema；未實作真 `ProgressRepository` Drift adapter；未做 FP7 MergeSummary 對話框；未做 #22 Audit Log。

## 輕量門檻紀錄（編譯階段）— S6-3/S6-4 ProgressEngine Domain

- 格式化：`dart format packages/domain/lib/src/model/progress_snapshot.dart packages/domain/lib/src/ports/progress_repository.dart packages/domain/lib/src/progress/progress_engine.dart packages/domain/lib/domain.dart packages/domain/test/progress_import_export_test.dart packages/domain/test/progress_engine_test.dart` ✅
- 目標測試：`flutter test packages/domain/test/progress_import_export_test.dart` **5/5 ✅**
- 回歸測試：`flutter test packages/domain/test/progress_engine_test.dart` **4/4 ✅**
- 後端（純 Dart）：`flutter test packages/domain/test` **70/70 ✅**（+5 Progress import/export tests；含 M5 domain purity、M6/CT-06、M7/CT-07）
- 分析：`flutter analyze` **No issues found** ✅
- Diff 檢查：`git diff --check` ✅
- Guardrails：`python3 scripts/check_guardrails.py ...` 仍預期不通過；剩餘 `REJECTED_NEEDS_IMPLEMENTATION` 維持 2 條（#9 Branch Protection、#22 Audit Log）。
- **結論：輕量門檻透過**。涵蓋任務：7.3 完成、7.4 Domain 可測部分完成。7.4 真 Drift adapter / FP7 MergeSummary UI、7.5、7.6、#9、#22 仍未完成。

## Task S6-5（ProgressEngine archive/restore）— 2026-07-06

### Task 7.5 歸檔狀態機（Domain 可測部分；REQ-08 / AT-08-05 / AT-08-06 / CT-08）
- **狀態**：InProgress（Domain contract + tests 完成；真 Drift adapter / 操作紀錄仍待後續接線）
- **TDD-red**：`packages/domain/test/progress_archive_test.dart` 初始因 `ProgressEngine.archive` / `restore` 尚未存在而編譯紅 ✅
- **產物（新增）**：
  - `packages/domain/test/progress_archive_test.dart`：4 個測試覆蓋 ACTIVE→ARCHIVED、167h restore 成功、169h restore 拒絕並惰性轉 EXPIRED、ARCHIVED/EXPIRED 不進 dueList。
- **產物（修改）**：
  - `packages/domain/lib/src/progress/progress_engine.dart`：新增 `archive(groupId)` / `restore(groupId)` 與 168h `archiveRestoreWindow`；restore 過期時保存 EXPIRED 後拋 `ERR_ARCHIVE_RESTORE_EXPIRED`。
  - `packages/domain/lib/src/ports/progress_repository.dart`：新增 `saveGroup(PracticeGroup group)` port，供 infra adapter 交易保存狀態轉換。
  - `packages/domain/test/progress_engine_test.dart`、`packages/domain/test/progress_import_export_test.dart`：fake repository 補齊新 port 方法，維持 7.3/7.4 回歸測試。
- **實作重點**：Clock 全程注入，不直呼 `DateTime.now()`；168h 判定採 `now - archivedAt >= 168h` 為過期（Q7 定案「168 小時不含」）；`dueList` 維持 pure query，不在查詢時惰性改 EXPIRED，只有 `restore` 檢查過期時寫狀態。
- **Non-scope 保留**：未新增/修改 Drift schema；未實作真 `ProgressRepository` Drift adapter；未寫 #22 Audit Log / 操作紀錄持久化；未接 FP7 UI。

## 輕量門檻紀錄（編譯階段）— S6-5 ProgressEngine Archive Domain

- 格式化：`dart format packages/domain/lib/src/ports/progress_repository.dart packages/domain/lib/src/progress/progress_engine.dart packages/domain/test/progress_archive_test.dart packages/domain/test/progress_engine_test.dart packages/domain/test/progress_import_export_test.dart` ✅
- 目標測試：`flutter test packages/domain/test/progress_archive_test.dart` **4/4 ✅**
- 後端（純 Dart）：`flutter test packages/domain/test` **74/74 ✅**（+4 Progress archive/restore tests；含 M5 domain purity、M6/CT-06、M7/CT-07、M8/CT-08）
- 分析：`flutter analyze` **No issues found** ✅
- Diff 檢查：`git diff --check` ✅
- Guardrails：`python3 scripts/check_guardrails.py ...` 仍預期不通過；剩餘 `REJECTED_NEEDS_IMPLEMENTATION` 維持 2 條（#9 Branch Protection、#22 Audit Log）。
- **結論：輕量門檻透過**。涵蓋任務：7.5 Domain 可測部分完成。7.5 真 Drift adapter / 操作紀錄、7.6、#9、#22 仍未完成；處理 #22 前須先切 `hard-guardrails` 並回報 schema / 持久化方案。

## Task S6-6（ProgressEngine persistence + #22 Audit Log + reminderConfig）— 2026-07-06

### Task 7.4/7.5 Drift adapter、7.6 reminderConfig、8.4.2 Audit Log
- **狀態**：Done（後端/infra 可測部分完成；FP7 完整 UI 仍另列）
- **人類確認**：#22 Audit Log 採 Drift `audit_log` 表，使用者於 2026-07-06 同意後實作；不做 immutable/tamper-proof，不記錄練習軌跡。
- **產物（新增）**：
  - `packages/domain/lib/src/model/settings.dart`：`ReminderConfig.defaults = 15/5/2`。
  - `packages/domain/lib/src/model/audit_log.dart`、`ports/audit_log_sink.dart`：輕量 audit entry 與敏感 token 拒絕。
  - `packages/infra/lib/src/db/drift_progress_repository.dart`：`ProgressRepository` 的 Drift adapter，含 `saveProgressSnapshot` transaction、`saveGroup`、`dueCandidates`、`app_settings` reminderConfig 與 `audit_log`。
  - `packages/domain/test/progress_settings_test.dart`、`packages/infra/test/drift_progress_repository_test.dart`：reminder/audit/persistence 測試。
- **產物（修改）**：
  - `packages/infra/lib/src/db/app_database.dart` / `.g.dart`：schemaVersion 2，新增 `AuditLogs` table、time/action indexes、in-memory DB factory。
  - `packages/infra/lib/db/schema/V2__alter_placeholder.sql`：V2 建立 `audit_log`。
  - `packages/domain/lib/src/progress/progress_engine.dart`：`archive/restore/setReminderConfig` 寫 audit；`reminderConfig` 預設 fallback。
  - `packages/domain/lib/src/ai/ai_service.dart`：`configure` 可寫 audit，metadata 不含 key 明文。
- **實作重點**：audit metadata 只存非敏感摘要，`AuditLogEntry` 會拒絕 key/secret/password/credential/audio/recording/path 等字樣；`.aboprogress` 與 `ProgressSnapshot` 不塞 audit 資料；progress merge 規則仍留在 Domain，Drift adapter 僅負責交易保存。
- **Non-scope 保留**：真 Keychain adapter、真 AI provider HTTP adapter、完整 FP7 import/export/歸檔 UI、#9 Branch Protection。

## Task S6-7（Frontend FP1/FP6/FP7 partial 接線）— 2026-07-06

### FP1 library dueList、FP6 translation shell、FP7 import/export + reminder settings + settle bar
- **狀態**：InProgress（FP1 課件清單入口與 FP7 歸檔/匯入匯出 UI 已完成；FP6 真 pack 開/存與真 PracticeGroup linkage 未全關）
- **產物（新增）**：
  - `app/lib/features/progress/progress_service.dart`：app 層 `ProgressService` provider，接 `DriftProgressRepository` + `ProgressEngine`。
  - `app/lib/features/library/library_screen.dart`：今日到期清單、`lesson_registry` 課件清單入口、歸檔確認對話框與 FP6 手動譯文 shell。
  - `app/lib/features/progress/progress_settings_screen.dart`：進度匯出/匯入 file picker、MergeSummary 對話框、提醒三參數設定頁、ARCHIVED 168h 倒數與恢復入口。
  - `app/lib/features/practice/widgets/settle_bar.dart`：困難/普通/輕鬆結算列。
  - `app/test/progress/progress_ui_test.dart`：Library due item、歸檔確認、課件清單練習/編輯入口、reminderConfig 讀寫、進度匯出/匯入、ARCHIVED 倒數恢復、SettleBar nextDue。
- **產物（修改）**：
  - `app/lib/shell/app_shell.dart`、`app/lib/shared/navigation.dart`：新增課件庫與設定導覽。
  - `app/lib/features/practice/practice_screen.dart`：加入 `SettleBar`（暫以 step placeholder groupId 接線）。
- **實作重點**：UI 不顯示逾期/懲罰字樣；課件清單讀 `lesson_registry` 並只切換 tab，不在 UI 自建課件狀態；歸檔/恢復只透過 `ProgressService` 進 Domain 狀態機；自動翻譯鈕在未設 key 時停用且有 tooltip，手動譯文永遠可編輯；設定保存透過 `ProgressEngine.setReminderConfig`，因此會走 audit log；進度匯入/匯出只呼叫 Domain `ProgressEngine`，UI 不重寫 merge policy。
- **Non-scope 保留**：真 Lesson 狀態 hydrate 到練習/編輯、回前景重查 dueList、真 `.abopack` 開啟/儲存與快捷鍵、AI key 設定 UI/Keychain adapter、sidecar.timeoutSec 設定、真 PracticeGroup 來源。

## 輕量門檻紀錄（編譯階段）— S6-6/S6-7 ProgressEngine persistence + UI slice

- 格式化：`dart format ...` 新增/修改 Dart 檔案 ✅
- Codegen：`cd packages/infra && flutter pub run build_runner build --delete-conflicting-outputs` ✅（首次 sandbox 因 Flutter SDK cache 寫入權限失敗，已依權限流程升級後成功）
- 後端（Domain）：`flutter test packages/domain/test` **78/78 ✅**
- Infra：`flutter test packages/infra/test` **65/65 ✅**（2 個本機 sidecar integration skips 維持預期）
- App：`cd app && flutter test` **49/49 ✅**
- 分析：`flutter analyze` **No issues found** ✅
- Guardrails：`python3 scripts/check_guardrails.py ...` 已降為只剩 1 項 `REJECTED_NEEDS_IMPLEMENTATION`：#9 Branch Protection；#22 已轉 `PARTIAL` 並不再阻擋 checker。
- 失敗分類：曾並行執行兩個 `flutter test` 造成 Flutter native assets 暫存刪除 race（`native_assets.json` PathNotFound）；改為單獨重跑後 Domain 78/78 通過，非程式碼失敗。
- **結論：輕量門檻透過**。涵蓋任務：7.4/7.5 真 Drift adapter、7.6 reminderConfig、8.4.2 Audit Log、FP1 課件清單入口、FP6 shell、FP7 進度匯入匯出與歸檔 UI。完整 S6 demo 尚須補 FP6 真 pack 開/存、真 PracticeGroup linkage 與 #9。

## Task S6-8（FP6 pack service + PracticeGroup linkage）— 2026-07-06

### FP6 `.abopack` open/save service、SettleBar 真 PracticeGroup linkage
- **狀態**：InProgress（真 open/save service 與 PracticeGroup linkage 完成；快捷鍵、完整 lesson hydrate、AI key/sidecar settings 未全關）
- **產物（新增）**：
  - `app/lib/features/library/lesson_pack_service.dart`：`LessonPackFilePicker`、`LessonPackService`、`AppLessonPackService` 與 current lesson draft builder；用 `LessonPackEngine + AtomicFileIo + file_selector` 開啟/儲存 `.abopack`，成功後同步 `lesson_registry`。
- **產物（修改）**：
  - `app/lib/features/library/library_screen.dart`：FP6 panel 改為真開啟/儲存；損毀 pack 顯示錯誤且不覆蓋現有手動譯文；儲存時把手動譯文寫入 `Lesson.translations`。
  - `app/lib/features/progress/progress_service.dart`：新增 `ensurePracticeGroup`，結算前可建立缺少的 group。
  - `app/lib/features/practice/practice_screen.dart`、`app/lib/features/practice/widgets/settle_bar.dart`：PracticeScreen 依目前 lesson/step 建穩定 `PracticeGroup`；SettleBar 先 ensure group 再 settle。
  - `packages/infra/lib/src/db/drift_progress_repository.dart`：`saveGroup` 對未註冊 lesson 建最小 `lesson_registry` row，避免即時練習流程缺 registry。
  - `app/test/progress/progress_ui_test.dart`、`packages/infra/test/drift_progress_repository_test.dart`：新增 FP6 open/save 與 PracticeGroup linkage 測試。
- **實作重點**：`.abopack` 格式、contentHash 與損毀拒絕仍由 Domain `LessonPackEngine` 控制；UI 不解析 zip、不重算 pack 規則。PracticeGroup id 由 lesson title + step index 穩定生成，只保存 ACTIVE group，不新增逾期/失敗/懲罰欄位。
- **Non-scope 保留**：⌘S/⌘O、獨立 `features/pack_translate/` controller、開啟課件後完整 hydrate 到 editor/practice、AI key 設定 UI/Keychain adapter、sidecar.timeoutSec 設定、#9 Branch Protection。

## 輕量門檻紀錄（編譯階段）— S6-8 FP6 + PracticeGroup linkage

- 格式化：`dart format ...` 新增/修改 Dart 檔案 ✅
- 目標測試：`flutter test app/test/progress/progress_ui_test.dart` **10/10 ✅**
- 目標測試：`flutter test packages/infra/test/drift_progress_repository_test.dart` **7/7 ✅**
- 後端（Domain）：`flutter test packages/domain/test` **78/78 ✅**
- Infra：`flutter test packages/infra/test` **66/66 ✅**（2 個本機 sidecar integration skips 維持預期）
- App：`cd app && flutter test` **52/52 ✅**
- 分析：`flutter analyze` **No issues found** ✅
- 失敗分類：再次並行跑 Flutter 測試會撞 native assets 暫存刪除 race；序列重跑後皆通過，故驗證指令後續請避免並行 Flutter test。
- **結論：輕量門檻透過**。涵蓋任務：FP6 真 `.abopack` open/save service、損毀不部分套用、SettleBar 真 PracticeGroup linkage。完整 S6 demo 尚須補 lesson hydrate、快捷鍵、AI key/sidecar settings 與 #9。

## Task S6-9（Lesson hydrate + FP7 AI key/sidecar settings + S6 round-trip）— 2026-07-06

### FP6/FP1 Lesson hydrate、pack session 與快捷鍵
- **狀態**：Done
- **產物（新增）**：
  - `app/lib/features/pack_translate/lesson_session_controller.dart`：`lessonSessionControllerProvider` 與 `LessonSessionState`，負責從 `.abopack` 的 `Lesson` 解碼 WAV、計算 waveform peaks，並保存目前 pack lesson session。
- **產物（修改）**：
  - `packages/domain/lib/src/practice/wav_encoder.dart`：新增純 Dart `decodeWav`，供 domain/infra 共用 16-bit mono RIFF/WAVE decode。
  - `packages/infra/lib/src/practice/recording_audio_source.dart`：改用 domain `decodeWav`，移除私有重複 parser。
  - `app/lib/features/library/lesson_pack_service.dart`：`open` 先驗證 pack audio 可解碼，`currentLessonDraftBuilderProvider` 依目前 editor source lesson 優先從 pack session 建 draft；save 保留原音 bytes/words/config，只更新譯文、音節與 prosody。
  - `app/lib/features/library/library_screen.dart`：課件卡、開啟 pack、儲存 pack 都會 hydrate session；FP6 panel 增加 ⌘O/⌘S 與 Ctrl+O/Ctrl+S。
  - `app/lib/features/editor/editor_controller.dart` / `editor_screen.dart`：state 新增 `sourceLessonId`；pack lesson editor 可用 session PCM/peaks 試聽與 undo；修正 `null == null` 造成 analysis-derived editor 誤用 pack session 的邏輯。
  - `app/lib/features/practice/practice_controller.dart` / `practice_screen.dart`：PracticeScreen 監聽 lesson session，使用 pack lesson id/title 建立 PracticeGroup，無 session 時仍回落 analysis result。
- **實作重點**：`.abopack` 的 open/save 仍由 `LessonPackEngine` 控制；UI 不解析 zip、不自訂 contentHash。開啟 pack 後若 WAV decode 失敗，不更新 session/UI state，避免部分載入。`sourceLessonId` 是防錯核心：只有 editor source 與 session lesson id 一致時，才使用 pack PCM/peaks。

### FP7 AI key / sidecar timeout settings
- **狀態**：Done（provider/key 路徑未回報前的可測設定 slice 完成；真 HTTP/Keychain adapter 仍為後續）
- **產物（新增/修改）**：
  - `packages/domain/lib/src/model/settings.dart`：新增 `SidecarConfig(timeoutSeconds: 120)`。
  - `packages/domain/lib/src/ports/progress_repository.dart`、`packages/domain/lib/src/progress/progress_engine.dart`：新增 `sidecarConfig()` / `setSidecarConfig()`；保存時寫 `sidecar_config_changed` audit，metadata 僅含 timeoutSeconds。
  - `packages/infra/lib/src/db/drift_progress_repository.dart`：`app_settings` 新增 `sidecar.timeoutSec` 讀寫。
  - `app/lib/features/progress/ai_settings_service.dart`：`AiSettingsService`、`InMemoryAiSecureStore`、`NoopAiClient`；UI 可呼叫 `AIService.configure` 並寫 audit，但不外呼、不持久化 key。
  - `app/lib/features/progress/progress_service.dart`、`progress_settings_screen.dart`：設定頁新增 AI key obscure 欄位、送出即清空；新增 sidecar timeout stepper；保存提醒設定與 sidecar config。
- **實作重點**：AI key 當前只進 in-memory secure store 與 Domain `AIService.configure`，不寫 pack/progress/DB/log；audit metadata 不含 key。`NoopAiClient` 使翻譯真外呼在 provider/key 路徑確認前 fail-closed。

### S6 demo round-trip widget slice
- **狀態**：Done
- **覆蓋流程**：dueList 可見 → open `.abopack` → hydrate session → 編輯 manual translation → save pack → Practice SettleBar ensure group + settle → progress export/import + MergeSummary → AI key configure 後欄位清空 → sidecar timeout 保存。
- **測試修正**：`app/test/progress/progress_ui_test.dart` 的 `_pump` 使用 `ProviderScope(key: UniqueKey())`，避免同檔多次 pump 不同 override 數量時沿用舊 provider tree。

## 輕量門檻紀錄（編譯階段）— S6-9 hydrate + settings + round-trip

- 目標測試：`flutter test packages/domain/test/wav_encoder_test.dart` ✅
- 目標測試：`flutter test packages/domain/test/progress_settings_test.dart` ✅
- 目標測試：`flutter test packages/infra/test/drift_progress_repository_test.dart` ✅
- 目標測試：`flutter test packages/infra/test/recording_audio_source_test.dart` ✅
- 目標測試：`cd app && flutter test test/pack_translate/lesson_session_controller_test.dart test/progress/progress_ui_test.dart` ✅
- 目標測試：`cd app && flutter test test/practice/practice_screen_test.dart` ✅
- 後端（Domain）：`flutter test packages/domain/test` **82/82 ✅**
- Infra：`flutter test packages/infra/test` **67/67 ✅**（2 個本機 sidecar integration skips 維持預期；仍會顯示既有 sidecar tag warning）
- App：`cd app && flutter test` **58/58 ✅**
- Guardrails：`python3 scripts/check_guardrails.py ...` 仍預期不通過，只剩 #9 Branch Protection（本機無 remote，不能假完成）。
- 分析：`flutter analyze` **No issues found** ✅
- Diff 檢查：`git diff --check` ✅
- Guardrails checker：仍只因 #9 Branch Protection 失敗，符合本輪外部阻塞判定。
- **結論：輕量門檻透過**。涵蓋任務：FP6/FP1 lesson hydrate + shortcuts、FP7 AI key UI/in-memory configure + sidecar timeout settings、S6 round-trip widget slice。S6 code 面剩餘外部阻塞為 #9 Branch Protection；真 HTTP/Keychain adapter 仍待 provider/key 安全路徑確認。

## Task S6-10（CT-09 本機授權掃描與 release gate）— 2026-07-06

### CT-09 / M9 授權白名單掃描
- **狀態**：Done（本機 release license gate；GitHub 上載/branch protection 依使用者最新指示保留到最後）
- **產物（新增）**：
  - `scripts/check_licenses.py`：讀取 release license manifest，擋 GPL/AGPL/CC BY-NC/non-commercial/research-only、bundled Python runtime；LGPL bundled 元件必須 `linking=dynamic`。
  - `scripts/test_check_licenses.py`：覆蓋目前 manifest 形狀、GPL/GPL-3.0 注入、LGPL static linking、bundled Python runtime、空 manifest。
  - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/release/license-manifest.json`：記錄 Dart/Flutter package、FFmpeg/whisper.cpp/demucs.cpp、Eigen、CMUdict 等 release 依賴授權狀態。
  - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/release/release-checklist.md`：本機必跑 gate 與人工核對項。
- **實作重點**：Homebrew FFmpeg 仍標 dev-only；release manifest 要求 FFmpeg release build 必須 LGPL-only + dynamic linking。此切片不 push、不建立 GitHub repo、不改 #9 Branch Protection 狀態。

## 輕量門檻紀錄（編譯階段）— S6-10 CT-09 local gate

- 授權 manifest 檢查：`python3 scripts/check_licenses.py spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/release/license-manifest.json` ✅（18 components）
- 授權 gate 測試：`python3 -m unittest scripts/test_check_licenses.py` **6/6 ✅**
- **結論：本機 CT-09 授權掃描 gate 已落地**。當時 8.2 整體尚未勾選完成，因 CT-01～CT-10 常駐遠端 CI、#9 Branch Protection 與 release 實機 gate 仍待最後階段；後續見 S6-11/S6-12。

## Task S6-11（#9 Branch Protection + GitHub upload gate）— 2026-07-07

### GitHub repository 與 main branch protection
- **狀態**：Done（GitHub repository 建立、public visibility、main ruleset active；尚未推送前先完成 #9）
- **GitHub 帳號**：`gh auth status` 已驗證登入 `karenli628`；未執行 `gh auth login`。
- **Repository**：依使用者指定 `syllable repeater` 正規化為 GitHub slug `syllable-repeater`；建立網址 `https://github.com/karenli628/syllable-repeater`。初始建立為 private；GitHub API 建立 private ruleset 回 403（需 GitHub Pro 或 public repository），使用者授權後已改為 public。
- **Branch Protection**：Repository Ruleset `main branch protection`（id `18580116`）建立成功：`enforcement=active`、`target=branch`、include `refs/heads/main`、rules `deletion` + `non_fast_forward`。依上傳限制未執行 `git push --force` 或 `--force-with-lease` 測試。
- **Guardrails 更新**：`hard-limits-matrix.md` #9 由 `REJECTED_NEEDS_IMPLEMENTATION` 轉 `IMPLEMENTED`；狀態統計改為 `IMPLEMENTED=7`、`PARTIAL=20`、`REJECTED_NEEDS_IMPLEMENTATION=0`。

## Task S6-12（8.2 GitHub Actions core CI gate）— 2026-07-07

### CT-01～CT-10 常駐 CI
- **狀態**：Done（8.2 勾選完成；GitHub Actions 遠端 gate 已通過）
- **產物（新增）**：
  - `.github/workflows/ci.yml`：push/PR 觸發，runner 固定 `macos-15`，使用 Flutter `3.44.4`、`actions/checkout@v7`、`actions/setup-python@v6`、`subosito/flutter-action@v2`。
  - `scripts/ci_core_checks.sh`：集中跑 `flutter pub get`、`scripts/check_guardrails.py`、`scripts/check_licenses.py`、`python3 -m unittest scripts/test_check_licenses.py`、`flutter test packages/domain/test`、`flutter test packages/infra/test`、`cd app && flutter test`、`flutter analyze`。
- **實作重點**：8.2 只接「核心驗收總表測試常駐 CI」；release 實機 gate（9.1/9.2）仍不假完成。GitHub Actions 初版 `macos-latest` 成功後，因 GitHub annotations 提醒 Node 20 與 macOS latest migration，改 pin `macos-15` 並升級 checkout/setup-python。
- **本地驗證**：`bash scripts/ci_core_checks.sh` ✅；guardrails checker 通過（37 rows，`REJECTED_NEEDS_IMPLEMENTATION=0`）、license gate 通過（18 components）、domain 82/82、infra 67/67、app 58/58、`flutter analyze` No issues。
- **遠端驗證**：GitHub Actions run `28808859106`（commit `62a0695`）✅，2m11s 通過；run URL：`https://github.com/karenli628/syllable-repeater/actions/runs/28808859106`。
- **Guardrails 更新**：`hard-limits-matrix.md` #8 CI 由 `PARTIAL` 轉 `IMPLEMENTED`；統計改為 `IMPLEMENTED=8`、`PARTIAL=19`。

## Task S6-13（8.3 Q10 performance benchmark）— 2026-07-07

### 10 秒音檔完整對齊管線 i5-8259U 實測
- **狀態**：Done（8.3 勾選完成；Q10 目標數值回填 requirement/backend-design）
- **產物（新增）**：
  - `packages/infra/bin/benchmark_alignment_pipeline.dart`：用使用者提供 mp3 產生 10,000ms benchmark WAV，量測完整 `AnalysisPipeline`：FFmpeg decode → whisper.cpp small.en `--no-gpu` → CMUdict syllabify → waveform peaks。
- **實測環境**：`Intel(R) Core(TM) i5-8259U CPU @ 2.30GHz`；FFmpeg 路徑 `/usr/local/bin/ffmpeg`；whisper.cpp small.en 與 CMUdict 走 `.local-tools/`。
- **實測指令**：`(cd packages/infra && dart run bin/benchmark_alignment_pipeline.dart)`。
- **結果**：`audioDurationMs=10000`、`elapsedMs=4689`（4.689s）、`syllableCount=22`、`waveformPeaks=32`、`targetSeconds=60`、`status=PASS`。
- **規格更新**：`requirement.md` v1.3、REQ-01 3.2.6 與附錄 A Q10 改為「10 秒音檔完整對齊管線 ≤ 60 秒」已實測鎖定；`backend-design.md` 目標與風險段落同步，未來更換模型/晶片/sidecar 版本需重跑 benchmark。

## Task S6-14（2.1 release sidecar staging gate）— 2026-07-07

### x86_64 sidecar release bundle 前置防線
- **狀態**：Partial（release sidecar 路徑、staging 腳本、build fail-closed gate 已落地；實體 bundle 待 LGPL-only FFmpeg 與 demucs.cpp artifacts）
- **產物（新增/修改）**：
  - `app/lib/shared/infra/sidecar_paths.dart`：新增 `SidecarPaths.current()` 與 `SidecarPaths.bundled()`；Release AOT 走 `Contents/Resources/sidecar/`，Debug/Test 維持 `.local-tools/`。
  - `app/lib/main.dart`、`lesson_pack_service.dart`、`progress_service.dart`、`export_dialog.dart`、`practice_recording.dart`：改用 `SidecarPaths.current()`。
  - `scripts/prepare_release_sidecars.py`：staging 前先跑 CT-09 license manifest gate；拒絕 `--enable-gpl` / `--enable-nonfree` 或非 shared FFmpeg/ffprobe；產出 `sidecar-manifest.json`；copy whisper/demucs/FFmpeg dylibs 並修正 Mach-O rpath。
  - `scripts/test_prepare_release_sidecars.py`：覆蓋 GPL FFmpeg 被拒絕、合法 fake bundle 產出 release layout。
  - `app/macos/Runner/Scripts/copy_release_sidecars.sh` + Xcode build phase：Release build 檢查 staging 內容，缺任一必要 sidecar/model/data 即中止；Debug/Profile 跳過。
  - `app/macos/Runner/Resources/sidecar/README.md` / `.gitignore`：說明 staging 指令，實際 binaries/models/dictionaries 不進版控。
  - `license-manifest.json`：補 `OpenAI Whisper small.en model`（MIT，官方 Whisper README 明示 code 與 model weights 皆 MIT）。
- **實測結果**：
  - `python3 scripts/check_licenses.py .../release/license-manifest.json` ✅（19 components）
  - `python3 -m unittest scripts/test_check_licenses.py scripts/test_prepare_release_sidecars.py` ✅（8 tests）
  - `flutter test app/test/shared/sidecar_paths_test.dart` ✅
  - 實際 dry-run：`python3 scripts/prepare_release_sidecars.py ... --dry-run` 對目前本機狀態正確失敗，因 `.local-tools/demucs.cpp/build/bin/demucs.cpp` 與 `ggml-model-htdemucs` 不存在；另 `/usr/local/bin/ffmpeg -version` 顯示 `--enable-gpl`，只能作 dev-only，不得進 release bundle。
- **結論**：2.1 的可程式化防線已落地；實體 x86_64 sidecar bundle 必須等 LGPL-only FFmpeg/ffprobe（dynamic/shared）與 demucs.cpp binary/model artifacts 就緒後再跑 staging，屆時才能勾選 2.1 完成並進入 9.1 release build。

## e2e 驗收紀錄 — S1a Frontend FP2

- **前置**：使用者裝完整 Xcode 15.4 + CocoaPods；`flutter build macos --debug` ✅（首次 pod install 成功，產物：`app/build/macos/Build/Products/Debug/syllable_repeater_app.app`）。
- **e2e widget test（`app/test/e2e_pipeline_test.dart`）**：以 `SidecarPaths.dev()` 覆寫 `analysisRunnerProvider` 為真 `InfraAnalysisRunner`，用金標準 `step up your coding skills to a new level.mp3` 走完 `selectAudioPath`→`start()`（`tester.runAsync` 進入真 async 環境，讓 `Process.start` 與 `Process.exitCode` 真時間跑）→pipeline done→`AppSection.editor` 切 tab→editor 顯示 `#1`..`#11` 音節列。**7 秒通過**（1/1 ✅）。
- **金標準 assert**：`finalState.result.syllables.length == 11`；`AppShellSelectedIndex` 從 `importAnalysis(1)` 切到 `editor(2)`；EditorScreen 顯示「音節校正」標題。
- **順帶抓到並修的 UI bug**：`_ImportPanel` 內 Column 在 done 態新增「進入編輯器」按鈕後 overflow 64px。原因：拖放區 230px + TextField 5 行 + 選項 Row + StagedProgress done 內容全部塞進 Column 超過右半窗高。修法：改 `SingleChildScrollView` 包 Column（讓桌面滑鼠滾動可看完）。
- **App 已 launch**：PID 31770 launched；**畫面全黑**，root cause = `Runner/DebugProfile.entitlements` 與 `Release.entitlements` 皆含 `com.apple.security.app-sandbox: true`，sandbox 擋住 `.local-tools/`（whisper.cpp、cmudict）讀取與 `/usr/local/bin/ffmpeg` spawn；`main()` 內 `File.existsSync()` 觸發權限錯誤導致 runApp 前崩潰。相對地，e2e widget test 走 dart VM 不透過 App bundle，不吃 sandbox，故該路徑通過。
- **本輪決策（使用者 2026-07-05 拍板）**：走「方案 3：不動 App，只靠 e2e widget test」。真 App macOS UI demo **列為 waived 到 M9 授權合規/發布規劃時再處理**。任務 9.1（macOS release build）落地前必須先解 sandbox（Debug + Release entitlements 內 `app-sandbox: true` → `false`，與 requirement Q4「免簽章＋略過 Gatekeeper」路線一致）。詳見 memory：`decision_macos_sandbox_ui_demo_waived_v1.md`。
- **不要走的死路（記入 memory）**：保留 sandbox 加 `com.apple.security.temporary-exception.files.absolute-path.*` — 這種 exception 只在簽章 App 內生效，本專案免簽章路線下無效。
- **結論**：e2e widget test 通過（覆蓋真檔 pipeline+11 音節+editor tab 切換）；App 本體 macOS UI demo waived 到 M9；S1a 切片 code 面＋e2e widget 全綠；`hard-guardrails matrix` 待接續 skill 補。

## S0 demo 對照（需求成稿 §5 完成定義）

| 完成定義 | 證據 |
|---|---|
| `Process.start` FFmpeg 取得時長 | `ffmpeg_integration_test.dart`：真實 FFmpeg 解碼 1 秒 WAV，durationMs 誤差 ≤20ms ✅ |
| sidecar 崩潰 App 不崩 | `sidecar_runner_test.dart`：kill -9 →負 exitCode 回傳、逾時→SIGKILL 回收＋SidecarFailure、spawn 失敗→SidecarFailure，測試行程全程不崩 ✅ |
