# 交接檔-20260705-fullstack-code-implementation_S1a-FP0_FP2剩餘

> 產出日期：2026-07-05（Asia/Taipei）  
> 專案根目錄：`/Users/karen_files/vibercoding project/syllable repeater`  
> 目前階段：`fullstack-code-implementation` / `S1a` / 工作項目 `Frontend FP0-FP2 剩餘`  
> 用途：彙整 20260705 的交接檔案與目前階段最新交接內容，給新 session 或接手 agent 直接續做。

## 0. 一句話結論

目前在 **S1a 收尾**。後端 3.1-3.5 與 8.1 Domain 純 Dart 本地 CI-ready 防線已完成；Flutter 3.44.4 已安裝；`app/` 已加入 workspace；前端 FP0/FP2 已有可編譯起手版，並通過 `flutter analyze` 與 `cd app && flutter test` 2/2。  
但 **S1a 全切片仍不可宣告完成**，因真 `AnalysisPipeline` / infra sidecar 注入、10 分鐘時長檢查、重試此階段、done 導向 editor、`shared/player/` 尚未完成。

另有流程缺口：**`hard-guardrails matrix` 尚未建立**。此流程尚未執行，不可視為已處理；review / archive 前必補。

## 1. 本檔彙整的 20260705 交接檔

本檔整合下列 20260705 交接檔與目前最新執行紀錄；若內容衝突，以本檔與最新 execution-log 為準。

1. `HANDOFF_目前階段_接續S1a收尾_20260705.md`
   - 狀態：較早交接；當時後端 3.1-3.5 完成，8.1 與前端尚未完成。
2. `HANDOFF_目前階段_接續前端FP0_FP2起手_20260705.md`
   - 狀態：中途交接；當時 Flutter 已安裝、`app/` 已建立，但尚未替換 counter demo。
3. `HANDOFF_目前階段_接續前端FP0_FP2剩餘_20260705.md`
   - 狀態：最新交接；前端 FP0/FP2 起手版已完成並通過分析與測試。

## 2. 新 session 必讀順序

1. 共用原則：
   - `/Users/karen_files/vibercoding project/02_Memory/constitution.md`
   - `/Users/karen_files/vibercoding project/02_Memory/preferences.md`
   - `/Users/karen_files/vibercoding project/02_Memory/MEMORY.md`
2. 只讀本專案記憶：
   - `/Users/karen_files/vibercoding project/syllable repeater/spec-syllable-repeater/memory/`
3. 讀需求與設計：
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/requirement/requirement.md`
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/backend-design.md`
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/frontend-design.md`
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md`
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/execution-log.md`
4. 讀本檔：
   - `交接檔-20260705-fullstack-code-implementation_S1a-FP0_FP2剩餘.md`

## 3. 目前實際狀態

### 已完成

S0：

- 1.1 Dart workspace 三包骨架：`app`、`packages/domain`、`packages/infra`。
- 1.2 Drift schema V1。
- 1.3 FileIO 抽象與 AtomicFileIo。
- 1.4 Clock 抽象。
- 2.2 SidecarRunner。
- 2.3 FFmpeg 解碼契約。

S1a 後端：

- 3.1 CMUdict 載入、音節數查詢、母音團 fallback、查無字 `needsReview`。
- 3.2 whisper.cpp JSON parser 與 runner wrapper；使用者指定只用 `small.en`。
- 3.3 音節切分與 `AlignmentResult`。
- 3.4 `AnalysisPipeline`：解碼、可選分離、轉寫、音節切分、waveform peaks、事件串流與重入鎖。
- 3.5 waveform peaks。
- 8.1 Domain 純 Dart本地 CI-ready 防線：`packages/domain/test/domain_purity_test.dart`。

前端起手版：

- root `pubspec.yaml` 已加入 `app` workspace。
- `app/pubspec.yaml` 已加入 `domain` / `infra` path deps。
- 已加入 `flutter_riverpod ^3.3.2`、`desktop_drop ^0.7.1`、`file_selector ^1.1.0`。
- `flutter_lints` 已調為 `^5.0.0`，以配合 workspace 既有 `lints ^5.x`。
- 已建立 FP0/FP2 起手版：
  - `app/lib/main.dart`
  - `app/lib/shell/app_shell.dart`
  - `app/lib/shared/tokens.dart`
  - `app/lib/shared/empty_state.dart`
  - `app/lib/shared/error/error_messages.dart`
  - `app/lib/features/import_analysis/analysis_controller.dart`
  - `app/lib/features/import_analysis/import_screen.dart`
  - `app/lib/features/import_analysis/widgets/staged_progress.dart`
  - `app/test/widget_test.dart`

### 尚未完成

- 真 `AnalysisPipeline` / infra sidecar 注入到 ImportScreen。
- 音檔 10 分鐘時長前置檢查。
- FP2「重試此階段」。
- FP2 done 後導向 editor。
- `shared/player/` 播放控制條。
- S1a 全切片 demo。
- `hard-guardrails matrix`。
- GitHub Actions / 遠端 CI（專案目前不是 git repo，需等 git/repo 決策）。

## 4. 驗證結果

目前已通過：

```bash
flutter pub get
flutter analyze
cd app && flutter test
```

結果：

- `flutter analyze`：No issues found。
- `cd app && flutter test`：2/2 passed。

注意：

- root 直接跑 `flutter test` 會報 `Test directory "test" not found.`，因 Flutter 測試在 `app/`。
- `dart format` / `dart analyze` / `dart test` 在 Codex sandbox 內會撞 `runtime/vm/cpuinfo_macos.cc:42`；同指令非 sandbox 可正常跑。
- Flutter 在 sandbox 內會因寫 `/usr/local/share/flutter/bin/cache` 被擋；重要 Flutter 指令需非 sandbox。
- Flutter 指令不要並行，避免 startup lock 互等。

## 5. 任務文件目前標記

`task-split.md` 已同步：

- 已勾選：
  - 後端 1.1-1.4、2.2、2.3、3.1-3.5、8.1。
  - 前端「全域錯誤碼→文案/策略映射」：17/17 已完成。
- 未勾選但已有進度註記：
  - App 殼層與導航：ProviderScope、NavigationRail、最小視窗已做；真 infra 注入未做。
  - Token 與共享元件：tokens、EmptyState 已做；`shared/player/` 未做。
  - ImportScreen：拖放、選檔、字稿、separateVocals、副檔名檢查已做；10 分鐘時長檢查未做。
  - 階段化進度與結果預覽：preview runner、階段文案、錯誤文案、11 音節預覽已做；真 pipeline 注入、重試此階段、done 導向 editor 未做。

`execution-log.md` 已新增：

- Frontend FP0/FP2 起手版記錄。
- 輕量門檻紀錄：`S1a Frontend FP0/FP2 起手版`。
- `hard-guardrails matrix` 尚未建立的問題記錄。

## 6. 重要本機路徑

專案根：

```bash
/Users/karen_files/vibercoding project/syllable repeater
```

使用者提供測試音檔：

```bash
/Users/karen_files/vibercoding project/syllable repeater/step up your coding skills to a new level.mp3
```

本機開發工具：

```bash
.local-tools/whisper.cpp/build/bin/whisper-cli
.local-tools/whisper.cpp/models/ggml-small.en.bin
.local-tools/cmudict/cmudict.dict
.local-tools/cmudict/LICENSE
.local-tools/s1a/step_up_16k.wav
.local-tools/s1a/step_up_small_cpu.json
.local-tools/s1a/analysis_pipeline_integration/
```

Flutter：

```text
Flutter 3.44.4 stable
Tools Dart 3.12.2
```

## 7. 3.4 AnalysisPipeline 對前端 FP2 的注入方向

目前 UI 起手版使用 `PreviewAnalysisRunner`，下一步要替換或補上真 runner。參考接法：

```dart
final runner = SidecarRunner(defaultTimeout: Duration(seconds: 120));
final pipeline = AnalysisPipeline(
  decoder: FfmpegDecoder(runner: runner, ffmpegPath: ffmpegPath),
  transcriber: WhisperAnalysisTranscriber(
    audioPreparer: FfmpegTranscriptionAudioPreparer(
      runner: runner,
      ffmpegPath: ffmpegPath,
      tempDirectory: tempDirectory,
    ),
    transcriber: WhisperCppTranscriber(
      runner: runner,
      whisperCliPath: whisperCliPath,
      modelPath: modelPath,
      noGpu: true,
    ),
    outputDirectory: tempDirectory,
  ),
  alignmentEngine: AlignmentEngine(
    dictionary: const CmuDictLoader().load(cmudictPath),
  ),
);
```

需要先決定這些開發期路徑如何注入：

- `ffmpegPath`
- `whisperCliPath`
- `modelPath`
- `cmudictPath`
- `tempDirectory`

## 8. hard-guardrails matrix 待補

狀態：**尚未建立**。

預期落點：

```text
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/decision-log.md
```

後續規則：

- 不可把「不適用」由 AI 自行批准。
- 不可刪除 matrix 中的限制項。
- 不可在 review / archive 前忽略。
- 目前沒有自動測試或 CI 會擋這件事，所以交接與導航必須持續提醒。

## 9. 接續建議

下一步仍是前端 FP2：收斂真 pipeline 聯調。

建議順序：

1. 實作真 `AnalysisRunner`，讓 `analysisRunnerProvider` 可注入真 `AnalysisPipeline`。
2. 建立開發期 sidecar path 設定方式，先只支援 `.local-tools`。
3. 補 10 分鐘時長前置檢查。
4. 補「重試此階段」；若先降級為「重新分析」，需寫入 Non-scope。
5. done 後導向 editor placeholder 或下一個 S1b 入口。
6. 跑：

```bash
flutter analyze
cd app && flutter test
```

## 10. 本次 20260705 記憶與 wiki 狀態

已新增 project memory：

- `spec-syllable-repeater/memory/workflow_domain_purity_ci_ready防線.md`
- `spec-syllable-repeater/memory/workflow_flutter_workspace_fp0_fp2起手.md`

已更新 project memory：

- `spec-syllable-repeater/memory/decision_開發環境工具鏈事實.md`

已更新 wiki：

- `/Users/karen_files/vibercoding project/02_Memory/wiki/chronicle_syllable-repeater.md`

沒有新增 universal memory，也沒有更新全域 `02_Memory/MEMORY.md` 索引。

## 11. 新 session 可直接複製的啟動提示

```text
請先讀 02_Memory/constitution.md、preferences.md、MEMORY.md，
再讀本專案 spec-syllable-repeater/memory/，
接著讀 /Users/karen_files/vibercoding project/syllable repeater/交接檔-20260705-fullstack-code-implementation_S1a-FP0_FP2剩餘.md。

目前階段是 fullstack-code-implementation / S1a / Frontend FP0-FP2 剩餘。
請接續實作真 AnalysisPipeline 注入 ImportScreen。
注意 hard-guardrails matrix 尚未建立，review/archive 前必補。
```
