# hard-limits-matrix.md — 硬性限制總表（v1.1 增量）

> 專案／需求：Syllable Repeater macOS v1.1（`syllable-practice-macos-v1.1_20260712`）
> 建立日期：2026-07-12
> 選用 profile：`local-single-user`（承 v1；純本機、單人、無伺服器、無金流；ASR 僅限本地 D7）
>
> **本表定位（增量式）**：v1 matrix（`../../syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md`，#1–#37）為全案通用權威，**保持凍結、繼續有效**；本表只列 v1.1 新增條款的限制項（#38 起）。審查時兩表都要看。
>
> **狀態值（只允許以下七種）**：
> `NOT_REVIEWED`／`IMPLEMENTED`／`PARTIAL`／`NOT_APPLICABLE_PENDING_HUMAN_REVIEW`／`APPROVED_NOT_APPLICABLE`／`BLOCKED`／`REJECTED_NEEDS_IMPLEMENTATION`
>
> **規則**：AI 不得刪行；不適用走狀態機不是刪行；批准人不得是 AI；`IMPLEMENTED` 落地位置必填。

## 專案上下文（v1.1 增量判定依據）

- **上游**：v1.1-r6 需求為 REQ-10～REQ-21 共 12 條；2026-07-15 使用者已批准段落三態、原音／分析軌隔離、1／1與3／1、錄音單次比對、`.abopack v3` 與四層匯出。
- **階段現況**：S10 已完成 TDD、分批全量回歸與真人驗收；r6/r7 三同步與新增防線均有自動證據。
- **r6 對應**：原音／分析軌 #57；標籤三態 #58；CourseBundle v3 #59；錄音限算與隱私 #60；四層匯出來源 #61。既有 #43/#49/#51/#55 因規則變更降為 PARTIAL。

| # | 限制 | 白話說明 | 狀態 | 落地位置（檔案/設定/SQL）或補完計畫 | 批准人 | decision-log 編號／備註 |
|---|------|----------|------|---------------------------|--------|--------------------------|
| 38 | Destructive Command Guard | 毀滅性指令防護（套件預置）：`rm -rf`、`git reset --hard`、`DROP TABLE` 等一鍵毀資料的指令，AI 執行前必須走四步契約（停下→說明→等同意→給替代），並裝上工具層自動攔截 | IMPLEMENTED | ①3a：`.claude/settings.json` `permissions.deny` 8 條規則（rm -rf/-r/-f、sudo rm、git reset --hard、git clean -f、git push --force/-f）——注意 `.claude/` 在 `.gitignore`，屬機器本地防線；②3b：`.githooks/pre-commit` 第 4 段毀滅性指令掃描（staged `.sh/.ps1/.sql/Makefile`，命中即擋，`--no-verify` 放行＝人工確認）——已以夾帶 `rm -rf` 之測試腳本驗證命中、乾淨腳本通過；③軟性層：憲法 C14 四步契約持續有效（雙層並用）。DB 層 3c 不適用（SQLite 無帳號權限模型，由 v1 #3 結構防線代位） | eslite0220@gmail.com（使用者 2026-07-12 批准「裝3a+3b」） | 3a 為本地防線不進版控（換機需重裝，記入 README 待辦）；3b 進版控全 clone 生效 |
| 39 | M11 Step-Count Invariant Test | 音節總數即當時值：切點增減後，疊加步數必須＝編輯後的實際音節數（金標準 11 僅為未編輯預設）——用測試把這條鎖死 | IMPLEMENTED | `packages/domain/test/practice_build_steps_test.dart`：AT-13-07 金標準刪 1 切點→10 步；AT-16-04 增 1 切點→12 步；逐步斷言第 n 步仍為句尾倒數 n 音節，且第 2 步固定 `tion skills`；10/10 PASS | — | Task 4.1～4.3（2026-07-13）完成；上游 v1 CT-02（固定 11 步）繼續有效不動 |
| 40 | M12 Arrangement-Override Test | 排列覆蓋規則：0 列→目前完整單句 1 單元；N 列→N 個使用者排列單元並即時連動；一鍵生成仍鎖定 M2 的 N 列句尾疊加 | IMPLEMENTED | `PracticeEngine.effectiveUnits` 為唯一判定入口；`practice_effective_units_test.dart`、`practice_controller_test.dart`、`practice_screen_test.dart` 鎖定 0 列完整 PCM 1 單元、N 列即時連動、一鍵生成仍為 M2 句尾排列；完整 Domain 171/171、App 155/155 PASS | 使用者（2026-07-14 批准本輪完整清單） | Task 9.6/FP21.1（2026-07-14） |
| 41 | M13 Dual-Port Purity Gate | 雙抽層契約：ASR 引擎與音節切分器都走 Domain port（插座）；新引擎=adapter（插頭），不改 Domain——用依賴方向檢查鎖死 | IMPLEMENTED | `packages/domain/lib/src/ports/transcriber_engine.dart`、`ports/syllabifier.dart`、`analysis/transcriber_registry.dart`、`alignment/syllabifier_registry.dart`；`analysis_pipeline.dart` 只依賴雙 Registry；`domain_purity_test.dart` 遞迴掃描 Domain，`transcriber_registry_test.dart`／`syllabifier_registry_test.dart` 鎖定契約；最新完整 Domain 157/157 PASS | — | Task 2.1～2.3（2026-07-13）完成；新增引擎只需 infra adapter＋Registry 註冊 |
| 42 | M1-Addendum Splice-Source Test | 串接白名單：自訂排列播放/匯出的每一 sample 必須來自本 Lesson 原音檔切片；組塊重複必為「完整組塊原音＋數位零靜音」逐輪重複，不可拆成各子塊各自重複 | IMPLEMENTED | `PracticeEngine.renderBlockRow`、`renderUnitsExport` 皆只經 `renderStep` 原 PCM 切片路徑；`practice_arrangement_render_test.dart` 鎖定逐 sample 來源、積木尾靜音、整列無尾靜音與預覽／練習／匯出同一結果 | 使用者（2026-07-14 批准本輪完整清單） | Task 9.6/9.7（2026-07-14） |
| 43 | M10 Recording Ephemeral Guard | RecordingBuffer 類型／service／provider／store／清單面板不得存在；僅允許目前單元最近一次 PCM 存於 UI 記憶體；來源與回放 temp 在成功／失敗／取消／停止均 finally 清除；DB／pack／progress 無錄音與路徑欄位 | IMPLEMENTED | `RecordingComparator` finally 清來源；`PracticeUiState.recordedPcm` 僅存目前單元記憶體；`practice_controller_test.dart` AT-18-02/05/08/09、`practice_player_test.dart`、`db_schema_test.dart`、`lesson_pack_engine_test.dart` 鎖定清除與無持久欄位；Finder 真人麥克風已由使用者確認 | 使用者（2026-07-15 批准 r7） | 不恢復 RecordingBuffer；目前單元記憶體回放為明確例外 |
| 44 | M14 Language-Route Fail-Closed | 語言拒絕默默兜底：查無該語言切分器→明確拒絕建課件，嚴禁默默用英文切分器亂切——validation＋測試 | IMPLEMENTED | `TranscriberRegistry`／`SyllabifierRegistry` 查無語言一律丟 `ERR_LANGUAGE_UNSUPPORTED` 並列出已註冊語言；`AnalysisPipeline` 在 decoder 等副作用前雙重檢查；`analysis_pipeline_test.dart` 鎖定 AT-17-02/03，`ImportRequest.language` 預設 `en` 保持向後相容；最新完整 Domain 157/157 PASS | — | Task 1.3、2.1～2.3（2026-07-13）三同步完成 |
| 45 | D1 TTS-Regression Ban | TTS 永不回歸：任何 TTS/AI 合成音訊生成路徑不得進入程式碼——依賴白名單＋介面掃描 | IMPLEMENTED | `packages/domain/test/transcriber_policy_test.dart` 掃描全 workspace pubspec 的 TTS 依賴黑名單，禁止 Transcriber Domain 出現 HTTP／URL；App `import_screen_no_tts_test.dart` 1/1 鎖定無音檔時按鈕置灰、指引文案且無 TTS／生成控制項；完整 license／CI gate PASS。 | 使用者（預先授權全數批准） | Task 1.4、FP11.2、8.1～8.2（2026-07-14）完成；發布閘門人工核對依使用者預先授權完成 |
| 46 | Local-Only ASR Gate | ASR 僅限本地：辨識引擎只能是本地 sidecar 行程＋本地模型檔，不得經網路呼叫線上 ASR API | IMPLEMENTED | `TranscriberEngine` 為 PCM＋language 輸入，無 URL/endpoint；`transcriber_policy_test.dart` 禁 HTTP／URL；`WhisperAnalysisTranscriber` 僅經 `ProcessRunner` 呼叫本地 FFmpeg／whisper sidecar 與本地模型；adapter／integration tests PASS，最新完整 Domain 157/157 | — | Task 1.4、2.4、2.5（2026-07-13）完成；線上 ASR 仍屬 Non-scope 11 |
| 47 | Cross-Lesson Splice Ban | 跨 Lesson 拼接禁止：練習排列只能引用同一 Lesson 同一原音檔的切片 | IMPLEMENTED | `PracticeArrangement` 綁定單一 `lessonId`；`PracticeBlock` 型別中沒有 lessonId、音訊或路徑欄位；`placeBlock` 必傳但不持久化 `sourceLessonId`，不符時在修改前以含雙方 id 的 `ArgumentError` 拒絕；S9-21 新增的刪除、組內抽出與併入操作只重排同一 Arrangement 既有音節，不接受外部來源；`practice_arrangement_test.dart` 鎖定拒絕後原排列不變及新操作 undo，28/28 PASS | — | Task 5.1～5.2、S9-21.3～21.4 完成；Non-scope 12；沿用「schema 上不存在該欄位」手法（v1 #3 同款） |
| 48 | Unsaved-Label Interception | 未儲存標籤攔截：段落標籤有未儲存變更時換音檔，必經「儲存/不儲存」明示選擇，不得靜默丟棄 | IMPLEMENTED | `LabelSession.dirty` 作為狀態機來源；`LabelingScreen._requestOpen` 在 `openAudio` 前檢查 dirty，強制「取消／放棄並開啟／儲存後開啟」三選一；取消不呼叫 `openAudio`，儲存僅在 `.abolabel` 成功寫入後由 Domain `markSaved()` 清除 dirty；`app/test/labeling/labeling_screen_test.dart` 4/4 覆蓋三分支與既有標籤載入，Controller 失敗寫入測試保留 dirty（AT-11-04） | — | 使用者 2026-07-14 批准 FP10.3；Task FP10.3 完成；對話框（UI）＋Domain dirty 狀態機雙層 |
| 49 | .abolabel Schema Versioning | `.abolabel v2` 必須保存 kept／discarded／note 並相容讀 v1；損毀／指紋不符拒絕且零副作用 | IMPLEMENTED | `LabelPackEngine.schemaVersion=2`；`label_pack_engine_test.dart` AT-11-13 鎖定 kept/discarded/note round-trip、v1→kept 相容、原子失敗零副作用；`label_session_test.dart` AT-11-12/15 鎖定三態與 kept-only 投影 | 使用者（2026-07-15 批准 r6） | Domain 全量 188/188 PASS |
| 50 | M9-Extended Engine License Gate | 新 ASR 引擎授權審查：每一個新引擎與模型檔上架前必過授權白名單（MIT/BSD/ISC/Apache-2.0/LGPL 動態連結），未過審不得進發布產物 | IMPLEMENTED | `scripts/check_licenses.py` 對 sidecar／sidecar-transitive／model 類別要求 `source`，並拒 GPL/AGPL/CC BY-NC/非商用／研究限定／bundled Python／LGPL static；`fetch_sidecar_artifacts.py` 強制 artifact URL＋SHA-256＋授權三元組、TLS 正常驗證；v1.1 `release/release-checklist.md` 固化 adapter→授權→M4 故障注入→金標準回歸→Registry 五步；23/23 Python gate PASS，既有 25 components manifest PASS | — | Task 8.1～8.2（2026-07-13）完成；無新增實際引擎／模型，流程防線已落地 |
| 51 | M3 Custom-Block Config Guard | repeat 1–10、silence 0–20／0.5；新建／重置／成組／拆組預設 1／1；舊 pack 明示值照原值相容 | IMPLEMENTED | `PracticeBlock.defaultRepeatN=1`、`defaultSilenceFactor=1`；`practice_arrangement_test.dart` AT-15-04/06/11/13 與 `lesson_pack_engine_test.dart` 鎖定邊界、重置、3/1 row 預設及舊值 round-trip | 使用者（2026-07-15 批准 r6） | Domain 全量 188/188 PASS |
| 52 | M15 Truthful Progress & Readiness Guard | 匯入、解碼、分離、切段、分析只能依真實 byte／階段事件推進；通過讀取、格式、時長驗證前不得顯示 ready 或開放分析；禁止硬編假百分比 | IMPLEMENTED | `AudioImportReader`、`SegmentEngine.openAudio` 與 App readiness 狀態機已只用真實 bytes／stage；preview 假百分比已移除；reader、staged progress、label/import 阻塞測試及 App 完整回歸皆 PASS | 使用者（2026-07-14 批准完整變更包） | Task 9.3、FP20.1/FP20.2（2026-07-14） |
| 53 | Draft Lesson Identity Guard | 分析成功後立即有穩定 Lesson id，使尚未存 pack 的一鍵生成可用；正式存檔沿用同 id，且不得藉草稿 id 繞過跨 Lesson 防線 | IMPLEMENTED | `DraftLessonIdentity` 在分析成功建立並沿用至 Arrangement／Lesson 存檔；換檔重生 id；跨 Lesson `placeBlock` 仍先拒絕；Domain／App 測試鎖定分析→生成→保存 id 不變 | 使用者（2026-07-14 批准完整變更包） | Task 9.2、FP18.1（2026-07-14） |
| 54 | Waveform Node-Range Consistency | 音節高亮、新增切點與積木預覽必須共用節點定義的區段；第一段從 PCM 0 開始、最後段到 PCM duration，禁止尾端不可選或播放截斷 | IMPLEMENTED | `waveformNodeRange` 已供 Canvas hit/highlight、insertBoundary 與積木試聽共用；AT-17-09/10 與最後積木 PCM 範圍測試 PASS；最新 Release App 的首尾黃色區段已由使用者於 2026-07-15 真人目視確認 | 使用者（2026-07-15 明示「真人驗收OK」） | Task 9.8/FP21.3/S9-22.5；自動與人工證據齊全 |
| 55 | Row-and-Export-Layer Guard | 積木內層先渲染；整列預設 3／1，gap 基準只算原始長度一次，最後一次無 row silence；匯出覆寫只取代 row 外層、不另乘一層、不回寫 | IMPLEMENTED | `PracticeEngine.renderBlockRow/renderUnitsExport`；`practice_arrangement_render_test.dart` 鎖定 95500ms/62500ms、最後無 row silence、AT-16-08 覆寫不回寫；`export_dialog_test.dart` 鎖定第四層 local override | 使用者（2026-07-15 批准 r6） | Domain 188/188、App 分批全綠 |
| 56 | Vocal-Separation Channel Integrity | 立體聲輸入送入 Demucs 前不得無條件 downmix；單聲道素材允許模型品質受限但不得虛報完全分離，後續仍只使用合法本地模型與原音分析路徑 | IMPLEMENTED | `FfmpegDemucsAudioPreparer` 直接從原始匯入檔準備 44.1kHz stereo PCM WAV，分離後才轉 mono；AT-18-10 與真 Demucs 整合 1/1 PASS；AAA.m4a 實測為 48kHz mono、16.23s，vocals mean -24.0dB、accompaniment -35.7dB，已誠實標示單聲道品質限制，不保證完全分離 | 使用者（2026-07-14 批准本輪完整清單） | Task 9.9（2026-07-14） |
| 57 | Original/Analysis PCM Isolation | Demucs 軌只能供辨識／分析；播放、錄音參考、單句封包與所有匯出只能取 originalPcm | IMPLEMENTED | `AnalysisAudioTracks`/`AnalysisEvent.analysisPcm` 明確雙軌，`decodedPcm` 固定原音；`analysis_pipeline_test.dart` AT-12-09 驗 ASR 用分離軌且 done 保留 original；播放、錄音、pack、export API 僅接受 original `Pcm` | 使用者（2026-07-15 批准 r6） | Domain 全量 188/188 PASS |
| 58 | Label Region Disposition Guard | kept／discarded／unmarked 三態須可 round-trip；只有 kept 可進單句分析，discarded 不得被靜默復活 | IMPLEMENTED | `LabelSession`/`SegmentDisposition` 與 `.abolabel v2`；AT-11-12/13/15 Domain、Controller、Widget 測試覆蓋三態、間隙、v1 相容、kept-only 分析 | 使用者（2026-07-15 批准 r6） | Domain/App 分批全綠 |
| 59 | Course Bundle v3 Portability Guard | v3 originalAudio 必填；可選區塊缺少不算損壞；portable projection 禁顯示偏好、錄音、路徑與完整 attempt history；v1/v2 可讀 | IMPLEMENTED | `CourseBundleEngine.schemaVersion=3`、`sentenceSourceRange`、可選 labels/lesson/arrangement/latestProgress；`course_bundle_engine_test.dart` AT-21-01～03/08、`file_io_test.dart` 原子失敗無半成品、App open-service 測試 | 使用者（2026-07-15 批准四層匯出與 v3） | Domain/Infra/App 分批全綠 |
| 60 | Recording Bounded-Compute & Privacy | 參考音固定單次原音；比較離開 UI isolate；每條圖 ≤1000 點；無 RecordingBuffer；目前單元記憶體 PCM 生命週期有界；來源與回放 temp finally 清理 | IMPLEMENTED | `RecordingComparator` 以 `Isolate.run` 比較；AT-18-01～09 覆蓋單次參考、UI heartbeat、≤1000 點且保留首尾/極值、finally、立即刪除與記憶體生命週期；DB/pack 結構掃描無 RecordingBuffer | 使用者（2026-07-15 批准 r7） | Domain 188/188、App 分批全綠；真人麥克風通過 |
| 61 | Four-Layer Export Provenance Guard | 四層選擇須先形成 immutable plan；fingerprint／range／lessonId 不符 fail closed；Demucs／錄音不得成為音訊來源；override 不回寫 | IMPLEMENTED | `PracticeExportPlanner`/immutable source refs/snapshot 在寫檔前驗 fingerprint/lessonId/range；音訊 enum 僅三種原音來源；App 依音訊篩相容排列並提供 v3 保留段；AT-21-04～07 與 Release FFmpeg 匯出 8/8 PASS | 使用者（2026-07-15 批准四層匯出） | 所有渲染仍委派 `PracticeEngine` |
| 62 | Managed Temp Lifecycle Guard | App／sidecar／預覽／解包中介檔只能位於本次 session 管理目錄；成功、失敗、取消與切課依契約清除；不得把使用者保存檔納入自動清理 | IMPLEMENTED | r8 Task S9-22.4：`ManagedTempSession` lease 鎖與 session 清掃；Whisper／Demucs finally；練習預覽與課程解包生命週期；`managed_temp_session_test.dart` 20 作業／多 session／使用者 pack 負向測試，adapter 與真 Sidecar 整合測試 | 使用者（2026-07-15 批准 r8） | session-only cache；不以共用 temp 全刪避免多實例互傷 |

<!-- #38 為套件預置（2026-07-12 版新增）；#39–#50 為 v1.1 需求條款對應；AI 不得刪除以上任何一行。 -->

## 狀態統計（每次更新後重算）

| 狀態 | 數量 |
|------|------|
| IMPLEMENTED | 25 |
| PARTIAL | 0 |
| NOT_APPLICABLE_PENDING_HUMAN_REVIEW | 0 |
| APPROVED_NOT_APPLICABLE | 0 |
| BLOCKED | 0 |
| REJECTED_NEEDS_IMPLEMENTATION | 0 |
| NOT_REVIEWED（交付前必須為 0） | 0 |

## BLOCKED 清單與解除條件

| # | 缺什麼 | 問誰／等什麼 |
|---|---|---|
| — | 目前沒有 BLOCKED 條款 | — |

（#38 已於 2026-07-12 經使用者批准並落地 3a＋3b，移出 BLOCKED。）

## 交付條件備忘

1. Finder 目視與真人麥克風已由使用者確認通過；r6/r7 的 #43/#49/#51/#55/#57～#61 已以紅測試、實作與分批全量回歸回到 IMPLEMENTED。
2. `NOT_APPLICABLE_PENDING_HUMAN_REVIEW` 為 0——v1.1 新條款全數適用，無不適用裁決需求；decision-log 見同目錄（本輪 0 筆新裁決，檔案為佔位與規則說明）。
3. v1 matrix（#1–#37）繼續有效；`fullstack-code-review` 與 `project-archive` 檢查時**兩表都要核**。
4. `scripts/ci_core_checks.sh` 與 `.githooks/pre-push` 需把本表加入 `check_guardrails.py` 檢查路徑（見 task-split 待排項）。
