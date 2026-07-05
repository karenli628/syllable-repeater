# 交接檔-20260706-fullstack-code-implementation_S2-PracticeEngine_FP4

> 產出日期：2026-07-06（Asia/Taipei）
> 專案根目錄：`/Users/karen_files/vibercoding project/syllable repeater`
> 目前階段：`fullstack-code-implementation` / **S2 尚未動工（計畫已定、拍板已完成）**
> 用途：讓新 session AI agent 接手立即續作 S2；亦作本 session 若中途中斷的續接錨點。

## 0. 一句話結論

**S2 拆分＝10 個 task（後端 4.1-4.4 TDD 強制＋WAV encoder＋FP4 practice controller/player/screen＋4.7 單音節試聽順帶做＋輕量門檻/文件同步/git commit）**；本 session 已完成 S0/S1a/S1b/S1c＋hard-guardrails＋3 次 git commit，程式碼與文件全綠。新 session 開啟後讀完必讀清單即可從 **S2-1 TDD-red buildSteps 測試** 直接動工。

## 1. 新 session 必讀順序

1. 共用原則（不可違反）：
   - `/Users/karen_files/vibercoding project/02_Memory/constitution.md`（憲法 C1-C13，特別 C4 計畫先行、C10 三同步、C12 硬性限制、C13 不臆測）
   - `/Users/karen_files/vibercoding project/02_Memory/preferences.md`（繁中/台灣用語、乾淨收尾、Non-scope 明列）
   - `/Users/karen_files/vibercoding project/02_Memory/MEMORY.md`
2. 只讀本專案記憶（**憲法 C8 跨專案隔離**）：
   - `spec-syllable-repeater/memory/` 全 20 條；S2 最相關 5 條：
     - `decision_zero_crossing_search_window_10ms`（3.7／4.4 共用 10ms 常數）
     - `decision_金標準例句音節數修正為11`（CT-02 恰 11 步）
     - `workflow_editor_undo_stack_domain_stateless`（Domain 純函式＋UI controller pattern）
     - `workflow_analysis_pipeline_domain_port_infra_adapter`（Domain/infra 分工）
     - `pitfall_widget_test_real_async_needs_runAsync`（widget test 觸及 IO 需 runAsync）
3. 需求／設計／任務／執行日誌／guardrails：
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/requirement/requirement.md` v1.2
     - §2.5 M1-M10 核心維持原則、§12 CT-01-10 核心驗收總表
     - §3.2 REQ-03 AT-03-01～07（本輪主軸）
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/backend-design.md`
     - §3.2.2 PracticeEngine 介面 3–6 欄位表
     - §0.1 M1 唯一合法實作＝copy+串接+零交越/fade
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/frontend-design.md`
     - §四 功能點 4「句尾疊加練習（practice）」
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md`（4.1-4.7 均為未勾 + FP4 未勾）
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/execution-log.md`（追加 S2 批次；末尾追加輕量門檻紀錄）
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md`（本輪未動；5 條 REJECTED 未實作前不能 push remote）
4. 讀本檔：本交接檔

## 2. 目前實際狀態（截至 2026-07-06 git commit `416e6e0`）

### 已完成（可宣告 Done）

**S0**（後端 sidecar 接線＋崩潰隔離）
- 1.1 Dart workspace 三包骨架、1.2 Drift V1 schema、1.3 AtomicFileIo、1.4 Clock、2.2 SidecarRunner、2.3 FfmpegDecoder（含真檔整合測試）

**S1a**（音檔匯入→11 音節）
- 後端 3.1 CmuDictLoader、3.2 WhisperCppTranscriber (small.en --no-gpu)、3.3 AlignmentEngine 11 音節切分、3.4 AnalysisPipeline（含 PipelineCheckpoint resume）、3.5 waveform peaks、8.1 domain purity CI-ready 防線
- 前端 FP0 App 殼＋tokens＋player minimum shell、FP2 匯入畫面（拖放/選檔/字稿/勾選+ffprobe 時長預檢＋pipeline 事件流＋重試此階段＋done→editor tab）＋17/17 錯誤碼映射

**S1b**（波形校正編輯器）
- 後端 3.6 updateSyllableBoundary（介面 2）、3.7 zero_crossing.dart（`kZeroCrossingSearchWindowMs=10`）、peaks 快取（domain port + FileWaveformPeaksCache）
- 前端 FP3 EditorController（監聽 pipeline done→loadFrom；dragStart/Update/End/undo/clearError）＋WaveformCanvas（CustomPaint+hit-test ±12dp）＋EditorScreen 改造（Focus.onKeyEvent ⌘/^Z undo＋SnackBar＋試聽 stub）

**S1c**（demucs.cpp 分離契約）
- OQ-2 授權核對 = MIT（sevagh/demucs.cpp）+ Eigen MPL-2.0 通過 M9 白名單
- infra DemucsCppVocalSeparator + 7 情境假 runner 測試 + integration test skip if missing
- SidecarPaths 擴充 demucs 為選用（missingPaths 不納，獨立 demucsAvailable() bool）
- InfraAnalysisRunner 條件性注入 vocalSeparator
- UI「demucs 未就緒」tooltip 提示 3 情境測試

**hard-guardrails**
- 37 項 matrix：IMPLEMENTED 5 / PARTIAL 17 / APPROVED_NOT_APPLICABLE 10 / REJECTED_NEEDS_IMPLEMENTATION 5 / NOT_REVIEWED 0
- decision-log 15 條全裁決
- scripts/check_guardrails.py（bootstrap，已修 gmail 誤判 bug）
- .githooks/pre-commit（secret scan + .env 誤送）+ .githooks/pre-push（matrix gate）
- git 已 init，`git config core.hooksPath .githooks` 已設定

### 目前綠燈狀態

```
flutter analyze                             → No issues found
flutter test packages/domain/test           → 29/29 ✅
flutter test packages/infra/test            → 51/51 ✅（+1 sidecar integration skip + 1 demucs integration skip 未安裝）
cd app && flutter test                      → 18/18 ✅
python3 scripts/check_guardrails.py <matrix> <log>  → 5 條 REJECTED 未實作即擋 push（預期）
```

### git 歷史

```
416e6e0 feat(s1c): demucs.cpp 分離契約接入（domain 3.8 + optional 選用注入）
907a33d feat(s1b): 波形校正編輯器（domain 3.6/3.7 + FP3 + peaks 快取）
3c00b15 chore: 初始 commit — Syllable Repeater macOS v1 (S0 + S1a + hard-guardrails)
```

### 尚未完成（本 session 未動）

- **S2**（本輪目標，見 §3）：4.1-4.4 後端 + 4.7 順帶做 + FP4 播放
- S3（後端 4.5-4.6 exportStep/exportMerged + 前端 FP5 匯出對話框）
- S4（後端 5.1-5.2 ProsodyAnalyzer + 前端 FP3 韻律疊圖）
- S5（後端 6.1-6.2 RecordingComparator + 前端 FP4 錄音比對）
- S6（後端 7.1-7.6 LessonPack/AIService/ProgressEngine + 前端 FP6/FP1/FP7）
- task 2.1（sidecar 發布版 LGPL FFmpeg 換裝）、8.2（授權掃描腳本 CT-09）、8.3（i5-8259U 效能實測 Q10 回填）、9.1/9.2（macOS release build + 免簽章文件）
- **hard-guardrails REJECTED 5 條**（task 8.4.1-8.4.5：Branch Protection／Audit Log／Rate Limit／Network Policy／Prompt Injection Guard；review/archive 前必補）
- **M9 前置 macOS App Sandbox**（Debug+Release entitlements `com.apple.security.app-sandbox: true` → `false`，見 memory `decision_macos_sandbox_ui_demo_waived_v1`）
- **使用者本機環境事宜**：demucs.cpp build + htdemucs 模型下載（`.local-tools/demucs.cpp/`）

## 3. S2 拆分（本交接檔的重點）

**S2 = PracticeEngine（後端 4.1-4.4 + 4.7）+ 前端 FP4 播放部分**。錄音比對面板（S5）、難度結算列（S6）本輪 Non-scope。

### 核心維持原則觸及

- **M1 原聲不可替換**：renderStep 唯一合法實作＝copy+串接+零交越/≤10ms fade（backend-design §3.2.2 介面 4）；**CT-01 是本專案最高防線**（CI 常駐、任何生成路徑進入即失敗）
- **M2 疊加演算法**：buildSteps 純函式，步數＝音節數、句尾倒數、無 word 邊界參數（CT-02 恰 11 步／第 2 步 `tion skills` 而非 `communication skills`）

### 使用者拍板（本輪 S2 前置決策）

1. **4.7 單音節試聽 helper**：**本輪順帶做**（FP3 editor chip onTap 改呼叫 renderStep+播放；stub SnackBar 換真播放）
2. **renderStep→播放路徑**：**項 A 寫檔→just_audio 播檔**（`<temp>/step-<hash>.wav`，符合現有 FileIo/tempDir + clearTemp pattern）

### 依 skill 步驟建立的 10 個 task（動工時依序推）

| # | Task | 落點 | AT/CT | Non-scope |
|---|---|---|---|---|
| S2-1 | TDD-red buildSteps | `packages/domain/test/practice_build_steps_test.dart`（新） | AT-03-01/03/04/06/07、CT-02 | 不寫實作 |
| S2-2 | buildSteps 實作 | `packages/domain/lib/src/practice/practice_engine.dart` + `PracticeStep` model | 讓 S2-1 綠 | — |
| S2-3 | TDD-red renderStep（CT-01） | 同檔測試：合成 PCM 呼叫 renderStep，assert 輸出＝原 `[start,end)` 逐 sample 相等（端點 ≤10ms fade 除外） | **CT-01（最高防線）**、AT-03-02 | — |
| S2-4 | renderStep 實作 | `PracticeEngine.renderStep(step, originalPcm) → Pcm`；copy sourceRanges→串接→端點呼叫 `findNearestZeroCrossingMs`；找不到→線性 ≤10ms fade | 讓 S2-3 綠 | 禁生成路徑（M1） |
| S2-5 | WAV encoder 純函式 | `packages/domain/lib/src/practice/wav_encoder.dart`：`Pcm → Uint8List (RIFF WAV bytes)`；M5 純 Dart | 對 domain_purity_test 過 | — |
| S2-6 | practice_controller.dart | `app/lib/features/practice/practice_controller.dart` Riverpod Notifier：`{steps, currentIndex, repeatN, playState}`；讀 `editorControllerProvider.syllables`＋`analysisControllerProvider.latestEvent.decodedPcm`；`selectStep/setRepeatN/play/stop` | AT-03-05（切步先 stop） | 錄音／結算 |
| S2-7 | practice_player.dart（just_audio） | `app/lib/features/practice/practice_player.dart`：把 renderStep 輸出寫 `<temp>/step-<hash>.wav`；用 `AudioSource.uri()` 播；`repeatN` 迴圈或預串接 | REQ-03 3.2.6 ≤200ms 啟動；hash by (syllables+step index+repeatN) 快取免重寫 | — |
| S2-8 | PracticeScreen | `app/lib/features/practice/practice_screen.dart`：StepNavigator（11 步 chip）＋PlayerBar（開始/停止＋repeatN Stepper 1-10 預設 3）；切步先 stop；掛到 `app_shell.dart` tab=3（`AppSection.practice`）取代目前 placeholder | AT-03-01/03/05/06 | 錄音面板、難度結算 |
| S2-9 | widget tests | `app/test/practice/practice_controller_test.dart`＋`practice_player_test.dart`（若可 fake just_audio）；4.7 更新 editor chip 試聽真播放測試 | 對齊 editor pattern | — |
| S2-10 | 輕量門檻＋文件同步＋git commit | task-split 4.1-4.4/4.7 勾選、FP4 播放勾選；execution-log 追加 S2 批次；記憶列報；git commit | — | — |

### 4.7 順帶做的具體位置

- domain：`PracticeEngine.singleSyllableStep(Syllable syl) → PracticeStep`（純函式 helper，`sourceRanges=[TimeRange(syl.startMs, syl.endMs)]`、`totalDurationMs = syl.endMs-syl.startMs`）
- app 端：`app/lib/features/editor/editor_screen.dart` 的 `_SyllableChip` onTap 從 stub SnackBar 換成呼叫 practice_player 播放單音節 step
- 新增 test：editor chip 點擊觸發 player.play 呼叫

## 4. 待你/新 agent 拍板但影響不大的細節

1. **just_audio 版本**：`app/pubspec.yaml` 需加 `just_audio: ^0.10.x`（pub.dev 最新穩定）；macOS desktop 支援；動工時直接查 pub outdated 挑穩定版即可。
2. **step 快取檔命名 hash 演算法**：sha1(syllables index + step index + repeatN + original pcm 首尾 sample) 就夠——避免撞名。實作時直接用 `crypto` 套件（domain 需要就走 infra；本輪推薦放 practice_player 內用 `package:crypto` 淺依賴，非 domain）。
3. **切步先 stop 的實作邊界**：controller 呼叫 `selectStep` 時先 await `player.stop()`（AT-03-05 無聲音重疊）。

## 5. 待補提醒（review／archive 前必補）

- **hard-guardrails REJECTED 5 條**（task 8.4.1-8.4.5）——`scripts/check_guardrails.py` 現階段仍失敗 5 條，`.githooks/pre-push` 會擋 push
- **M9 前置**：關 macOS App Sandbox（Debug + Release entitlements）；`decision_macos_sandbox_ui_demo_waived_v1` 有詳細操作
- **demucs 使用者本機**：build + htdemucs 模型
- **task 8.3 效能實測**：i5-8259U 上跑 10 秒音檔 pipeline 實測 → 回填 Q10 目標數值

## 6. 本機關鍵路徑

專案根：`/Users/karen_files/vibercoding project/syllable repeater`

開發工具（`.local-tools/`）：
- `.local-tools/whisper.cpp/build/bin/whisper-cli`
- `.local-tools/whisper.cpp/models/ggml-small.en.bin`
- `.local-tools/cmudict/cmudict.dict`
- `.local-tools/demucs.cpp/build/bin/demucs.cpp`（**尚未安裝**）
- `.local-tools/demucs.cpp/ggml-model-htdemucs/`（**尚未下載**）

系統：
- `/usr/local/bin/ffmpeg`、`/usr/local/bin/ffprobe`
- Flutter 3.44.4 stable、Dart 3.12.2
- Xcode 15.4 + CocoaPods 已裝（但 macOS App Sandbox 開著，flutter run macOS 目前黑屏——waive 到 M9）

使用者提供測試音檔：
- `step up your coding skills to a new level.mp3`（3 秒，e2e_pipeline_test 依賴）

## 7. 本 session 已寫入記憶（跨 session 可讀）

過去 20 條專案記憶皆在 `spec-syllable-repeater/memory/`。本 session 產出的最新條目（按時間順序）：

- **hard-guardrails 相關**（2026-07-05）：`decision_hard_guardrails_matrix_20260705`、`workflow_git_hook_two_layer_split`、`pitfall_check_guardrails_ai_names_substring_bug`、`decision_macos_sandbox_ui_demo_waived_v1`
- **S1b 相關**（2026-07-06）：`workflow_editor_undo_stack_domain_stateless`、`decision_zero_crossing_search_window_10ms`、`pitfall_waveform_canvas_widget_test_stateful_host`
- **S1c 相關**（2026-07-06）：`decision_demucs_cpp_selected_mit_licence`、`workflow_sidecar_optional_dependency_injection`

Wiki 更新：`/Users/karen_files/vibercoding project/02_Memory/wiki/chronicle_syllable-repeater.md` 追加 4 段（2026-07-05 hard-guardrails／sandbox；2026-07-06 S1b／S1c）。

## 8. 新 session 可直接複製的啟動提示

```text
請先讀 02_Memory/constitution.md、preferences.md、MEMORY.md，
再讀本專案 spec-syllable-repeater/memory/（原則 5 條，Precision > Recall），
接著讀 /Users/karen_files/vibercoding project/syllable repeater/交接檔-20260706-fullstack-code-implementation_S2-PracticeEngine_FP4.md。

目前階段是 fullstack-code-implementation / S2 / PracticeEngine 4.1-4.4 + 4.7 順帶 + 前端 FP4 播放。
本 session（2026-07-06）已完成 S0/S1a/S1b/S1c＋hard-guardrails matrix；git commit 3 筆；全 test 綠。
請切 fullstack-code-implementation skill，按交接檔 §3 表格從 S2-1 TDD-red buildSteps 動工。

使用者已拍板：4.7 順帶做、renderStep 播放走「寫檔→just_audio 播檔」。
切勿：關 macOS App Sandbox（待 M9）、跳過 CT-01/CT-02 TDD 紅測試、生成路徑進入 renderStep。
push 遠端會被 pre-push hook 擋（REJECTED 5 條未實作），本輪不推。
```
