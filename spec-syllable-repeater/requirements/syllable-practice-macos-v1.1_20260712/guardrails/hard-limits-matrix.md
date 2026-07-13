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

- **上游**：v1.1 需求成稿已定稿（2026-07-12），REQ-10～REQ-20 共 11 條；新增核心條款 M11–M14 與 M1/M10 補述；Non-scope 8 修訂＋10–13 新增；七決策 D1–D7。
- **階段現況**：需求已定稿；**fullstack-design／task-split／implementation 尚未開始**——多數新防線的程式落點還不存在，狀態以 `BLOCKED`（等待設計與實作階段）或 `PARTIAL`（v1 既有機制部分覆蓋）誠實標記，並附補完計畫；implementation 各切片完成時回寫本表。
- **新核心條款 → 本表對應**：M1 補述 → #42；M10 補述 → #43；M11 → #39；M12 → #40；M13 → #41；M14 → #44；D1 → #45；Non-scope 11 → #46；Non-scope 12 → #47；REQ-11 資料保護 → #48；`.abolabel` schema → #49；M9 擴大 → #50。

| # | 限制 | 白話說明 | 狀態 | 落地位置（檔案/設定/SQL）或補完計畫 | 批准人 | decision-log 編號／備註 |
|---|------|----------|------|---------------------------|--------|--------------------------|
| 38 | Destructive Command Guard | 毀滅性指令防護（套件預置）：`rm -rf`、`git reset --hard`、`DROP TABLE` 等一鍵毀資料的指令，AI 執行前必須走四步契約（停下→說明→等同意→給替代），並裝上工具層自動攔截 | IMPLEMENTED | ①3a：`.claude/settings.json` `permissions.deny` 8 條規則（rm -rf/-r/-f、sudo rm、git reset --hard、git clean -f、git push --force/-f）——注意 `.claude/` 在 `.gitignore`，屬機器本地防線；②3b：`.githooks/pre-commit` 第 4 段毀滅性指令掃描（staged `.sh/.ps1/.sql/Makefile`，命中即擋，`--no-verify` 放行＝人工確認）——已以夾帶 `rm -rf` 之測試腳本驗證命中、乾淨腳本通過；③軟性層：憲法 C14 四步契約持續有效（雙層並用）。DB 層 3c 不適用（SQLite 無帳號權限模型，由 v1 #3 結構防線代位） | eslite0220@gmail.com（使用者 2026-07-12 批准「裝3a+3b」） | 3a 為本地防線不進版控（換機需重裝，記入 README 待辦）；3b 進版控全 clone 生效 |
| 39 | M11 Step-Count Invariant Test | 音節總數即當時值：切點增減後，疊加步數必須＝編輯後的實際音節數（金標準 11 僅為未編輯預設）——用測試把這條鎖死 | BLOCKED | 補完計畫：`packages/domain/test/` 新增核心測試——①金標準 11 音節刪 1 切點→`buildSteps` 輸出 10 步（AT-13-07）②增 1 切點→12 步③增減後第 n 步仍=句尾往前 n 個（演算法本身不變）。落點掛在 REQ-13 實作切片 | — | 等 fullstack-design 定 AlignmentEngine 增減 API 簽名後實作；上游 v1 CT-02（固定 11 步）繼續有效不動 |
| 40 | M12 Arrangement-Override Test | 排列覆蓋規則：無自訂排列→自動句尾疊加；有→使用者排列；刪→回落自動。三態轉換用測試鎖死 | BLOCKED | 補完計畫：`packages/domain/test/` 新增——①無 Arrangement 時 PracticeEngine 輸出=`buildSteps` 結果（AT-16-01/04：第 2 步仍 `tion skills` 不吸附）②有 Arrangement 時輸出=排列各列（AT-16-02）③刪除後回落（AT-16-03）。落點掛在 REQ-15/16 實作切片 | — | M2 演算法不變性（v1 CT-02）與本項雙保險：自訂功能存在不得改變自動模式行為 |
| 41 | M13 Dual-Port Purity Gate | 雙抽層契約：ASR 引擎與音節切分器都走 Domain port（插座）；新引擎=adapter（插頭），不改 Domain——用依賴方向檢查鎖死 | PARTIAL | **已存在**：`AnalysisTranscriber` port（`packages/domain/lib/src/analysis/analysis_pipeline.dart:129`）＋`domain_purity_test.dart`（Domain 不 import sidecar/UI/平台，15 tests）＋CI 常駐。**補完計畫**：①port 升級為 `TranscriberEngine`（加語言/能力自述）②新增 `Syllabifier` port（現況：CMUdict＋母音團 fallback 寫死在 `alignment_engine.dart:148-163`，未抽層）③`TranscriberRegistry`/`SyllabifierRegistry`④domain_purity_test 擴充覆蓋新 port 檔案。落點掛在 REQ-17 實作切片 | — | v1 抽層已完成一半（Transcriber 有 port、Syllabifier 沒有）；擴充不動既有測試 |
| 42 | M1-Addendum Splice-Source Test | 串接白名單：自訂排列播放/匯出的每一 sample 必須來自本 Lesson 原音檔切片（任意順序/次數可、跨檔生成不可）——逐 sample 比對測試 | PARTIAL | **已存在**：v1 CT-01（`practice_build_steps_test.dart`：renderStep 輸出逐 sample 來自原 PCM sourceRanges，端點 ≤10ms fade 除外）鎖住基本 M1。**補完計畫**：新增 arrangement 渲染路徑的同級測試——①`[itll, rain, itll+rain]` 排列渲染輸出逐 sample 可對應回 syllable 時間區間（AT-15-09）②靜音段為數位零③重複次數展開後 sample 數=切片長×次數+靜音。落點掛在 REQ-15 實作切片 | — | CT-01 的測試手法（sourceRanges 逐 sample 核對）直接複用到新路徑 |
| 43 | M10-Addendum Recording-Buffer Guard | 錄音暫存三保證：①明示同意才暫存②時限到/重啟即清③永不寫入 .abopack/.aboprogress/任何持久檔——結構防線＋測試 | PARTIAL | **已存在**：v1 M10 全套（attempt 表結構上無音訊欄位=`db_schema_test.dart` 斷言；`RecordingComparator.compare` finally 刪錄音；pack/progress 無 audio 掃描測試）。**補完計畫**：①`RecordingBuffer` 只準寫 App 暫存目錄（路徑白名單，程式層拒絕其他路徑）②`db_schema_test` 加斷言：任何新表不得有錄音欄位③pack/progress byte 掃描測試沿用並確認暫存不進檔④App 啟動時清掃暫存目錄（孤兒清理）⑤TTL 邊界測試（29:59 可播/30:01 已清，AT-18-04）。落點掛在 REQ-18 實作切片 | — | v1 的「結構上不存在該欄位」手法是本項最硬防線，直接沿用 |
| 44 | M14 Language-Route Fail-Closed | 語言拒絕默默兜底：查無該語言切分器→明確拒絕建課件，嚴禁默默用英文切分器亂切——validation＋測試 | BLOCKED | 補完計畫：①Registry 查無 language 時回明確錯誤碼（新增 `ERR_LANGUAGE_UNSUPPORTED`，走三同步：設計檔錯誤碼總表→errors.dart→error_messages→測試，防 v1 code-review I-002 的錯誤碼借用漂移重演）②domain 測試：`ja` 建課件被拒且錯誤附已註冊語言清單（AT-17-02）；有 ASR 無切分器仍拒（AT-17-03）③舊檔無 language 欄位讀取時補 `en` 的向後相容測試（AT-17-04）。落點掛在 REQ-17 實作切片 | — | 「寧可明確說不支援，不可給錯的結果」；fail-closed 是本專案一貫手法（同 SidecarPaths.missingPaths） |
| 45 | D1 TTS-Regression Ban | TTS 永不回歸：任何 TTS/AI 合成音訊生成路徑不得進入程式碼——依賴白名單＋介面掃描 | BLOCKED | 補完計畫：①`domain_purity_test.dart` 或新增 policy 測試：掃 `pubspec.yaml` 全 workspace 禁止 TTS 類套件（flutter_tts、可產生音訊的模型 runtime 等黑名單樣式）②UI 測試：無音檔時「開始分析」置灰且介面無任何生成選項（AT-12-03）③`check_licenses.py` manifest 審查時人工核對新 sidecar 不具 TTS 用途。落點掛在 REQ-12 實作切片 | — | Non-scope 6/10「永不重新評估」的程式層對應；D1 決策留痕在 requirement.md §一 |
| 46 | Local-Only ASR Gate | ASR 僅限本地：辨識引擎只能是本地 sidecar 行程＋本地模型檔，不得經網路呼叫線上 ASR API | BLOCKED | 補完計畫：①`TranscriberEngine` port 契約定義為「PCM in→Word[] out」不含 URL/endpoint 欄位（型別層防線：介面上就沒有網路的位置）②domain_purity_test 確保 Transcriber 相關 Domain 檔不 import `dart:io` HttpClient/`package:http`③infra adapter 審查項：新引擎 adapter 只准 `Process.start`（sidecar 模式），出現網路 client import 即測試 fail。落點掛在 REQ-17 實作切片 | — | D7＋Non-scope 11；注意與 AIService（翻譯，允許 HTTPS）區隔——防線範圍限 Transcriber 鏈路 |
| 47 | Cross-Lesson Splice Ban | 跨 Lesson 拼接禁止：練習排列只能引用同一 Lesson 同一原音檔的切片 | BLOCKED | 補完計畫：①型別層：`PracticeArrangement` 綁定單一 `lessonId`，`PracticeBlock` 不帶跨檔參照欄位（結構上不存在=最硬）②domain 測試：嘗試注入他 Lesson syllable 的構造被建構子 assertion 拒絕。落點掛在 REQ-15 實作切片（model 設計時定案） | — | Non-scope 12；沿用「schema 上不存在該欄位」手法（v1 #3 同款） |
| 48 | Unsaved-Label Interception | 未儲存標籤攔截：段落標籤有未儲存變更時換音檔，必經「儲存/不儲存」明示選擇，不得靜默丟棄 | BLOCKED | 補完計畫：①controller 層：dirty flag＋換檔前置檢查（不能只做 UI 對話框，狀態機在 domain/controller 層擋）②widget 測試：dirty 時匯入 B 音檔→出現三選一對話框；選取消→停留原音檔（AT-11-04）。落點掛在 REQ-11 實作切片 | — | 2.5「不可接受」清單明列本條；對話框（UI）＋狀態機（邏輯層）雙層 |
| 49 | .abolabel Schema Versioning | 標籤檔格式版本防線：`.abolabel` 帶 schemaVersion；讀取時驗版本與欄位完整性，損毀/不相容即拒絕不部分載入 | BLOCKED | 補完計畫：沿用 v1 `.abopack`/`.aboprogress` 的既有手法——①schemaVersion 欄位必填②讀取全檔驗證後才套用，損毀不部分載入（同 AT-07-03 手法）③音檔指紋（Content Hash）不符時明確提示。落點掛在 REQ-11 實作切片 | — | `LessonPackEngine` 的 round-trip＋corrupt-reject 測試樣板直接複用 |
| 50 | M9-Extended Engine License Gate | 新 ASR 引擎授權審查：每一個新引擎與模型檔上架前必過授權白名單（MIT/BSD/ISC/Apache-2.0/LGPL 動態連結），未過審不得進發布產物 | PARTIAL | **已存在**：`scripts/check_licenses.py`＋`license-manifest.json`＋`fetch_sidecar_artifacts.py`（URL＋SHA-256＋授權三元組強制、TLS 驗證不得降級、GPL/AGPL/LGPL-static 拒絕）＋CI 常駐——機制對「任何新 sidecar」通用，天然覆蓋未來新引擎。**補完計畫**：REQ-17 的「新引擎上架程序」文件化進 release checklist（adapter 實作→授權審查→M4 故障注入→金標準回歸→Registry 註冊五步驟），讓流程有 checklist 可勾 | — | v1 #12 的機制即本項防線；差的只是流程文件化 |

<!-- #38 為套件預置（2026-07-12 版新增）；#39–#50 為 v1.1 需求條款對應；AI 不得刪除以上任何一行。 -->

## 狀態統計（每次更新後重算）

| 狀態 | 數量 |
|------|------|
| IMPLEMENTED | 1 |
| PARTIAL | 4 |
| NOT_APPLICABLE_PENDING_HUMAN_REVIEW | 0 |
| APPROVED_NOT_APPLICABLE | 0 |
| BLOCKED | 8 |
| REJECTED_NEEDS_IMPLEMENTATION | 0 |
| NOT_REVIEWED（交付前必須為 0） | 0 |

## BLOCKED 清單與解除條件

| # | 缺什麼 | 問誰／等什麼 |
|---|---|---|
| 39/40/42 補完/44/45/46/47/48/49 | ~~fullstack-design 定 API 簽名~~（2026-07-12 已完成：backend-design 介面 20~34＋核心防線對照表）；餘待 task-split → implementation 對應切片落地 | 每切片完成時回寫本表狀態 |

（#38 已於 2026-07-12 經使用者批准並落地 3a＋3b，移出 BLOCKED。）

## 交付條件備忘

1. 本表為**需求階段基線**：BLOCKED 9 條是誠實現況（程式落點尚不存在），不是欠帳——它們在 task-split 時必須各自對應到任務編號，實作切片完成時回寫 IMPLEMENTED。
2. `NOT_APPLICABLE_PENDING_HUMAN_REVIEW` 為 0——v1.1 新條款全數適用，無不適用裁決需求；decision-log 見同目錄（本輪 0 筆新裁決，檔案為佔位與規則說明）。
3. v1 matrix（#1–#37）繼續有效；`fullstack-code-review` 與 `project-archive` 檢查時**兩表都要核**。
4. `scripts/ci_core_checks.sh` 與 `.githooks/pre-push` 需把本表加入 `check_guardrails.py` 檢查路徑（見 task-split 待排項）。
