# 交接檔 20260712-01 · fullstack-design / v1.1 設計定稿 / 接 task-split

> 型別:中斷型（代碼:USER）。本交接檔為**未完成中斷**——接手者第一件事：完成下方 4 項，完成之前不得開始任何新階段。

## 1. 讀原則檔

新 session 開始請先讀（順序固定）：

1. `~/Karen_Memory/Dev_Memory/constitution.md`（憲法，全文）
2. `~/Karen_Memory/Dev_Memory/preferences.md`（偏好，全文——注意 2026-07-12 新增「零程式基礎新手假設＋專有名詞附白話」條款）
3. `~/Karen_Memory/Dev_Memory/MEMORY.md`（通用記憶索引）

> 舊路徑相容：若 `~/Karen_Memory/Dev_Memory/` 不存在，回退到 `<工作區>/02_Memory/`（相容視窗至 2026-09-07）。

## 2. 讀本專案記憶（Precision > Recall）

從 `spec-syllable-repeater/memory/` 中挑本任務相關的 5 條打開：

- `decision_v1.1需求分析七決策_20260712.md` — D1~D7（撤 TTS／分離後切句／雙抽層／串接白名單／預設可覆蓋／暫存例外／僅本地 ASR）
- `workflow_v1.1增量matrix需求階段基線.md` — guardrails #38~#50 增量表模式與 BLOCKED＋補完計畫手法
- `workflow_v1.1增量設計介面續編與M12單一入口.md` — 介面 20~34 續編、effectiveUnits 唯一判定入口、「結構上不可能」防線手法
- `decision_金標準例句音節數修正為11.md` — 11 音節僅為未編輯預設（M11 參照）
- `decision_zero_crossing_search_window_10ms.md` — 切點吸附 10ms 窗（REQ-13 沿用）

## 3. 讀本交接檔

完整絕對路徑（避免新 agent 猜路徑）：

```
/Users/karen_files/vibercoding project/syllable repeater/spec-syllable-repeater/handoffs/交接檔-20260712-01-fullstack-design_v1.1設計定稿_接task-split_中斷USER.md
```

## 4. 目前階段

`fullstack-design / none / v1.1 前後端增量設計定稿（含 r1 裁決回寫）`

（與 `requirements/syllable-practice-macos-v1.1_20260712/pipeline-state.md` 的 stage_skill=fullstack-design、stage_status=done 一致；v1.1 尚無 task-split，切片=none）

## 5. 本 session 完成量

- **v1 版控收尾**：74 個 dirty 檔分批 commit（C1~C6a）＋C6b 六份舊史料交接檔進版控（check_handoff.py 加 `LEGACY_HANDOFF_CUTOFF="20260712"` 遷移期豁免，使用者批准）。
- **v1.1 需求成稿定稿**：`requirement/requirement.md`（1086 行、REQ-10~REQ-20 共 11 條全交付、M11~M14＋M1/M10 補述、Non-scope 8 修訂＋10~13、七決策 D1~D7、修訂 r1）。
- **v1.1 guardrails**：`guardrails/hard-limits-matrix.md` #38~#50（1 IMPLEMENTED／4 PARTIAL／8 BLOCKED 附補完計畫）＋decision-log 佔位；ci_core_checks.sh 與 pre-push 升級雙表檢查；#38 毀滅性指令防護已落地（3a `.claude/settings.json` deny 8 條＝本地防線、3b pre-commit 掃描＝進版控）。
- **v1.1 設計**：`design/backend-design.md`（介面 20~34、8 新錯誤碼、.abopack schemaVersion 2、V3 label_registry、核心防線對照表）＋`design/frontend-design.md`（labeling/arrangement 新模組、功能點 9~16、介面對齊 8 項自檢全過）。
- **設計裁決 r1 已回寫**：O2 `.abolabel` 記 separateVocals；O4 暫存 TTL 10 分鐘＋手動即刪＋切步即清/同步驟覆蓋；F1 組塊手勢＝長按拖曳堆疊（iPhone 式）；F2 AI 譯文鈕一併搬移。
- 測試綠燈：scripts unittest 22 tests OK；check_guardrails 雙表通過；check_handoff --staged 各 commit 通過。
- Git commits：`1b815eb`、`c6fe56f`、`413512a`、`4343fd5`、`0cd0666`、`cd59b62`、`d5de28a`、`a55179c`、`35d1f7e`、`2c2e7c5`、`effde0e`、`781b3bd`。

### 中斷證據

使用者原話：「寫一份提示詞，給新session 交接繼續」

## 6. 具體動工建議

- **下一 skill**：`task-split`（與 pipeline-state.next_skill 一致）
- **從交接檔哪節開始**：本檔第 10 節第 1 項
- **第一個 task**：對 v1.1 需求目錄執行 task-split——輸入為 design/ 兩檔＋requirement.md；拆分時 guardrails #39~#49 每條 BLOCKED 必須對應到任務編號（matrix「交付條件備忘」第 1 條）；切片順序建議先排「回歸不變性測試」（金標準 11 音節 ±1ms、v1 全綠不動）再動抽層

## 7. 拍板事項

- 11 條 REQ 全數為 v1.1 交付範圍（P0/P1/P2 僅動工順序，不可裁減）
- TTS 分支撤回（D1，永不重評）；ASR 僅限本地 sidecar（D7）
- 設計裁決：O2 記分離狀態／O4 暫存 10 分鐘不曝露＋切步即清／F1 長按拖疊成組／F2 AI 譯文鈕一併搬
- matrix #38 已批准落地（3a＋3b）；設定頁批次「儲存」按鈕維持現況不拆
- 六份舊史料交接檔均裁定完成型（內文不追改，README 留痕）

## 8. 不要做的事

- 不要動 v1 目錄（`syllable-practice-macos-v1_20260704/`）任何檔案——v1 已凍結交付
- 不要清理或 revert 工作樹既存的 29 檔前序 session 變更（S6-22 GUI smoke remediation 遺留，見第 10 節第 3 項，等使用者裁定）
- 不要在任何練習播放/匯出路徑引入生成音訊（M1；D1 TTS 已撤回勿再提案）
- 不要用 `git add -A`（會把前序遺留檔誤收）；逐檔點名 stage
- 新交接檔（≥2026-07-12）必須新格式全額檢查；勿再依賴遷移期豁免

## 9. 接手方式

- 新 session 只需說：「**接手**」——開機五步會自動讀 LATEST → pipeline-state → 本檔。
- 該平台沒有開機區塊時，貼以下 3 行（內容固定，永遠相同，可存輸入法快捷）：

```text
讀 spec-*/handoffs/LATEST.md,依其指向讀 pipeline-state.md 全文與最新交接檔第 4-8 段;
再讀 ~/Karen_Memory/Dev_Memory/ 的 constitution.md、preferences.md、MEMORY.md 與本專案 spec-*/memory/ 相關卡 ≤5 條。
回報:目前階段/建議 skill/前 3 項待辦,等我拍板後才動工。
```

## 10. 接續應同階段/下一個新階段之依序工作項目清單（供人類決策）

（v1.1 尚無 task-split，以下為階段級項目；第 1 項完成後改以 task-split 編號追蹤）

- [ ] 執行 task-split — 產出 `task/task-split.md`（先後端後前端；guardrails #39~#49 逐條掛任務編號；回歸不變性測試切片先行）
- [ ] 執行 fullstack-code-implementation — 依 task-split 切片實作（P0 先行：REQ-10/11/12/13/15）
- [ ] v1 遺留：使用者裁定工作樹 29 檔前序變更（S6-22 遺留；`git status --short` 盤點後分批確認 commit 或棄置）
- [ ] v1 遺留：AT-09-03 release smoke（使用者親跑：解壓 dist zip、xattr -cr 或右鍵開啟、跑 REQ-01→08 GUI 流程）
