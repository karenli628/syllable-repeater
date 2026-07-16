// AI-Generate
# 執行日誌 — Syllable Repeater macOS v1.1 implementation

> 對應任務清單：`task-split.md`；任務狀態流轉 Pending → InProgress → Done / Failed。

## 執行概覽

- **開始時間**：2026-07-13
- **目前切片**：S9-22／段落校正效能、兩層捲動與 session 暫存生命週期（程式與自動驗證完成；待 Finder 人工驗收）
- **環境**：macOS／Intel i5-8259U／Flutter 3.44.4／Dart 3.12.2
- **說明**：S0～S8 既有基線保留；使用者 2026-07-14 明示批准最終完整變更包，已完成 requirement r5、backend/frontend design、task-split S9 與 matrix #42/#43/#51～#53 同步，並已依要求先通知再啟用 `fullstack-code-implementation`。

## 任務執行記錄

### Task 1.2 建立 v1 行為特徵基線與金標準不變性測試

- **狀態**：Done（2026-07-13）
- **產物**：
  - `packages/domain/test/alignment_engine_test.dart`：AT-17-01 明確鎖定 11 音節、10 個連續切點、完整時間戳。
  - `packages/domain/test/analysis_pipeline_test.dart`：AT-17-01 鎖定 pipeline 輸出的金標準時間戳。
  - `packages/infra/bin/benchmark_alignment_pipeline.dart`：保留 v1 Q10 4.689s 基準與可複製重跑指令輸出。
- **驗證**：
  - `flutter test packages/domain/test/alignment_engine_test.dart packages/domain/test/analysis_pipeline_test.dart`：12/12 PASS。
  - `dart run bin/benchmark_alignment_pipeline.dart`（工作目錄 `packages/infra`）：10,000ms 音檔、Intel i5-8259U、elapsed 4.397s、syllableCount 22、waveformPeaks 32、status PASS；v1 baseline 4.689s。
- **核心證據**：既有 `practice_build_steps_test.dart` 已鎖定 11 步與第 2 步 `tion skills`；本次新增基線測試補齊 10 切點與時間戳。

## 問題記錄

- **OQ-1 已有既存裁決證據**：`requirement/requirement.md` v1.1-r1 修訂歷史（2026-07-12，作者 Karen）、REQ-18 與 `backend-design.md` §3.2.5 均明載 TTL 10 分鐘、不曝露設定頁、手動刪除與切步即清；因此這不是本 session 新猜測，待依變更防線同步修正仍殘留的 30 分鐘總表／matrix 文字。
- **OQ-1 本次確認**：使用者再次回覆「以10分鐘為基準」；已將核心驗收總表、Q5 與 matrix #43 的邊界同步為 9:59／10:01。
- **OQ-2 已裁決**：使用者 2026-07-13 回覆「隨 .aboprogress 匯出／匯入」；已將 requirement v1.1-r2、backend-design §1.5/§3.2.6、frontend-design 功能點 16 與 task-split DFT-05 同步，預定由 7.1／FP16.2 實作 `progress.transcriptDisplayModes`。
- **OQ-4 已裁決**：使用者 2026-07-13 指定 `LabelSession` 僅剩一段時沿用 `ERR_BOUNDARY_INVALID`；已補 backend-design 介面 21、REQ-11 AT-11-09、frontend error mapping 與 task-split DFT-08，不新增第 9 個錯誤碼。
- **OQ-5 已裁決**：使用者 2026-07-13 指定 ASR 切段失敗時「回傳正常結果＋警告」；已新增 `LabelOpenWarning` 契約，`LabelOpenResult` 回傳空 session、已解碼波形與 `ERR_TRANSCRIBE_FAILED` warning，只有無法安全建立工作階段的失敗才拋例外。
- **OQ-6 已裁決**：使用者 2026-07-13 批准新增 `LabelRegistryRepository` Domain port；backend-design 已補 `LabelRegistryRecord`、`findByFingerprint`／`upsert` 與 Drift adapter 邊界，維持 M5 Domain 純度。
- **OQ-3 已有設計契約**：`backend-design.md` §3.1.1 明定 `PracticeArrangement` 綁定單一 `lessonId`，`PracticeBlock` 無跨檔參照欄位；可作為 #47 的型別不變式，但仍需補可執行測試。
- **OQ-7 屬允許實作時實測的開放項**：設計 O1/Q1 明定 800ms 可依代表性 fixture 調整，不阻塞骨架。
- **後續確認規則**：OQ-8 的 `[必須確認]` 動作仍在各切片逐項取得批准；目前 2.1 為 `[可直接做]`。

### Task 1.1 變更防線七題（Done；2026-07-13）

| 題號 | 判定 | 事實依據／下一步 |
|---|---|---|
| 1. 會破壞核心流程嗎？ | 是（若默默選邊） | TTL、語言拒絕、錄音暫存與跨 Lesson 防線都屬核心；先取得 OQ 裁決。 |
| 2. 會造成資料不一致嗎？ | 是 | requirement、design、matrix 存在 DFT-01～DFT-09 漂移；需同步修正文／程式／測試。 |
| 3. 會讓權限變得不清楚嗎？ | 否 | 本輪是單機單人；仍需保留使用者對高風險刪除／schema 變更的明示批准。 |
| 4. 會讓外部服務影響核心規則嗎？ | 否 | ASR 只准本地 sidecar；新 port／adapter 不改核心演算法。 |
| 5. 需要新增測試嗎？ | 是 | 已先完成 1.2～1.4 基線、錯誤碼與 policy 測試；DFT 裁決後仍需對應切片測試。 |
| 6. 需要更新需求成稿嗎？ | 是 | DFT-01～DFT-05 需要需求／驗收／matrix 同步；等待使用者確認。 |
| 7. 需要調整架構嗎？ | 是 | DFT-06～DFT-09 涉及 Arrangement 型別、ASR 降級契約、錯誤碼與 label repository port；等待裁決後才實作。 |

**完成證據**：OQ-1～OQ-7 均有既存設計／需求證據或使用者裁決；OQ-8 為逐任務批准規則。DFT-01～DFT-09 已全數同步；`git diff --check`、v1.1 `check_guardrails.py`、`check_handoff.py --latest` 均 PASS。

### Task 1.3 三同步新增 8 個 v1.1 錯誤碼與 UI 文案

- **狀態**：Done（2026-07-13）
- **產物**：`packages/domain/lib/src/errors.dart`、`app/lib/shared/error/error_messages.dart`、`packages/domain/test/model_test.dart`、`app/test/shared/error_messages_test.dart`。
- **驗證**：Domain 完整集合 27 碼且無重複；App 27 碼映射測試通過；`widget_test.dart` 的映射數斷言更新為 27。
- **範圍控制**：僅新增 backend-design §3.2.8 已定義的 8 碼；DFT-08 的第 9 個候選錯誤碼未擅自新增。

### Task 1.4 擴充 Domain 純度、TTS 黑名單與本地 ASR policy 測試

- **狀態**：Done（2026-07-13）
- **產物**：`packages/domain/test/transcriber_policy_test.dart`；既有 `domain_purity_test.dart` 以遞迴掃描涵蓋後續新增的 Domain port。
- **驗證**：TTS workspace 依賴黑名單與 Transcriber Domain 禁 HTTP／URL 掃描 2/2 PASS。
- **TDD 邊界**：測試先鎖定負向條件；未放寬既有 Domain purity 防線。

## 檔案清單（本次新增／修改）

- 修改：`packages/domain/test/alignment_engine_test.dart`
- 修改：`packages/domain/test/analysis_pipeline_test.dart`
- 修改：`packages/infra/bin/benchmark_alignment_pipeline.dart`
- 修改：`task/task-split.md`
- 新增：`task/execution-log.md`
- 修改：`packages/domain/lib/src/errors.dart`
- 修改：`app/lib/shared/error/error_messages.dart`
- 修改：`packages/domain/test/model_test.dart`
- 新增：`app/test/shared/error_messages_test.dart`
- 修改：`app/test/widget_test.dart`
- 新增：`packages/domain/test/transcriber_policy_test.dart`

### Task 2.1 雙 Registry fail-closed 與金標準契約紅測試

- **狀態**：Done（2026-07-13）
- **產物**：`packages/domain/test/transcriber_registry_test.dart`、`packages/domain/test/syllabifier_registry_test.dart`。
- **紅燈證據**：首次執行時因 `TranscriberEngine`、`Segment`、兩個 Registry 與 `EnglishSyllabifier` 尚不存在而編譯失敗（exit 1）；確認測試先於 production 實作。
- **契約範圍**：en 放行、ja 缺切分器拒絕、部分支援仍拒、錯誤列出 en、公開語言集合不可變，以及金標準仍為 11 音節。

### Task 2.2 TranscriberEngine／Syllabifier ports、Registries 與 EnglishSyllabifier

- **狀態**：Done（2026-07-13）
- **產物**：新增兩個 Domain port、雙 Registry、`EnglishSyllabifier` 與公開 exports；因 `TranscriberEngine.segment()` 的編譯期型別依賴，提前建立 task 3.2 原訂的不可變 `Segment` 基礎模型，未提前實作 LabelSession 或 SegmentEngine。
- **核心行為**：兩個 Registry 皆採明確語言註冊與 fail-closed；查無時回 `ERR_LANGUAGE_UNSUPPORTED` 並列出已註冊語言；英文切分先包裝既有 `AlignmentEngine`，未搬動 v1 演算法。
- **驗證**：2.1 測試與既有 AlignmentEngine 測試 9/9 PASS；完整 Domain 測試 90/90 PASS（含 purity／policy）；`flutter analyze packages/domain` 無問題。
- **範圍控制**：未新增網路欄位、線上 API、模型下載或非英文切分器。

### Task 2.3 AnalysisPipeline 雙 Registry 前置檢查

- **狀態**：Done（2026-07-13）
- **產物**：`ImportRequest.language`（預設 en）；`AnalysisPipeline` 改由 `TranscriberRegistry`／`SyllabifierRegistry` 注入，並以新 ports 完成轉寫與逐字切分。
- **驗證**：AT-17-01 金標準時間戳不變；AT-17-02／03 的 ja 無支援與部分支援皆回 `ERR_LANGUAGE_UNSUPPORTED`，decoder 呼叫 0 次，證明副作用前 fail-closed。

### Task 2.4 Whisper 本地 adapter 與 segment 級時間戳

- **狀態**：Done（2026-07-13）
- **產物**：`WhisperAnalysisTranscriber` 對齊 `TranscriberEngine`；PCM 先包 WAV 再經 FFmpeg 16k mono；`WhisperJsonParser.parseSegments` 讀取既有 JSON segment offsets；app／benchmark／integration 接線改為雙 Registry。
- **驗證**：segment parser／adapter／sidecar mapping 測試全綠；完整 Domain＋infra 169 PASS、1 項環境條件 skip；全專案 `flutter analyze` 無問題。
- **硬限制**：仍只經本地 `ProcessRunner`；Intel 路徑保留 FFmpeg 16k mono 與 `--no-gpu`；未新增 HTTP client、URL 欄位或模型下載。

### Task 2.5 S1 端到端與效能回歸

- **狀態**：Done（2026-07-13）
- **真檔 e2e**：`flutter test app/test/e2e_pipeline_test.dart` PASS；真 sidecar 由 provider→controller→新 Registry pipeline→UI／Editor，金標準顯示 11 音節。
- **效能**：Intel i5-8259U、10 秒音檔，v1.1 4.189s；v1 基線 4.689s；5% 上限 4.924s，PASS；syllableCount 22、waveformPeaks 32。
- **里程碑**：S1 最薄端到端完成，切換新抽層未改變金標準輸出。

### Task 3.1 Segment／LabelSession 不變式與 dirty 狀態機紅測試

- **狀態**：Done（2026-07-13）
- **紅燈證據**：首次執行因 `LabelSession`、`LabelOpenResult`、`LabelOpenWarning` 尚不存在而編譯失敗（exit 1）。
- **契約範圍**：單調不重疊、音檔範圍、500ms 兩側、移動／插入／合併、undo、dirty→saved、最後一段沿用 `ERR_BOUNDARY_INVALID`、ASR 降級結果。

### Task 3.2 Segment、LabelSession 與 SegmentEngine

- **狀態**：Done（2026-07-13）
- **產物**：不可變 `Segment`、帶 undo 的 `LabelSession`、`SegmentEngine.openAudio`、`LabelOpenResult`／`LabelOpenWarning`；依 OQ-6 提前建立 `LabelRegistryRepository` port 供 openAudio 查詢提示。
- **核心行為**：雙 Registry 在讀檔前 fail-closed；SHA-256 指紋；可選分離失敗降級原音；ASR 失敗回正常空 session＋固定 `ERR_TRANSCRIBE_FAILED` 警告；共用重入鎖。
- **驗證**：LabelSession／SegmentEngine／policy／purity 15/15 PASS；完整 Domain 102/102 PASS；`flutter analyze packages/domain` 無問題。

### Task 3.3 `.abolabel` round-trip／損毀／指紋不符紅測試

- **狀態**：Done（2026-07-13）
- **紅燈證據**：首次執行因 `LabelPackEngine` 與 session 分離開關尚不存在而編譯失敗（exit 1）。
- **契約範圍**：schemaVersion、language、separateVocals、segments、全檔重疊驗證、損毀零副作用、指紋 mismatch、原子寫入失敗不 markSaved／不 upsert。

### Task 3.4 LabelPackEngine 與 label registry Domain port

- **狀態**：Done（2026-07-13）
- **產物**：`LabelPackEngine`、`LabelRegistryRepository`／`LabelRegistryRecord`、`LabelSession.separateVocals`；`.abolabel` 僅含 `label.json`。
- **寫入順序**：`writeBytesAtomic` 成功→repository upsert 成功→`markSaved()`；任一步失敗不會誤標 CLEAN。
- **讀取防線**：全 zip／schema／欄位／Segment 不變式先驗證；損毀回 `ERR_LABEL_CORRUPTED`，完整有效後才檢查指紋並回 `ERR_LABEL_FINGERPRINT_MISMATCH`。
- **驗證**：LabelPack／LabelSession／purity targeted 18/18 PASS；`flutter analyze packages/domain` 無問題。

### Task 3.5 Drift V3 label_registry schema 與結構防線

- **狀態**：Done（2026-07-13；使用者明示批准後動工）
- **紅燈證據**：production 實作前，三項測試分別因缺少第七張表、四欄結構與 V2→V3 migration 而失敗（exit 1）。
- **產物**：新增 `V3__v11_label_registry.sql`；`AppDatabase.schemaVersion` 升到 3；migration 只新增 `label_registry`；generated code 由 build_runner 產生。
- **結構防線**：固定 `audio_fingerprint`、`label_path`、`segment_count`、`updated_at` 四欄，以指紋為主鍵；明確斷言沒有 audio bytes／PCM／recording／blob 欄位；未建立 RecordingBuffer 表、未修改既有表。
- **驗證**：schema／V2→V3 舊資料保留／repository adapter 目標測試 12/12 PASS；`flutter analyze packages/infra` 0 問題。

### Task 3.6 DriftLabelRegistryRepository 與標籤跨層整合

- **狀態**：Done（2026-07-13）
- **產物**：`DriftLabelRegistryRepository` 實作 fingerprint 查詢與主鍵 upsert；infra 公開 export；新增真檔案＋SQLite 的 `label_pack_integration_test.dart`。
- **整合行為**：`LabelPackEngine` 經 `AtomicFileIo` 原子寫出 `.abolabel`，再寫 Drift V3 索引，並可由索引路徑完整讀回；遺失檔案或損毀 zip 一律回 `ERR_LABEL_CORRUPTED`，既有 session 不被改動。
- **驗證**：S2 目標測試 15/15 PASS；完整 Domain 107/107 PASS；完整 infra 85 PASS、1 項因未指定 `FFMPEG_PATH` 正常 skip；`flutter analyze packages/infra` 0 問題。
- **範圍控制**：沒有雲端標籤庫、跨裝置索引、RecordingBuffer 表或音訊持久化欄位。

### Task 4.1 實作前介面缺口裁決

- **狀態**：Resolved（2026-07-13；使用者明示「批准」）
- **缺口**：原 `insertBoundary(r, syllableIndex, atMs)` 沒有 PCM，無法履行 REQ-13 要求的 ±10ms 零交越吸附。
- **變更防線**：七題中資料一致性、新增測試與架構介面為「是」；其餘為「否」。需求行為與範圍不變。
- **裁決**：介面新增 named required `Pcm pcm`；同步更新 backend/frontend design 與 Task 4.1 測試契約，不把 PCM 存入 `AlignmentResult`，避免跨音檔誤用。

### Task 4.1 AlignmentEngine 音節編輯紅測試

- **狀態**：Done（TDD-red，2026-07-13）
- **產物**：新增 `packages/domain/test/alignment_edit_test.dart`，覆蓋 AT-13-01～06、49/51ms 兩側、PCM 零交越、originalText 與四個不可變快照。
- **紅燈證據**：首次執行因 `AlignmentEngine` 尚無 `removeBoundary`、`insertBoundary`、`updateSyllableText` 而編譯失敗（exit 1）；production 實作尚未存在。

### Task 4.2 AlignmentEngine 增減／改字與模型佐證欄

- **狀態**：Done（2026-07-13）
- **產物**：`AlignmentEngine.removeBoundary`／`insertBoundary`／`updateSyllableText`；`Syllable.originalText` 與不可變 `copyWith`；`AlignmentResult.copyWith`。
- **核心行為**：刪除切點合併相鄰音節且至少保留 1 音節；插入切點使用使用者批准的 required PCM 做 ±10ms 零交越吸附，距兩端 <50ms 拒絕；改字保留第一次辨識原文，空白暫存強制 `needsReview=true`。
- **三同步補洞**：`Lesson.language` 依 M14 寫入 pack manifest，舊 v1 pack 缺欄位時預設 `en`；`originalText` 只在非 null 時序列化，維持未編輯舊 pack 的 contentHash 相容性。
- **驗證**：Task 4.1 targeted 26/26 PASS；完整 Domain 118/118 PASS；`flutter analyze packages/domain` 無問題。

### Task 4.3 編輯後步數與 M2 不變性防線

- **狀態**：Done（2026-07-13）
- **產物**：`practice_build_steps_test.dart` 新增 AT-13-07／AT-16-04，直接串接 `AlignmentEngine` 增減結果到 `PracticeEngine.buildSteps`。
- **驗證**：金標準刪 1 切點為 10 步、增 1 切點為 12 步；每個第 n 步逐一等於編輯後清單的句尾 suffix；第 2 步仍固定 `tion skills`。測試 10/10 PASS。
- **防線回寫**：v1.1 hard-limits-matrix #39 由 BLOCKED 轉 IMPLEMENTED；統計更新為 IMPLEMENTED 6、BLOCKED 3。

### Task 4.4 執行順序阻塞

- **狀態**：Blocked（2026-07-13；等待使用者裁決）
- **衝突**：Task 4.4 的檔案欄明訂 `PracticeArrangement`「由 5.2 新增」，依賴表也列 4.4 依賴 5.2；但 implementation skill 要求依任務編號循序完成。
- **建議裁決**：只調整施工順序為 `5.1 → 5.2 → 4.4`，不變更需求、功能、介面或驗收條件。
- **禁止偷跑**：未獲批准前不先建 production model，也不跳號執行。
- **解除**：使用者 2026-07-13 明示「批准調整順序」；依 `5.1 → 5.2 → 4.4` 執行，完成後回到 5.3。

### Task 5.1／5.2 lessonId 介面缺口

- **狀態**：Blocked（2026-07-13；等待使用者裁決）
- **缺口**：`PracticeArrangement` 按設計必須綁單一 `lessonId`，但介面 27 `generateArrangement(List<Syllable>)` 無 lessonId；`placeBlock` 也無來源課件資訊，無法執行 guardrails #47 的跨 Lesson 拒絕測試。
- **建議契約**：`generateArrangement` 新增 required `lessonId`；`placeBlock` 入口新增 required `sourceLessonId` 並與 Arrangement 比對，不符以 `ArgumentError` 拒絕；PracticeBlock 不持久化 lessonId／路徑／音訊。
- **變更防線**：七題中資料一致性、新增測試、架構介面為「是」；核心流程、權限、外部服務、需求範圍為「否」。未獲批准前不寫測試或 production 程式。
- **解除**：使用者 2026-07-13 回覆「批准」；前後端設計同步 required lessonId/sourceLessonId，Task 5.1 依此建立 #47 負向測試。

### Task 5.1 PracticeArrangement 操作與結構防線紅測試

- **狀態**：Done（TDD-red，2026-07-13）
- **產物**：新增 `packages/domain/test/practice_arrangement_test.dart`，覆蓋 AT-15-01～04/06/08 與 guardrails #47。
- **紅燈證據**：首次執行因 `PracticeArrangement`／`PracticeRow` 尚不存在、`PracticeEngine.generateArrangement` 尚未實作而編譯失敗（exit 1）；production 實作尚未存在。
- **契約鎖定**：金標準 11 列、不可變集合、插刪列、重複放置、移動、成組／組內排序、獨立 undo、repeatN 1–10、silenceFactor 0–5，以及跨 Lesson 注入以含雙方 lessonId 的 `ArgumentError` 拒絕。

### Task 5.2 PracticeArrangement 聚合模型與操作

- **狀態**：Done（2026-07-13）
- **產物**：新增 immutable `PracticeBlock`／`PracticeRow`／`PracticeArrangement`；`PracticeEngine.generateArrangement`；Domain export；`Lesson.arrangement` nullable 聚合關係。
- **核心行為**：依 M2 由 N 個音節生成 N 列句尾 suffix；集合皆不可修改；插刪列、重複放置、跨／同列移動、成組／解組／組內排序、設定與獨立 undo 都回傳新快照；時間由呼叫端傳入，不在 Domain 讀系統時鐘。
- **結構防線**：Arrangement 單一 `lessonId`；block 不保存 lessonId、音訊或路徑；跨 Lesson 在修改前拒絕。guardrails #47 轉 IMPLEMENTED。
- **驗證**：目標測試 16/16 PASS；完整 Domain 136/136 PASS；`dart analyze packages/domain` 0 問題；v1.1 `check_guardrails.py` PASS（IMPLEMENTED 7、PARTIAL 4、BLOCKED 2）。

### Task 4.4 音節總數變更與 Arrangement stale 協調

- **狀態**：Done（2026-07-13）
- **紅燈證據**：production 實作前，測試因缺少 `markStale`、EditorUiState arrangement 與三個協調入口而編譯失敗（exit 1）。
- **產物**：`PracticeArrangement.markStale`／`keepCurrentArrangement`；Editor state 載入並保存排列；`applySyllableEdit` 依總數差異協調 stale；明示保留與重新生成入口；儲存 draft 保留記憶體中的 arrangement。
- **不變性**：增減音節只置旗標，原 rows、blocks 與排列 undo 不動；邊界拖動等總數不變操作不誤標；只有明示保留或重新生成清旗標。
- **驗證**：Task 4.4 目標 30/30 PASS；完整 Domain 138/138 PASS；從正確 `app/` 目錄執行完整 App 79/79 PASS；`flutter analyze packages/domain app` 0 問題。首次從 workspace 根執行 App 測試的單一失敗是相對路徑啟動目錄錯誤，修正 cwd 後通過。

### Task 5.3 自訂排列渲染逐 sample 紅測試

- **狀態**：Done（TDD-red，2026-07-13）
- **產物**：新增 `practice_arrangement_render_test.dart`，以 `[itll, rain, itll+rain]` 鎖定自訂次數、600/700/1950ms 數位零靜音、非端點 sample 原音對應、原 PCM 不可回寫，以及播放採單一不可變列快照。
- **紅燈證據**：修正測試自身 const 語法後，唯一編譯失敗原因為 `PracticeEngine.renderBlockRow` 尚不存在（exit 1）；production 渲染實作尚未寫入。

### Task 5.4 renderBlockRow 原聲唯一渲染路徑

- **狀態**：Done（2026-07-13）
- **實作**：`renderBlockRow` 逐塊建立只含 sourceRanges 的 `PracticeStep`，重用既有 CT-01 保護的 `renderStep`，再依 repeatN 複製並以精確 sample 數加入數位零；整列只讀呼叫當下 immutable 快照。
- **M1/M3 證據**：`[itll, rain, itll+rain]` 的非端點 sample 逐段對應原 PCM；靜音為 600/700/1950ms 全零；原 PCM 不被修改；排列在 Future 完成前產生新快照也不混播。
- **驗證**：自訂渲染＋既有 CT-01/M2 目標 13/13 PASS；完整 Domain 141/141 PASS；`dart analyze packages/domain` 0 問題；guardrails #42 轉 IMPLEMENTED。

### Task 5.5 effectiveUnits 三態與 M2/M3 紅測試

- **狀態**：Done（TDD-red，2026-07-13）
- **產物**：新增 `practice_effective_units_test.dart`，鎖定 null→auto、3 列→custom、刪除→auto、stale 透傳、不可變單元清單、第 2 步 `tion skills`，以及 auto 第一段 1260ms 靜音規則不變。
- **紅燈證據**：production 實作前，唯一失敗類型為 `PracticeMode`／`PracticeUnit`／`AutoPracticeUnit`／`CustomPracticeUnit` 與 `effectiveUnits` 尚不存在（exit 1）。

### Task 5.6 effectiveUnits 與 M3 雙軌匯出

- **狀態**：Done（2026-07-13）
- **產物**：新增 `PracticeMode`、sealed `PracticeUnit`、auto/custom 單元與 immutable `PracticeUnits`；`PracticeEngine.effectiveUnits` 成為 Domain 唯一模式判定入口；`PracticeExporter.exportUnit(s)` 只消費判定結果。
- **雙軌不變性**：auto 仍呼叫原 `renderMergedExport`，既有前一步 totalDurationMs 靜音分毫不變；custom 只呼叫 `renderCustomExport`，依各 block 的 repeatN／silenceFactor 組裝；不允許 UI 或 infra 重做 lesson.arrangement 判定。
- **驗證**：5.5 Domain＋infra 目標 11 PASS、1 項真 FFmpeg 因未設 `FFMPEG_PATH` 正常 skip；完整 Domain 145/145 PASS；完整 infra 87 PASS、1 skip；`dart analyze packages/domain packages/infra` 0 問題；guardrails #40 轉 IMPLEMENTED。

### Task 5.7 `.abopack` schemaVersion 2 與 v1 相容

- **狀態**：Done（2026-07-13；使用者批准後動工）
- **產物**：`LessonPackEngine.schemaVersion=2`；`Lesson`、`PracticeArrangement`／`Row`／`Block` 完成 arrangement JSON round-trip；讀取仍接受 schemaVersion 1，缺 language 補 `en`、缺 arrangement 視為 null。
- **相容與安全**：v2 新寫入包含 language／arrangement；v1 舊檔不被改寫；未知版本、損毀 zip、缺音訊仍統一回 `ERR_PACK_CORRUPTED`；contentHash 仍只依原音＋音節，排列變更不重置既有進度。
- **驗證**：Task 5.7 targeted 6/6 PASS；完整 Domain 146/146 PASS；完整 infra 87 PASS、1 項未設 `FFMPEG_PATH` 正常 skip；`dart analyze packages/domain packages/infra` 0 問題。

### Task 6.1 RecordingBufferService 同意／TTL／清掃紅測試

- **狀態**：Done（TDD-red，2026-07-13）
- **產物**：新增 `packages/domain/test/recording_buffer_service_test.dart`，鎖定明示同意才 stash、預設 TTL 10 分鐘、9:59 可列出／回聽、10:01 惰性清除、同 context 覆蓋、`purgeContext`、App 啟動 `purgeAll`，以及 `ERR_BUFFER_STASH_FAILED` 不阻斷主流程。
- **紅燈證據**：`dart test packages/domain/test/recording_buffer_service_test.dart` exit 1；唯一錯誤為 `RecordingBufferEntry`／`RecordingBufferStore`／`RecordingBufferService` 尚未建立，測試自身已通過格式化，production 尚未寫入。
- **契約鎖定**：Domain service 注入 `Clock` 與 `RecordingBufferStore`；store 只負責受管理暫存 IO，服務層負責 TTL／context 規則與錯誤映射；不新增持久化欄位。

### Task 6.2 RecordingBufferEntry、Service 與暫存 IO port

- **狀態**：Done（2026-07-13；使用者批准後動工）
- **產物**：新增 `RecordingBufferEntry`、`RecordingBufferStore` port、`RecordingBufferService`，並由 `packages/domain/lib/domain.dart` 公開匯出。
- **核心行為**：`stash` 明示同意語意、預設 TTL 10 分鐘、同 context 覆蓋；`list` 惰性清掃過期項；`play`／手動 `delete`／`purgeContext`／`purgeExpired`／`purgeAll` 完成；TTL 邊界採 `createdAt + ttl` 不含。
- **安全與純度**：Domain 只依賴 `Clock` 與 `RecordingBufferStore`，不 import `dart:io`；store 契約限定受管理暫存目錄與原子寫入，PCM 索引不進 Attempt、audit_log、pack、progress；寫入錯誤統一為 `ERR_BUFFER_STASH_FAILED`。
- **驗證**：Task 6.1 目標 6/6 PASS；完整 Domain 152/152 PASS；`dart analyze packages/domain` 無問題。guardrails #43 維持 PARTIAL，待 6.3／6.4／前端啟動清掃完成後再轉正。

### Task 6.3 TempRecordingBufferStore 與孤兒清掃

- **狀態**：Done（2026-07-13；使用者批准後動工）
- **產物**：新增 `packages/infra/lib/src/recording/temp_recording_buffer_store.dart`、`packages/infra/test/temp_recording_buffer_store_test.dart`，並由 `packages/infra/lib/infra.dart` 公開匯出。
- **核心行為**：固定 `<OS temp>/recording_buffer` 根目錄；PCM WAV 與 metadata 均 temp→rename 原子寫入；可跨 store instance 重建 metadata；刪除 PCM／metadata 冪等；越界、非 WAV、symbolic link 路徑拒絕；`purgeAll` 清空孤兒與半成品但不碰白名單外檔案。
- **整合證據**：接上 `RecordingBufferService` 後同 context 覆蓋，9:59 可回聽、10:01 實際刪檔；目標測試 6/6 PASS。
- **驗證**：infra 非 sidecar 全量 90/90 PASS、1 項未設 `FFMPEG_PATH` 正常 skip；Domain 全量 152/152 PASS；`dart analyze packages/domain packages/infra` 無問題。另行嘗試 sidecar 標記整合測試，demucs 真機測試 1:46 未完成後手動中止，未列為通過證據。

### Task 6.4 DB／pack／progress 錄音不持久化負向防線

- **狀態**：Done（2026-07-13；使用者批准後動工）
- **產物**：擴充 `packages/infra/test/db_schema_test.dart`，掃描所有 Drift 表與表名；擴充 `packages/domain/test/lesson_pack_engine_test.dart`，檢查 archive entry 與 bytes 不含 RecordingBuffer metadata／暫存檔名／PCM 檔；擴充 `packages/domain/test/progress_import_export_test.dart`，遞迴檢查 progress 欄位與 bytes 不含錄音、PCM、暫存路徑。
- **核心維持**：既有 `RecordingComparator.compare` 的 finally 刪除測試（CT-10）保持不變；未新增資料表、欄位或持久化路徑。
- **驗證**：負向目標測試 22/22 PASS；完整 Domain 153/153 PASS；infra 非 sidecar 全量 90/90 PASS、1 項未設 `FFMPEG_PATH` 正常 skip；`dart analyze packages/domain packages/infra` 無問題；v1.1 `check_guardrails.py` 通過（IMPLEMENTED 9、PARTIAL 3、BLOCKED 1，僅 #48 尚待前端）。guardrails #43 已更新證據但維持 PARTIAL，待 FP15.3 App 啟動 `purgeAll`。

### Task 7.1 TranscriptDisplayMode 與每 Lesson 儲存契約

- **狀態**：Done（2026-07-13；使用者批准後動工）
- **產物**：新增 `TranscriptDisplayMode`、`SettingsService` port、`DriftSettingsService`；`ProgressSnapshot` 新增 immutable `transcriptDisplayModes` 欄位與舊檔缺欄相容讀取；Drift progress adapter 以同一快照欄位保存／還原。
- **核心行為**：四態值（transcript／transcriptWithTranslation／translationOnly／hidden）；缺少 Lesson key 預設 transcript；每 Lesson 隔離；匯入時偏好 map 以 incoming key 覆寫、未帶 key 保留；Lesson／`.abopack` JSON 不含偏好欄位。
- **驗證**：Task 7.1 新增驗證 6/6 PASS（Domain settings 3、ProgressEngine `.aboprogress` 匯出／匯入 1、Drift adapter 2）；完整 Domain 157/157 PASS；infra 非 sidecar 全量 92/92 PASS、1 項未設 `FFMPEG_PATH` 正常 skip；`flutter analyze packages/domain packages/infra` 無問題。
- **範圍控制**：未新增資料表或 `.abopack` 欄位；`app_settings` 僅作本機 adapter 儲存，進度快照仍是匯出／匯入唯一資料契約。

### Task 8.1 新 ASR 引擎／模型上架五步驟

- **狀態**：Done（2026-07-13；依 `[需要回報]` 風險分類完成文件與 gate 測試）
- **產物**：新增 v1.1 `release/release-checklist.md`，補齊 adapter→授權審查→M4 故障注入→金標準回歸→Registry 註冊五步；`docs/codex/commands.md` 加入同一流程與禁止提前 staging 說明。
- **授權 gate**：`scripts/check_licenses.py` 對 `sidecar`／`sidecar-transitive`／`model` 類別要求 `source`；`scripts/test_check_licenses.py` 新增缺 source 負向測試；既有 v1 license manifest 25 components PASS。
- **驗證**：`python3 -m unittest scripts/test_check_licenses.py scripts/test_prepare_release_sidecars.py scripts/test_fetch_sidecar_artifacts.py scripts/test_make_release_zip.py`：23/23 PASS（其中 GPL fake FFmpeg 拒絕訊息為預期測試輸出）。
- **狀態邊界**：#50 的 matrix 狀態與統計留給 Task 8.2 依完整證據回寫；本任務未新增實際引擎、模型或下載來源。

### Task 8.2 v1.1 hard-limits matrix 狀態回寫

- **狀態**：Done（2026-07-13；依實際產物證據回寫，不自批不適用）
- **產物**：更新 `guardrails/hard-limits-matrix.md` 的 S8 階段、#39～#50 最新測試數與檔案證據；#50 由 PARTIAL 轉 IMPLEMENTED；#43／#45 保持 PARTIAL，#48 保持 BLOCKED 並列明解除條件。
- **統計**：IMPLEMENTED 10、PARTIAL 2、NOT_APPLICABLE_PENDING_HUMAN_REVIEW 0、BLOCKED 1、NOT_REVIEWED 0。
- **驗證**：`python3 scripts/check_guardrails.py <v1.1 matrix> <v1.1 decision-log>` PASS；`git diff --check` PASS；未刪除 matrix 行、未把任何未完成前端／錄音清掃項目誤標完成。

### FP9.1 殼層 LayoutBuilder、1280px 斷點與捲動基線

- **狀態**：Done（2026-07-14；依 `[需要回報]` 風險分類完成）
- **產物**：新增 `app/lib/shared/responsive_layout.dart`；`ResponsiveLayout` 以 `LayoutBuilder` 計算 viewport，維持 1100×700 最小內容尺寸並提供水平／垂直 `Scrollbar`；`ResponsiveTwoPane` 在 1280px 以上並排、以下堆疊；`AppShell` 改接共用殼層。
- **測試**：新增 `app/test/responsive_layout_test.dart`，鎖定 1280/1279.99 邊界、800×600 兩軸捲動、1600px 寬度不被 1100 綁死、雙欄／堆疊切換；targeted 4/4 PASS。
- **驗證**：`flutter test`（工作目錄 `app/`）完整 82/82 PASS；`flutter analyze app` No issues；既有 `macos_window_config_test.dart` 的 1100×700 斷言未改。
- **範圍控制**：未改 macOS `contentMinSize`、未持有 feature 狀態；逐頁套用留給 FP9.2，未宣稱完成其它前端需求。

### FP9.2 逐頁套用響應式容器並保留編輯狀態

- **狀態**：Done（2026-07-14；依 `[需要回報]` 風險分類完成）
- **產物**：既有 `LibraryScreen`、`ImportScreen`、`EditorScreen`、`PracticeScreen`、`ProgressSettingsScreen` 均保留最外層垂直 `SingleChildScrollView`；`ImportScreen` 使用 `ResponsiveTwoPane`，1280px 以上並排、以下堆疊；結果面板改以 `minHeight` 避免窄版無限高度約束。
- **狀態保留**：`responsive_layout_test.dart` 新增整合情境，輸入匯入字稿後切換校正頁、縮放 1100×700→1600×1000，再切回匯入頁，TextField 內容仍為 `state preserved`。
- **驗證**：responsive targeted 5/5 PASS；`flutter test`（工作目錄 `app/`）完整 84/84 PASS；`flutter analyze app` No issues；`git diff --check` PASS。
- **範圍控制**：段落標籤與排列區目前尚未建立主畫面，未虛構頁面；FP10／FP13 建頁時必須沿用 `ResponsiveLayout`／`ResponsiveTwoPane`，不改動既有 controller 狀態策略。

### FP10.1 LabelingScreen、NavigationRail 入口與 Controller 骨架

- **狀態**：Done（2026-07-14；依 `[需要回報]` 風險分類完成）
- **產物**：新增 `app/lib/features/labeling/labeling_screen.dart`、`labeling_controller.dart` 與 `segment_engine_factory.dart`；NavigationRail 新增「段落標籤」頂層項，既有 AppSection 索引同步後移；畫面沿用響應式雙欄／上下堆疊與外層捲動。
- **介面 20**：`labelingEngineProvider` 注入 Domain `SegmentEngine`；Controller 對 unsupported format、工具未就緒、DomainException 分流，成功保留 `LabelSession`、波形 peaks、`existingLabelPath` 與 `LabelOpenWarning`，不把 ASR warning 當失敗。
- **驗證**：`labeling_controller_test.dart` 2/2 PASS；focused navigation/progress/e2e 10/10 PASS；`flutter test`（工作目錄 `app/`）完整 86/86 PASS；`flutter analyze app` No issues；`git diff --check` PASS。
- **範圍控制**：標籤線增刪／拖曳、`.abolabel` dirty 三選一與 segment→單句分析交接留給 FP10.2～FP10.4；本任務只建立可注入骨架與靜態 peaks 預覽，不複製 PCM 或建立第二套 Domain 流程。

### FP10.2 FullTrackWaveform、標籤線與區段清單互動

- **狀態**：Done（2026-07-14；依 `[需要回報]` 風險分類完成）
- **產物**：新增 `FullTrackWaveform` 與 `SegmentList`；波形支援時間軸、段落選取、邊界 ± hit-test 拖曳、選取段落中點 `＋`、邊界 `×`；清單支援編號、單選、時間範圍、原音段落試聽與刪線。
- **Domain 委派**：`LabelingController` 增加本地 drag preview，放開才呼叫 `LabelSession.moveBoundary`；新增／刪除分別呼叫 `insertBoundary`／`removeBoundary`，錯誤沿用 Domain `ERR_BOUNDARY_INVALID`／`ERR_SEGMENT_TOO_CLOSE`；未直接修改 Segment list。
- **M1 試聽**：`JustAudioLabelingSegmentPreview` 只以原始音檔路徑＋Segment 起訖設 clip，不做 TTS、合成或跨來源拼接。
- **驗證**：Controller 3/3 PASS；`full_track_waveform_test.dart` widget 2/2 PASS；`flutter test`（工作目錄 `app/`）完整 89/89 PASS；`flutter analyze app` No issues；`git diff --check` PASS。
- **範圍控制**：`.abolabel` 儲存／dirty 三選一、載入既有標籤提示與交接單句分析留給 FP10.3／FP10.4；本任務不新增持久化欄位。

### FP10.3 `.abolabel` 提示／匯出與 dirty 三選一攔截

- **狀態**：Done（2026-07-14；使用者批准「批准 FP10.3」後動工）
- **產物**：`LabelingFilePicker` 增加 `.abolabel` 儲存／開啟契約；`DomainLabelingPackStore` 委派 `LabelPackEngine`；`LabelingController.saveLabel`／`loadExistingLabel`／`dismissExistingLabel`；`LabelingScreen` 既有標籤提示與 dirty 三選一攔截；新增 `labeling_controller_test.dart` 與 `labeling_screen_test.dart`。
- **資料保存**：`LabelSession.dirty` 是攔截狀態來源；取消不呼叫新音檔 `openAudio`；放棄需明示；儲存只在 `.abolabel` 原子寫入與 registry upsert 成功後由 Domain `markSaved()` 清除 dirty；寫入失敗保留原 session／dirty 與錯誤。
- **既有標籤**：新音檔開啟後若 `existingLabelPath` 不為空，提示是否載入；載入經目前音檔 fingerprint 驗證，失敗不替換 session。
- **驗證**：Controller targeted 6/6、Screen targeted 4/4；`flutter test`（工作目錄 `app/`）96/96 PASS；`flutter analyze app` No issues；`git diff --check` PASS。
- **防線回寫**：v1.1 hard-limits-matrix #48 由 BLOCKED 轉 IMPLEMENTED；#49 維持 IMPLEMENTED；未新增音訊／錄音持久化欄位。

### FP10.4 勾選 Segment→單句分析交接

- **狀態**：Done（2026-07-14；依 `[需要回報]` 風險分類完成）
- **產物**：新增 `app/lib/shared/pending_segment.dart` 單一待處理槽位；`LabelingController.handoffSelectedSegment`／`handoffSegment` 將原音路徑、起訖毫秒、文字、language 交接；`AnalysisController.consumePendingSegment` 預填單句輸入並清空 pending；`SegmentList` 加入單選 Checkbox，`LabelingScreen` 加入「送到單句分析」入口與導頁。
- **核心維持**：`PendingSegment` 僅攜帶 metadata，不複製 PCM；provider 只允許一筆，後一次交接明確替換前一次；分析狀態保留 `pendingSegment` 的起訖與來源，`ImportRequest.language` 沿用交接語言。
- **驗證**：pending／Controller targeted 3/3；handoff widget 1/1；既有 labeling targeted 4/4；`flutter test`（工作目錄 `app/`）100/100 PASS；`flutter analyze app` No issues；`git diff --check` PASS。
- **範圍控制**：未在本任務切 PCM、未新增分析引擎；來源徽章與實際原音切片由 FP11.1 接續完成。

### FP11.1 直接匯入與 pending Segment 雙入口

- **狀態**：Done（2026-07-14；依 `[需要回報]` 風險分類完成）
- **產物**：`ImportScreen` 自動消費 `pendingSegmentProvider`，顯示「來自段落標籤：第 N 段」來源徽章並預填字稿；`AnalysisUiState` 保留 pending metadata 與 language；`AnalysisController` 將 language／`TimeRange` 傳入 `ImportRequest`。
- **M1 原音切片**：`ImportRequest.sourceRange` 在 Domain pipeline 解碼後呼叫 `Pcm.slice`，以 sample 子範圍送入可選人聲分離、ASR 與音節切分；原始 PCM 不回寫、不複製成第二引擎，resume checkpoint 不重複切片。
- **直接入口相容**：直接選檔仍沿用原有 `selectAudioPath`；pending 入口只改 metadata／字稿與來源狀態，分析完成仍由既有 `AlignmentResult` 驅動畫面音節預覽。
- **驗證**：ImportScreen targeted 7/7、Domain sourceRange／Pcm slice 2/2；`dart test packages/domain/test` 159/159；`flutter test`（工作目錄 `app/`）103/103 PASS；`flutter analyze` No issues；`git diff --check` PASS。

### FP11.2 無音檔防呆與 TTS 零入口

- **狀態**：Done（2026-07-14；風險分類 `[可直接做]`）
- **產物**：`ImportScreen` 在沒有音檔且沒有 pending Segment 時顯示「請先匯入音檔，或到『段落標籤』選擇一個區段」；既有 `AnalysisUiState.canStart` 讓「開始分析」維持 disabled；新增 `import_screen_no_tts_test.dart` 掃描 widget tree。
- **D1 防線**：無新增 TTS／文字生音／生成控制項；既有 `transcriber_policy_test.dart` 依賴與 Domain URL 黑名單不變。
- **驗證**：FP11.2 targeted 1/1、ImportScreen regression 7/7；`flutter test`（工作目錄 `app/`）104/104 PASS；`flutter analyze` No issues；`git diff --check` PASS；hard-limits-matrix #45 維持 PARTIAL（只剩發布授權人工核對）。

### FP11.3 搬移手動／AI 譯文群組並保持設定頁其餘功能

- **狀態**：Done（2026-07-14；使用者批准後動工）
- **產物**：`ImportScreen` 接手譯文 controller、課件 `_saveLesson`（含 ⌘S）與 AI 翻譯按鈕；`AnalysisUiState` 保存 AI 譯文，`lesson_pack_service.dart` 在草稿建構時以 manual 優先、無 manual 才保存 AI；`ProgressSettingsScreen` 移除手動譯文欄位與課件儲存入口，AI key／封存／提醒／Sidecar 逾時／進度匯出匯入／批次「儲存」維持。
- **驗收證據**：新增 `app/test/features/import_analysis/import_screen_translation_test.dart` 2/2，覆蓋 AT-20-01（AI 預覽＋手動覆蓋＋⌘S 課件保存）、AT-20-04（無草稿置灰）與 AT-20-05（manual 優先）；`progress_ui_test.dart` 設定頁回歸與既有流程 15/15；responsive／demucs widget finder 隨新群組調整。
- **驗證**：focused 合併 25/25 PASS；`flutter test`（工作目錄 `app/`）106/106 PASS；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
- **範圍控制**：未改 AI provider／Domain API；AI 譯文只走既有 `AiSettingsService`，不接觸音訊；設定頁批次保存未拆分。

### FP12.1 EditorController 編輯操作、共享選中與校正 undo

- **狀態**：Done（2026-07-14；使用者預先授權全數批准）
- **產物**：`EditorUiState.selectedSyllableIndex` 單一選中來源；`EditorController` 新增 `selectSyllable`、`removeBoundary`、`insertBoundary`、`updateSyllableText`，均委派注入的 `AlignmentEngine`；成功編輯共用 immutable snapshot undo，最多保留最近四步。
- **核心行為**：刪除選中音節清空選中；插入切點後調整後續索引；空字串由 Domain 標記 `needsReview`；音節總數變更標記既有排列 stale，排列 undoDepth 不受校正 undo 影響。
- **驗證**：EditorController targeted 16/16 PASS；`flutter test`（工作目錄 `app/`）110/110 PASS；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
- **範圍控制**：未改 WaveformCanvas 手勢、chip UI 或 Arrangement 區，分別留給 FP12.2、FP12.3、FP13.x。

### FP12.2 WaveformCanvas 編號、高亮與＋／×手勢

- **狀態**：Done（2026-07-14；使用者預先授權全數批准）
- **產物**：`WaveformCanvas` 加入邊界圓點 1-based 編號、共用選取音節黃色區段與選取邊界高亮；EditorScreen 接上 `selectedSyllableIndex`、選取、刪除切點與新增切點 callbacks。
- **互動防線**：浮動「×」委派 `removeBoundary`；音節中心「＋」以兩側各 50ms 前端停用，實際插入仍由 Domain `AlignmentEngine.insertBoundary` 再驗證；未改 waveform sample／prosody 計算。
- **驗證**：`waveform_canvas_test.dart` 8/8 PASS（選取、刪除、有效新增、短音節停用）；`flutter test`（工作目錄 `app/`）114/114 PASS；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
- **範圍控制**：文字 chip 編號／編輯留給 FP12.3；Arrangement 區留給 FP13.x。

### FP12.3 文字 chip 序號、編輯與同步高亮

- **狀態**：Done（2026-07-14；使用者預先授權全數批准）
- **產物**：`_SyllableChip` 改為可編輯狀態元件，chip 下方顯示連續 1-based 序號；pointer-down 立即同步 `selectedSyllableIndex` 並保留單擊原音試聽，300ms 內第二次點擊進入 TextField。
- **Domain 委派**：送出文字一律呼叫 `EditorController.updateSyllableText`；空字串沿用 Domain `needsReview` 與 `originalText` 保留規則；選中 chip 與 WaveformCanvas 共用黃色高亮來源，刪除切點後序號由 index 重新連續渲染。
- **驗證**：新增 `editor_screen_edit_test.dart` 4/4 PASS（序號／選取、雙擊編輯保留原文、空值 needsReview、刪除後重排）；editor focused 29/29 PASS；`flutter test`（工作目錄 `app/`）118/118 PASS；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
- **範圍控制**：未新增第二份 transcript 狀態；Arrangement 仍留給 FP13.x。

### FP13.1 ArrangementController／Section 與一鍵生成

- **狀態**：Done（2026-07-14；使用者預先授權全數批准）
- **產物**：新增 `ArrangementController`／`ArrangementUiState` 與 `ArrangementSection`，EditorScreen 於音節 chip 下方提供自由排列區；可一鍵依音節數生成 N 列、插入／刪除列與連續編號。
- **核心維持**：排列操作一律委派 Domain `PracticeArrangement` immutable API；stale banner 支援重新生成／保留目前排列；排列 undo 由 Domain 快照維持，透過 `setArrangement` 回寫但不污染校正 undo。
- **驗證**：新增 `arrangement_section_test.dart` 3/3 PASS（生成、列操作與獨立 undo、stale banner）；editor/practice/arrangement focused 52/52 PASS；`flutter test`（工作目錄 `app/`）121/121 PASS；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
- **範圍控制**：長按成組／組內排序／拆組留給 FP13.2；積木設定與列預覽留給 FP13.3。

### FP13.2 長按堆疊成組、組內排序與拆組

- **狀態**：Done（2026-07-14；使用者預先授權全數批准）
- **產物**：新增 `arrangement_row.dart`；每個未成組積木使用 `LongPressDraggable`／`DragTarget`，同列 hover 300ms 顯示「預覽成組」後才 group；跨列 drop 只呼叫 move。
- **核心行為**：成組 block 內以 syllable drag data 委派 `reorderGroupedSyllable`，提供「拆組」按鈕委派 `ungroup`；所有結果由 Domain immutable arrangement snapshot 回傳。
- **驗證**：`arrangement_row_test.dart` 3/3 PASS（同列預覽／成組、跨列 move、組內排序／拆組）；`arrangement_section_test.dart` 3/3 PASS；`flutter test`（工作目錄 `app/`）124/124 PASS；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
- **範圍控制**：repeatN／silenceFactor、列預覽與播放競態留給 FP13.3；未新增跨列成組或圈選框手勢。

### FP13.3 積木設定、列預覽與播放競態防護

- **狀態**：Done（2026-07-14；使用者預先授權全數批准）
- **產物**：新增 `block_config_menu.dart`；ArrangementSection／Row 接上 repeatN 1–10、silenceFactor 0–5（0.5 步進）、積木與列預覽入口；`ArrangementController` 委派 Domain `setBlockConfig` 並以 immutable row snapshot 預覽。
- **M1/M3 維持**：列預覽共用 `PracticeEngine.renderBlockRow`，每塊仍由原音切片、重複與數位零靜音組裝；`PracticePlayer` 新增 row render/play 與 `_playRunId`，排列變更或新播放會停止／淘汰舊 snapshot，不會半新半舊。
- **驗證**：`block_config_menu_test.dart` 3/3、`arrangement_section_test.dart` 4/4、`practice_player_test.dart` 6/6；`flutter test`（工作目錄 `app/`）130/130 PASS；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
- **範圍控制**：未建立第二套音訊 renderer；錯誤時保留既有設定與排列 undo。

### FP14.1 PracticeController effectiveUnits 與模式顯示

- **狀態**：Done（2026-07-14；使用者預先授權全數批准）
- **產物**：`PracticeController` 以 Domain `PracticeEngine.effectiveUnits` 建立 immutable units；auto／custom 共用 steps 目錄與 current index，custom 透過 `PracticePlayback.playRow` 播放；PracticeScreen 顯示模式 chip 與 stale banner，custom 隱藏全域 repeat stepper。
- **核心維持**：Lesson 的最新 editor arrangement 先寫回 effective snapshot，避免 session 舊課件排列成為第二真相；auto 步數、順序與既有錄音比對路徑不變。
- **驗證**：`practice_controller_test.dart` 13/13、`practice_screen_test.dart` 5/5 PASS；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。

### FP14.2 custom 單元匯出與刪除排列確認

- **狀態**：Done（2026-07-14；使用者預先授權全數批准）
- **產物**：`PracticeExportService`／`PracticeExportDialog` 改以 `PracticeUnits` 委派 infra `exportUnits`，custom 勾選項保留 `CustomPracticeUnit.row`；練習頁新增刪除排列確認，確認後只清除 editor arrangement 並回落 auto。
- **資料邊界**：刪除流程不觸碰音節校正、錄音暫存或 SRS／Attempt 進度。
- **驗證**：`export_dialog_test.dart` 6/6、custom practice screen 1/1 PASS；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。

### FP15.1 錄音暫存明示同意與隱私文案

- **狀態**：Done（2026-07-14；使用者預先授權全數批准）
- **產物**：RecordPanel 在錄音比對完成後顯示預設未勾選的 `record-stash-consent`；Tooltip 明列 10 分鐘 TTL、切步／重啟清除與不進課件；PracticeController 僅在勾選時呼叫 `RecordingBufferService.stash`。
- **隱私維持**：未勾選沿用原 finally 清理；暫存只寫受管理 recording_buffer，錯誤轉 `ERR_BUFFER_STASH_FAILED`，不阻擋比對結果。
- **驗證**：PracticeController FP15.1 targeted 1/1、既有 practice screen 錄音回歸 PASS。

### FP15.2 暫存清單、回聽、刪除與切步清除

- **狀態**：Done（2026-07-14；使用者預先授權全數批准）
- **產物**：新增 `RecordingBufferPanel` ExpansionTile；每筆提供播放與刪除；controller 提供 `playBuffered`／`deleteBuffered`，選步驟時 purge 前一 context。
- **核心維持**：回聽仍經 PracticePlayer／原始 PCM port；清單只呈現 `RecordingBufferEntry` metadata，不把音訊放入 Attempt、progress 或課件。
- **驗證**：PracticeController FP15.1 targeted 1/1 同時覆蓋 stash／回聽／purge；`flutter analyze app packages/domain` No issues。

### FP15.3 App 啟動注入 RecordingBuffer 並先 purgeAll

- **狀態**：Done（2026-07-14；使用者預先授權全數批准）
- **產物**：新增 `recording_buffer_provider.dart` 注入 `RecordingBufferService`＋`TempRecordingBufferStore`；`main()` 在 runApp 前呼叫 `purgeAll`，失敗只記 debug audit 訊息、不阻擋 App。
- **防線**：store 根目錄仍限定 recording_buffer，沿用 temp→rename 與冪等清除；provider 未新增其他 temp 清理範圍。
- **驗證**：既有 `TempRecordingBufferStore` focused 5/5；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。

### FP16.1 四態字稿／譯文顯示

- **狀態**：Done（2026-07-14；使用者預先授權全數批准）
- **產物**：PracticeScreen 新增 `SegmentedButton<TranscriptDisplayMode>` 四態（字稿、字稿＋譯文、僅譯文、隱藏）與條件渲染；無譯文時含譯文模式仍可選並顯示導引。
- **範圍控制**：不改翻譯內容與 manual 優先規則；只消費 Lesson 現有 translations。
- **驗證**：`practice_screen_test.dart` FP16.1 targeted 1/1 PASS；`flutter analyze app packages/domain` No issues。

### FP16.2 每 Lesson 顯示偏好與 `.aboprogress` 服務

- **狀態**：Done（2026-07-14；使用者預先授權全數批准）
- **產物**：注入 `transcriptSettingsServiceProvider`（DriftSettingsService），PracticeController load／set 依 lessonId 讀寫；偏好沿既有 ProgressRepository snapshot 匯出／匯入，不寫入 `.abopack`。
- **隔離維持**：lessonId 是偏好 map key，切換課件不共用模式；儲存失敗只回報錯誤，不破壞練習狀態。
- **驗證**：`practice_screen_test.dart` FP16.2 targeted 1/1、既有 `progress_settings_test.dart` 7/7 PASS；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。

### FE-QA.1 v1.1 跨切片 e2e 與錯誤文案回歸

- **狀態**：Done（2026-07-14；使用者預先授權全數批准）。
- **產物**：新增 `app/test/e2e_v11_pipeline_test.dart`，以可控 analysis runner 串起 label→analysis→editor→arrangement→practice→record buffer→display mode；沿用 `error_messages_test.dart` 驗證 27 碼映射完整。
- **驗證**：FE-QA smoke 1/1、error messages 1/1；完整 `bash scripts/ci_core_checks.sh` PASS（Domain 159/159、Infra 96/96〔1 skip〕、App 137/137、analyze No issues、license／兩份 guardrails／handoff gate PASS）。
- **範圍控制**：未以 mock 取代既有 `e2e_pipeline_test.dart` 的真 sidecar／真檔案 smoke；1100×700 尺寸在 widget smoke 中固定驗證。

### 8.3 完整 CI、效能與真機 smoke 收尾

- **狀態**：Blocked（2026-07-14；自動化交付閘門已通過，真機 GUI 項目待使用者親跑）。
- **驗證**：`bash scripts/ci_core_checks.sh` PASS；Domain 159/159、Infra 96/96（1 項 sidecar skip）、App 137/137；靜態分析、授權、兩份 guardrails 與 handoff/pipeline-state gate 均 PASS。v1.1 matrix 回寫為 IMPLEMENTED 13、PARTIAL 0、BLOCKED 0。
- **Intel benchmark**：在本機 Intel i5-8259U 重跑 `dart run bin/benchmark_alignment_pipeline.dart`，10 秒音檔 elapsed 3.859s；上限 4.924s；syllableCount 22、waveformPeaks 32；status PASS。
- **macOS 啟動 smoke**：`flutter run -d macos --debug` 成功建置 `syllable_repeater_app.app` 並連上 macOS desktop device；本執行環境無可擷取的互動顯示器，未將此結果視為 GUI smoke 完成證據。
- **黑畫面修正**：確認 Finder 啟動 Debug App 時 `Directory.current` 不在 workspace，舊版 `SidecarPaths.dev()` 在 `runApp()` 前拋 `StateError`；改為同時從 current directory 與 `Platform.resolvedExecutable` 向上尋找 workspace。重新以 `open -a .../Debug/syllable_repeater_app.app` 啟動後，process／visible window／1100×700 content size 均可取得，runtime 無 StateError。
- **尚待人工**：依 AT-10-01～05、AT-11-01、AT-17-01 在 Intel Mac 實機完成 1100×700 GUI smoke；本環境未由使用者親跑，故 8.3 不勾選。
- **人工驗收步驟**：在本 repo 執行 `flutter run -d macos`，將視窗調為內容區 1100×700；依序確認匯入／校正頁可捲動與狀態保留（AT-10-01～05）、標籤切換與錯誤提示（AT-11-01）、金標準分析仍為 11 音節／10 切點（AT-17-01），再將結果與截圖回填本段後才可勾選 8.3。

### S9 最終完整變更包規格同步

- **狀態**：Done（文件階段，2026-07-14；使用者明示「批准最終完整變更包」）。
- **變更防線七題**：核心規則＝是（M3 自訂靜音契約）；資料一致性＝是（草稿 Lesson id／ready）；權限＝否；外部服務＝否；新增測試＝是；更新需求＝是；調整架構＝是（進度 port／audio session coordinator）。使用者已在動工前批准整包。
- **三同步產物**：requirement v1.1-r5 新增／修訂 AT-11-10～11、AT-12-06～08、AT-14-06、AT-15-10～12、AT-16-07、AT-18-08、AT-19-05 與 M15；backend 介面 20/27～29/33 更新並新增 35/36；frontend 功能點 10～16 更新；task-split 新增 9.1～9.5、FP17～20、FE-QA.2。
- **guardrails**：#42/#43 因實機回歸降為 PARTIAL；新增 #51 M3 config、#52 truthful progress、#53 draft identity，皆為 PARTIAL，禁止在證據完成前自批 IMPLEMENTED。
- **下一步**：啟用 `fullstack-code-implementation` 前先通知使用者；獲知會開始後，從 Task 9.1 TDD-red 動工。

### Task 9.1 組塊整組重複與 M3 新設定範圍 TDD

- **狀態**：Done（2026-07-14；M1/M3 `[需要回報]`）。
- **紅測試證據**：先新增 AT-15-11、AT-15-06 邊界與舊 pack round-trip；首次 targeted 執行 29 pass／4 fail，失敗精準命中預設 2、上限 5、未限制 0.5 step。
- **實作**：`PracticeBlock` 單一定義預設 3／5、repeat 1–10、silence 0–20、step 0.5；成組與拆組沿用建構子預設，避免偏向任一來源設定；既有 `renderBlockRow` 維持先串整組再重複的 M1 路徑。
- **相容性**：新增 schemaVersion 2 舊值 `silenceFactor=2.5` round-trip，原值不遷移、不改 pack schema。
- **驗證**：`flutter test packages/domain/test/practice_arrangement_test.dart packages/domain/test/practice_arrangement_render_test.dart packages/domain/test/lesson_pack_engine_test.dart` 33/33 PASS。
- **下一步**：Task 9.2 串接草稿 Lesson identity，並讓 App 的生成／儲存沿用同一 id。

### Task 9.2 PracticeBlock 契約與 DraftLessonIdentity

- **狀態**：Done（2026-07-14；M1/M3／guardrails #51/#53 `[需要回報]`）。
- **Domain**：新增 immutable `DraftLessonIdentity`；`PracticeArrangement.resetBlockConfig` 原子回到 3／5；成組／拆組沿用同一預設契約，跨 Lesson 驗證未放寬。
- **App 協調**：`AnalysisController` 只在分析成功時透過可注入 generator 建立一次 draft id；換檔／重跑先清空；`EditorController`、`ArrangementController`、`Lesson` 草稿建構與 pack 保存沿用同一 id。
- **修復結果**：尚未保存 `.abopack` 時 editor 已有 `sourceLessonId`，一鍵生成不再因 null 置灰；保存時不再依檔名另造 id，且把草稿排列一併寫入 Lesson。
- **驗證**：Domain `practice_arrangement_test.dart` 22/22 PASS；App import／translation／arrangement targeted 10/10 PASS；測試涵蓋分析→排列→保存 id 相同與第二檔換新 id。
- **下一步**：Task 9.3 真實 byte／階段進度與 ready fail-closed。

### Task 9.3 真實匯入／段落階段事件與 ready 狀態機

- **狀態**：Done（2026-07-14；M15／guardrails #52 `[需要回報]`）。
- **Domain**：新增 `AudioImportReader` port、`AudioImportProgress`／`AudioReadySource`；`SegmentEngine.openAudio` 以 start/done 事件回報指紋、解碼、選用分離、切句、波形與完成階段，ASR 失敗仍回正常空 session＋warning。
- **Infra**：新增 `DartIoAudioImportReader`，以真實 `File.openRead()` bytes 推進；非空後才驗格式與 ffprobe 時長，全部成功才發唯一 ready。
- **App 狀態**：直接選檔在 reader 完成前為 loading 且 `canStart=false`；後選檔以 runId 作廢前一 stream；段落交接因前階段已驗證而立即 ready；正式 main 注入真 reader。
- **誠實進度**：移除 preview runner 的 15/35/62/86 假百分比；未知工作量只保留階段事件，不捏造 sidecar 內部比例。
- **驗證**：完整 Domain 166/166 PASS（含 purity）；infra reader 2/2 PASS；App import／label controller 11/11 PASS；測試以 completer 證明解碼未完成前不會越級到切句。
- **下一步**：Task 9.4 macOS 錄音→播放 session 與 temp 生命週期。

### Task 9.4 macOS 錄音後回播工作階段與 temp 生命週期

- **狀態**：Done（程式與自動測試，2026-07-14；Finder 實機 smoke 留待 FE-QA.2）。
- **紅測試**：先證明現況缺少 `PracticeAudioSessionCoordinator` 與可注入 session，編譯紅燈如期出現。
- **實作**：把既有 transitive `audio_session 0.2.4` 宣告為直接依賴；錄音開始前啟用 record session，`recorder.stop()` 完成後先釋放，再由 `PracticePlayer` 啟用 playback session。
- **temp 生命週期**：`playPcm` 等 backend 播放 Future 真正完成後才釋放 session 並在 finally 刪除 preview WAV；播放中檔案仍存在，連播兩次後皆清空。
- **錯誤與清理**：啟用失敗映射為可見 DomainException；取消、例外與 provider dispose 都釋放錄音 session，且 onDispose 不再非法讀 Riverpod ref。
- **驗證**：player／controller／recording targeted 22/22 PASS；含 recorder.stop→session.finish 順序、完成前 temp 存在、完成後刪除與連播兩次。
- **下一步**：FP17～20 前端互動與誠實呈現。

### FP17～20 前端互動與誠實呈現

- **狀態**：Done（2026-07-14；Finder 實機與完整 CI 留 FE-QA.2／9.5）。
- **校正選取**：新增半開 `selectedTimeRange`；波形拖選與 chip 點選共用範圍，所有 overlap 音節同步黃色高亮，增刪／undo 後重算有效選取。
- **自由排列**：上方音節改一般 `Draggable`，空列可接 drop；移除長按與 300ms 等待；同列 drop 成組、跨列只移動；雙擊積木／組塊開集中設定，右側設定與播放 icon 移除，只保留列右預覽；設定視窗支援 repeat 1–10、silence 0–20/step0.5、reset 3/5 與積木預覽。
- **練習頁**：可見「步」統一為「單元」；hidden 時 navigator 只 `#n`、播放器只 `第 n 單元`，錄音暫存項目只顯示單元編號；移除模式徽章、練習頁刪除入口與「每列沿用各積木設定」，刪排列移到自由排列標題左側。
- **真實進度**：段落頁刪除頁首重複選檔；介面 20 stage 直接呈現，可量測才顯示百分比，未知總量維持 indeterminate；匯入頁逐 byte 顯示比例，驗格式／時長完成才顯示就緒；pending segment 立即就緒；分析前結果預覽留白，完成後只顯示實際 syllables。
- **回播錯誤**：錄音回播沿用 9.4 audio session／temp 生命週期；SnackBar 同時顯示友善說明與實際 Domain 錯誤細節。
- **自動驗證**：`flutter analyze` No issues；FP17 editor 31/31、arrangement 13/13、practice＋arrangement 12/12、label/import 17/17、增量跨頁集合 20/20 PASS；擴大回歸唯一舊測試失敗為仍期待已刪除的 `practice-mode-chip`，同步更新後轉綠。
- **完整閘門阻塞紀錄**：`bash scripts/ci_core_checks.sh` 在「Flutter toolchain」步驟因 sandbox 無權寫 `/usr/local/share/flutter/bin/cache/` 失敗；依規則申請沙箱外執行時，平台因 Codex 用量上限拒絕，並明示不得繞路。此項不是程式測試紅燈，但完整 CI 未完成，故 9.5、FE-QA.2 與 matrix #42/#43/#51～#53 不轉全綠。
- **下一步**：額度恢復後重跑完整 CI；由 Finder 開正式 App 實測拖曳、真 sidecar 進度與錄音連播兩次，再完成 FE-QA.2／9.5。

### S9 實機回饋修正包（Task 9.6～9.9／FP21～22）

- **狀態**：程式、TDD 與 Release 建置已完成（2026-07-14）；波形目視與真人麥克風仍待使用者驗收，不標記 FE-QA.2／9.5／8.3 完成。
- **練習單元**：0 列為完整單句 1 單元；N 列為 N 單元即時連動；練習頁 `×N` 直接編輯當前 row，不再另乘第三層。
- **M1/M3 層次**：積木預設 1／3，每輪保留積木靜音；row 預設 3／3，靜音基準只算各擺放積木原始長度一次，最後 row 重複後不留 row 靜音；預覽／練習／匯出共用 Domain renderer。
- **匯出微調**：每單元可暫時覆寫 row repeat/silence，不另包一層、不回寫排列；多單元仍保持 M3「上一單元總時長」間隔。
- **波形**：新增 `waveformNodeRange`，首段從 0ms、尾段至 PCM duration；Canvas 點選／高亮／新增切點與積木試聽共用同一節點區間。
- **錄音**：macOS 外掛若交付 stereo／float WAV，檔案穩定後經 bundle FFmpeg 正規化為 44.1kHz PCM16 mono，並以 `AtomicFileIo` 覆寫受管 temp；失敗及比對完成仍由 M10 路徑刪除。
- **人聲分離**：Demucs 改為直接從原始匯入檔準備 44.1kHz stereo，不再先 downmix mono；AAA.m4a 本身是 48kHz mono，因缺左右聲道差異，模型將大多數能量判為 vocals 是素材限制，不虛報完全分離。
- **拆批驗證**：Domain 171/171；Infra 99/99＋1 項未設 `FFMPEG_PATH` 正常 skip（含真 FFmpeg／Analysis／Demucs 4/4）；App 155/155；`flutter analyze app packages/domain packages/infra` 無問題；Python release gate 23/23；兩份 guardrails、25 元件授權與 `git diff --check` PASS。本環境未重跑單條 `ci_core_checks.sh`，而是依環境限制將同源項目拆批實際執行。
- **Release**：`flutter build macos --release` 成功產生 634.7MB `.app`；bundle FFmpeg 為 shared、`--disable-gpl --disable-nonfree`；`codesign --verify --deep --strict` PASS；已以 `open` 啟動最新 Release，啟動不代表人工驗收完成。

### S9-20 實機驗收追補（錄音回放／長列拖曳／段落播放）

- **狀態**：S9-20.1～20.3 已完成 TDD 與自動回歸；S9-20.4 的 Finder 目視與真人麥克風仍待使用者驗收。
- **錄音回放**：只保留目前單元最近一次 PCM 於 `PracticeUiState`；比對失敗仍可播放；播放／停止與垃圾桶可操作；切單元、重錄、離頁皆清除；不恢復 RecordingBuffer。新增離頁紅測試先取得殘留 PCM，最小修正監聽 IndexedStack 導覽後轉綠；播放途中 stop 亦驗證一次性 WAV 由 finally 刪除。
- **自由排列**：來源積木工具列固定、列區獨立垂直捲動；插入列後自動定位並短暫高亮；拖曳至上下緣持續自動捲動，drop／離開邊緣停止。1100×700 widget 情境轉綠。
- **段落播放**：just_audio clip 使用相對 0ms seek，位置串流加回 clipStart；generation id 避免 pause 舊 Future 把狀態清空；resume 由原處繼續、stop 清游標，所有區段共用完整 `end-start` 契約。
- **拆批結果**：App 174 PASS；Domain 178 PASS；Infra 93 PASS＋1 SKIP；`flutter analyze --no-pub` No issues；兩份 guardrails、25 元件授權、`git diff --check` PASS；`check_handoff.py --latest` PASS（保留既有 stage drift 警告）。
- **Release**：`flutter build macos --release --no-pub` 成功，產出 634.8MB `app/build/macos/Build/Products/Release/syllable_repeater_app.app`。完整報告見 `release/test-report-S9-20-20260715.md`。

### S9-21 排列操作實機追補（名稱／捲動／彈性排列）

- **狀態**：S9-21.1～21.4 已完成 TDD、實作與自動回歸；S9-21.5 的 Release 已重建並啟動，但 Finder 拖曳手感與真人驗收仍待使用者確認，故不勾選 21.5。
- **名稱**：校正頁主標題改為「段落校正」，刪除排列提示也移除舊稱；route／provider key 不變。
- **互動**：內容點按只做選取；單一、整組與組員各有專用六點把手。積木間插入線處理頂層重排／組員抽出，組內插入線處理組員重排／單一併入；所選單一／整組／組員可用垃圾桶或 Delete 刪除，剩一名組員自動降為單一積木，所有變更可由既有排列 undo 復原。
- **捲動**：列區固定顯示 scrollbar；游標位於列區或拖曳期間鎖定 Editor 外層捲動，邊緣自動捲動只改列區 offset。
- **驗證**：Domain 182/182、App 181/181 分批 PASS；`flutter analyze --no-pub app packages/domain packages/infra` No issues；v1.1 guardrails、25 元件授權與 `git diff --check` PASS。Infra 本切片未變更，沿用 S9-20 93 PASS＋1 SKIP，不虛報重跑。
- **Release**：`flutter build macos --release` 成功；增量建置的外層 ad-hoc seal 經沿用 `Release.entitlements` 重簽後，`codesign --verify --deep --strict` PASS；已啟動最新 App。完整報告見 `release/test-report-S9-21-20260715.md`。

### S9-22 段落校正效能、兩層捲動與暫存衛生

- **狀態**：S9-22.1～22.4 已完成 TDD、實作與自動回歸；S9-22.5 的 Release 已重建、重簽並啟動，但 Finder 切點延遲、最後一列與觸控板拿起／放下手感仍待使用者確認，故不勾選 22.5。
- **切點效能**：增刪／拖曳先同步提交 syllables 與選取範圍，Prosody 改由 isolate runner 背景計算；generation id 保證快速連續操作時舊結果不得倒灌。
- **捲動與長距離放置**：移除 `ResponsiveLayout` 的全 App 捲動，只保留功能頁與自由排列列區；新增列只控制列區 scroll controller。來源積木可單擊拿起、放開觸控板捲動，再點任一列藍色插入位置放下，Esc／再點來源取消；近距離 drag 保留。
- **暫存生命週期**：新增帶 lease 鎖的 `ManagedTempSession`，避免多開 App 互刪；Whisper／Demucs 成功失敗皆清中介檔，練習快取於 provider dispose 清除，v3 課程解包在切課、離頁與後續故障時清除；使用者保存的 pack／label／匯出檔有負向測試保護。guardrails #62 已轉 IMPLEMENTED。
- **TDD 證據**：切點測試先因缺 runner/provider 紅燈；全域捲動測試先找到兩個多餘 Scrollbar；20 列拿起／放下提示先不存在；temp manager、Sidecar finally 與解包故障注入皆先紅後綠。
- **拆批驗證**：Domain 182/182 PASS；App 187/187 PASS；Infra 95 PASS＋1 項未設 `FFMPEG_PATH` 正常 SKIP；另真 AnalysisPipeline 2/2、真 Demucs 1/1 明確重跑 PASS。`flutter analyze` No issues；兩份 guardrails、25 元件授權、Python release gate、`git diff --check` PASS。依環境上限拆批，未將未執行的單條 `ci_core_checks.sh` 說成通過。
- **Release**：`flutter build macos --release` 成功（build 輸出 634.9MB，`du` 606M）；以 `Release.entitlements` ad-hoc 深層重簽後 `codesign --verify --deep --strict` PASS，並已用 `open -n` 啟動。完整報告見 `release/test-report-S9-22-20260715.md`。
- **容量診斷**：App bundle 606M 中 sidecar 581M，主要為 Whisper small.en 465M、Demucs model 80M；匯入音檔不會寫進 `.app`。本機另有舊版未管理 temp 218M 與舊練習 WAV cache 80M；新 session 架構阻止後續累積，但既有 298M 未自動刪除，避免誤傷仍執行的舊 App，須在關閉所有 App 後由使用者批准一次性清理。

### S9-23 自由排列互動簡化

- **狀態**：S9-23.1～23.3 已完成 TDD、實作與自動回歸；S9-23.4 的 Release 已重建、驗證並啟動；Finder 長按／三指拖移手感仍待使用者確認，故不勾選 23.4。兩張社群圖因內建產圖服務 HTTP 520 後由使用者明示取消，不再列為本輪待辦。
- **Domain 防線**：`moveBlock`、`extractGroupedSyllable`、`moveSingleBlockIntoGroup` 在改資料前拒絕跨列；Controller API 收斂為單一 `rowIndex`，UI 不能傳入不同目標列。
- **列內互動**：移除六點把手；單一積木、整組與組員都以內容區 300ms 長按啟動拖曳。頂層插入線與組內插入線只接受同列資料；短按選取、雙擊設定與 Delete／垃圾桶維持。
- **來源段落**：來源 Chip 不再是 Draggable；點選後，每個頂層積木左側與列尾出現 compact 插入按鈕，空列整列可點；插入後清選取，Esc／再點取消。來源垂直邊緣自動捲動一併移除，避免搶列區捲動。
- **視覺**：文案改為「來源段落」，移除大型藍色跨列軌、六點與積木麥克風裝飾；組合層級仍由外框與背景表達。
- **驗證**：Domain 184/184；App 189/189；Infra 95 PASS＋1 SKIP；`flutter analyze` No issues；v1.1／v1 guardrails、25 元件授權、Python release gate 與 `git diff --check` PASS。完整報告見 `release/test-report-S9-23-20260715.md`。
- **Release**：`flutter build macos --release` 成功（634.9MB）；`codesign --verify --deep --strict` PASS；以 `open -n` 啟動並擷取真實首頁來源圖。啟動與截圖不等於 Finder 手勢人工驗收完成；社群圖已依使用者指示取消。

### S9-20～23 真人驗收確認（2026-07-15）

- **使用者確認**：使用者明示「真人驗收OK」，完成最新 Release App 的 Finder 目視、觸控板／滑鼠手勢與真人麥克風驗收。
- **涵蓋範圍**：首尾波形黃色區段與切點即時性、末列與來源段落插入／捲動、同列長按／三指排序與成組、所有標籤區段完整播放及暫停／續播、真人錄音後回放／停止／刪除，以及跨頁 smoke。
- **關閉項目**：S9-20.4、S9-21.5、S9-22.5、S9-23.4、FE-QA.2 全部完成；guardrails #54 由 PARTIAL 轉為 IMPLEMENTED。
- **仍未關閉**：#43 的真人麥克風人工項已通過，但 Task 10.6 的 single-pass／isolate／每圖限點仍未實作，故 #43 維持 PARTIAL；9.5 與 8.3 也須等 S10／r6 防線及最終閘門完成，不因本次人工驗收提前勾選。
- **取消項目**：兩張社群圖已由使用者明示取消，不屬本次驗收或未完成待辦。

### S10 r6／r7 最終交付與複審（2026-07-16）

- **狀態**：Task 8.3、9.5～9.9、10.1～10.10 全部完成；`fullstack-code-review` 第 2 輪通過，0 blocking。
- **紅→綠**：四層匯出與 v3 `sentenceSourceRange` 先由編譯／契約紅測試鎖定；錄音 480000 samples 限點測試先證明首點遺失，再以首尾＋內部分桶 min/max 的最小修正轉綠；自訂積木／整列錄音參考鎖定只播放來源一次、無 repeat／silence。
- **核心實作**：`AnalysisAudioTracks` 固定原音／分析軌分離；v3 開啟服務解碼完整原始 PCM；immutable `PracticeExportPlan` 以 fingerprint／lessonId／range fail closed；App 只顯示與音訊來源相容的排列候選。
- **拆批回歸**：Domain 188/188；Infra 59＋35 PASS、1 個條件式 skip 另以 Release FFmpeg 8/8 PASS；App 190/190；`flutter analyze` No issues。App macOS fixture 曾因從 repo root 執行而失敗，於正確 `app/` 目錄重跑 1/1 PASS。
- **防線與授權**：v1／v1.1 guardrails checker PASS；v1.1 為 25 IMPLEMENTED、0 PARTIAL；25 元件 manifest 與 23/23 Python release／license tests PASS。
- **效能**：Intel i5-8259U 10 秒音訊 benchmark 4.132 秒，低於 4.924 秒回歸線與 60 秒需求線。
- **Release**：`flutter build macos --release` 成功；App `du` 606M，其中 sidecar 581M；FFmpeg 8.1.2 shared、`--disable-gpl --disable-nonfree`；ad-hoc 深層重簽後 strict codesign PASS，主程式 x86_64。
- **人工證據**：沿用使用者明示「真人驗收OK」；社群圖已取消，不列為缺口。受 30 秒上限影響未宣稱整支 `ci_core_checks.sh` 單次通過，而是如實記錄同源拆批結果。
- **完整報告**：`release/test-report-S10-20260716.md`；下一階段為 `project-archive`。
