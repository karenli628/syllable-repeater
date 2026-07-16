// AI-Generate
# Syllable Repeater macOS v1.1 — 任務拆分（task-split）

## 1. 本次任務拆分概覽

- **需求名稱**：Syllable Repeater macOS v1.1 增量
- **主依據**：
  - 後端：`../design/backend-design.md`（增量介面 20–38、核心防線 §4.4）
  - 前端：`../design/frontend-design.md`（增量功能點 9–17）
- **需求追溯**：`../requirement/requirement.md`（REQ-10～REQ-21、AT-10-*～AT-21-*）
- **硬性限制**：`../guardrails/hard-limits-matrix.md`（v1.1 #38～#61；v1 #1～#37 繼續有效）
- **涉及範圍**：後端＝純 Dart Domain＋infra／sidecar／Drift；前端＝Flutter macOS UI。
- **主要交付目標**：
  - 多句音檔可切成段落標籤、手動校正、匯出／載入 `.abolabel`，並把單一 Segment 送入既有分析流程。
  - 音節切點可增減與改字，波形／文字雙向高亮且編號一致；編輯後音節數成為練習步數基準（M11）。
  - 自訂排列可預覽、播放與匯出；0 列為完整單句 1 單元，N 列為 N 單元；M2 一鍵生成演算法不變（M1/M2/M3/M12）。
  - ASR＋Syllabifier 雙抽層，查無語言明確拒絕；僅允許本地 ASR（M13/M14、D7）。
  - 錄音固定單次原音比對，背景限點；RecordingBuffer 整體移除，temp finally 清除（M10）。
  - `.abopack v3` 複合封包與四層匯出來源 fail-closed。
  - REQ-10～REQ-21 全數交付；P0/P1/P2 只決定順序，不裁減範圍。

### 1.1 實作前文件漂移登錄

以下差異不得由 implementation 默默選邊；任務 1.1 完成前，受影響切片不得進入實作：

| 漂移 | 已核對事實 | 影響 | 處理 |
|---|---|---|---|
| DFT-01 | requirement r1、REQ-18、AT-18-04、backend/frontend design 均為 **10 分鐘**；核心驗收總表仍寫 30 分 01 秒，Q5 仍標待定 | REQ-18 驗收 | **已由 O4 既有裁決＋本次變更防線同步為 10:01；待驗證測試落地** |
| DFT-02 | matrix #43 仍寫 29:59／30:01 | guardrails #43 | **已同步改為 9:59／10:01；待驗證測試落地** |
| DFT-03 | matrix 專案上下文仍稱 fullstack-design 尚未開始 | 階段事實 | **已更新為設計／task-split 完成、目前 S0 implementation** |
| DFT-04 | frontend-design 自檢第 8 項仍稱 O3「需確認」，但 F2 已由使用者定案為 AI 譯文鈕一併搬移 | REQ-20 | **已清除舊待確認文字** |
| DFT-05 | REQ-19 寫「隨 .aboprogress 個人層記憶」；backend-design 介面 34 寫 `app_settings`，只共同確定「不進 .abopack」 | REQ-19 儲存契約 | **已由使用者裁決隨 `.aboprogress` 匯出／匯入；design 已同步，實作落在 7.1／FP16.* ** |
| DFT-06 | guardrails #47 要測「他 Lesson syllable 注入被拒」，但設計中的 `Syllable`／`PracticeBlock` 無 lessonId，僅 Arrangement 帶 lessonId | M1／Non-scope 12 | **使用者 2026-07-13 批准：`generateArrangement` 必傳 lessonId；`placeBlock` 必傳但不持久化 sourceLessonId，不符以 ArgumentError 拒絕；待 5.1 負向測試落地** |
| DFT-07 | `SegmentEngine.openAudio` 同時描述「拋 ERR_TRANSCRIBE_FAILED」與「仍回傳空 session」，非致命失敗的回傳契約未定 | REQ-11 降級流程 | **已由使用者裁決正常回傳空 session＋`LabelOpenWarning(ERR_TRANSCRIBE_FAILED)`；已補需求／設計／前端契約，待測試落地** |
| DFT-08 | `LabelSession.removeBoundary` 僅剩一段時要拒絕，但設計未指定錯誤碼；不得就近借用不相符錯誤碼 | 錯誤碼三同步 | **已由使用者裁決沿用 `ERR_BOUNDARY_INVALID`；已補設計、驗收與前端文案，待測試落地** |
| DFT-09 | `LabelPackEngine` 要存取 label_registry，但 backend-design 未定義 Domain→infra 的 repository port | M5 Domain 純度 | **已由使用者批准 `LabelRegistryRepository` Domain port；設計已補查詢／upsert 契約，待 3.4～3.6 實作** |
| DFT-10 | `AlignmentEngine.insertBoundary` 要計算 ±10ms 零交越吸附，但原介面未提供 PCM | REQ-13／M1 | **已由使用者 2026-07-13 批准新增 `required Pcm pcm`；前後端設計同步，Task 4.1/4.2 依此測試與實作** |

### 1.2 垂直切片與可展示終點

> S0 是安全前置，不算產品里程碑。第一個產品里程碑 S1 必須是一條真實端到端使用者流程；不得以「只有 schema／只有 port／只有靜態頁」收尾。

| 切片 | 可展示終點 | 後端任務 | 前端任務 |
|---|---|---|---|
| S0 防線基線 | v1 金標準與核心測試基線固定，文件漂移已裁決 | 1.1～1.4 | — |
| S1 最薄端到端 | 直接匯入金標準單句→新雙 Registry 路徑→畫面顯示 11 音節，時間戳與 v1 ±1ms | 2.1～2.5 | FP9.1、FP11.1～FP11.2 |
| S2 段落選句 | 匯入多句音檔→標籤線可調→存 `.abolabel`→選一段送單句分析 | 3.1～3.6 | FP10.1～FP10.4 |
| S3 校正閉環 | 新增／刪除切點與改字→編號同步→⌘Z 回復→練習步數跟著變 | 4.1～4.4 | FP12.1～FP12.3 |
| S4 自由排列 | 一鍵生成→拖曳成組→設定次數／靜音→列預覽逐 sample 仍為原音 | 5.1～5.4 | FP13.1～FP13.3 |
| S5 練習覆蓋 | 無排列／有排列／刪排列三態可切換，播放與匯出遵守 M1/M2/M3/M12 | 5.5～5.7 | FP14.1～FP14.2 |
| S6 錄音回聽 | 明示同意後可回聽；10 分鐘、切步、重啟與手動刪除皆會清掉 | 6.1～6.4 | FP15.1～FP15.3 |
| S7 顯示與佈局 | 1100×700 全功能可到達；四態字稿／譯文可記住；譯文入口搬移且設定頁其餘不變 | 7.1 | FP9.2、FP11.3、FP16.1～FP16.2 |
| S8 交付閘門 | 兩份 matrix 均無未處理項，完整 CI、授權與效能回歸通過 | 8.1～8.3 | FE-QA.1 |
| S9 實機回饋完整包 | 真實進度／就緒、範圍高亮、草稿期生成、直接拖曳與整組設定、完整 hidden、錄音真機回播全部可串接 demo | 9.1～9.5 | FP17.1、FP18.1～3、FP19.1～2、FP20.1～2、FE-QA.2 |

---

## 2. 後端任務清單（Domain＋infra）

> 編號使用「主分類.子任務」。所有演算法／核心防線任務一律先完成 TDD-red，再做 green 實作；未做的維持 `- [ ]`。

### 1. 契約同步與回歸基線（S0）

- [x] 1.1 **執行變更防線並同步修正 DFT-01～DFT-09**（完成：2026-07-13；OQ-1～OQ-7 契約均定案，DFT-01～09 已同步；guardrails／handoff／diff check PASS）
  - **File**：`../requirement/requirement.md`、`../design/backend-design.md`、`../design/frontend-design.md`、`../guardrails/hard-limits-matrix.md`
  - **Work**：先用 `fullstack-code-review` 的變更防線七題逐項呈報；只在使用者批准後修正 TTL、階段敘述、REQ-19 儲存契約與 DFT-06～09 設計缺口；目前九項皆已裁決／同步。
  - **Purpose**：在寫程式前恢復需求／設計／防線單一事實來源，避免 implementation 猜測。
  - **風險分層**：`[必須確認]`（受保護規格與 guardrails）
  - **Non-scope**：不改 v1 凍結目錄，不藉同步新增功能。
  - **驗證方式**：DFT-01～09 逐項關閉；`python3 scripts/check_guardrails.py <v1.1-matrix> <decision-log>` 通過。
  - _Requirements: REQ-11、REQ-18、REQ-19、REQ-20；M5/M10/M14；#43/#47/#48/#49_

- [x] 1.2 **建立 v1 行為特徵基線與金標準不變性測試**（完成：2026-07-13；domain 基線測試 12/12、benchmark 4.397s vs v1 4.689s，均 PASS）
  - **File**：`packages/domain/test/analysis_pipeline_test.dart`、`packages/domain/test/practice_build_steps_test.dart`、`packages/infra/bin/benchmark_alignment_pipeline.dart`、`app/test/e2e_pipeline_test.dart`
  - **Work**：在重構前固定 11 音節、10 切點、11 步、第 2 步 `tion skills`、時間戳與既有路徑；記錄 4.689s 基準的重跑方式。
  - **Purpose**：抽層或自訂功能不得改變 v1 行為。
  - **風險分層**：`[可直接做]`
  - **Non-scope**：不改任何 production 實作。
  - **驗證方式**：AT-17-01、AT-16-01/04、CT-01/CT-02；測試在重構前全綠。
  - _Requirements: REQ-16、REQ-17；M1/M2/M11/M12_

- [x] 1.3 **三同步新增 8 個 v1.1 錯誤碼與 UI 文案**（完成：2026-07-13；27 碼集合斷言與 UI 映射測試全綠）
  - **File**：`packages/domain/lib/src/errors.dart`、`app/lib/shared/error/error_messages.dart`、`packages/domain/test/model_test.dart`、`app/test/shared/error_messages_test.dart`（新）
  - **Work**：依 backend-design §3.2.8 新增 8 碼；錯誤碼總數由 19→27，補完整集合與 UI 映射碼數斷言。
  - **Purpose**：錯誤契約先就位，避免後續模組借用錯碼。
  - **風險分層**：`[需要回報]`（跨 Domain/UI 契約）
  - **Non-scope**：不新增 DFT-08 的第 9 個錯誤碼；沿用既有 `ERR_BOUNDARY_INVALID`。
  - **驗證方式**：backend-design §3.2.8 逐碼對照；27 碼映射測試全綠。
  - _Requirements: REQ-11、REQ-13、REQ-15、REQ-17、REQ-18_

- [x] 1.4 **【TDD-red】擴充 Domain 純度、TTS 黑名單與本地 ASR policy 測試**（完成：2026-07-13；新增 policy 負向掃描 2/2 PASS，既有 domain purity 遞迴涵蓋新 port）
  - **File**：`packages/domain/test/domain_purity_test.dart`、`packages/domain/test/transcriber_policy_test.dart`（新）
  - **Work**：先寫會紅的結構掃描：新 port 不得 import `dart:io/ffi/html`、Flutter、infra；Transcriber 鏈路不得出現 HTTP client／URL 欄；workspace pubspec 禁 TTS 類依賴。
  - **Purpose**：在抽層前先裝上 #41/#45/#46 自動阻擋。
  - **風險分層**：`[必須確認]`（`domain_purity_test.dart` 是防線本體）
  - **Non-scope**：不修改既有測試來放寬 M5。
  - **驗證方式**：#41/#45/#46 的負向 fixture 會被擋；合法 Domain 檔案可通過。
  - _Requirements: REQ-12、REQ-17；M5/M13；#41/#45/#46_

### 2. 雙抽層與單句最薄路徑（S1）

- [x] 2.1 **【TDD-red】建立雙 Registry fail-closed 與金標準契約測試**（完成：2026-07-13；先因新型別不存在而紅，2.2 後 AT-17-01～03 轉綠）
  - **File**：`packages/domain/test/transcriber_registry_test.dart`（新）、`packages/domain/test/syllabifier_registry_test.dart`（新）
  - **Work**：測 en 雙表放行、ja 缺切分器拒絕、部分支援仍拒、錯誤附已註冊語言；金標準走新 Syllabifier 仍為 11。
  - **Purpose**：先鎖住 M13/M14，再搬動既有切分邏輯。
  - **風險分層**：`[可直接做]`
  - **Non-scope**：不實作非英文切分器。
  - **驗證方式**：AT-17-01～03；#41/#44（測試先紅）。
  - _Requirements: REQ-17_

- [x] 2.2 **實作 TranscriberEngine／Syllabifier ports、Registries 與 EnglishSyllabifier**（完成：2026-07-13；Domain 90/90 PASS、analyze PASS）
  - **File**：`packages/domain/lib/src/ports/transcriber_engine.dart`（新）、`packages/domain/lib/src/ports/syllabifier.dart`（新）、`packages/domain/lib/src/analysis/transcriber_registry.dart`（新）、`packages/domain/lib/src/alignment/syllabifier_registry.dart`（新）、`packages/domain/lib/src/alignment/english_syllabifier.dart`（新）、`packages/domain/lib/domain.dart`
  - **Work**：採「先包舊碼、測試轉綠，再搬移」兩步；每個公開類別／方法附繁中規格註解；集合不可變。
  - **Purpose**：換 adapter 不改 Domain，且不默默 fallback。
  - **風險分層**：`[需要回報]`（核心抽層）
  - **Non-scope**：不加線上 API、模型下載或其他語言實作。
  - **驗證方式**：2.1 轉綠、AT-17-06、`dart test packages/domain/test`。
  - _Requirements: REQ-17；M5/M13/M14；#41/#44/#46_

- [x] 2.3 **讓 AnalysisPipeline 的所有建課件入口先雙查 Registry**（完成：2026-07-13；ja 缺任一 Registry 時解碼呼叫 0 次）
  - **File**：`packages/domain/lib/src/analysis/analysis_pipeline.dart`、`packages/domain/test/analysis_pipeline_test.dart`
  - **Work**：以 TranscriberEngine／Syllabifier 注入取代寫死切分；介面 1 與未來介面 20 在任何副作用前先驗 language。
  - **Purpose**：把 M14 fail-closed 放在唯一入口。
  - **風險分層**：`[需要回報]`（既有核心流程重構）
  - **Non-scope**：不改 v1 對齊演算法與重入鎖語意。
  - **驗證方式**：AT-17-01～03、AT-12-01、AT-12-05；時間戳 ±1ms。
  - _Requirements: REQ-12、REQ-17；#39/#41/#44_

- [x] 2.4 **對齊 Whisper 本地 adapter 與 segment 級時間戳**（完成：2026-07-13；Domain＋infra 169 PASS／1 skip，analyze PASS）
  - **File**：`packages/infra/lib/src/analysis/analysis_pipeline_adapters.dart`、`packages/infra/lib/src/sidecar/whisper_transcriber.dart`、`packages/infra/test/whisper_transcriber_test.dart`、`packages/infra/test/analysis_pipeline_adapters_test.dart`、`app/lib/shared/infra/infra_analysis_runner.dart`
  - **Work**：既有 Whisper adapter 對齊新 port；解析既有 JSON segment offsets；只經 ProcessRunner 呼叫本地 sidecar。
  - **Purpose**：完成 S1 真實 adapter 接線並供 REQ-11 段落切句重用。
  - **風險分層**：`[需要回報]`（sidecar 契約）
  - **Non-scope**：不新增網路 client、不自動下載模型、不更換 small.en。
  - **驗證方式**：AT-17-01/05；#46；Intel 16k mono＋`--no-gpu` 回歸。
  - _Requirements: REQ-11、REQ-17；M4/M9/M13_

- [x] 2.5 **完成 S1 端到端與效能回歸**（完成：2026-07-13；真檔 UI e2e PASS；4.189s vs v1 4.689s，PASS）
  - **File**：`app/test/e2e_pipeline_test.dart`、`packages/infra/test/analysis_pipeline_integration_test.dart`、`packages/infra/bin/benchmark_alignment_pipeline.dart`
  - **Work**：直接匯入金標準單句走新 port→adapter→UI 資料流；比較 v1 直呼基線。
  - **Purpose**：第一個里程碑必須可 demo 使用者完成一個動作。
  - **風險分層**：`[可直接做]`
  - **Non-scope**：不以 fake-only 測試取代真 sidecar 可用環境的整合測試。
  - **驗證方式**：AT-12-01、AT-17-01；11 音節、±1ms、效能劣化 ≤5%。
  - _Requirements: REQ-12、REQ-17_

### 3. 段落標籤與 .abolabel（S2）

- [x] 3.1 **【TDD-red】建立 Segment／LabelSession 不變式與 dirty 狀態機測試**（完成：2026-07-13；先紅後綠，AT-11-02/04/06/09 已鎖定）
  - **File**：`packages/domain/test/label_session_test.dart`（新）
  - **Work**：測單調不重疊、500ms 兩側、移動／插入／合併、undo、dirty→saved、僅剩一段拒絕與 ASR 失敗降級契約。
  - **Purpose**：先鎖住資料保護與邊界規則。
  - **風險分層**：`[可直接做]`
  - **Non-scope**：不做多層巢狀標籤。
  - **驗證方式**：AT-11-02/04/06；#48（測試先紅）。
  - _Requirements: REQ-11_

- [x] 3.2 **實作 Segment、LabelSession 與 SegmentEngine**（完成：2026-07-13；Domain 102/102 PASS、purity／analyze PASS）
  - **File**：`packages/domain/lib/src/model/segment.dart`（新）、`packages/domain/lib/src/labeling/label_session.dart`（新）、`packages/domain/lib/src/labeling/segment_engine.dart`（新）、`packages/domain/lib/domain.dart`
  - **Work**：openAudio、指紋、雙 Registry、可選人聲分離、手動操作與共用重入鎖；依 1.1 對 DFT-07/08 的裁決實作非致命錯誤。
  - **Purpose**：Domain 層提供自動切句＋全手動兜底。
  - **風險分層**：`[需要回報]`（新聚合根與跨模組流程）
  - **Non-scope**：不新增 VAD sidecar；800ms 閾值只按 OQ-1 實測裁決。
  - **驗證方式**：3.1 轉綠、AT-11-01/02/05～08。
  - _Requirements: REQ-11；M4/M5/M14_

- [x] 3.3 **【TDD-red】建立 .abolabel round-trip／損毀／指紋不符測試**（完成：2026-07-13；先紅後綠，AT-11-03/#49 已鎖定）
  - **File**：`packages/domain/test/label_pack_engine_test.dart`（新）
  - **Work**：先測 schemaVersion、language、separateVocals、segments、全檔驗證、零副作用、原子寫入與指紋 mismatch。
  - **Purpose**：格式防線先於讀寫實作。
  - **風險分層**：`[可直接做]`
  - **Non-scope**：不支援巢狀 Segment 或音訊內嵌。
  - **驗證方式**：AT-11-03；#49（測試先紅）。
  - _Requirements: REQ-11_

- [x] 3.4 **實作 LabelPackEngine 與 label registry Domain port**（完成：2026-07-13；18/18 targeted PASS、purity／analyze PASS）
  - **File**：`packages/domain/lib/src/pack/label_pack_engine.dart`（新）、`packages/domain/lib/src/ports/label_registry_repository.dart`（新）、`packages/domain/lib/domain.dart`
  - **Work**：依 1.1 對 DFT-09 的裁決注入 repository；write 走 FileIo 原子寫入，read 先全檔驗證再回傳。
  - **Purpose**：保持 Domain 純 Dart，又能索引最近標籤檔。
  - **風險分層**：`[需要回報]`（新增內部 port）
  - **Non-scope**：不讓 Domain import Drift 或 dart:io。
  - **驗證方式**：3.3 轉綠、AT-11-03、#49、domain purity。
  - _Requirements: REQ-11；M5_

- [x] 3.5 **建立 Drift V3 label_registry schema 與結構斷言**（完成：2026-07-13；使用者批准後實作，schema／migration／結構測試 12/12 PASS）
  - **File**：`packages/infra/lib/db/schema/V3__v11_label_registry.sql`（新）、`packages/infra/lib/src/db/app_database.dart`、`packages/infra/lib/src/db/app_database.g.dart`、`packages/infra/test/db_schema_test.dart`
  - **Work**：新增 label_registry 四欄與主鍵；generated code 由 build_runner 產生；斷言無音訊／錄音欄位。
  - **Purpose**：重匯入同指紋音檔時能找到既有 .abolabel。
  - **風險分層**：`[必須確認]`（schema／migration；`db_schema_test.dart` 為防線本體）
  - **Non-scope**：不修改既有表，不建 RecordingBuffer 表。
  - **驗證方式**：backend-design §3.1.2 逐欄；AT-11-03；M10 結構測試。
  - _Requirements: REQ-11；#43/#49_

- [x] 3.6 **實作 DriftLabelRegistryRepository 並完成標籤整合測試**（完成：2026-07-13；真檔案＋Drift 整合 15/15 PASS，Domain 107/107、infra 85 PASS／1 skip）
  - **File**：`packages/infra/lib/src/db/drift_label_registry_repository.dart`（新）、`packages/infra/test/drift_label_registry_repository_test.dart`（新）、`packages/infra/test/label_pack_integration_test.dart`（新）、`packages/infra/lib/infra.dart`
  - **Work**：fingerprint 查詢／upsert；標籤檔不存在或損毀時 fail-closed，不污染現有 session。
  - **Purpose**：完成 S2 的 Domain↔infra 連接。
  - **風險分層**：`[需要回報]`（DB adapter）
  - **Non-scope**：不做雲端標籤庫或跨裝置索引。
  - **驗證方式**：AT-11-03/04、#48/#49。
  - _Requirements: REQ-11_

### 4. 音節切點增減與 M11（S3）

- [x] 4.1 **【TDD-red】建立 remove／insert／updateText 與兩側邊界測試**（完成：2026-07-13；缺少三個 production API 導致編譯失敗，紅燈證據 exit 1）
  - **File**：`packages/domain/test/alignment_edit_test.dart`（新）
  - **Work**：覆蓋 1 音節下限、50ms 的 49/51ms 兩側、透過使用者批准的 `required Pcm pcm` 做零交越吸附、後半空白 needsReview、originalText、四步 undo 快照。
  - **Purpose**：先定義 REQ-13 行為與錯誤。
  - **風險分層**：`[可直接做]`
  - **Non-scope**：不改既有拖動切點規則。
  - **驗證方式**：AT-13-01～06（測試先紅）。
  - _Requirements: REQ-13_

- [x] 4.2 **實作 AlignmentEngine 增減／改字與模型佐證欄**（完成：2026-07-13；AT-13-01～06、完整 Domain 118/118 與 analyze PASS）
  - **File**：`packages/domain/lib/src/alignment/alignment_engine.dart`、`packages/domain/lib/src/model/syllable.dart`、`packages/domain/lib/src/model/alignment_result.dart`、`packages/domain/lib/src/model/lesson.dart`
  - **Work**：回傳 immutable 新結果；originalText 首次編輯保存；入口驗證訊息含實際值。
  - **Purpose**：完成可撤銷的校正 Domain 操作。
  - **風險分層**：`[需要回報]`（核心模型變更）
  - **Non-scope**：不把 undo stack 放進 Domain 引擎，不引入 Flutter 狀態。
  - **驗證方式**：4.1 轉綠、AT-13-01～06。
  - _Requirements: REQ-13_

- [x] 4.3 **【TDD-red→green】鎖住編輯後步數與 M2 不變性**（完成：2026-07-13；10/12 步、全 suffix 與 `tion skills`，10/10 PASS）
  - **File**：`packages/domain/test/practice_build_steps_test.dart`
  - **Work**：11→刪 1＝10 步、加 1＝12 步；每個 n 仍是句尾倒數 n 音節；第 2 步仍 `tion skills`。
  - **Purpose**：落地 guardrails #39。
  - **風險分層**：`[可直接做]`
  - **Non-scope**：不修改 `buildSteps` 演算法或加入 word boundary。
  - **驗證方式**：AT-13-07、AT-16-04、#39。
  - _Requirements: REQ-13、REQ-16；M2/M11_

- [x] 4.4 **建立音節變更→Arrangement stale 的協調契約**（完成：2026-07-13；目標 30/30、完整 App 79/79 PASS）
  - **File**：`packages/domain/lib/src/model/practice_arrangement.dart`（由 5.2 新增）、`app/lib/features/editor/editor_controller.dart`、對應測試
  - **Work**：增減成功後只置 stale，不自動改排列；使用者重生成或明示保留才清旗標。
  - **Purpose**：避免校正後自訂內容被靜默覆寫。
  - **風險分層**：`[需要回報]`（跨 editor／arrangement）
  - **Non-scope**：不在切點拖動但總數未變時誤標 stale。
  - **驗證方式**：AT-15-08、AT-13-04。
  - _Requirements: REQ-13、REQ-15_

### 5. PracticeArrangement 與練習覆蓋（S4/S5）

- [x] 5.1 **【TDD-red】建立 Arrangement 型別不變式、操作與跨 Lesson 注入測試**（完成：2026-07-13；首次執行因缺少模型與介面而編譯失敗，exit 1）
  - **File**：`packages/domain/test/practice_arrangement_test.dart`（新）
  - **Work**：測 N 列初始、插刪列、重複放置、同列相鄰成組、組內排序、設定 1–10／0–5 兩側、獨立 undo；依 DFT-06 補足的型別契約測跨 Lesson 必拒。
  - **Purpose**：先鎖住 M11、Non-scope 12 與 #47。
  - **風險分層**：`[可直接做]`（DFT-06 裁決後）
  - **Non-scope**：不做跨列堆疊或跨 Lesson 拼接。
  - **驗證方式**：AT-15-01～04/06/08；#47（測試先紅）。
  - _Requirements: REQ-15；M11_

- [x] 5.2 **實作 PracticeBlock／Row／Arrangement 與聚合操作**（完成：2026-07-13；目標 16/16、完整 Domain 136/136 PASS）
  - **File**：`packages/domain/lib/src/model/practice_arrangement.dart`（新）、`packages/domain/lib/src/practice/practice_engine.dart`、`packages/domain/lib/domain.dart`
  - **Work**：immutable 模型、List.unmodifiable、named parameters、設定驗證；Arrangement 綁單一 Lesson 的結構防線。
  - **Purpose**：提供自由編排的唯一 Domain 狀態。
  - **風險分層**：`[需要回報]`（核心模型）
  - **Non-scope**：不加入音訊生成、TTS、跨來源欄位。
  - **驗證方式**：5.1 轉綠、AT-15-01～04/06/08、#47。
  - _Requirements: REQ-15；M1/M11_

- [x] 5.3 **【TDD-red】建立 renderBlockRow 逐 sample 與靜音計數測試**（完成：2026-07-13；因缺少 `renderBlockRow` 編譯失敗，exit 1）
  - **File**：`packages/domain/test/practice_arrangement_render_test.dart`（新）
  - **Work**：以 `[itll, rain, itll+rain]` 驗來源 sample、數位零、重複展開、650ms×3＝1950ms 靜音、端點 ≤10ms micro-fade 例外。
  - **Purpose**：在新播放路徑出現前鎖住 M1/M3。
  - **風險分層**：`[可直接做]`
  - **Non-scope**：不把 TTS、重採樣或跨來源 PCM 放進 renderer。
  - **驗證方式**：AT-15-04/05/09、#42（測試先紅）。
  - _Requirements: REQ-15；M1/M3_

- [x] 5.4 **實作 renderBlockRow 並重用 renderStep 原聲路徑**（完成：2026-07-13；目標 13/13、完整 Domain 141/141 PASS）
  - **File**：`packages/domain/lib/src/practice/practice_engine.dart`、`packages/domain/lib/src/practice/practice_export_audio.dart`
  - **Work**：copy sourceRanges→串接→重複→數位零靜音→零交越／micro-fade；排列變更採 runId 取消或舊快照播完。
  - **Purpose**：列預覽與後續匯出共用唯一合法渲染語意。
  - **風險分層**：`[需要回報]`（M1 核心音訊路徑）
  - **Non-scope**：不建立第二條渲染實作。
  - **驗證方式**：5.3 轉綠、CT-01、AT-15-07/09、#42。
  - _Requirements: REQ-15_

- [x] 5.5 **【TDD-red】建立 effectiveUnits 三態與自動模式回歸測試**（完成：2026-07-13；因介面 30 與型別尚不存在而編譯失敗，exit 1）
  - **File**：`packages/domain/test/practice_effective_units_test.dart`（新）
  - **Work**：null→auto、存在→custom、刪除→auto；stale 透傳；auto 第 2 步與 M3 靜音分毫不差。
  - **Purpose**：先鎖住 M12 唯一判定入口。
  - **風險分層**：`[可直接做]`
  - **Non-scope**：不讓 UI 自行重做 mode 判定。
  - **驗證方式**：AT-16-01～05、#40（測試先紅）。
  - _Requirements: REQ-16；M2/M3/M12_

- [x] 5.6 **實作 effectiveUnits 與自訂模式匯出整合**（完成：2026-07-13；Domain 145/145、infra 87 PASS＋1 skip）
  - **File**：`packages/domain/lib/src/practice/practice_engine.dart`、`packages/domain/lib/src/practice/practice_export_audio.dart`、`packages/infra/lib/src/practice/practice_exporter.dart`
  - **Work**：所有 v1 直呼 buildSteps 的消費端改經 effectiveUnits；auto 沿用 totalDurationMs，custom 依 block silenceFactor。
  - **Purpose**：播放與匯出只由一個 mode 判定入口決定內容。
  - **風險分層**：`[需要回報]`（跨 Domain／infra 匯出）
  - **Non-scope**：不改 auto 模式編碼、格式或靜音規則。
  - **驗證方式**：5.5 轉綠、AT-16-01～06、#40。
  - _Requirements: REQ-16_

- [x] 5.7 **升級 .abopack schemaVersion 2 並相容 v1**（完成：2026-07-13；Domain 146/146、infra 87 PASS＋1 skip）
  - **File**：`packages/domain/lib/src/model/lesson.dart`、`packages/domain/lib/src/pack/lesson_pack_engine.dart`、`packages/domain/test/lesson_pack_engine_test.dart`
  - **Work**：加入 language／arrangement；v2 讀 v1 缺欄補 en＋null；v1 讀 v2 明確拒絕；contentHash 規則依設計同步。
  - **Purpose**：自訂排列與語言標記能隨 Lesson 保存。
  - **風險分層**：`[必須確認]`（持久格式 schema 變更）
  - **Non-scope**：不改 v1 已產檔案，不把顯示偏好或錄音放進 pack。
  - **驗證方式**：AT-17-04、AT-19-04、pack round-trip／corrupt tests。
  - _Requirements: REQ-15、REQ-17、REQ-19；M10/M14_

### 6. RecordingBuffer（S6，歷史已完成；v1.1-r6 由 10.6 明確撤回並移除）

- [x] 6.1 **【TDD-red】建立同意、TTL、切步、覆蓋、重啟清除測試**（完成：2026-07-13；production 尚未存在，紅測試 exit 1）
  - **File**：`packages/domain/test/recording_buffer_service_test.dart`（新）
  - **Work**：預設不呼叫 stash；9:59 可播／10:01 已清；同 context 覆蓋；purgeContext／purgeAll；不可寫失敗不阻斷。
  - **Purpose**：在檔案寫入前鎖住 M10 補述。
  - **風險分層**：`[可直接做]`（1.1 同步 TTL 後）
  - **Non-scope**：不開放 TTL 設定、不保留跨 App 生命週期錄音。
  - **驗證方式**：AT-18-02～07、#43（測試先紅）。
  - _Requirements: REQ-18；M10_

- [x] 6.2 **實作 RecordingBufferEntry、Service 與暫存 IO port**（完成：2026-07-13；目標 6/6、完整 Domain 152/152 PASS）
  - **File**：`packages/domain/lib/src/model/recording_buffer_entry.dart`（新）、`packages/domain/lib/src/recording/recording_buffer_service.dart`（新）、`packages/domain/lib/src/ports/recording_buffer_store.dart`（新）、`packages/domain/lib/domain.dart`
  - **Work**：Clock 注入；stash/list/play/delete/purge*；白名單路徑由 port 保證；集合不可變。
  - **Purpose**：Domain 可測且無 dart:io。
  - **風險分層**：`[需要回報]`（隱私與檔案生命週期）
  - **Non-scope**：不把 pcmPath 加入 Attempt／audit_log／pack／progress 模型。
  - **驗證方式**：6.1 轉綠、AT-18-01～07、M5。
  - _Requirements: REQ-18_

- [x] 6.3 **實作 TempRecordingBufferStore 與孤兒清掃**（完成：2026-07-13；目標 6/6、infra 非 sidecar 90/90＋1 skip）
  - **File**：`packages/infra/lib/src/recording/temp_recording_buffer_store.dart`（新）、`packages/infra/test/temp_recording_buffer_store_test.dart`（新）、`packages/infra/lib/infra.dart`
  - **Work**：唯一根目錄為 getTemporaryDirectory/recording_buffer；temp→rename；路徑越界拒絕；刪除放 finally；purgeAll 清孤兒。
  - **Purpose**：把錄音暫存限制在可清除的 OS temp 範圍。
  - **風險分層**：`[必須確認]`（刪除／覆蓋暫存錄音資料）
  - **Non-scope**：不刪除白名單目錄以外任何檔案。
  - **驗證方式**：AT-18-04～07、#43；越界 fixture 必拒。
  - _Requirements: REQ-18_

- [x] 6.4 **擴充 DB／pack／progress 結構負向防線**（完成：2026-07-13；負向目標 22/22、Domain 153/153、infra 非 sidecar 90/90＋1 skip）
  - **File**：`packages/infra/test/db_schema_test.dart`、`packages/domain/test/lesson_pack_engine_test.dart`、`packages/domain/test/progress_import_export_test.dart`
  - **Work**：斷言所有表無錄音／路徑欄，pack/progress byte 掃描不含暫存檔名或音訊；不勾同意仍走 v1 finally 刪除。
  - **Purpose**：讓錄音不持久化是結構事實，不是提醒。
  - **風險分層**：`[必須確認]`（`db_schema_test.dart` 為防線本體）
  - **Non-scope**：不放寬 v1 M10 測試。
  - **驗證方式**：AT-18-02/03/05、CT-10、#43。
  - _Requirements: REQ-18_

### 7. 顯示模式偏好（S7）

- [x] 7.1 **實作 TranscriptDisplayMode 與每 Lesson 儲存契約**（完成：2026-07-13；新增驗證 6/6、Domain 157/157、infra 非 sidecar 92/92＋1 skip）
  - **File**：`packages/domain/lib/src/model/settings.dart`、`packages/domain/lib/src/ports/settings_service.dart`（新）、`packages/infra/lib/src/db/drift_settings_service.dart`（新）、`packages/domain/test/progress_settings_test.dart`、`packages/infra/test/drift_settings_service_test.dart`（新）
  - **Work**：依已裁決契約將 `transcriptDisplayModes` 納入 `.aboprogress`；預設 `transcript`；每 Lesson key 隔離；永不進 `.abopack`。
  - **Purpose**：四態顯示可在同課件重開後恢復。
  - **風險分層**：`[必須確認]`（儲存契約尚有需求／設計衝突）
  - **Non-scope**：不把偏好分享給其他使用者或寫進課件本體。
  - **驗證方式**：AT-19-03/04。
  - _Requirements: REQ-19_

### 8. Guardrails、授權與交付閘門（S8）

- [x] 8.1 **文件化新 ASR 引擎上架五步驟**（完成：2026-07-13；Python gate 23/23 PASS、既有 manifest 25 components PASS）
  - **File**：`docs/codex/commands.md`、release checklist（依 1.1 補定落點）、`scripts/check_licenses.py` 既有 gate 的測試
  - **Work**：adapter→授權審查→M4 故障注入→基準回歸→Registry 註冊；確認新引擎／模型 manifest 三元組。
  - **Purpose**：補完 guardrails #50 的流程防線。
  - **風險分層**：`[需要回報]`（發布合規）
  - **Non-scope**：不新增任何實際 ASR 引擎或下載來源。
  - **驗證方式**：#50；CT-09；`python3 scripts/test_check_licenses.py`。
  - _Requirements: REQ-17；M9_

- [x] 8.2 **依切片回寫 v1.1 matrix 狀態與證據**（完成：2026-07-14；IMPLEMENTED 13、PARTIAL 0、BLOCKED 0；checker PASS）
  - **File**：`../guardrails/hard-limits-matrix.md`、`../guardrails/decision-log.md`
  - **Work**：#39～#50 逐條以測試／schema／檔案證據更新；PARTIAL/BLOCKED 只在實際完成時轉 IMPLEMENTED；重算統計。
  - **Purpose**：硬性限制沒有空頭支票。
  - **風險分層**：`[需要回報]`（防線狀態）
  - **Non-scope**：AI 不自批不適用、不刪 matrix 行。
  - **驗證方式**：`check_guardrails.py` 通過；每項證據路徑存在。
  - _Requirements: M1/M9～M14；#39～#50_

- [x] 8.3 **完整 CI、效能與真機 smoke 收尾**（完成：2026-07-16；依環境上限拆批全綠，Intel 基準 4.132 秒，真人驗收已由使用者確認）
  - **File**：`task/execution-log.md`（新）、`scripts/ci_core_checks.sh`（只執行，除非另經批准修正）
  - **Work**：逐切片記錄 red→green；最後跑 domain／infra／app tests、analyze、license、兩份 guardrails；Intel 基準與 1100×700 GUI smoke 由使用者親跑項照實標記。
  - **Purpose**：程式完成不等於產品完成。
  - **風險分層**：`[需要回報]`
  - **Non-scope**：不為過 gate 修改測試或 guardrails 腳本。
  - **驗證方式**：`bash scripts/ci_core_checks.sh` PASS；AT-10-01～05；AT-11-01；AT-17-01；未親跑項不得勾選。
  - _Requirements: REQ-10～REQ-20_

### 9. 2026-07-14 實機回饋增量（S9）

- [x] 9.1 **【TDD-red】鎖定組塊整組重複與 M3 新設定範圍**（完成：2026-07-14；紅測試 4 項如期失敗，實作後 targeted 33/33 PASS）
  - **File**：`packages/domain/test/practice_arrangement_test.dart`、`packages/domain/test/practice_arrangement_render_test.dart`、`packages/domain/test/lesson_pack_engine_test.dart`
  - **Work**：先寫紅測試：`aftern+oon` 3 次必為 `[afternoon]×3`；預設／重置／成組／拆組皆 3／5；repeat 1–10、silence 0–20 且 step0.5 兩側；既有 pack 的 0–5 值原值 round-trip。
  - **Purpose**：先鎖住 M1/M3，再改模型常數與 renderer。
  - **風險分層**：`[需要回報]`（M1/M3 核心音訊規則）
  - **Non-scope**：不改 auto 模式 M2/M3，不加入 TTS／重採樣／跨 Lesson。
  - **驗證方式**：AT-15-04/06/09/11；guardrails #42/#51，先紅後綠。
  - _Requirements: REQ-15；M1/M3_

- [x] 9.2 **實作 PracticeBlock 3／5 契約、整組 renderer 與 DraftLessonIdentity**（完成：2026-07-14；Domain 22/22、相關 widget 10/10 PASS）
  - **File**：`packages/domain/lib/src/model/practice_arrangement.dart`、`packages/domain/lib/src/practice/practice_engine.dart`、`app/lib/features/import_analysis/analysis_controller.dart`、`app/lib/features/editor/editor_controller.dart`、`app/lib/features/library/lesson_pack_service.dart`
  - **Work**：單一定義設定常數；group/ungroup/reset 套 3／5；先串整組再 repeat；分析成功建立一次 draft lessonId，generate／save 沿用，跨 Lesson 驗證不放寬。
  - **Purpose**：修復尚未存 pack 時一鍵生成無反應，並確保組塊的聲音語意正確。
  - **風險分層**：`[需要回報]`（Domain 模型＋跨 feature 身分）
  - **Non-scope**：不改 `.abopack` schemaVersion、不遷移舊值、不允許跨 Lesson。
  - **驗證方式**：9.1 轉綠；AT-15-11/12；guardrails #42/#47/#51/#53。
  - _Requirements: REQ-15；M1/M3_

- [x] 9.3 **【TDD-red→green】實作真實匯入／段落階段事件與 ready 狀態機**（完成：2026-07-14；Domain 166/166、infra targeted 2/2、App targeted 11/11 PASS）
  - **File**：`packages/domain/lib/src/labeling/segment_engine.dart`、`packages/domain/lib/src/analysis/`、`packages/domain/lib/src/ports/audio_import_reader.dart`（新）、`packages/infra/lib/src/analysis/`、對應 domain/infra tests
  - **Work**：SegmentEngine 由真實完成點回報 progress；AudioImportReader 逐 chunk 回報 bytes，完成非空／格式／時長驗證後才 ready；以可控 completer 阻塞每階段，斷言進度不越級；移除假百分比來源。
  - **Purpose**：M15 讓畫面進度與系統真實狀態一致。
  - **風險分層**：`[需要回報]`（分析／IO 長任務契約）
  - **Non-scope**：不臆造 sidecar 內部百分比；無資料時只顯示 indeterminate 階段。
  - **驗證方式**：AT-11-10、AT-12-06～08；guardrails #52。
  - _Requirements: REQ-11、REQ-12；M15_

- [x] 9.4 **【TDD-red→green】修正 macOS 錄音後回播工作階段與 temp 生命週期**（完成：2026-07-14；targeted 22/22 PASS，待 Finder smoke）
  - **File**：`app/lib/features/practice/practice_player.dart`、`app/lib/features/practice/practice_recording.dart`、`app/lib/features/practice/practice_controller.dart`、對應 tests
  - **Work**：測試 stop recorder→deactivate record→activate playback→等待 processingState completed→finally 刪 temp；錯誤進 state；連播兩次。必要時只加入官方 `audio_session` 配套。
  - **Purpose**：修復真機錄音檔存在但播放無聲。
  - **風險分層**：`[需要回報]`（macOS 音訊生命週期＋暫存刪除）
  - **Non-scope**：不延長 10 分鐘 TTL、不保留跨單元／重啟錄音、不更換播放器。
  - **驗證方式**：AT-18-01～08；guardrails #43；Finder 正式 App smoke。
  - _Requirements: REQ-18；M10_

- [x] 9.5 **回寫增量 guardrails 與完整交付閘門**（完成：2026-07-16；v1／v1.1 matrix、授權、analyze、拆批測試與 Release gate 全綠）
  - **File**：`../guardrails/hard-limits-matrix.md`、`task/execution-log.md`
  - **Work**：#42/#43/#51～#53 只有在證據全綠後轉 IMPLEMENTED；跑完整 CI、license、兩份 matrix、Finder smoke，記錄 red→green。
  - **Purpose**：完整變更包不能以局部 widget test 代替交付。
  - **風險分層**：`[需要回報]`
  - **Non-scope**：不修改測試／gate 來換綠燈；未親跑 Finder 項不勾選。
  - **驗證方式**：`bash scripts/ci_core_checks.sh` PASS；AT-11-10、AT-12-06～08、AT-15-10～12、AT-18-08、AT-19-05。
  - _Requirements: REQ-11、REQ-12、REQ-14～REQ-19_

- [x] 9.6 **【TDD-red→green】重寫積木／整列／M12 單元 Domain 契約**（完成：2026-07-16；最終 1／1、3／1 與 0/N 列契約由 S10.4／10.9 覆蓋）
  - **File**：`packages/domain/lib/src/model/practice_arrangement.dart`、`packages/domain/lib/src/model/practice_units.dart`、`packages/domain/lib/src/practice/practice_engine.dart`、對應 Domain tests
  - **Work**：此任務原列的 1／3、3／3 已由 r6 取代；現行執行內容移至 10.4（1／1、3／1、自然接合）。0 列／N 列與 M2 不變部分仍有效。
  - **Purpose**：先用 sample 長度與來源測試鎖定兩層播放語意與 M1/M2/M3/M12。
  - **風險分層**：`[需要回報]`
  - **Non-scope**：不加入生成音、不跨 Lesson、不改自動句尾疊加演算法本身。
  - **驗證方式**：AT-15-04/05/09/11/13、AT-16-01～05；guardrails #40/#42/#51/#55。
  - _Requirements: REQ-15、REQ-16；M1/M2/M3/M12_

- [x] 9.7 **實作練習連動與匯出逐單元覆寫**（完成：2026-07-16；預覽、練習、匯出共用 renderer，覆寫不回寫排列）
  - **File**：`app/lib/features/arrangement/`、`app/lib/features/practice/`、`app/lib/features/export/export_dialog.dart`、`packages/infra/lib/src/practice/practice_exporter.dart`、對應 tests
  - **Work**：列設定按鈕／停止方框；草稿排列直接驅動練習；右上 ×N 代表目前 row；匯出逐單元 override 初值帶 row、只存本次 dialog snapshot；多單元 M3 gap 保留。
  - **Purpose**：讓自由排列、預覽、練習與匯出使用同一套可驗證的 Domain renderer。
  - **風險分層**：`[需要回報]`
  - **Non-scope**：匯出 override 不持久化、不回寫排列、不增加第四層 repeat。
  - **驗證方式**：AT-15-14、AT-16-02/03/05/08/09；widget＋infra targeted tests。
  - _Requirements: REQ-15、REQ-16；M3/M12_

- [x] 9.8 **【TDD-red→green】統一波形節點區段、高亮、插點與預覽**（完成：2026-07-15；自動測試與真人驗收均通過）
  - **File**：`app/lib/features/editor/`、`packages/domain/lib/src/alignment/`、對應 tests
  - **Work**：第一段 `0..node1`、中段 `nodeN..nodeN+1`、最後段 `lastNode..pcm.duration`；選取高亮、最後區間新增切點、積木播放全部共用同一 mapper。
  - **Purpose**：修復首段黃色缺角、尾段無法新增節點與最後積木播放不完整。
  - **風險分層**：`[需要回報]`
  - **Non-scope**：不變更 M1 來源、不新增單字邊界吸附。
  - **驗證方式**：首／中／尾區段 pixel hit test、insertBoundary 邊界測試、完整 sample 預覽；guardrails #54。
  - _Requirements: REQ-13、REQ-15；M1/M11_

- [x] 9.9 **修正錄音 WAV 正規化與 Demucs 聲道完整性**（完成：2026-07-15；正規化、聲道測試、AAA 診斷與真人麥克風通過）
  - **File**：`app/lib/features/practice/practice_recording.dart`、`packages/infra/lib/src/analysis/analysis_pipeline_adapters.dart`、對應 tests
  - **Work**：錄音停止後用受控 FFmpeg 轉 PCM 16-bit mono WAV 再 decode，全部 temp finally 清理；Demucs 前轉檔不指定 `-ac`，保留來源 channels（stereo 保留雙聲道，mono 保持單聲道），mono 不虛構可完全分離；輸出 AAA 診斷音檔。
  - **Purpose**：處理真機 `only PCM 16-bit mono WAV supported`，並避免立體聲來源在分離前遺失空間資訊。
  - **風險分層**：`[需要回報]`
  - **Non-scope**：不更換／下載模型、不導入 Python／GPL release、不保存錄音。
  - **驗證方式**：非 PCM16 錄音 fixture、temp 清理、FFmpeg args、Demucs mono/stereo adapter tests、Finder 麥克風 smoke；guardrails #43/#56。
  - _Requirements: REQ-01、REQ-18；M4/M9/M10_

---

## 3. 前端任務拆分原則與粒度約定

- 每個功能點完成後必須能獨立驗證；S1 為第一個可 demo 端到端切片。
- UI 直用 Domain 型別，不另建重複 DTO。
- 長任務防競態採既有 runId／重入鎖／目標集合鎖樣板。
- 每個新程式檔第一行標 `// AI-Generate`；公開 API 以繁中 doc comment 引用 REQ／AT／設計章節。
- widget test 涉真 async 時使用 `tester.runAsync`；不以修改防線測試換取綠燈。

## 4. 前端任務清單（功能點 9–16）

### 功能點 9：視窗自適應（REQ-10）

- [x] FP9.1 **建立殼層 LayoutBuilder、1280px 斷點與捲動基線**（完成：2026-07-14；FP9.1 targeted 4/4、App full 82/82、analyze PASS）
  - **File**：`app/lib/shell/app_shell.dart`、`app/lib/shared/navigation.dart`、`app/lib/shared/responsive_layout.dart`（新）
  - **Work**：≥1280 雙欄、<1280 上下堆疊；保留 1100×700 macOS 最小尺寸；提供垂直／水平 Scrollbar 元件。
  - **Purpose**：新功能頁一開始就建立「看不到必可捲到」的骨架。
  - **風險分層**：`[需要回報]`（全域佈局）
  - **Non-scope**：不改 MainFlutterWindow 最小尺寸。
  - **驗證方式**：AT-10-01～04；`macos_window_config_test.dart` 不變。
  - _Leverage: AppShell、WaveformCanvas LayoutBuilder_
  - _Requirements: REQ-10_

- [x] FP9.2 **逐頁套用響應式容器並保留編輯狀態**（完成：2026-07-14；targeted 5/5、App full 84/84、analyze PASS）
  - **File**：`app/lib/features/**/**/*_screen.dart`、`app/test/responsive_layout_test.dart`（新）
  - **Work**：既有 library/import/editor/practice/settings 主畫面逐一套用外層 `SingleChildScrollView`；import 以 `ResponsiveTwoPane` 於 1280px 切換並排／堆疊；labeling 與 arrangement 尚未建立，待各自頁面任務建立時沿用共用容器；快速縮放不殘影，狀態不重建丟失。
  - **Purpose**：把殼層策略落到所有實際頁面。
  - **風險分層**：`[需要回報]`（跨多 feature）
  - **Non-scope**：不重設功能流程或視覺 Token。
  - **驗證方式**：AT-10-01～05；targeted responsive 5/5，含匯入字稿切頁／縮放後狀態保留。
  - _Leverage: FP9.1 responsive helpers_
  - _Requirements: REQ-10_

### 功能點 10：段落標籤（REQ-11）

- [x] FP10.1 **建立 LabelingScreen、NavigationRail 入口與 Controller 骨架**（完成：2026-07-14；targeted 2/2、focused navigation/progress/e2e 10/10、App full 86/86、analyze PASS）
  - **File**：`app/lib/features/labeling/labeling_screen.dart`（新）、`app/lib/features/labeling/labeling_controller.dart`（新）、`app/lib/shared/navigation.dart`、`app/lib/shell/app_shell.dart`
  - **Work**：新增段落標籤頁與 NavigationRail 入口；提供單檔選擇／拖入、開啟階段狀態、session／dirty／selectedSegment 狀態；以 `labelingEngineProvider` 注入 Domain `SegmentEngine.openAudio` 介面 20，並保留正常結果＋`LabelOpenWarning`。
  - **Purpose**：先能匯入並看見全檔波形與自動標籤結果。
  - **風險分層**：`[需要回報]`（新頂層頁）
  - **Non-scope**：不加入多層標籤或批次匯入。
  - **驗證方式**：AT-11-01/05～08；Controller targeted 2/2，含 warning、peaks、session 與 unsupported format 防呆。
  - _Leverage: ImportScreen、StagedProgress、analysis runId_
  - _Requirements: REQ-11_

- [x] FP10.2 **實作 FullTrackWaveform、標籤線與區段清單互動**（完成：2026-07-14；Controller 3/3、widget 2/2、App full 89/89、analyze PASS）
  - **File**：`app/lib/features/labeling/widgets/full_track_waveform.dart`（新）、`app/lib/features/labeling/widgets/segment_list.dart`（新）、對應 widget tests
  - **Work**：完成時間軸、波形、線 hit-test／選取／拖曳、＋／×、編號、原音範圍試聽、單選區段；Controller 透過 `LabelSession.moveBoundary`／`insertBoundary`／`removeBoundary` 寫回 Domain。
  - **Purpose**：自動切句不準時仍可完整手動修正。
  - **風險分層**：`[需要回報]`（複合手勢）
  - **Non-scope**：不讓 UI 直接改 mutable Segment list。
  - **驗證方式**：AT-11-01/02/06；`full_track_waveform_test.dart` 2/2，覆蓋 callbacks、時間軸、拖曳預覽、清單試聽／刪線。
  - _Leverage: WaveformCanvas hit-test、PlayerBar_
  - _Requirements: REQ-11_

- [x] FP10.3 **實作 .abolabel 提示／匯出與 dirty 三選一攔截**（完成：2026-07-14；Controller 6/6、Screen 4/4、App full 96/96、analyze PASS）
  - **File**：`app/lib/features/labeling/labeling_controller.dart`、`app/lib/features/labeling/labeling_screen.dart`、`app/test/labeling/labeling_screen_test.dart`（新）
  - **Work**：existingLabelPath 提示；儲存／不儲存／取消；取消保持原音檔；匯出成功才 markSaved。
  - **Purpose**：未儲存標籤不得靜默丟失。
  - **風險分層**：`[必須確認]`（覆寫／放棄使用者標籤資料）
  - **Non-scope**：不以只有 Dialog 的軟提醒取代 Domain dirty 狀態機。
  - **驗證方式**：AT-11-03/04；#48/#49；Controller 6/6、Screen 4/4；`flutter test`（`app/`）96/96；`flutter analyze app` No issues。
  - _Leverage: export dialog patterns_
  - _Requirements: REQ-11_

- [x] FP10.4 **實作勾選 Segment→單句分析交接**（完成：2026-07-14；pending／Controller 3/3、UI 1/1、App full 100/100、analyze PASS）
  - **File**：`app/lib/features/labeling/labeling_controller.dart`、`app/lib/features/import_analysis/analysis_controller.dart`、`app/lib/shared/pending_segment.dart`（新）
  - **Work**：傳遞起訖、文字、language、原音來源；一次只允許一個 segment。
  - **Purpose**：完成 S2 真實使用者流程。
  - **風險分層**：`[需要回報]`（跨 feature 狀態）
  - **Non-scope**：不複製 PCM 或建立第二套分析引擎。
  - **驗證方式**：AT-12-02/04；pending／Controller targeted 3/3、handoff widget 1/1；`flutter test`（`app/`）100/100；`flutter analyze app` No issues。
  - _Leverage: Riverpod Provider、AnalysisController_
  - _Requirements: REQ-11、REQ-12_

### 功能點 11：單句分析與譯文搬移（REQ-12、REQ-20）

- [x] FP11.1 **整合直接匯入與 pending Segment 雙入口**（完成：2026-07-14；Domain 159/159、App full 103/103、analyze PASS）
  - **File**：`app/lib/features/import_analysis/analysis_controller.dart`、`app/lib/features/import_analysis/import_screen.dart`、`packages/domain/lib/src/analysis/analysis_pipeline.dart`、`packages/domain/lib/src/model/pcm.dart`、`app/test/features/import_analysis/import_screen_test.dart`、`packages/domain/test/analysis_segment_slice_test.dart`
  - **Work**：來源徽章、字稿預填、language 傳遞、Segment 原 PCM 切片；分析完成音節預覽與字稿同源。
  - **Purpose**：完成 S1/S2 的共同單句入口。
  - **風險分層**：`[需要回報]`（分析入口）
  - **Non-scope**：不重新編碼 Segment 音訊。
  - **驗證方式**：AT-12-01/02/04/05；ImportScreen targeted 7/7、Domain slice targeted 2/2；`dart test packages/domain/test` 159/159；`flutter test`（`app/`）103/103；`flutter analyze` No issues。
  - _Leverage: AnalysisController、InfraAnalysisRunner_
  - _Requirements: REQ-12_

- [x] FP11.2 **實作無音檔防呆與 TTS 零入口 policy widget test**（完成：2026-07-14；targeted 1/1、App full 104/104、analyze PASS）
  - **File**：`app/lib/features/import_analysis/import_screen.dart`、`app/test/features/import_analysis/import_screen_no_tts_test.dart`（新）
  - **Work**：按鈕置灰、指路文案；掃描 widget tree 與依賴確認無 TTS／生成控制項。
  - **Purpose**：把 D1 永不回歸落到 UI。
  - **風險分層**：`[可直接做]`
  - **Non-scope**：不提供任何文字生音或 AI 音訊功能。
  - **驗證方式**：AT-12-03；#45；`import_screen_no_tts_test.dart` 1/1；`flutter test`（`app/`）104/104；`flutter analyze` No issues。
  - _Leverage: EmptyState、policy tests_
  - _Requirements: REQ-12；D1_

- [x] FP11.3 **搬移手動／AI 譯文群組並保持設定頁其餘功能**（完成：2026-07-14；使用者批准後動工）
  - **File**：`app/lib/features/import_analysis/import_screen.dart`、`app/lib/features/import_analysis/analysis_controller.dart`、`app/lib/features/progress/progress_settings_screen.dart`、`app/lib/features/library/lesson_pack_service.dart`、`app/test/features/import_analysis/import_screen_translation_test.dart`、`app/test/progress/progress_ui_test.dart`
  - **Work**：將課件譯文 controller、`_saveLesson` 與 AI 翻譯入口搬到匯入頁同一譯文群組；分析狀態保存 AI 譯文，草稿建構時 manual 永遠優先；設定頁移除譯文欄位但保留 AI key／封存／提醒／sidecar timeout／批次儲存。
  - **Purpose**：譯文回到製作課件情境，功能契約不變。
  - **風險分層**：`[需要回報]`（跨頁搬移）
  - **Non-scope**：不拆設定頁批次儲存按鈕，不改 AI provider。
  - **驗證方式**：AT-20-01～05；新增 `import_screen_translation_test.dart` 2/2（無草稿置灰、AI 預覽／手動優先／⌘S 儲存）；設定頁與既有進度回歸 15/15；`flutter test`（工作目錄 `app/`）106/106；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
  - _Leverage: 現有 _saveLesson、AIService_
  - _Requirements: REQ-20_

### 功能點 12：切點增減與雙向高亮（REQ-13、REQ-14）

- [x] FP12.1 **擴充 EditorController 操作、共享選中與 undo**（完成：2026-07-14；使用者預先授權全數批准）
  - **File**：`app/lib/features/editor/editor_controller.dart`、`app/test/editor/editor_controller_test.dart`
  - **Work**：新增 remove/insert/updateText；selectedSyllableIndex 為波形／文字單一來源；刪除選中清空、插入索引同步；校正 undo 限最近四步且與排列 undo 分離；總數變更標記排列 stale。
  - **Purpose**：波形與文字操作只改同一份狀態。
  - **風險分層**：`[需要回報]`（既有 editor 狀態擴充）
  - **Non-scope**：不把 arrangement undo 混進 editor undo。
  - **驗證方式**：AT-13-01～07、AT-14-03～05、AT-15-08；EditorController targeted 16/16；`flutter test`（工作目錄 `app/`）110/110；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
  - _Leverage: 現有 immutable snapshots_
  - _Requirements: REQ-13、REQ-14_

- [x] FP12.2 **擴充 WaveformCanvas 的編號、高亮與＋／×手勢**（完成：2026-07-14；使用者預先授權全數批准）
  - **File**：`app/lib/features/editor/widgets/waveform_canvas.dart`、`app/test/editor/waveform_canvas_test.dart`
  - **Work**：圓點內 1-based 編號、黃色區段、切點選中、浮動控制；50ms 前端預防與 Domain 防禦雙層。
  - **Purpose**：讓波形校正操作可見、可對照、可防誤觸。
  - **風險分層**：`[需要回報]`（CustomPainter hit-test）
  - **Non-scope**：不改 waveform sample 或 prosody 計算。
  - **驗證方式**：AT-13-01/02/05/06、AT-14-01～05；`waveform_canvas_test.dart` 8/8；`flutter test`（工作目錄 `app/`）114/114；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
  - _Leverage: 現有 boundary drag hit-test_
  - _Requirements: REQ-13、REQ-14_

- [x] FP12.3 **實作文字 chip 序號、編輯與同步高亮**（完成：2026-07-14；使用者預先授權全數批准）
  - **File**：`app/lib/features/editor/editor_screen.dart`、`app/test/editor/editor_screen_edit_test.dart`（新）
  - **Work**：chip 下方序號、雙擊 TextField、空值 needsReview、黃色高亮；編號隨增減連續重排。
  - **Purpose**：文字與波形雙向指向同一音節。
  - **風險分層**：`[可直接做]`
  - **Non-scope**：不另存第二份 transcript 狀態。
  - **驗證方式**：AT-13-03/04、AT-14-01～05；`editor_screen_edit_test.dart` 4/4；`flutter test`（工作目錄 `app/`）118/118；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
  - _Leverage: _SyllableChipsRow_
  - _Requirements: REQ-13、REQ-14_

### 功能點 13：自由編輯區（REQ-15）

- [x] FP13.1 **建立 ArrangementController／Section 與一鍵生成**（完成：2026-07-14；使用者預先授權全數批准）
  - **File**：`app/lib/features/arrangement/arrangement_controller.dart`（新）、`app/lib/features/arrangement/arrangement_section.dart`（新）、`app/lib/features/editor/editor_screen.dart`
  - **Work**：N 列、插刪列、stale banner、獨立 undo；區域置於 editor 下方可捲動位置。
  - **Purpose**：先把自動疊加可視化成可編輯積木。
  - **風險分層**：`[需要回報]`（新複合狀態）
  - **Non-scope**：不新增頂層導覽項。
  - **驗證方式**：AT-15-01/02/08；`arrangement_section_test.dart` 3/3；`flutter test`（工作目錄 `app/`）121/121；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
  - _Leverage: Editor chips、Riverpod copyWith _unset_
  - _Requirements: REQ-15_

- [x] FP13.2 **實作長按堆疊成組、組內排序與拆組**（完成：2026-07-14；使用者預先授權全數批准）
  - **File**：`app/lib/features/arrangement/widgets/arrangement_row.dart`（新）、`app/test/arrangement/arrangement_drag_test.dart`（新）
  - **Work**：LongPressDraggable、同列懸停 300ms 預覽、放開成組、組內滑動、ungroup、跨列不成組。
  - **Purpose**：落地 F1 已定案的 iPhone 式手勢。
  - **風險分層**：`[需要回報]`（高互動手勢）
  - **Non-scope**：不做跨列組塊、不做圈選框另一套手勢。
  - **驗證方式**：AT-15-02/03；`arrangement_row_test.dart` 3/3；`arrangement_section_test.dart` 3/3；`flutter test`（工作目錄 `app/`）124/124；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
  - _Leverage: Flutter Draggable/DragTarget_
  - _Requirements: REQ-15_

- [x] FP13.3 **實作塊設定、列預覽與播放競態防護**（完成：2026-07-14；使用者預先授權全數批准）
  - **File**：`app/lib/features/arrangement/widgets/block_config_menu.dart`（新）、`app/lib/features/arrangement/arrangement_controller.dart`、`app/lib/features/practice/practice_player.dart`、對應 tests
  - **Work**：repeatN／silenceFactor stepper、預覽、播放中改排列停止或播舊快照；錯誤不清值。
  - **Purpose**：完成 S4 可聽見的自訂練習積木。
  - **風險分層**：`[需要回報]`（播放競態）
  - **Non-scope**：不建立另一套音訊 renderer。
  - **驗證方式**：`block_config_menu_test.dart` 3/3、`arrangement_section_test.dart` 4/4、`practice_player_test.dart` 6/6；`flutter test`（工作目錄 `app/`）130/130；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
  - _Leverage: PracticePlayer runId_
  - _Requirements: REQ-15_

### 功能點 14：疊加練習頁 M12（REQ-16）

- [x] FP14.1 **PracticeController 全面改用 effectiveUnits 並顯示模式**（完成：2026-07-14；使用者預先授權全數批准）
  - **File**：`app/lib/features/practice/practice_controller.dart`、`app/lib/features/practice/practice_screen.dart`、`app/test/practice/practice_controller_test.dart`、`app/test/practice/practice_screen_test.dart`
  - **Work**：mode chip、stale banner；所有 unit 來源走介面 30；播放／錄音沿用既有操作。
  - **Purpose**：UI 不自行判斷自動／自訂，避免雙重真相。
  - **風險分層**：`[需要回報]`（核心練習控制器）
  - **Non-scope**：不改 auto 的步數、順序或錄音比對規則。
  - **驗證方式**：`practice_controller_test.dart` 13/13、`practice_screen_test.dart` 5/5；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
  - _Leverage: PracticeController、PracticePlayer_
  - _Requirements: REQ-16_

- [x] FP14.2 **整合 custom 單元匯出與刪除排列確認**（完成：2026-07-14；使用者預先授權全數批准）
  - **File**：`app/lib/features/export/export_dialog.dart`、`app/lib/features/practice/practice_screen.dart`、對應 tests
  - **Work**：custom 選取項對應各 row；刪除排列需確認後設 null 並回落 auto；進度不刪。
  - **Purpose**：自訂排列可真正拿來練與匯出。
  - **風險分層**：`[必須確認]`（刪除使用者排列資料）
  - **Non-scope**：不刪 Attempt／SRS／音節校正資料。
  - **驗證方式**：`export_dialog_test.dart` 6/6、custom practice screen 1/1；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
  - _Leverage: 現有 export dialog、Atomic exporter_
  - _Requirements: REQ-16_

### 功能點 15：錄音暫存回聽（REQ-18）

- [x] FP15.1 **錄音結束加入明示同意勾選與隱私文案**（完成：2026-07-14；使用者預先授權全數批准）
  - **File**：`app/lib/features/practice/widgets/record_panel.dart`、`app/lib/features/practice/practice_recording.dart`、`app/test/practice/practice_recording_test.dart`
  - **Work**：預設不勾；只有勾選才 stash；tooltip 明列 10 分鐘、切步、重啟與不進課件。
  - **Purpose**：同意是呼叫語意，不是預設開啟。
  - **風險分層**：`[需要回報]`（隱私 UX）
  - **Non-scope**：不改 v1 未勾選時 finally 刪錄音。
  - **驗證方式**：`practice_controller_test.dart` FP15.1 1/1、`practice_screen_test.dart` 錄音回歸；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
  - _Leverage: 現有 RecordPanel_
  - _Requirements: REQ-18；M10_

- [x] FP15.2 **實作暫存清單、播放、逐筆刪除與切步清除**（完成：2026-07-14；使用者預先授權全數批准）
  - **File**：`app/lib/features/practice/practice_controller.dart`、`app/lib/features/practice/practice_player.dart`、`app/lib/features/practice/practice_screen.dart`、對應 tests
  - **Work**：ExpansionTile 清單；播放／刪除；切步呼叫 purgeContext；同步驟覆蓋；失敗 SnackBar 不擋比對。
  - **Purpose**：使用者可排除錄音問題，隱私開口仍最小。
  - **風險分層**：`[必須確認]`（刪除／覆蓋暫存錄音）
  - **Non-scope**：不保存跨步驟歷史。
  - **驗證方式**：`practice_controller_test.dart` FP15.1 覆蓋 stash／回聽／切步 purge；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
  - _Leverage: PracticePlayer、RecordPanel_
  - _Requirements: REQ-18_

- [x] FP15.3 **App 啟動注入 RecordingBuffer 並先 purgeAll**（完成：2026-07-14；使用者預先授權全數批准）
  - **File**：`app/lib/main.dart`、`app/lib/shared/infra/recording_buffer_provider.dart`（新）、`app/test/widget_test.dart`
  - **Work**：服務建立後、任何清單呈現前先清孤兒；啟動錯誤不拖垮 App 但需記 audit。
  - **Purpose**：重啟即清空成為 App 生命週期保證。
  - **風險分層**：`[必須確認]`（啟動時刪除暫存資料）
  - **Non-scope**：不清理其他 temp 子目錄。
  - **驗證方式**：`TempRecordingBufferStore` 既有 5/5、`main.dart` 啟動 purge 注入；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
  - _Leverage: main providers、AtomicFileIo clearTemp_
  - _Requirements: REQ-18_

### 功能點 16：字稿／譯文顯示（REQ-19）

- [x] FP16.1 **實作四態 SegmentedButton 與條件渲染**（完成：2026-07-14；使用者預先授權全數批准）
  - **File**：`app/lib/features/practice/practice_screen.dart`、`app/test/practice/transcript_display_test.dart`（新）
  - **Work**：字稿／字稿＋譯文／僅譯文／隱藏；無譯文顯示指路，不禁用。
  - **Purpose**：使用者可依練習階段調整提示量。
  - **風險分層**：`[可直接做]`
  - **Non-scope**：不改譯文內容或 AI/manual 優先規則。
  - **驗證方式**：practice screen transcript targeted 1/1；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
  - _Leverage: Translation model、Material SegmentedButton_
  - _Requirements: REQ-19_

- [x] FP16.2 **連接每 Lesson 顯示偏好並驗證隔離**（完成：2026-07-14；使用者預先授權全數批准）
  - **File**：`app/lib/features/practice/practice_controller.dart`、`app/test/practice/transcript_display_test.dart`、`packages/domain/test/lesson_pack_engine_test.dart`
  - **Work**：load 時 get、切換時 set；換 Lesson 各自記憶；依 DFT-05 裁決驗證是否隨 aboprogress。
  - **Purpose**：顯示模式能重開恢復，又不污染課件分享。
  - **風險分層**：`[必須確認]`（依 7.1 儲存契約）
  - **Non-scope**：不把偏好寫入 abopack。
  - **驗證方式**：practice screen transcript preference targeted 1/1、既有 `progress_settings_test.dart` 7/7；`flutter analyze app packages/domain` No issues；`git diff --check` PASS。
  - _Leverage: 介面 34_
  - _Requirements: REQ-19_

### 功能點 17：時間範圍同步高亮（REQ-14 r5）

- [x] FP17.1 **改用 SelectedTimeRange 並高亮全部重疊積木**（完成：2026-07-14；editor targeted 31/31 PASS）
  - **File**：`app/lib/features/editor/editor_controller.dart`、`app/lib/features/editor/editor_screen.dart`、`app/lib/features/editor/widgets/waveform_canvas.dart`、對應 tests
  - **Work**：波形選取輸出半開時間範圍；chips 以 overlap 判斷多選透明黃；點 chip 回寫其完整範圍；增刪後重算／清空失效 range。
  - **Purpose**：修復同一選取區段只有部分積木變黃。
  - **風險分層**：`[需要回報]`（editor 共用選取狀態）
  - **Non-scope**：不改切點時間或 prosody 計算。
  - **驗證方式**：AT-14-01～06，特別是 `think/it'll/rain` 三塊重疊。
  - _Leverage: 現有 waveform hit-test、EditorController copyWith_
  - _Requirements: REQ-14_

### 功能點 18：自由排列完整互動（REQ-15/16 r5）

- [x] FP18.1 **接通上方積木→任一列與草稿期一鍵生成**（完成：2026-07-14；arrangement targeted PASS）
  - **File**：`app/lib/features/editor/editor_screen.dart`、`app/lib/features/arrangement/arrangement_section.dart`、`arrangement_controller.dart`、`widgets/arrangement_row.dart`
  - **Work**：共用公開 `ArrangementDragData`；上方 chip 為一般 Draggable；空列 DragTarget 接受；generate 使用 draft lessonId，不再因 `sourceLessonId == null` disabled。
  - **Purpose**：空白第一列可接積木，一鍵生成在保存 pack 前即可用。
  - **風險分層**：`[需要回報]`（跨 editor／arrangement 拖曳）
  - **Non-scope**：不允許跨 Lesson drop。
  - **驗證方式**：AT-15-01/02/10/12；guardrails #53。
  - _Requirements: REQ-15_

- [x] FP18.2 **改為同列直接成組與雙擊集中設定視窗**（完成：2026-07-14；一般拖曳、雙擊、reset／邊界 targeted PASS）
  - **File**：`app/lib/features/arrangement/widgets/arrangement_row.dart`、`block_config_menu.dart`（改為 dialog 或重新命名）、`arrangement_controller.dart`、對應 tests
  - **Work**：移除 LongPressDraggable／300ms；同列 block drop 成組，跨列只移動；雙擊開 repeat/silence/reset/block preview dialog；移除每塊旁設定與播放 icon；只留列右播放。
  - **Purpose**：符合 macOS 觸控板直覺，設定不常駐干擾積木排列。
  - **風險分層**：`[需要回報]`（複合手勢＋播放）
  - **Non-scope**：不新增三指手勢、不讓 UI 自行合併設定值。
  - **驗證方式**：AT-15-03～07/10/11；repeat/silence 邊界與 reset 3/5。
  - _Requirements: REQ-15；M1/M3_

- [x] FP18.3 **搬移刪排列控制並清除練習頁模式 UI**（完成：2026-07-14；arrangement／practice targeted PASS）
  - **File**：`arrangement_section.dart`、`practice_screen.dart`、對應 tests
  - **Work**：刪除控制放自由排列標題左側；練習頁移除模式徽章、刪除 icon、「每列沿用各積木設定」；只改顯示，不繞過 `effectiveUnits`。
  - **Purpose**：控制回到建立排列的情境，練習頁保持專注。
  - **風險分層**：`[必須確認]`（刪除排列資料；已由本完整包批准）
  - **Non-scope**：不刪 Attempt／SRS／校正資料。
  - **驗證方式**：AT-16-01～07；guardrails #40。
  - _Requirements: REQ-16_

### 功能點 19：練習顯示與錄音回播（REQ-18/19 r5）

- [x] FP19.1 **統一「單元」用語並完整套用 hidden 模式**（完成：2026-07-14；practice 12/12、跨頁 smoke PASS）
  - **File**：`app/lib/features/practice/practice_screen.dart`、`widgets/record_panel.dart`、對應 tests
  - **Work**：建立共享 visibility view-model；hidden 時 navigator 只 #n、player/record 只第 n 單元；其餘三態不變；內部 PracticeStep key 不改。
  - **Purpose**：隱藏答案時不從其他元件洩漏，同時維持進度相容。
  - **風險分層**：`[可直接做]`
  - **Non-scope**：不改 `.aboprogress` schema 或顯示模式列舉。
  - **驗證方式**：AT-19-01～05、AT-16-07。
  - _Requirements: REQ-16、REQ-19_

- [x] FP19.2 **接上錄音→播放 coordinator 與可見錯誤**（完成：2026-07-14；音訊 targeted 22/22、UI 回歸 PASS；Finder smoke 留最終跨頁驗收）
  - **File**：`practice_player.dart`、`practice_recording.dart`、`practice_controller.dart`、`practice_screen.dart`
  - **Work**：消費 9.4 coordinator；播放中顯示狀態，錯誤顯示實際訊息；完成後再清 temp；UI 可連播。
  - **Purpose**：讓暫存錄音在 Finder 正式 App 真正可聽。
  - **風險分層**：`[需要回報]`
  - **Non-scope**：不保存錄音歷史、不上傳音訊。
  - **驗證方式**：AT-18-01/04/05/07/08；guardrails #43。
  - _Requirements: REQ-18_

### 功能點 20：真實進度與預覽誠實（REQ-11/12 r5）

- [x] FP20.1 **段落標籤改用真實階段進度並移除重複選檔**（完成：2026-07-14；labeling targeted PASS）
  - **File**：`labeling_controller.dart`、`labeling_screen.dart`、`shared/staged_progress.dart`、對應 tests
  - **Work**：接介面 20 progress；可量測才顯示比例，否則階段 indeterminate；刪頁首「選擇音檔」，保留卡內瀏覽與拖放。
  - **Purpose**：使用者看到真實處理位置且只有一個清楚選檔入口。
  - **風險分層**：`[需要回報]`
  - **Non-scope**：不偽造 sidecar percent。
  - **驗證方式**：AT-11-10/11；guardrails #52。
  - _Requirements: REQ-11；M15_

- [x] FP20.2 **匯入頁接真實 ready 狀態、移除假進度與硬編預覽**（完成：2026-07-14；import targeted PASS）
  - **File**：`analysis_controller.dart`、`import_screen.dart`、`shared/staged_progress.dart`、對應 tests
  - **Work**：接介面 35 bytes/validation；pending Segment 立即 ready；移除 preview runner 假數字；開始前結果留白，完成後只顯示實際 syllables。
  - **Purpose**：只有真的可分析時才說就緒，結果區只顯示事實。
  - **風險分層**：`[需要回報]`
  - **Non-scope**：不顯示硬編 11，不以 path exists 取代讀取驗證。
  - **驗證方式**：AT-12-03/05～08；guardrails #52。
  - _Requirements: REQ-12；M15_

### 前端共享驗收

- [x] FE-QA.1 **建立 v1.1 跨切片 e2e 與錯誤文案回歸**（完成：2026-07-14；使用者預先授權全數批准）
  - **File**：`app/test/e2e_v11_pipeline_test.dart`（新）、`app/test/shared/error_messages_test.dart`（新）
  - **Work**：label→segment→analysis→edit→arrange→practice→record buffer→display mode；27 碼映射完整；1100×700 可到達。
  - **Purpose**：驗證 11 條 REQ 不是各自綠、串起來卻壞。
  - **風險分層**：`[需要回報]`（跨模組 QA）
  - **Non-scope**：不以 mock 全鏈路取代必要真 sidecar／真檔案 smoke。
  - **驗證方式**：AT-10-*～AT-20-* 核心情境；`bash scripts/ci_core_checks.sh`。
  - **完成證據**：`e2e_v11_pipeline_test.dart` 1/1、`error_messages_test.dart` 1/1；完整 CI App 137/137 PASS、`flutter analyze` No issues。
  - _Leverage: app/test/e2e_pipeline_test.dart_
  - _Requirements: REQ-10～REQ-20_

- [x] FE-QA.2 **完整變更包跨頁回歸與 Finder smoke**（完成：2026-07-15；使用者明示「真人驗收OK」）
  - **File**：相關 widget/e2e tests、`task/execution-log.md`
  - **Work**：校正多塊高亮→空列拖入→成組／雙擊設定→練習 hidden→錄音回播→段落／匯入真實進度；Finder 開正式 App 逐項驗證。
  - **Purpose**：避免單頁修好但跨頁狀態仍斷裂。
  - **風險分層**：`[需要回報]`
  - **Non-scope**：不以 mock-only 取代錄音與 sidecar 真機驗收。
  - **驗證方式**：本批新增 AT 全數＋`bash scripts/ci_core_checks.sh`。
  - _Requirements: REQ-11、REQ-12、REQ-14～REQ-19_

### S9-20：2026-07-15 實機驗收追補（已批准；全數 TDD）

- [x] S9-20.1 **目前單元錄音記憶體回放**
  - **File**：`practice_controller.dart`、`practice_player.dart`、`widgets/record_panel.dart`、對應 tests
  - **Work**：保存目前單元最近一次 PCM；比對失敗仍可播；播放／停止；切單元、重錄、垃圾桶、離頁清除；來源檔與回放暫存不殘留；不建立 RecordingBuffer。
  - **驗證**：AT-18-08/09；practice controller/player/screen 31 項通過。
  - _Requirements: REQ-18；M10_

- [x] S9-20.2 **自由排列固定工具列與長列捲動**
  - **File**：`arrangement_section.dart`、`widgets/arrangement_row.dart`、對應 tests
  - **Work**：固定來源積木工具列、列區獨立垂直捲動、插入列定位與短暫標示、拖曳上下緣自動捲動。
  - **驗證**：AT-16-11/12；1100×700 arrangement 測試通過。
  - _Requirements: REQ-15/16_

- [x] S9-20.3 **段落標籤完整播放與暫停續播**
  - **File**：`labeling_controller.dart`、`labeling_segment_preview_test.dart`、對應 labeling tests
  - **Work**：移除 clip 雙重位移；所有區段完整播放；暫停保留紅色虛線；續播不重頭；stop 清除游標並使下次由區段開頭開始。
  - **驗證**：AT-11-14/16；labeling 測試 20 項通過。
  - _Requirements: REQ-11_

- [x] S9-20.4 **拆批回歸、release 與真人驗收**（完成：2026-07-15；自動閘門、Release 與真人麥克風／Finder 驗收皆完成）
  - **Work**：app／domain／infra 拆批回歸、analyze、guardrails、license、release build；Finder 目視與真人麥克風驗收。
  - **驗證**：自動閘門與 release 重建已完成；Finder 目視、真人麥克風仍須使用者執行，人工項不得由 AI 勾選。
  - _Requirements: REQ-11、REQ-15/16、REQ-18；M1/M5/M9/M10_

### S9-21：2026-07-15 排列操作實機追補（已批准；全數 TDD）

- [x] S9-21.1 **段落校正主標題一致**
  - **Work**：校正頁主標題由舊稱改為「段落校正」，route 與 provider key 不變。
  - **驗證**：AT-10-06 widget test。
- [x] S9-21.2 **排列列區與外層捲動手勢隔離**
  - **Work**：列區固定捲軸、pointer scroll 只捲列區；拖曳期間鎖住 Editor 外層，邊緣自動捲動只作用列區。
  - **驗證**：AT-15-16，1100×700、8 列 widget test。
- [x] S9-21.3 **單一積木與整組選取、刪除、重排**
  - **Work**：內容選取、專用把手、垃圾桶／Delete、列間藍色插入線；單一與整組共用頂層移動契約。
  - **驗證**：AT-15-17，Domain＋widget tests。
- [x] S9-21.4 **組內成員刪除、重排、抽出與插入**
  - **Work**：組內音節獨立把手與插入線；成員可刪除／重排／抽出成單一，單一可插入組內；剩一項自動降級。
  - **驗證**：AT-15-18，Domain＋widget tests。
- [x] S9-21.5 **拆批回歸與 release 重建**（完成：2026-07-15；使用者確認 Finder 拖曳與捲動手感通過）
  - **Work**：Domain、arrangement/editor widget、App 拆批、analyze、guardrails、license、release build；人工手感仍由使用者驗收。
  - **驗證**：測試報告＋Finder 真人操作。

### S9-22：2026-07-15 段落校正效能、兩層捲動與暫存衛生（已批准；全數 TDD）

- [x] S9-22.1 **切點即時提交與背景音韻分析**
  - **Work**：先提交 syllables 並清 transient state；Prosody 走背景 runner＋generation 防晚到覆蓋。
  - **驗證**：AT-13-08/09；editor controller/widget 紅測試。
- [x] S9-22.2 **移除全 App 多餘捲動並穩定顯示最後一列**
  - **Work**：ResponsiveLayout 只做斷點與幾何；只保留 Editor 頁與列區兩層；新增列只用列區 controller 定位。
  - **驗證**：AT-15-19；1100×700、8 列含高列 widget 紅測試。
- [x] S9-22.3 **來源積木拿起／放下模式**
  - **Work**：單擊選取、可放手捲動、點指定插入位置放下；Esc／再點取消；保留近距離 drag。
  - **驗證**：AT-15-20；20 列 widget 紅測試。
- [x] S9-22.4 **session 暫存生命週期**
  - **Work**：管理式 session／operation 目錄；Whisper、Demucs、預覽與解包 finally／切課清理；不碰使用者保存檔。
  - **驗證**：成功／失敗／取消故障注入、20 檔壓力與重啟清理；guardrails #62。
- [x] S9-22.5 **拆批回歸與 release 重建**（完成：2026-07-15；使用者確認切點、末列與長距離放置通過）
  - **Work**：editor／arrangement／infra targeted、App／Domain／Infra 拆批、analyze、guardrails、license、release；人工手感仍由使用者驗收。
  - **驗證**：測試報告＋Finder 真人操作。

### S9-23：2026-07-15 自由排列互動簡化（已批准；先 TDD）

- [x] S9-23.1 **同列操作 Domain／Controller 防線**
  - **Work**：`moveBlock`、組員抽出、單一併組拒絕不同 rowIndex；既有 pack schema 不變。
  - **驗證**：AT-15-17/18 Domain 紅測試，跨列失敗時排列與 undoDepth 不變。
- [x] S9-23.2 **積木本體長按與視覺簡化**
  - **Work**：移除六點把手、大型跨列插入軌與麥克風 avatar；單一／組合／組員本體 `LongPressDraggable`，只接受同列改序、成組與組內操作。
  - **驗證**：AT-15-17/18 widget 紅測試；短按選取、雙擊設定、長按拖曳互不污染。
- [x] S9-23.3 **來源段落按鈕插入**
  - **Work**：文案改「來源段落」；選取後顯示每個頂層左側與列尾插入按鈕，空列整列可點；插入後清選取，取消保留 Esc／再點。
  - **驗證**：AT-15-10/20，20 列第一／中間／列尾／空列 widget 紅測試。
- [x] S9-23.4 **分批回歸、Release 與 Finder 人工驗收**（完成：2026-07-15；使用者確認長按／三指與來源段落插入通過；社群圖已取消）
  - **Work**：Domain／App targeted、拆批 gate、analyze、guardrails、license、release build。原訂兩張英文社群 PNG 於內建產圖服務 HTTP 520 後，由使用者明示取消，不列入驗收。
  - **驗證**：測試報告、Release 啟動；Finder 操作手感仍由使用者驗收。

### S10：2026-07-15 r6 收尾變更包（已批准；一律先紅測試）

- [x] 10.1 **M1 原音／分析軌隔離：紅測試→實作** `[需要回報]`（完成：2026-07-16；AT-12-09）
  - Demucs PCM 與原音不同時，播放、錄音參考、pack、export 仍只取 original；新增 `AnalysisAudioTracks`／`analysisPcm`，`decodedPcm` 相容語意固定為 original。
  - **驗證**：AT-12-09；guardrails #57。

- [x] 10.2 **段落三態與 `.abolabel v2`：紅測試→實作** `[需要回報]`（完成：2026-07-16；AT-11-12/13/15）
  - kept／discarded／unmarked、有間隙、首尾、v1 相容、只有 kept 可送分析；再做框選 UI、灰色捨棄與原子寫入。
  - **驗證**：AT-11-12/13/15；guardrails #58。

- [x] 10.3 **兩頁紅色播放軸與標籤播放狀態機：widget 紅測試→實作** `[需要回報]`（完成：2026-07-16；AT-11-14、AT-14-07）
  - play→pause→resume→stop reset；position stream 推動紅色虛線且 dispose 無晚到更新；30fps 節流。
  - **驗證**：AT-11-14、AT-14-07。

- [x] 10.4 **預設 1／1、整列 3／1與自然接合：紅測試→實作** `[需要回報]`（完成：2026-07-16；AT-15／16 音訊契約全綠）
  - 95.5 秒、40 秒、block／row 最後靜音差異；相鄰 range 一次切片，非相鄰吸附或 ≤10ms micro-fade；四路共用 PracticeEngine。
  - **驗證**：AT-15-04/05/11/13/15、AT-16-01/08；M1/M3。

- [x] 10.5 **切點殘影：widget 紅測試→最小修正** `[需要回報]`（完成：2026-07-16；AT-13-08）
  - 提交後下一幀舊 dragging preview 消失；delete pointer 不觸發父層 drag；finally 清 transient state。
  - **驗證**：AT-13-08。

- [x] 10.6 **錄音單次參考、背景限點與移除 buffer：紅測試→實作** `[需要回報]`（完成：2026-07-16；AT-18-01～09、真人麥克風通過）
  - 忽略所有 repeat/silence；480000 samples 回 UI ≤1000 點且保留極值；UI 心跳不中斷；success/error/cancel finally 清 temp；垃圾桶立即清除。刪 service/provider/store/panel/startup purge。
  - **驗證**：AT-18-01～07；M10；guardrails #60。

- [x] 10.7 **`.abopack v3` 複合封包：紅測試→實作** `[需要回報]`（完成：2026-07-16；AT-21-01～03/08）
  - originalAudio 必填；labels／lesson／arrangement／latestProgress optional；portable 白名單；v1/v2/v3 fixtures；課程設定儲存與課程匯入分派。
  - **驗證**：AT-21-01～03/08；guardrails #59。

- [x] 10.8 **四層匯出 planner：紅測試→實作** `[需要回報]`（完成：2026-07-16；AT-21-04～07）
  - 音訊／排列／範圍／設定來源組合；fingerprint／range／lessonId 不符拒絕；Demucs／錄音型別不存在；override 不回寫。
  - **驗證**：AT-21-04～07；guardrails #61。

- [x] 10.9 **導覽命名與跨頁連動：widget 紅測試→實作** `[一般]`（完成：2026-07-16；AT-10-06、AT-16）
  - 六個新名稱；0 列＝1 單元、N 列＝N 單元；練習 ×N 回寫同列；route id 不變。
  - **驗證**：AT-10-06、AT-16-01～03/09。

- [x] 10.10 **分批 gate、release 與真人驗收** `[必須確認]`（完成：2026-07-16；拆批全綠、Release 重建／重簽，使用者已確認真人驗收 OK）
  - Domain／Infra／App 拆批、guardrails、licenses、analyze、release build；Finder 目視與真人麥克風。30 秒上限造成整支 CI 中斷時只回報分批事實，真人未確認不得標完成。

---

## 5. 依賴關係與時序建議（任務級）

| 任務 | 型別 | 前置任務 | 阻塞／外部依賴 | 建議順序 | 設計章節 |
|---|---|---|---|---|---|
| 1.1 | 文件／雙端 | 本 task-split | 使用者逐項確認 DFT-01～09 | S0-1 | BE/FE 開放問題、matrix |
| 1.2 | 後端測試 | — | — | S0-2 | BE §5 |
| 1.3 | 雙端契約 | 1.1（DFT-08） | 錯誤碼裁決 | S0-3 | BE §3.2.8 |
| 1.4 | 後端防線 | 使用者批准防線調整 | `domain_purity_test.dart` 受保護 | S0-4 | BE §4.4 |
| 2.1 | 後端測試 | 1.2、1.3 | — | S1-1 | BE §3.2.4 |
| 2.2 | 後端 | 2.1 | — | S1-2 | BE §3.1.1 |
| 2.3 | 後端 | 2.2 | — | S1-3 | BE 介面 31 |
| 2.4 | infra | 2.2 | 本地 small.en／sidecar | S1-3 並行 | BE 介面 31 |
| FP9.1 | 前端 | — | — | S1-2 並行 | FE 功能點 9 |
| FP11.1～2 | 前端 | 2.3、FP9.1 | — | S1-4 | FE 功能點 11 |
| 2.5 | 整合 | 2.3、2.4、FP11.1 | i5-8259U 實測 | S1-5 | BE §5 |
| 3.1 | 後端測試 | 1.1、2.2 | DFT-07/08 裁決 | S2-1 | BE §3.1.3 |
| 3.2 | 後端 | 3.1、2.3/2.4 | — | S2-2 | BE 介面 20/21 |
| 3.3 | 後端測試 | 1.3 | — | S2-1 並行 | BE 介面 22/23 |
| 3.4 | 後端 | 3.3、1.1 | DFT-09 裁決 | S2-2 | BE 介面 22/23 |
| 3.5 | infra schema | 使用者確認 schema | Drift migration | S2-2 並行 | BE §3.1.2 |
| 3.6 | infra | 3.4、3.5 | — | S2-3 | BE §3.2.1 |
| FP10.1～3 | 前端 | 3.2、3.4、3.6、FP9.1 | file picker／真音檔 | S2-4 | FE 功能點 10 |
| FP10.4 | 前端 | FP10.1～3、FP11.1 | — | S2-5 | FE 功能點 10/11 |
| 4.1 | 後端測試 | 1.3 | — | S3-1 | BE §3.2.2 |
| 4.2 | 後端 | 4.1 | — | S3-2 | BE 介面 24–26 |
| 4.3 | 後端測試 | 4.2、1.2 | — | S3-3 | BE §4.4 M11 |
| 5.1 | 後端測試 | 1.1、4.2 | DFT-06 裁決 | S4-1 | BE §3.1.1 |
| 5.2 | 後端 | 5.1 | — | S4-2 | BE 介面 27/28 |
| 4.4 | 雙端 | 4.2、5.2 | — | S4-3 | BE §3.1.3 |
| FP12.1～3 | 前端 | 4.2～4.4 | — | S3-4 | FE 功能點 12 |
| 5.3 | 後端測試 | 5.2、1.2 | — | S4-3 | BE 介面 29 |
| 5.4 | 後端 | 5.3 | — | S4-4 | BE 介面 29 |
| FP13.1～3 | 前端 | 5.2、5.4、FP12.1 | — | S4-5 | FE 功能點 13 |
| 5.5 | 後端測試 | 5.2、1.2 | — | S5-1 | BE 介面 30 |
| 5.6 | 後端/infra | 5.4、5.5 | — | S5-2 | BE 介面 30 |
| 5.7 | 後端格式 | 5.2、使用者確認 | schemaVersion 2 | S5-3 | BE §3.1.2 |
| FP14.1～2 | 前端 | 5.6、5.7 | 刪排列需確認 | S5-4 | FE 功能點 14 |
| 6.1 | 後端測試 | 1.1 | TTL 文件同步 | S6-1 | BE 介面 32/33 |
| 6.2 | 後端 | 6.1 | — | S6-2 | BE 介面 32/33 |
| 6.3 | infra | 6.2、使用者確認刪除範圍 | OS temp | S6-3 | BE §1.5 |
| 6.4 | 防線測試 | 6.2、6.3、使用者批准 | 防線檔受保護 | S6-3 | BE §4.4 M10 |
| FP15.1～3 | 前端 | 6.2～6.4 | 麥克風／temp 權限 | S6-4 | FE 功能點 15 |
| 7.1 | 後端/infra | 1.1（DFT-05） | 儲存契約裁決 | S7-1 | BE 介面 34 |
| FP11.3 | 前端 | S1 穩定 | — | S7-2 | FE 功能點 11 |
| FP16.1～2 | 前端 | 7.1 | — | S7-3 | FE 功能點 16 |
| FP9.2 | 前端 | 所有新頁骨架 | — | 各切片同步，S7 收齊 | FE 功能點 9 |
| 8.1～2 | 合規 | 對應切片完成 | 授權／matrix 證據 | 各切片同步 | BE §4.4 |
| 8.3、FE-QA.1 | 全案 | 其餘全部 | 真機 smoke 由使用者親跑 | S8 | 全案 |
| 9.1 | 後端測試 | 既有 5.1～5.4 | — | S9-1 | BE 介面 28/29 |
| 9.2 | 後端／協調 | 9.1 | — | S9-2 | BE 介面 27～29/36 |
| 9.3 | 後端／infra | 既有介面 20／AnalysisPipeline | 真檔 IO／sidecar | S9-2 並行 | BE 介面 20/35 |
| 9.4 | App 音訊 | 既有 6.*／FP15.* | macOS 麥克風／播放器 | S9-2 並行 | BE 介面 33 |
| FP17.1 | 前端 | 既有 FP12.* | — | S9-3 | FE 功能點 12 |
| FP18.1～3 | 前端 | 9.1～9.2 | — | S9-3 | FE 功能點 13/14 |
| FP19.1～2 | 前端 | 9.4 | macOS audio session | S9-3 | FE 功能點 15/16 |
| FP20.1～2 | 前端 | 9.3 | — | S9-3 | FE 功能點 10/11 |
| 9.5、FE-QA.2 | 全案 | S9 其餘全部 | Finder 正式 App | S9-4 | 全案 |
| 10.1～10.6 | TDD／實作 | r6 三同步文件 | 原音 fixture／macOS recorder | S10-1～6 | BE §3.2.1/3/5；FE 10～15 |
| 10.7～10.8 | TDD／格式／匯出 | 10.1、10.4 | v1/v2 fixtures、schema v3 | S10-7～8 | BE §3.2.6；FE 17 |
| 10.9 | 前端 | 10.2～10.8 | — | S10-9 | FE 9～17 |
| 10.10 | 全案 | 10.1～10.9 | Finder＋真人麥克風 | S10-10 | 全案 |

**關鍵路徑（增量）**：既有 S0～S8 基線→9.1→9.2→FP18.*；9.3→FP20.* 與 9.4→FP19.2 可並行；最後 FE-QA.2→9.5。

**並行原則**：

- S1 的 FP9.1 可與 2.1～2.4 並行；S1 結束前必須聯調成真實單句流程。
- S2 的 3.1/3.3/3.5 可在各自前置批准後並行；3.2/3.4/3.6 完成才進 FP10。
- S3 editor UI 可在 4.2 契約穩定後與 4.3 並行，但 S3 收尾必須一起通過 M11。
- S6 不得與未裁決的 TTL／刪除範圍並行偷跑。

---

## 6. Guardrails #39～#50 任務映射

| Guardrail | 對應任務 | 完成證據 |
|---|---|---|
| #39 M11 Step-Count | 4.1～4.3、FP12.1 | AT-13-07；10/12 步與 M2 不變 |
| #40 M12 Override | 5.5～5.6、FP14.1～2 | AT-16-01～05 三態 |
| #41 Dual-Port Purity | 1.4、2.1～2.3 | ports／Registries＋purity gate |
| #42 M1 Splice Source | 5.3～5.4、9.1～9.2、FP18.2 | AT-15-09/11：先串整組再 repeat＋逐 sample |
| #43 Recording Buffer | 6.1～6.4、9.4、FP19.2 | 同意／TTL／無持久化＋audio session＋Finder 回播 |
| #44 Language Fail-Closed | 2.1～2.3 | ja／部分支援拒絕＋語言清單 |
| #45 TTS Ban | 1.4、FP11.2 | pubspec policy＋UI 無生成入口 |
| #46 Local-Only ASR | 1.4、2.2～2.4 | port 無 URL、Domain 無 network import、adapter 只 ProcessRunner |
| #47 Cross-Lesson Ban | 1.1、5.1～5.2 | 型別不變式＋他 Lesson 注入拒絕 |
| #48 Unsaved Labels | 3.1～3.2、FP10.3 | Domain dirty＋UI 三選一 |
| #49 .abolabel Version | 3.3～3.6、FP10.3 | round-trip／corrupt／mismatch |
| #50 Engine License | 2.4、8.1～8.2 | release checklist＋CT-09 |
| #51 M3 Custom Config | 9.1～9.2、FP18.2 | 3/5 預設與重置、0–20 step0.5、舊值相容 |
| #52 Truthful Progress | 9.3、FP20.1～2 | byte／stage 阻塞測試、無假百分比、ready fail-closed |
| #53 Draft Lesson Identity | 9.2、FP18.1 | 分析→生成→保存 id 不變＋跨 Lesson 仍拒 |
| #57 Original/Analysis PCM Isolation | 10.1、10.4、10.7～8 | Demucs 不可進播放／錄音參考／pack／export |
| #58 Label Region Disposition | 10.2～3 | kept/discarded/unmarked round-trip＋只有 kept 可送分析 |
| #59 Course Bundle v3 | 10.7 | v1/v2/v3 相容＋portable 白名單＋原子寫入 |
| #60 Recording Bounded Compute & Privacy | 10.6 | single-pass、isolate、≤1000 點、無 buffer、finally |
| #61 Export Provenance | 10.8 | 四層來源型別＋fingerprint/range/lessonId fail-closed |

> 2026-07-14 回饋增量開始後，#42/#43 暫降 PARTIAL，#51～#53 新增為 PARTIAL；只有 9.5 證據齊全後才能回寫 IMPLEMENTED。

---

## 7. 開放問題與需人工確認

| 編號 | 需確認事項 | 影響任務 | 阻塞範圍 |
|---|---|---|---|
| ~~OQ-1~~ | ~~是否確認以 v1.1-r1 的 **10 分鐘**為唯一權威，並授權依變更防線同步修正 requirement 核心總表／Q5 與 matrix #43？~~ | 1.1、6.*、FP15.* | **已定案：10 分鐘（O4，2026-07-12）並完成同步** |
| ~~OQ-2~~ | ~~REQ-19 顯示偏好要只存本機 `app_settings`，還是必須隨 `.aboprogress` 匯出／匯入？~~ | 1.1、7.1、FP16.2 | **已定案：隨 `.aboprogress` 匯出／匯入（使用者 2026-07-13）** |
| ~~OQ-3~~ | ~~跨 Lesson 防線採哪個可驗證結構：A. block 儲存同 Lesson 的 local syllable id 並由 factory 建立；B. SyllableRef 帶 lessonId；或由 fullstack-design 提出第三案？~~ | 1.1、5.1～5.2 | **已定案：Arrangement 綁單一 lessonId、block 無跨檔參照（fullstack-design）** |
| ~~OQ-4~~ | ~~LabelSession 僅剩一段再刪邊界時，沿用 `ERR_BOUNDARY_INVALID`，或三同步新增 `ERR_SEGMENT_MIN_COUNT`？~~ | 1.1、1.3、3.1～3.2 | **已定案：沿用 `ERR_BOUNDARY_INVALID`（使用者 2026-07-13）** |
| ~~OQ-5~~ | ~~ASR 切段失敗但保留空 session 的契約：回 `LabelOpenResult.warning`，或以攜 payload 的 DomainException 表達？~~ | 1.1、3.1～3.2、FP10.1 | **已定案：正常結果＋`LabelOpenWarning`（使用者 2026-07-13）** |
| ~~OQ-6~~ | ~~是否批准新增 `LabelRegistryRepository` Domain port，補足 LabelPackEngine→Drift 的 M5 依賴方向？~~ | 1.1、3.4～3.6 | **已批准（使用者 2026-07-13）** |
| OQ-7 | 800ms 靜音合併閾值以哪一組代表性歌曲 fixture 實測；若不佳，何時切換 VAD？ | 3.2、3.6、FP10.1 | REQ-11 品質；不阻塞骨架 |
| OQ-8 | schema／防線本體修改、暫存刪除、排列刪除等所有 `[必須確認]` 任務，須在各切片動工前逐項取得批准；核可本 task-split **不等於**自動批准這些高風險動作。 | 1.1/1.4/3.5/5.7/6.3/6.4/7.1、FP10.3/FP14.2/FP15.2/FP15.3/FP16.2 | 對應切片 |
| ~~OQ-9~~ | ~~是否批准 2026-07-14 實機回饋最終完整變更包（9.1～9.5、FP17～20、FE-QA.2）？~~ | S9 全部 | **已批准（使用者 2026-07-14 明示「批准最終完整變更包」）；批准只涵蓋本表 S9 範圍，不擴張至其他 schema／部署／正式環境操作** |

---

## 8. 自我檢查

- [x] 章節順序＝概覽→後端→前端原則→前端→依賴→開放問題。
- [x] 後端先於前端；每個前端任務都有明確後端前置。
- [x] 每條任務皆有風險分層、Non-scope、驗證方式。
- [x] REQ-10～REQ-21 全數至少有一個後端或前端任務承接。
- [x] AT-10-*～AT-21-* 與核心總表情境已落到任務驗證。
- [x] guardrails #39～#50 逐項映射；#38 保留回歸檢查。
- [x] TDD 任務在對應 production 實作之前。
- [x] 第一個產品里程碑 S1 是真端到端，不是水平層。
- [x] Non-scope 8/10～13 未被納入；TTS、線上 ASR、跨 Lesson、巢狀標籤均明確排除。
- [x] 2026-07-14 回饋包已拆成後端 9.1～9.5 與前端 FP17～20／最終跨頁驗收；後端先於前端，M1/M3/M10/M15 均有先行測試。
- [x] DFT-01～09 未被臆測解決，均以 OQ／[必須確認] 標明。
- [x] v1 凍結目錄與現存 29 個前序工作樹變更不在本輪修改範圍。
