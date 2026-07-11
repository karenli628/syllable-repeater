<!-- BOOT-BLOCK v1 BEGIN(本區塊必須保持在檔案最前;修改本區塊視同修憲,需使用者批准)-->
# Session 開機五步(回覆第一則訊息前依序執行;輸出回執前禁止讀寫任何專案檔案)
1. 讀 `spec-*/handoffs/LATEST.md`(多個 spec-* → 列出請使用者選)。不存在 →
   `ls spec-*/handoffs/交接檔-*.md | sort | tail -1` 取最新;連 handoffs/ 都沒有 → 跑 pipeline-navigator 後跳第 5 步。
2. 讀 LATEST 的 `state_file` 指向的 `pipeline-state.md` 全文(≤30 行)。缺檔或欄位不合格式 →
   跑 pipeline-navigator 完整掃描,向使用者回報建議的 state 內容,同意後寫入重建。
3. 讀 LATEST 的 `latest_handoff` 指向的交接檔第 4-8 段(跳過第 9-10 段)。
   欄位與 state 不一致 → 一律以 pipeline-state.md 為準,回執後加一行 `DRIFT:<欄位>=state值/交接檔值`。
4. 讀 `~/Karen_Memory/Dev_Memory/` 的 constitution.md、preferences.md、MEMORY.md 全文(不存在則回退 `<工作區>/02_Memory/`,相容至 2026-09-07);
   再讀本專案 `spec-*/memory/` 中與 state.open_tasks 相關的記憶卡 ≤5 條(沒有相關卡則 0 條並照實回報)。
5. 輸出一行開機回執後停下等使用者拍板:
   `【開機完成】階段=<stage_skill>/<slice>|交接=<檔名|無>(<型別>)|記憶=憲法+偏好+N條|巡檢=<未到期|到期|無>|待辦=<open_tasks 前 3 項>`
   例外一:LATEST 的 type 以 `interrupted` 開頭 → 回執上一行先輸出
   `【未完成中斷】首要待辦:<剩餘清單>——完成這些之前不得開始任何新階段或新需求`。
   例外二:今天日期 ≥ state.next_patrol_due → 回執「巡檢=到期」並建議本 session 先跑 ops-monitoring 巡檢。
<!-- BOOT-BLOCK v1 END -->

# AGENTS.md — Syllable Repeater coding agent 守則

> 適用對象：Codex 及任何在本 repo 工作的 AI coding agent。本檔是「不可違反的守則＋最短上手路徑」。
> 更完整的脈絡：需求成稿與設計檔在 `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/`；
> 可貼上的任務提示詞在 `docs/codex/prompts.md`；指令速查在 `docs/codex/commands.md`。
> 溝通與文件一律使用繁體中文（台灣用語）。

## 1. 這個專案是什麼

macOS 桌面 App（Flutter + Dart workspace）：匯入音檔 → 自動音節對齊（FFmpeg / whisper.cpp / demucs.cpp sidecar）→ 波形校正 → 句尾疊加跟讀練習 → 匯出 mp3 → 錄音比對 → SRS 進度。純本機、單人、無伺服器。

金標準例句：`She has excellent communication skills` ＝ **11 音節 → 10 切點 → 11 步**（不是 15，任何文件寫 15 都是舊誤植）。

```
app/                Flutter macOS UI（features/*、shared/*、shell/）
packages/domain/    純 Dart 領域層（引擎、模型、ports）★核心規則全在這
packages/infra/     轉接層（SidecarRunner、FFmpeg/whisper/demucs wrapper、Drift DB、檔案 IO）
scripts/            guardrails / license / CI / release staging 腳本
spec-syllable-repeater/  需求、設計、任務拆分、guardrails matrix、審查報告（單一事實來源）
.local-tools/       開發期 sidecar 二進位與模型（不進版控）
```

依賴方向：`app → domain + infra`；`infra → domain`；`domain → 無`（只有抽象 ports）。

## 2. 紅線（違反任何一條 = 交付失敗，沒有例外）

1. **M1 原聲不可替換**：練習播放/匯出的音訊逐 sample 來自原始 PCM 切片串接（`PracticeEngine.renderStep` 是唯一合法路徑；僅允許零交越吸附或 ≤10ms micro-fade）。**禁止**任何 TTS、生成、合成、音高重算、跨來源拼接進入播放或匯出路徑。分析模組只讀不寫音訊。
2. **M2 疊加演算法**：步數＝音節總數；第 n 步＝句尾倒數 n 個音節→句尾；**禁止**單字邊界吸附（第 2 步是 `tion skills`，不是 `communication skills`）。
3. **M5 Domain 純 Dart**：`packages/domain` **禁止** import `flutter`、`package:infra`、sidecar 實作、`dart:io`／`dart:ffi`／`dart:html`。副作用一律走 ports 注入（FileIo/Clock/SecureStore/AiClient/ProgressRepository/RecordingAudioSource/AuditLogSink）。`domain_purity_test.dart` 會擋——**禁止修改測試來繞過**。
4. **M9 授權白名單**：只允許 MIT/BSD/ISC/Apache-2.0/LGPL(動態連結)；**禁止** GPL/AGPL/非商用限定/研究限定的程式碼或模型進主程式與 release；零 Python 進 release。FFmpeg 必須 LGPL shared build（`scripts/check_licenses.py` 與 staging gate 會擋 `--enable-gpl`，禁止繞過）。
5. **M10 隱私**：API key 只進 SecureStore（Keychain），**禁止**出現在程式碼、設定、pack、DB、log、commit；錄音比對後刪除（finally 保證）；attempt/audit_log 表**不得**新增音訊或路徑欄位。
6. **M3/M4/M6/M7/M8**：合併匯出靜音＝前一步 totalDurationMs（以 sample 數計，±20ms）；sidecar 崩潰不得拖垮 App（一律經 SidecarRunner）；進度合併依 updatedAt 較新覆寫、contentHash 只重置該課；跨日**零懲罰**（schema 禁止逾期/失敗欄位）；歸檔 168 小時（不含）可恢復、EXPIRED 不可逆。
7. **三同步（憲法 C10）**：任何規則變動＝需求成稿＋程式＋測試三者同步改。只改其中一處＝核心被破壞。錯誤碼、schema、SRS 參數、靜音規則皆適用。
8. **範圍紀律（憲法 C5）**：Non-scope 清單（手機端、Windows、批次匯入、雲端同步、伺服器、TTS、金流、防盜欄位）**禁止**擅自實作。想加 → 先提出、說明代價、等使用者決定。
9. **不臆測（憲法 C13）**：使用者沒說的不要替他決定。必須假設時，明寫「【臆測揭露】我正在假設：＿＿」等使用者確認；無法即時確認就標 `[需與產品確認]`。
10. **誠實紀錄**：測試失敗就說失敗；沒做的任務不勾選；guardrails matrix 狀態不得由 AI 自批「不適用」。

## 3. 每次動工的固定流程

```bash
# 首次 clone 後一次
git config core.hooksPath .githooks

# 動工前
flutter pub get

# 交付前（與 GitHub Actions 完全同源的完整 gate）
bash scripts/ci_core_checks.sh
```

- 動到 `packages/domain` → 先跑 `flutter test packages/domain/test`（尤其動 PracticeEngine 必跑 CT-01/CT-02 所在的 `practice_build_steps_test.dart`）。
- 動到 guardrails matrix → 跑 `python3 scripts/check_guardrails.py <matrix> <decision-log>`（路徑見 docs/codex/commands.md）。
- 演算法類新功能（M1/M2/M3 等級）→ **TDD：先寫紅測試再實作**。
- commit 訊息用約定式前綴（`feat:`/`fix:`/`chore:`/`docs:`/`ci:`），main 有 ruleset 禁 force push。
- session 結束 → 呼叫 `handoff` skill：先過步驟 0 三閘門（不過且無合法中斷代碼＝回去做完，不寫交接檔）；產出後同步 `handoffs/LATEST.md` 與 `pipeline-state.md`，並跑 `python3 scripts/check_handoff.py --latest`（必須 PASS）。

## 4. 程式風格（與現有 82 檔一致，逐條遵守）

1. AI 產出的每個檔案第一行：`// AI-Generate`（shell/python 用 `# AI-Generate`）。
2. 公開類別/方法的 doc comment 用繁體中文，並**引用規格出處**（如 `/// PracticeEngine（backend-design.md §3.2.2）。` 或 M2/CT-01/AT-04-05 編號）。
3. 錯誤一律 `DomainException(code, message)`，code 取自 `packages/domain/lib/src/errors.dart` 的 `ErrorCodes` 常數。**新增錯誤碼流程**：先改 backend-design §3.2.8 → errors.dart → app 的 `error_messages.dart`（含碼數斷言測試）→ frontend-design 功能點 8 對照表。
4. 邊界驗證放建構子/方法入口，錯誤訊息帶實際值（`got $x`）。Domain 內部互信，不重複驗。
5. 回傳集合 `List.unmodifiable`；模型類 immutable ＋ named parameters。
6. UI 狀態類手寫 `copyWith`，可清空的 nullable 欄位用 `_unset` 哨兵（見 `practice_controller.dart`）。
7. 長任務防競態三選一（照既有樣板）：世代編號（`_playRunId`）／布林重入鎖（`_inProgress`）／目標集合鎖（`_activeDestPaths`）。
8. 檔案寫入一律 temp → rename 原子搬移（`AtomicFileIo`）；清理放 finally；temp 目錄靠 App 啟動 clearTemp 兜底。
9. sidecar 一律經 `ProcessRunner` 窄介面；錯誤映射照 `ffmpeg_decoder.dart` 樣板：timeout→`ERR_SIDECAR_TIMEOUT`、被訊號殺→`ERR_SIDECAR_CRASHED`、exit≠0→模組語意碼＋stderr 末 300 字。
10. 規格常數單一定義＋註解標出處（如 `kZeroCrossingSearchWindowMs`、`intervalDays=[0,1,3,7,14,30]`）。
11. 結構防線優先：能用「schema 沒有該欄位」就不要用「程式邏輯擋」；新表同步加 `db_schema_test.dart` 結構斷言。
12. 測試描述直接寫對應的 CT-xx/AT-xx 編號。

## 5. 已知地雷（前人踩過，不要重踩）

- **macOS App Sandbox**：entitlements 的 `app-sandbox: true` 會擋 `.local-tools/` 讀取與 ffmpeg spawn 導致黑屏。任務 9.1 時兩份 entitlements 都改 `false`（使用者已拍板）；**不要**用 `temporary-exception.files.absolute-path.*`（免簽章下無效）。
- **whisper.cpp on Intel Mac**：必須 FFmpeg 先轉 16k mono WAV 並加 `--no-gpu`，否則輸出異常。模型固定 `small.en`。
- **demucs.cpp CLI**：`demucs.cpp.main <model-file> <input-audio> <out-dir>`，vocals 輸出檔名 `target_3_vocals.wav`，模型 `ggml-model-htdemucs-4s-f16.bin`。
- **本機 `/usr/local/bin/ffmpeg` 是 GPL build**：只能開發測試用，**絕不可**進 release bundle。
- **Drift 表名**：類名會被複數化，須覆寫 `tableName` 對齊設計的單數表名。
- **Riverpod 3**：`Override` 型別要從 `flutter_riverpod/misc.dart` import。
- **widget test 跑真 async**（Process/檔案 IO）：用 `tester.runAsync`。
- **dev sidecar 路徑**：`SidecarPaths.dev()` 預設指向本機絕對路徑，他機請設環境變數 `SYLLABLE_REPEATER_DEV_ROOT`／`FFMPEG_PATH` 等（見 `sidecar_paths.dart`）。

## 6. 現況與剩餘工作

**本檔禁止記錄進度數字或任務完成狀態**——同一事實兩處記必漂移（本節 2026-07-07 版的「54/58、四項未完成」就曾過期誤導接手者）。現況唯一來源：

- `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/pipeline-state.md`（階段／待辦／巡檢時點）
- `spec-syllable-repeater/handoffs/LATEST.md` 指向的最新交接檔（該時點完成量與雷區）

動工前請執行檔首「Session 開機五步」（BOOT-BLOCK），不要憑本檔或記憶判斷進度。

## 7. 不要動的東西

- `spec-syllable-repeater/requirements/**` 的需求/設計/guardrails 文件：修改必須走變更防線（七題檢查，見 review skill 的 change-defense-checklist），並經使用者確認；**不得**為了讓程式過而反向改規格。
- `.githooks/`、`scripts/check_guardrails.py`、`scripts/check_licenses.py`、`domain_purity_test.dart`、`db_schema_test.dart`：這些是防線本體；行為調整需使用者同意。
- `~/Karen_Memory/Dev_Memory/`（家目錄下，若可見；舊路徑 `02_Memory/` 相容至 2026-09-07）：記憶庫有自己的規則；只讀 `constitution.md`／`preferences.md`，不要寫入。
- 其他專案的 `spec-*/memory/`：禁止讀取（跨專案隔離）。
