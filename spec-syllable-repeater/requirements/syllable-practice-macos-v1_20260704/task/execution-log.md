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
