// AI-Generate
# 程式碼與介面歸檔（Code Archive）

## 1. 歸檔資訊

| 欄位 | 內容 |
|------|------|
| 需求目錄 | `spec-syllable-repeater/requirements/syllable-practice-macos-v1.1_20260712/` |
| 歸檔時間 | 2026-07-16 11:00 |
| 涵蓋範圍 | macOS v1.1 增量：段落標籤（REQ-11）、單句分析（REQ-12）、切點增減（REQ-13）、雙向高亮（REQ-14）、自由排列（REQ-15/16）、ASR/切分雙抽層（REQ-17）、錄音單次比對（REQ-18）、顯示模式（REQ-19）、譯文搬移（REQ-20）、`.abopack v3` 四層匯出（REQ-21）、響應式佈局（REQ-10） |
| 關聯需求檔案 | `requirement/requirement.md`（v1.1-r7） |
| 關聯設計檔案 | `design/backend-design.md` / `design/frontend-design.md` |
| 關聯任務拆分 | `task/task-split.md`（115 項全數完成）＋`task/execution-log.md` |
| 關聯審查 | `review/code-review-report.md`（第 2 輪，0 blocking）＋`review/code-review-report-r3-independent.md`（獨立複核，透過） |
| 知識庫專案路徑 | `spec-syllable-repeater/knowledge/code/syllable-repeater/` |
| 版控落點 | commits `043f92c`～`2d113f9`（2026-07-16 分七批入版控） |

本輪歸檔在 task-split 115/115 完成、兩份 guardrails matrix 全 IMPLEMENTED、三輪審查（含獨立複核）通過、使用者明示「真人驗收 OK」後建立。本專案是純本機 macOS App，無 server deployment；發版驗收對象為 Release `.app`（x86_64、ad-hoc 簽章）、bundled sidecar 與 Core CI gate。

## 2. 需求與範圍摘要

### 2.1 需求概述

v1.1 在 v1「單句音檔→音節疊加練習」基礎上補齊完整製課流程：多句音檔先在「段落標籤」頁切段（`.abolabel` 可存可載），送單句分析後可增刪音節切點與改字，再以「自由排列」把音節積木組成自訂練習單元（`.abopack v3` 可整包封裝、四層選擇匯出）。同時建立 ASR／音節切分雙抽層（M13/M14 語言路由 fail-closed）、真實進度與就緒語意（M15）、錄音最短生命週期（M10 r7：撤回 RecordingBuffer，只留目前單元記憶體 PCM）。

### 2.2 需求項對照

| 序號 | 需求項 | 模組 | 優先級 | 設計/任務拆分中的對應章節 |
|------|--------|------|--------|---------------------------|
| 1 | REQ-10 視窗自適應與響應式佈局 | shared/shell | P0 | frontend 功能點 9；task FP9.1-9.2 |
| 2 | REQ-11 段落標籤與 `.abolabel` | SegmentEngine / LabelPackEngine / labeling UI | P0 | backend 介面 20-23；frontend 功能點 10；task 3.1-3.6、FP10.1-10.4 |
| 3 | REQ-12 匯入與分析改為單句模式 | AnalysisPipeline / import UI | P0 | backend 介面 35-36；frontend 功能點 11；task 9.2-9.3、FP11.1-11.3 |
| 4 | REQ-13 音節切點增減校正 | AlignmentEngine / editor UI | P0 | backend 介面 24-26；frontend 功能點 12；task 4.1-4.4、FP12.1-12.3 |
| 5 | REQ-14 波形↔文字雙向高亮 | editor UI | P1 | frontend 功能點 12；task FP17 |
| 6 | REQ-15 練習內容自由編輯區 | PracticeEngine / arrangement UI | P0 | backend 介面 27-29；frontend 功能點 13；task 5.1-5.7、FP13.1-13.3、S9-21/23 |
| 7 | REQ-16 句尾疊加區顯示自訂排列 | PracticeEngine.effectiveUnits / practice UI | P1 | backend 介面 30；frontend 功能點 14；task 5.5-5.6、FP14.1-14.2 |
| 8 | REQ-17 ASR 抽換與多語言基礎 | Transcriber/Syllabifier Registry | P1 | backend 介面 31；task 2.1-2.5、8.1 |
| 9 | REQ-18 錄音單次比對與效能 | RecordingComparator / practice UI | P0 | backend 介面 32-33；frontend 功能點 15；task 9.4、10.6、S9-20 |
| 10 | REQ-19 字稿／譯文顯示切換 | SettingsService / practice UI | P2 | backend 介面 34；frontend 功能點 16；task 7.1、FP16.1-16.2 |
| 11 | REQ-20 手動譯文編輯區搬移 | import UI | P2 | frontend 功能點 11；task FP11.3 |
| 12 | REQ-21 `.abopack v3` 與四層匯出 | CourseBundleEngine / PracticeExportPlanner | P0 | backend 介面 37-38；frontend 功能點 17；task 10.1-10.10 |

## 3. 實作路徑（前後端）

### 3.1 後端實作路徑摘要

| 模組 | 主要實作 | 驗證重點 |
|------|----------|----------|
| Labeling（新） | `Segment`（不可變、三態 disposition）、`LabelSession`（dirty 狀態機＋undo）、`SegmentEngine.openAudio`（階段事件、SHA-256 指紋、ASR 失敗降級空 session＋warning）、`LabelPackEngine`（`.abolabel` v2 原子寫入／全檔驗證／指紋比對） | AT-11 系列；損毀零副作用；dirty 攔截 |
| 雙抽層 Registry（新） | `TranscriberEngine`／`Syllabifier` Domain ports、`TranscriberRegistry`／`SyllabifierRegistry`（fail-closed）、`EnglishSyllabifier`（包裝 v1 AlignmentEngine） | AT-17 系列；查無語言拋 `ERR_LANGUAGE_UNSUPPORTED` 附支援清單；金標準 11 音節不變 |
| Alignment 擴充 | `removeBoundary`／`insertBoundary`（required PCM ±10ms 零交越吸附、50ms 下限）／`updateSyllableText`（`originalText` 保留、空值 `needsReview`） | AT-13 系列；M11 步數＝當時音節總數（AT-13-07） |
| Arrangement（新） | `PracticeBlock`（預設 1／1.0）／`PracticeRow`（預設 3／1.0）／`PracticeArrangement`（綁單一 lessonId、markStale）、`generateArrangement`、`renderBlockRow`（原聲唯一渲染路徑）、`effectiveUnits`（M12 唯一判定入口）、`renderSinglePassReference`（錄音單次參考） | AT-15/16 系列；M1 補述雙軌、M3 r6 靜音規則、跨 Lesson `ArgumentError` 拒絕 |
| CourseBundle（新） | `CourseBundleEngine`（`.abopack` v3 讀寫、v1/v2 相容路由、欄位白名單）、`PracticeExportPlan`／Planner（fingerprint/lessonId/range fail-closed 四層匯出） | AT-21 系列；portable projection 無顯示偏好／路徑／錄音 |
| 真實進度（新） | `AudioImportReader` port＋`AudioImportProgress`／`LabelOpenProgress` 階段事件、`DraftLessonIdentity`（分析成功建立一次、全程沿用） | M15；移除假百分比；ready 只在 byte／格式／時長全驗證後 |
| M10 r7 | 撤回 `RecordingBufferService`／`Store`／`Entry` 與 `ERR_BUFFER_STASH_FAILED`（零殘留）；`RecordingComparator` finally 清除不變 | 全庫 grep 零命中；DB/pack/progress 負向掃描測試 |
| Infra | `V3__v11_label_registry.sql`＋`DriftLabelRegistryRepository`、`DriftSettingsService`、`DartIoAudioImportReader`、`ManagedTempSession`（lease 鎖）、Whisper adapter 對齊新 port、Demucs 改 44.1kHz stereo 直取原始檔 | schema 防線斷言無音訊欄位；temp 白名單清掃；sidecar 仍僅本地 ProcessRunner |

### 3.2 前端實作路徑摘要

| 功能點 | 實作位置 | 摘要 |
|--------|----------|------|
| 響應式殼層 | `shared/responsive_layout.dart`、`shell/app_shell.dart` | 1280px 斷點雙欄／堆疊、1100×700 最小內容、兩軸捲動、切頁狀態保留 |
| 段落標籤 | `features/labeling/`（screen/controller/full_track_waveform/segment_list） | 真實階段進度、標籤線拖曳／增刪、原音段落試聽、`.abolabel` 儲存／載入／dirty 三選一、送單句分析 |
| 單句分析 | `features/import_analysis/`＋`shared/pending_segment.dart` | 直接匯入與 pending Segment 雙入口、逐 byte 就緒、來源徽章、手動／AI 譯文群組（自設定頁搬入）、TTS 零入口 |
| 段落校正 | `features/editor/`＋`prosody_analysis_runner.dart`、`waveform_node_range.dart` | 切點＋／×手勢、chip 雙擊改字、時間範圍選取雙向黃色高亮、序號重排、prosody isolate 背景計算 |
| 自由排列 | `features/arrangement/`（controller/section/row/block_config_menu） | 一鍵生成 N 列、同列長按排序／成組／組內排序、來源段落點選插入、雙擊集中設定（repeat 1–10、silence 0–20/0.5、reset）、列預覽、獨立 undo、stale banner |
| 疊加練習 | `features/practice/` | effectiveUnits 單元目錄、hidden 只留編號、四態顯示切換（每 Lesson 儲存）、錄音單次參考、目前單元記憶體 PCM 回放／停止／刪除、audio_session 錄播分離 |
| 匯出 | `features/export/` | 四層選擇（音訊來源／排列來源／單元範圍／設定覆寫）、相容排列候選過濾 |
| 課件庫 | `features/library/` | `.abopack` v3 開啟服務、v1/v2 相容 |

## 4. 介面與契約（以後端為權威）

### 4.1 介面清單（Domain 介面 20-38，續 v1 的 1-19）

本專案無自家 HTTP API；以下為 Domain 層契約（`DomainException(code, message)` 錯誤模型）：

| 介面 | 簽名要點 | 錯誤/防線要點 | 設計依據 |
|------|----------|---------------|----------|
| 20 `SegmentEngine.openAudio` | path、separateVocals、onProgress → `LabelOpenResult`（session＋波形＋warning?） | 雙 Registry 前置 fail-closed；ASR 失敗回空 session＋`ERR_TRANSCRIBE_FAILED` warning；階段事件單調真實 | backend §3.2.1 |
| 21 `LabelSession` 聚合操作 | move/insert/removeBoundary、markKept/markDiscarded、undo、dirty | 單調不重疊、500ms 兩側；僅剩一段沿用 `ERR_BOUNDARY_INVALID`（OQ-4 裁決） | backend §3.2.1 |
| 22/23 `LabelPackEngine.writeLabel/readLabel` | `.abolabel` v2（zip 內 label.json） | temp→rename 原子寫入→registry upsert→markSaved；讀取全檔驗證，損毀 `ERR_LABEL_CORRUPTED`、指紋不符 `ERR_LABEL_FINGERPRINT_MISMATCH` | backend §3.2.1 |
| 24/25/26 `AlignmentEngine.removeBoundary/insertBoundary/updateSyllableText` | insertBoundary 帶 required `Pcm`（Task 4.1 裁決） | 至少 1 音節（`ERR_SYLLABLE_MIN_COUNT`）；50ms 下限（`ERR_BOUNDARY_TOO_CLOSE`）；±10ms 零交越吸附 | backend §3.2.2 |
| 27 `PracticeEngine.generateArrangement` | syllables＋required lessonId（DFT-06 裁決） | 依 M2 生成 N 列句尾疊加 | backend §3.2.3 |
| 28 `PracticeArrangement` 聚合操作 | 插刪列、放置／移動／成組／組內排序、setBlockConfig、resetBlockConfig、markStale、獨立 undo | 全部回傳新 immutable 快照；跨 Lesson 修改前 `ArgumentError` 拒絕（#47）；config 越界 `ERR_BLOCK_CONFIG_OUT_OF_RANGE` | backend §3.2.3 |
| 29 `PracticeEngine.renderBlockRow` | row＋originalPcm → 渲染 PCM | 唯一渲染路徑；逐 sample 來自原 PCM＋數位零；M3 r6 規則 | backend §3.2.3 |
| 30 `PracticeEngine.effectiveUnits` | lesson → `PracticeUnits`（auto/custom sealed） | M12 唯一判定入口：0 列→完整單句 1 單元、N 列→N 單元；stale 透傳 | backend §3.2.3 |
| 31 `TranscriberRegistry/SyllabifierRegistry.resolve` | language → engine | 查無拋 `ERR_LANGUAGE_UNSUPPORTED` 附已註冊清單；兩表皆過才建課件（M14） | backend §3.2.4 |
| 32 `PracticeEngine.renderSinglePassReference` | 單元 → 單次參考音 | 只播來源一次、不含 repeat/silence | backend §3.2.5 |
| 33 `RecordingComparator.compare` | 沿 v1；比對運算移 isolate、每圖 ≤1000 點（首尾＋分桶 min/max） | finally 清除不變；不接路徑欄位 | backend §3.2.5 |
| 34 `SettingsService.transcriptDisplayMode` | per-lessonId 讀寫四態 enum | 缺 key 預設 transcript；隨 `.aboprogress` 匯出匯入、不進 `.abopack` | backend §3.2.7 |
| 35 `AudioImportReader.readAndValidate` | path → byte 事件流＋ready | 非空→格式→時長全過才 ready（M15） | backend §3.2.7 |
| 36 `DraftLessonIdentity` | 分析成功建立一次 | editor/arrangement/save 全程沿用；不得保存時另產 id（#53） | backend §3.2.7 |
| 37 `CourseBundleEngine.writeV3/read` | CourseBundle（schemaVersion 3） | 欄位白名單；v1/v2/v3 路由；音訊 ref 必須對上 originalAudio fingerprint 且 range 在界內 | backend §3.2.6 |
| 38 `PracticeExportPlanner.build` | 四層選擇 → immutable `PracticeExportPlan` | 型別綁 fingerprint/lessonId/range，構造時拒絕不一致（#61） | backend §3.2.6 |

### 4.2 與知識庫 `backend-interface` 的對照

| 本需求介面 | 分冊檔案/項目 | 變更型別 |
|------------|---------------|----------|
| Domain ports（TranscriberEngine/Syllabifier/LabelRegistryRepository/SettingsService/AudioImportReader） | `backend-interface.md` Domain ports 節 | 新增 5 個 port |
| DriftLabelRegistryRepository/DriftSettingsService | `backend-interface.md` Drift repository adapter | 新增 2 個 adapter |
| Whisper segment 能力、Demucs stereo 輸入 | `backend-interface.md` Sidecar CLI contracts | 修改 2 行 |
| Riverpod 新 provider（labeling/arrangement/pending segment/recording 等） | `backend-interface.md` provider entrypoints | 新增行 |
| OpenAI Responses API、release packaging contracts | 同左 | 不變 |

### 4.3 interface-detail 追溯

同 v1：本專案無 REST Controller，未生成 `interface-detail/` 分冊。契約集中於 `backend-interface.md`、backend-design 介面 1-38 與對應測試（AT 編號雙向可追）。

## 5. 資料與儲存

### 5.1 表結構/欄位變更摘要

| 表名 | 變更型別 | 說明 | 依據 |
|------|----------|------|------|
| `label_registry` | **新增（V3 migration）** | 四欄：`audio_fingerprint`（PK，SHA-256）、`label_path`、`segment_count`、`updated_at`；供重匯入提醒；明確斷言無音訊/錄音/blob 欄位 | backend §3.1.2；task 3.5 |
| 既有 6 張表 | 不變 | V2→V3 migration 只新增 label_registry，舊資料保留有測試 | task 3.5 |
| RecordingBuffer 表 | **不存在（r7 撤回）** | 曾規劃後撤回；db_schema_test 遞迴掃描所有表名／欄位確認 | requirement M10 r7 |

**檔案格式變更**：

| 格式 | 版本 | 說明 |
|------|------|------|
| `.abolabel` | v2（讀相容 v1） | zip 內 label.json：fingerprint、language、separateVocals、segments（含三態 disposition）；全檔驗證後套用 |
| `.abopack` | v3（讀相容 v1/v2） | CourseBundle：originalAudio 必填＋labels/sentenceLesson/arrangement/latestProgress 可選；v2 加 language/arrangement；contentHash 仍只依原音＋音節 |
| `.aboprogress` | 欄位增量 | 新增 `progress.transcriptDisplayModes`（Map<lessonId, mode>）；舊檔缺欄相容 |

### 5.2 與 `backend-database.md` 的對照

`backend-database.md` 已於本輪融合更新：新增 `label_registry` 表結構、V3 migration 說明與 ER 關係；其餘 6 張表口徑不變。資料防線由 `db_schema_test.dart`（含 v1.1 擴充的全表遞迴掃描）與 Core CI 維持。

## 6. 前端程式碼與工程側

### 6.1 目錄/路由/元件變更摘要

| 型別 | 路徑或名稱 | 說明 | 依據 |
|------|------------|------|------|
| 新增頁面 | `features/labeling/`（＋NavigationRail「段落標籤」項） | 段落標籤主畫面、全軌波形、區段清單 | 功能點 10 |
| 新增區域 | `features/arrangement/` | 自由排列區（掛在段落校正頁音節 chip 下方） | 功能點 13 |
| 新增共用 | `shared/responsive_layout.dart`、`shared/pending_segment.dart`、`shared/infra/segment_engine_factory.dart` | 響應式容器、跨頁單一交接槽位、SegmentEngine 注入 | 功能點 9/11 |
| 新增 editor 輔助 | `features/editor/prosody_analysis_runner.dart`、`waveform_node_range.dart` | prosody isolate 背景計算、波形節點區間 | S9-22 |
| 修改 | editor/import/practice/export/library/progress 各 screen 與 controller | 見 §3.2 | 功能點 11-17 |
| 依賴 | `app/pubspec.yaml`：`audio_session ^0.2.4` 轉直接依賴 | 錄音／播放 session 分離 | task 9.4 |

### 6.2 `frontend-project.md` 增量說明

| 章節 | 是否更新 | 摘要 |
|------|----------|------|
| 業務功能模組 | 是 | 新增 labeling／arrangement 模組；import/editor/practice 職責更新（單句模式、切點增減、單元模式、錄音回放） |
| 介面呼叫清單 | 否 | 無新增 HTTP provider（AI 翻譯仍為唯一遠端呼叫） |
| 目錄結構說明 | 是 | 補 labeling/、arrangement/、responsive_layout、pending_segment 等 |
| 技術堆疊 | 是 | 補 audio_session 直接依賴 |

## 7. 實際實作內容（版控追溯）

實作以 7 個 commit 分批入版控（2026-07-16）：

| Commit | 範圍 | 檔數/行數 |
|--------|------|-----------|
| `043f92c` | .gitignore（crash log／diagnostics 排除） | 1 檔 +4 |
| `1fd9654` | v1.1 spec 全案（需求/設計/matrix/task/release/review） | 20 檔 +2,625 |
| `f4459db` | Domain 層（19 新檔＋擴充；188 測試） | 51 檔 +6,906 |
| `add8180` | Infra 層（V3 migration、5 新 adapter/服務） | 26 檔 +2,106 |
| `49a4c48` | Flutter App 層（labeling/arrangement 新模組等） | 69 檔 +13,567 |
| `f0df54f` | scripts 授權 gate＋codex commands | 3 檔 +27 |
| `2d113f9` | 專案記憶卡＋prompt-lab | 14 檔 +256 |

新增/修改檔案細目見各 commit diff 與 `task/execution-log.md` 逐任務「產物」欄。

## 8. 驗證與發版證據（部署驗收檢查）

### 8.1 自動化證據（S10 最終報告，2026-07-16）

| 項目 | 結果 |
|------|------|
| Domain 測試 | 188/188 PASS |
| Infra 測試 | 59＋35 PASS＋1 條件式 skip；真 FFmpeg 以 Release 內建重跑 8/8 PASS |
| App 測試 | 190/190 PASS（五批拆批） |
| `flutter analyze` | No issues |
| v1 guardrails（37 項） | checker PASS |
| v1.1 guardrails（25 項） | checker PASS：25 IMPLEMENTED、0 PARTIAL、0 BLOCKED |
| 授權 manifest | 25 components PASS；Python release/license 測試 23/23 |
| Intel benchmark | i5-8259U、10 秒音訊 4.132s（回歸上限 4.924s、需求上限 60s） |
| Release build | `flutter build macos --release` 成功；`du` 606MB（sidecar/模型 581MB） |
| codesign | `--verify --deep --strict` PASS（ad-hoc 深層重簽；`app-sandbox=false`、麥克風 true、x86_64） |
| 內建 FFmpeg | 8.1.2 shared、`--disable-gpl --disable-nonfree` |

### 8.2 部署驗收檢查表（步驟 5.5）

| # | 檢查項 | 結果 |
|---|--------|------|
| 1 | 型別檢查／編譯通過 | ✅ flutter analyze No issues |
| 2 | build 通過 | ✅ Release build 成功 |
| 3 | 本機執行正常 | ✅ `open -n` 啟動＋真人驗收 |
| 4 | Preview／測試環境正常 | 不適用（純本機 App，無測試環境） |
| 5 | Production 部署最新版本 | 不適用（無伺服器）；v1.1 未重打 unsigned zip，`[需人工確認]` 是否需要對外散布用 zip |
| 6 | 使用者流程端到端走得通 | ✅ 使用者明示「真人驗收 OK」（2026-07-15/16：Finder 目視、觸控板／滑鼠手勢、段落播放、波形、真人麥克風） |
| 7 | 資料正確出現 | ✅ 真機驗收含波形／播放／錄音回放 |
| 8 | UI 符合實際操作情境 | ✅ 同上；S9-20～23 實機回饋修正包已閉環 |
| 9 | hard-limits-matrix 檢查通過 | ✅ 無 NOT_REVIEWED、無未批准不適用項；25/25 IMPLEMENTED |

**結論**：部署驗收通過（兩項「不適用」均因純本機無伺服器架構）。`[監測規劃待補]`——下一階段 `ops-monitoring` 產出 `ops/monitoring-plan.md` 後解除。

## 9. 開放問題（實作側）

| 編號 | 問題 | 影響 | 狀態 |
|------|------|------|------|
| C-101 | v1.1 未重打 unsigned zip；`dist/` 內仍是 v1 產物 | 對外散布 v1.1 需重跑 `make_release_zip.py` | `[需人工確認]` 是否需要 |
| C-102 | `analysisRunnerProvider` 預設值為 `PreviewAnalysisRunner`（硬編假音節），正式入口靠 `main.dart` 覆蓋 | 未來新增入口忘記覆蓋會靜默顯示假結果（違 M15 精神） | 獨立複核 suggestion；建議預設改拋錯。`[可升級為通用經驗]`：「DI 預設值不得是靜默假實作，應拋錯讓漏接在啟動即爆」與技術棧無關 |
| C-103 | 本機殘留舊版未管理 temp 218MB＋舊練習 WAV cache 80MB（S9-22 診斷） | 佔磁碟；新 ManagedTempSession 架構已阻止後續累積 | 待使用者關閉所有 App 後批准一次性清理 |
| C-104 | 環境單次 30 秒上限使 `ci_core_checks.sh` 無法單條跑完，僅同源拆批 | GitHub Actions 遠端 CI 不受此限 | 記錄事實，無待辦 |

## 10. 知識庫融合檢查

| 檢查項 | 目標檔案 | 檢查結果 |
|--------|----------|----------|
| 應用層知識已融合 | `knowledge/application/application-overview.md` | 已更新（新呼叫鏈／例外／發布型態） |
| 業務層知識已融合 | `knowledge/business/business-overview.md` | 已更新（新核心規則／流程／範圍） |
| 前端專案檔案已融合 | `frontend-project.md` | 已更新（模組／目錄／依賴） |
| 後端專案檔案已融合 | `backend-project.md` | 已更新（分層／模組／業務規則 M11-M15） |
| 介面清單已融合 | `backend-interface.md` | 已更新（新 ports/adapters/providers） |
| 資料模型已融合 | `backend-database.md` | 已更新（label_registry V3） |
| 外部依賴已融合 | `backend-external-dependency.md` | 已更新（audio_session、FFmpeg 8.1.2 快照） |
