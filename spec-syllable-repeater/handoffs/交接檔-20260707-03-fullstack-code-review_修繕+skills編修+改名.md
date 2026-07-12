# 交接檔 20260707-03 · fullstack-code-review / 全專案修繕+skills編修+改名 / 6 階段收尾

> 首份依 2026-07-07 新交接規範（`ai-dev-skills/skills/handoff/`）產出的交接檔。
> Dogfooding：新規範自己第一次落實。

## 1. 讀原則檔

新 session 開始請先讀（順序固定）：

1. `~/Karen_Memory/Dev_Memory/constitution.md`（憲法，全文）
2. `~/Karen_Memory/Dev_Memory/preferences.md`（偏好，全文）
3. `~/Karen_Memory/Dev_Memory/MEMORY.md`（通用記憶索引）

> 舊路徑相容：若 `~/Karen_Memory/Dev_Memory/` 不存在，回退到 `<工作區>/02_Memory/`（相容視窗至 2026-09-07）。

## 2. 讀本專案記憶（Precision > Recall）

從 `spec-syllable-repeater/memory/` 中挑本任務相關的 5 條打開（憲法 C7 原則）。建議清單：

- `workflow_交接檔命名需用原流程階段與任務編號.md` — 檔名規則（本輪已加升級註記，見末尾）
- `workflow_交接檔新session啟動提示範本.md` — 8+1 段結構的專案層原型（本輪已加升級註記）
- `pitfall_錯誤碼借用_新增碼須三同步.md` — 本輪 I-002 修繕的規則來源（已升級為 universal）
- `decision_hard_guardrails_matrix_20260705.md` — matrix 37 項裁決紀錄
- `workflow_release_sidecar_staging_gate_s6.md` — 2.1 sidecar staging gate 邏輯（下一段接手依據）

## 3. 讀本交接檔

完整絕對路徑：

```
/Users/karen_files/vibercoding project/syllable repeater/spec-syllable-repeater/handoffs/交接檔-20260707-03-fullstack-code-review_修繕+skills編修+改名.md
```

## 4. 目前階段

`fullstack-code-review / 全專案修繕+skills 編修+Karen_Memory 改名 / A~F 六階段收尾完成 → 下一段回歸 fullstack-code-implementation 主線`

（本 session 執行的並非單一 skill 的常規流程，而是 fullstack-code-review 上輪產出的 3 份建議報告的修繕收尾＋跨專案基礎設施升級。**6 階段已全數完成**，交給下一 session 的是**主線任務 2.1**。）

## 5. 本 session 完成量

**階段完成**：A ✅ B ✅ C ✅ D ✅ E ✅（本檔即為 E-4 dogfooding） F ✅ **本輪全部收齊**。

**具體產出**：
- **A**：I-001 修（matrix 備忘 20→19）；I-002 修（新增 `ERR_TRANSCRIBE_FAILED` / `ERR_SEPARATE_FAILED`，backend-design §3.2.8 → errors.dart → error_messages.dart（17→19 碼）→ frontend-design 功能點 8 → whisper/demucs wrapper → 新增 3 條測試斷言，全部三同步）
- **B**：S-001 修（sidecar_paths.dart 移除寫死 `_defaultDevRoot`，改為向上尋 workspace 或要求 env var）；新增 `SidecarPaths.diagnose()` 方法回傳結構化就緒清單＋`SidecarComponentStatus` 資料類（借鏡 QwenASRMiniTool 報告三優先 2；本輪不接 UI）
- **C**：ai-dev-skills 套件新增獨立 `handoff/` skill（SKILL.md + 3 個 references：命名規則、9 段範本、工作衛生守則）；15 個既有 SKILL.md 的記憶掛接章節升級為雙路徑相容（`Karen_Memory/Dev_Memory/` 優先，`02_Memory/` 舊路徑相容至 2026-09-07）；`.claude/skills/` 同步完成（handoff skill 已被系統掃描掛載）
- **D**：`~/Karen_Memory/Dev_Memory/` 建立（家目錄下最上層母層，備份友善）；`02_Memory/` 整目錄 mv 過去（.git 歷史保留）；constitution.md 與 memory_schema.yaml 內部自我引用更新；原 `02_Memory/` 目錄留 README.md 指路（過渡期至 2026-09-07）；專案內 AGENTS.md 與 docs/codex/prompts.md 路徑更新
- **E**：建目錄 `spec-syllable-repeater/handoffs/{drafts,archive}`、`docs/legacy/`、`.local-tools/fixtures/`；12 份根目錄 `交接檔-*.md` → `handoffs/`；1 份「拷貝」重複檔（md5 同源）刪除；`HANDOFF_手機端討論.md` → `handoffs/archive/20260612-01-手機端討論.md`（順帶新規則重命名）；`PLAN3.0.md` → `docs/legacy/`；`step up your coding skills to a new level.mp3` → `.local-tools/fixtures/`；`.gitignore` 加 `spec-*/handoffs/drafts/`；`handoffs/README.md` 說明沿革；**本檔（20260707-03）為 dogfooding 首份**

**測試綠燈**：本地 `bash scripts/ci_core_checks.sh` 全綠 ✅
- domain 82 tests
- infra 67 tests（含 whisper 新增 2 條 + demucs 修 2 條）
- app 62 tests（含 sidecar_paths_test 新增 3 條 diagnose 覆蓋 + widget_test 碼數 17→19）
- `flutter analyze` 無問題

**F 階段補做記錄（本 session 內完成）**：
- ✅ F-1 · Dev_Memory/workflows/`workflow_handoff_convention.md`（universal，跨專案交接規範主表）
- ✅ F-1 · Dev_Memory/workflows/`workflow_workspace_hygiene.md`（universal，跨專案工作區衛生守則）
- ✅ F-2 · `spec-syllable-repeater/memory/workflow_交接檔命名需用原流程階段與任務編號.md` 末尾加「升級 2026-07-07」段（原內容保留）
- ✅ F-2 · `spec-syllable-repeater/memory/workflow_交接檔新session啟動提示範本.md` 末尾加「升級 2026-07-07」段（原內容保留）
- ✅ F-3 · Dev_Memory/pitfalls/`pitfall_錯誤碼借用_新增碼須三同步.md`（升 universal，補「為何與技術棧無關」的 reasoning）
- ✅ F-4 · Dev_Memory/`wiki/chronicle_syllable-repeater.md` 追加本輪執行紀錄（176 行）
- ✅ F-4 · Dev_Memory/`MEMORY.md` 追加 3 條索引行（2 workflow + 1 pitfall）

**Git**：本 session 尚未 commit（使用者可決定要拆成 A/B/C/D/E/F 六個 commit 或視情合併）。

## 6. 具體動工建議

**下一段（新 session）**：回歸主線 — 剩餘任務 2.1 / 7.2 / 9.1 / 9.2 依序推進

- **下一 skill**：`fullstack-code-implementation`（接主線任務）
- **從交接檔哪節開始**：本檔第 10 節「剩餘主線任務（依 task-split.md）」的 2.1 起
- **第一個 task**：`task-split 2.1` — sidecar 實體工件與 release staging；建議先寫 `scripts/fetch_sidecar_artifacts.py`（借鏡 QwenASRMiniTool 報告三優先 1：SHA-256 pinning + LGPL-shared FFmpeg 來源 + 拒絕 CERT_NONE 降級）；然後跑 `python3 scripts/prepare_release_sidecars.py --dry-run`

之後依序：2.1 → 7.2（真 Keychain/HTTP adapter，接完更新 matrix 7 條 PARTIAL）→ 9.1（entitlements → false，release build）→ 9.2（寫 make_release_zip.py + 使用者 README，借鏡優先 3/4）→ `code-knowledge-init` → `project-archive` → `ops-monitoring`。

## 7. 拍板事項

- Karen_Memory 母資料夾置於家目錄 `~/Karen_Memory/`（風險最小、備份友善）；未來平行擴增 Life_Memory / Learn_Memory / Mindset_Memory
- 交接檔進版控走 `spec-*/handoffs/`；`drafts/` 為 `.gitignore` 排除的草稿區
- handoff 為**獨立 skill**（自動觸發於階段完成或工作項目中斷前）
- 錯誤碼新增文案定案：`ERR_TRANSCRIBE_FAILED`＝「辨識失敗，可重試」；`ERR_SEPARATE_FAILED`＝「人聲分離失敗，可跳過分離重試」
- 「17 碼」字樣的更新範圍：**只動規範性文件**（backend-design / frontend-design / errors.dart / widget_test / matrix #6 註解）；史料類（execution-log / task-split 進度註記 / code-review-report / HTML 報告 / pitfall 卡）**保留原數字**＝發現時的實情
- ai-dev-skills 相容視窗：至 2026-09-07；期後可移除舊路徑 fallback 並刪除 `02_Memory/` 占位

## 8. 不要做的事

- **不要**動 `spec-syllable-repeater/memory/` 內既有兩張交接規範卡的**主體內容**（保留），只在末尾加「升級 2026-07-07」段（原內容不刪、不改身分）
- **不要**動已完成的 sidecar_paths UI 整合（progress_settings_screen.dart）——`diagnose()` 本輪只加方法不接 UI
- **不要**在 F 階段變動 `~/Karen_Memory/Dev_Memory/` 內既有卡的核心欄位；只補「升級為 universal」的新卡與註記
- **不要**繞過 CI gate（`bash scripts/ci_core_checks.sh` 必須全綠）
- **不要**照抄 QwenASRMiniTool 的 GPL FFmpeg 下載源、SSL CERT_NONE 降級、單檔巨型 UI、伺服器/批次功能（違 M9 或 Non-scope）
- **不要**動已遷移的既有交接檔內容（雖然它們寫 `02_Memory/`，但那是史料——handoffs/README.md 已註明沿革）

## 9. 給新 session AI agent 的可複製提示詞（人類直接複製全文貼上）

以下 fenced code block 內即為可複製全文——人類把整段貼進新 session 的第一則訊息即可讓 agent 冷啟動接手：

```text
你在 Syllable Repeater repo 工作。先讀 AGENTS.md 全文並遵守其中紅線與風格守則；
再讀 ~/Karen_Memory/Dev_Memory/constitution.md、preferences.md、MEMORY.md
（若不存在則回退 <工作區>/02_Memory/，相容期至 2026-09-07）。
接著讀 spec-syllable-repeater/memory/（Precision > Recall 挑 5 條相關，建議：
workflow_release_sidecar_staging_gate_s6 / workflow_demucs_cpp_official_cli_contract_s6 /
decision_demucs_cpp_selected_mit_licence / decision_開發環境工具鏈事實 /
workflow_ct09_license_gate_release_manifest_s6）
與本交接檔 /Users/karen_files/vibercoding\ project/syllable\ repeater/spec-syllable-repeater/handoffs/交接檔-20260707-03-fullstack-code-review_修繕+skills編修+改名.md 全文。

目前階段 fullstack-code-implementation / 2.1 / SidecarReleaseStaging 實體工件補齊。
上一 session（2026-07-07）已完成 fullstack-code-review 收尾六階段 A~F：
修 I-001/I-002、S-001＋diagnose、新增 handoff skill＋15 SKILL.md 雙路徑、建 Karen_Memory
遷 02_Memory、工作區清理、跨專案守則寫入 Dev_Memory＋既有卡升級註記。
本地 bash scripts/ci_core_checks.sh 全綠（domain 82 / infra 67 / app 62 tests；
flutter analyze 無問題）；本輪未 commit。

請按本檔第 10 節「剩餘主線任務」從 2.1 動工：先寫 scripts/fetch_sidecar_artifacts.py
（借鏡 QwenASR 報告三優先 1：SHA-256 pinning + LGPL-shared FFmpeg + 拒絕 CERT_NONE），
然後跑 python3 scripts/prepare_release_sidecars.py --dry-run 對盤點結果，
工件齊全後跑實跑並勾選 task-split 2.1。
每完成一階段/工作項目呼叫 handoff skill 產下一份交接檔
（檔名：交接檔-<yyyymmdd>-<下一個流水號>-<skill>_<切片>_<關鍵字>.md，
落點 spec-syllable-repeater/handoffs/，9+1 段完整）。

拍板：Karen_Memory 置於家目錄；交接檔進版控走 spec-*/handoffs/；handoff 為獨立 skill；
17 碼→19 碼只動規範文件、史料保留；A~F 六階段全部收齊。
不要：把 /usr/local/bin/ffmpeg 的 GPL build 放進 release staging（違 M9）；
繞過或弱化 scripts/check_licenses.py 的 GPL/non-shared 檢查；
動 Apple Silicon（Non-scope，x86_64 先行）；
照抄 QwenASR 的 GPL 下載源、SSL CERT_NONE 降級、單檔巨型 UI 或伺服器/批次功能。

工作規則：動工前 flutter pub get；交付前 bash scripts/ci_core_checks.sh 必須全綠；
新檔案第一行 // AI-Generate（或 # AI-Generate for shell/python）；
memory 卡片按 memory_schema.yaml 格式；F 完成後呼叫 handoff skill 產下一份交接檔
（檔名：交接檔-20260707-04-<skill>_<切片>_<關鍵字>.md）。
```

## 10. 接續應有階段/流程的工作項目清單（非 9 段內容，供人類決策）

### F 階段（本 session 內已完成）

- [x] F-1 · `~/Karen_Memory/Dev_Memory/workflows/workflow_handoff_convention.md` — 新建 universal 卡（跨專案交接規範主表）
- [x] F-1 · `~/Karen_Memory/Dev_Memory/workflows/workflow_workspace_hygiene.md` — 新建 universal 卡（跨專案工作衛生守則）
- [x] F-2 · `spec-syllable-repeater/memory/workflow_交接檔命名需用原流程階段與任務編號.md` — 末尾加「升級 2026-07-07」段（原內容保留）
- [x] F-2 · `spec-syllable-repeater/memory/workflow_交接檔新session啟動提示範本.md` — 末尾加「升級 2026-07-07」段（原內容保留）
- [x] F-3 · `~/Karen_Memory/Dev_Memory/pitfalls/pitfall_錯誤碼借用_新增碼須三同步.md`（升 universal，補「為何與技術棧無關」的 reasoning）
- [x] F-4 · `~/Karen_Memory/Dev_Memory/wiki/chronicle_syllable-repeater.md` 追加本輪執行紀錄
- [x] F-4 · `~/Karen_Memory/Dev_Memory/MEMORY.md` 追加 3 條索引行（2 workflow + 1 pitfall）

### 剩餘主線任務（依 task-split.md）

- [ ] `task-split 2.1` — sidecar 實體工件與 release staging（LGPL-only FFmpeg + demucs.cpp binary/model；建議先寫 `scripts/fetch_sidecar_artifacts.py` 借鏡 QwenASR 下載器模式）
- [ ] `task-split 7.2` — 真 Keychain adapter（`flutter_secure_storage`）＋ AI provider HTTP adapter；接完更新 hard-limits-matrix #11/#19/#20/#22/#23/#31/#34 的 PARTIAL 註記
- [ ] `task-split 9.1` — macOS release build（entitlements `app-sandbox: false`、驗證 LGPL 動態連結）
- [ ] `task-split 9.2` — 未簽章打包 + Gatekeeper 略過操作說明（建議寫 `scripts/make_release_zip.py` + 使用者導向 README，借鏡 QwenASR make_release_zip 模式）

### 後續 skill 流程

- 上述 4 條收尾後 → `code-knowledge-init`（生 `knowledge/code/frontend-project.md` 與 `backend-project.md` 首版）
- 接 `project-archive`（含 F 階段的 chronicle 也會被回顧）
- 接 `ops-monitoring`（交付後監測規劃）

## 附錄：本 session 的變動檔案清單（供 git commit 拆分參考）

**階段 A** — 修 I-001 + I-002：
- `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md`（3 處改字）
- `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/backend-design.md`（§3.2.8 加 2 列）
- `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/frontend-design.md`（功能點 8 加 2 列 + 前言與自檢改數字）
- `packages/domain/lib/src/errors.dart`（加 2 常數 + 註解 17→19）
- `app/lib/shared/error/error_messages.dart`（加 2 筆 ErrorPresentation）
- `app/test/widget_test.dart`（斷言 17→19）
- `packages/infra/lib/src/sidecar/whisper_transcriber.dart`（2 處錯誤碼改）
- `packages/infra/lib/src/sidecar/demucs_separator.dart`（2 處錯誤碼改）
- `packages/infra/test/whisper_transcriber_test.dart`（+ 2 條斷言）
- `packages/infra/test/demucs_separator_test.dart`（2 條斷言改）

**階段 B** — sidecar_paths S-001 + diagnose：
- `app/lib/shared/infra/sidecar_paths.dart`（`_defaultDevRoot` 移除 + `_findWorkspaceRoot()` + `diagnose()` + `SidecarComponentStatus`）
- `app/test/shared/sidecar_paths_test.dart`（+ 3 條 diagnose 測試）

**階段 C** — handoff skill + 15 SKILL.md 雙路徑：
- 新增：`skills library/ai-dev-skills/skills/handoff/{SKILL.md, references/handoff-naming-convention.md, handoff-template.md, workspace-hygiene.md}`
- 15 個既有 SKILL.md 記憶掛接段升級（權威來源 + `.claude/skills/` 同步副本）

**階段 D** — Karen_Memory 建立 + 02_Memory 遷移：
- 新增：`~/Karen_Memory/Dev_Memory/`（=原 02_Memory 全部內容，.git 歷史保留）
- 修改：`~/Karen_Memory/Dev_Memory/constitution.md`（自我引用 + 路徑沿革 banner）
- 修改：`~/Karen_Memory/Dev_Memory/memory_schema.yaml`（自我引用 + 路徑沿革 banner）
- 新增：`vibercoding project/02_Memory/README.md`（過渡指路空殼）
- 修改：`syllable repeater/AGENTS.md`（路徑更新）
- 修改：`syllable repeater/docs/codex/prompts.md`（路徑更新）

**階段 E** — 工作區清理 + 本檔：
- 新增：`spec-syllable-repeater/handoffs/{drafts/,archive/,README.md}`
- 新增：`docs/legacy/`、`.local-tools/fixtures/`
- 遷移：12 份 `交接檔-*.md` → `handoffs/`（1 份「拷貝」重複刪除）
- 遷移：`HANDOFF_手機端討論.md` → `handoffs/archive/20260612-01-手機端討論.md`
- 遷移：`PLAN3.0.md` → `docs/legacy/`
- 遷移：`step up your coding skills to a new level.mp3` → `.local-tools/fixtures/`
- 修改：`.gitignore`（加 `spec-*/handoffs/drafts/`）
- 新增：`spec-syllable-repeater/handoffs/交接檔-20260707-03-fullstack-code-review_修繕+skills編修+改名.md`（**本檔**）

**階段 F** — Dev_Memory 跨專案守則寫入 + 既有卡升級註記：
- 新增：`~/Karen_Memory/Dev_Memory/workflows/workflow_handoff_convention.md`（universal）
- 新增：`~/Karen_Memory/Dev_Memory/workflows/workflow_workspace_hygiene.md`（universal）
- 新增：`~/Karen_Memory/Dev_Memory/pitfalls/pitfall_錯誤碼借用_新增碼須三同步.md`（升 universal，補 reasoning）
- 修改：`~/Karen_Memory/Dev_Memory/MEMORY.md`（追加 3 條索引行）
- 修改：`~/Karen_Memory/Dev_Memory/wiki/chronicle_syllable-repeater.md`（追加本輪紀錄，共 176 行）
- 修改：`syllable repeater/spec-syllable-repeater/memory/workflow_交接檔命名需用原流程階段與任務編號.md`（末尾加升級註記，原文保留）
- 修改：`syllable repeater/spec-syllable-repeater/memory/workflow_交接檔新session啟動提示範本.md`（末尾加升級註記，原文保留）
