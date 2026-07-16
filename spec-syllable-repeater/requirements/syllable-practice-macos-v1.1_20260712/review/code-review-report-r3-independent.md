// AI-Generate
# 程式碼審查報告（第 3 輪：獨立複核）

## 基本資訊

| 專案 | 內容 |
|------|------|
| 需求名稱 | syllable-practice-macos-v1.1_20260712 |
| 審查日期 | 2026-07-16 |
| 審查輪次 | 第 3 輪（獨立複核；審查者 Claude Code，與實作者/前兩輪審查者 codex 不同 agent） |
| 審查動機 | 第 1–2 輪為實作者自審；本輪由不同 agent 對聲明做獨立抽驗 |
| 變更檔案數 | 已修改 94 檔（+9,552／−1,422 行）＋未追蹤 70 檔 |
| 審查範圍 | 全端（Domain／Infra／Flutter App／需求·設計·guardrails 三同步） |
| 設計檔案 | backend-design.md ✅／frontend-design.md ✅ |
| 編譯閘門 | 沿用 S10 報告拆批證據（Domain 188、Infra 94＋8、App 190、analyze 無問題、Release codesign PASS）；本輪未重跑（審查技能不執行測試） |

## 審查結論

**✅ 透過（帶 1 項 important：整包變更未入版控，建議歸檔前立即 commit）**

### 統計概覽

| 嚴重性 | 數量 |
|--------|------|
| blocking | 0 |
| important | 1 |
| suggestion | 2 |
| nit | 0 |
| praise | 3 |

## 獨立抽驗結果（機器可驗證聲明逐項實查）

| 聲明 | 實查方式 | 結果 |
|------|----------|------|
| v1.1 guardrails 25 IMPLEMENTED／0 PARTIAL | 實跑 `scripts/check_guardrails.py` | ✅ PASS，25/25 |
| M10（r7）：RecordingBuffer 完全移除 | 全庫 grep `recordingbuffer`／`ERR_BUFFER_STASH_FAILED` | ✅ lib 零殘留；死錯誤碼已一併刪除 |
| M10：temp 由 `finally` 清除 | 讀 `recording_comparator.dart:53`、`practice_recording.dart:171`、`practice_player.dart:293/305/314` | ✅ 三處均有 finally 防線 |
| M10：僅目前單元記憶體 PCM | `PracticeUiState.recordedPcm` 單槽、切步清 null | ✅ |
| M5 Domain 純度 | grep `dart:io`／`http` import 於 packages/domain/lib | ✅ 零命中 |
| M14 語言拒絕不 fallback | 讀 `TranscriberRegistry.resolve` | ✅ 查無即拋 `ERR_LANGUAGE_UNSUPPORTED` 並列支援清單，無英文 fallback 分支 |
| M3（r6）預設與靜音規則 | 讀 `PracticeBlock`（1／1.0）、`PracticeRow`（3／1.0）、`_renderRowInner`／`_applyOuterConfig` | ✅ 列 gap 只算原始長度一次；列最後一輪不留靜音；積木每輪（含最後）保留靜音——與需求 2.5 M3、總表、設計 §4.4 三方一致 |
| M1 補述雙軌隔離 | 讀 `AnalysisAudioTracks`（originalPcm／analysisPcm 分欄） | ✅ |
| M12 唯一判定入口 | `PracticeEngine.effectiveUnits` 存在且為 sealed unit 模型 | ✅ |
| 錯誤碼三同步 | errors.dart 26 碼＝design §3.2.8（19＋7）＝error_messages 測試斷言 26 | ✅（執行日誌歷史記載「27」為 r7 移除 stash 碼前的當時正確值，非現行漂移） |
| M15 無假百分比 | grep 假進度常數於 app/lib | ✅（命中僅為波形 Y 座標與 preview fixture confidence，非進度） |
| `.abopack v3` fail-closed | 讀 `CourseBundleEngine`：schemaVersion／欄位逐項驗證、損毀統一 `ERR_PACK_CORRUPTED`、v1/v2 相容分流 | ✅ |
| 介面 37／38 落地 | `course_bundle_engine.dart`、`practice_export_plan.dart`＋`course_bundle_engine_test.dart` | ✅ |
| M2/M11 步數不變式 | `practice_build_steps_test.dart` 含 AT-13-07 | ✅ |
| 需求 r7 無 TTL/RecordingBuffer 殘影 | grep 總表與正文（修訂歷史除外） | ✅ 總表已無 9:59/10:01 邊界列 |
| AI-Generate 標註 | 未追蹤 .dart 新檔逐檔查首行 | ✅ 全數有標註 |
| TODO/FIXME 殘留 | 變更 .dart 檔掃描 | ✅ 零殘留 |
| `audio_session` 直接依賴（9.4） | app/pubspec.yaml:45 | ✅ `^0.2.4` |
| task-split 閉環 | checkbox 統計 | ✅ 115 done／0 open |

## 發現詳情

### Important

#### [I-001] IA-回復方案：整包 v1.1 實作（94 修改＋70 未追蹤檔，約 9,500 行）完全未 commit
- **檔案**: 全案（git 工作區）
- **描述**: 最後一個 commit（fc504e9）停在 2026-07-12 設計階段；S9＋S10 全部實作、測試與規格同步只存在於工作區。是否考慮在進入 project-archive 前先入版控？目前任何誤操作（清理指令、硬體故障、另一 agent 的 reset）都會讓四天工作無法復原，且歸檔報告引用的證據缺 commit hash 可追溯。
- **建議**: 立即分批 commit（規格文件、Domain、Infra、App、測試可分開），再進入歸檔。
- **規範來源**: impact-analysis IA-*（變更回復方案）；憲法 C14 精神（毀滅性風險前置防護）

### Suggestion

- [FQ-狀態一致性] `app/lib/features/import_analysis/analysis_controller.dart:9` — `analysisRunnerProvider` 預設值是 `PreviewAnalysisRunner`（回傳硬編音節、`source: 'preview:…'`）。正式入口靠 `main.dart:45` 覆蓋為 `InfraAnalysisRunner`，目前安全；但未來若新增入口（第二個 main、整合測試 harness）忘記覆蓋，會靜默顯示假分析結果，與 M15 誠實呈現精神相悖。是否考慮把預設 provider 改為 `throw UnimplementedError('須由 main 注入')`，讓漏接在啟動即爆而非默默出假資料？
- [流程衛生] `review/` — 第 1 輪審查報告檔案不存在，只在第 2 輪報告中被引用（3 個 blocking 的原文與定位已不可考）。複審機制要求「引用原報告編號」；建議日後首輪報告落檔保留，複審以增量檔或章節疊加。

### Praise

- [S6] fail-closed 驗證密度一致且徹底：Registry 語言路由、`.abolabel`／`.abopack` 讀取、`PracticeExportPlan` fingerprint/lessonId/range 綁定，全部「先驗證後套用、損毀零副作用」。
- [S6] 執行日誌的 TDD 紅燈證據具體到 exit code 與失敗原因，「誠實揭露」段落主動記錄拆批執行與不宣稱未跑的 CI——可追溯性極佳。
- [S6] r7 撤回 RecordingBuffer 時把 service/store/provider/錯誤碼/測試一次清乾淨，無死碼殘留——需求回退的三同步執行得很乾淨。

## 與第 2 輪報告的關係

第 2 輪（codex 自審）結論「通過、0 blocking」——本輪對其中可機器驗證的聲明逐項實查，**未發現任何與事實不符的聲明**。本輪新增的 I-001 屬版控衛生而非程式碼缺陷，不推翻第 2 輪結論。

## 下一階段建議

1. **先處理 I-001（commit 入版控）**，建議同時由 handoff skill 產出完成型交接檔，修正 `handoffs/LATEST.md` 仍指向 2026-07-12 interrupted 交接檔的過時狀態。
2. 之後進入 `project-archive`。
