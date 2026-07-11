id: WF-20260706-handoff-new-session-starter-prompt-template
type: workflow
scope: project
source: syllable-repeater / 使用者要求範本化新 session 啟動提示（2026-07-06 S2 前置錨定收尾）
context: 現有 memory [[workflow_交接檔命名需用原流程階段與任務編號]] 只規範「交接檔檔名」；每次 session 收尾時交接檔內末尾章節「新 session 可直接複製的啟動提示」全靠當下 AI agent 拼湊出。2026-07-06 S2 前置錨定時使用者比對 S1a 交接檔 §11 與本 session 尾的啟動提示，兩者結構相近但缺明文範本；若不範本化，跨 session 一致性靠運氣。
action: 範本化「新 session 啟動提示」為 8 段結構（見下 `## 範本`），與 [[workflow_交接檔命名需用原流程階段與任務編號]] 分工——那條管「檔名指向哪」、這條管「檔內末章長什麼樣」。每次 session 收尾寫交接檔的末章時，逐段依此範本填；空段落（如「使用者已拍板事項」為空時）明寫「無」不要留空；「不要做的事」只列本切片相關已知雷區，不抄全歷史避免壓爆新 agent context 視窗。
result: 後續每個 session 收尾都可直接照範本填入該階段狀態；新 agent 讀到啟動提示即知該讀什麼、目前在哪、拍板了什麼、雷區在哪，冷啟動立刻進入動工節奏而非解讀對話歷史。
reasoning: 啟動提示是「新 agent 冷啟動的第一段有效輸入」——比記憶檢索本身更前置；格式漂移會讓新 agent 每次花時間解讀而非直接動工。跟命名 memory 分開兩條的原因：兩者職責邊界清楚（一個是檔名指標、一個是內文段結構），一卡一檔便於未來單獨修訂。
recommendation: 每次 session 收尾（或中途中斷）產出交接檔時，末章依此範本填；填完貼一份給使用者看，作為「session 收尾摘要」的一部分。避免變動範本 8 段順序——順序反映「新 agent 冷啟動的閱讀依賴」（讀原則→讀本專案記憶→讀交接檔→定位階段→回顧完成量→找到下一步→接住拍板→避開雷區）。若未來發現某段長期為空，回頭改本範本刪掉該段而非讓使用者長期看到「無」字樣。

## 範本（複製後填入該 session 狀態；三重引號區塊內即為新 agent 可直接複製的文字）

    ```text
    請先讀 02_Memory/constitution.md、preferences.md、MEMORY.md，
    再讀本專案 spec-syllable-repeater/memory/（Precision > Recall 挑 <N> 條相關），
    接著讀 <本次交接檔完整絕對路徑>。

    目前階段 <skill 名稱> / <切片編號> / <該切片的具體工作項目名稱>。
    本 session（<yyyy-mm-dd>）已完成 <本切片累計完成清單>，<test 綠燈統計 or 環境狀態摘要>。
    請切 <下一個 skill>，按交接檔 <引用交接檔內具體節> 從 <第一個具體 task> 動工。

    拍板：<使用者已拍板事項；若無寫「無」>。
    不要：<本切片相關且已知的雷區>。
    ```

### 8 段結構逐段規則

1. **讀原則檔**（固定 3 行）：constitution / preferences / MEMORY——這是「憲法優於本 session 決策」的入口，不可省。
2. **讀本專案記憶**：明寫「Precision > Recall」與挑選條數（依憲法 C7 原則 5 條，確有需要可超出）；不要列具體檔名——讓新 agent 依當下任務挑，避免範本鎖死。
3. **讀交接檔**：完整絕對路徑，含專案根與檔名——避免新 agent 猜路徑。
4. **目前階段**（斜線分隔 3 層）：`<skill> / <切片> / <工作項目>`——三層都要有，取自 `task-split.md` 或 execution-log 真實命名（不用 session 臨時代號，見 [[workflow_交接檔命名需用原流程階段與任務編號]]）。
5. **本 session 完成量**：切片列表 + 綠燈狀態一句；不列 code 細節（交接檔內文本身有）。
6. **具體動工建議**：`<下一個 skill> + <引用交接檔某節> + <第一個具體 task>`——這一句讓新 agent 冷啟動立刻知道打哪張 task。
7. **拍板事項**：使用者已明示的決策——如「4.7 順帶做」「路徑走寫檔」；空時明寫「無」，不省略段落。
8. **不要做的事**：本切片相關的雷區——含 M9 前置、TDD 紅測試不可跳、Non-scope 不可越、生成路徑禁入（M1）、Sandbox 不可自關等；不抄全歷史，只列**本切片會踩到的**。

## 範例（2026-07-06 S2 前置錨定實填，供對照）

```text
請先讀 02_Memory/constitution.md、preferences.md、MEMORY.md，
再讀本專案 spec-syllable-repeater/memory/（Precision > Recall 挑 5 條相關），
接著讀 /Users/karen_files/vibercoding project/syllable repeater/交接檔-20260706-fullstack-code-implementation_S2-PracticeEngine_FP4.md。

目前階段 fullstack-code-implementation / S2 / PracticeEngine 4.1-4.4 + 4.7 順帶 + FP4 播放。
本 session（2026-07-06）已完成 S0/S1a/S1b/S1c + hard-guardrails，全 test 綠。
請切 fullstack-code-implementation skill，按交接檔 §3 從 S2-1 TDD-red buildSteps 動工。

拍板：4.7 順帶做、renderStep 走「寫檔→just_audio 播檔」。
不要：關 macOS Sandbox（M9 前置）、跳過 CT-01/CT-02 TDD、renderStep 走生成路徑。
```

confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-07

## 升級 2026-07-07（不改原文，僅補新規範連結）

- **新增第 9 段**：原 8 段結構後新增第 9 段「給人類貼給下一個 agent 的可複製提示詞」，用 ```` ```text ``` ```` fenced code block 圍住整段可複製全文；人類複製即可讓新 session agent 冷啟動接手。同時附第 10 段「接續應有階段/流程的工作項目清單」（引用 task-split 編號＋一句白話），供人類決策要不要接手。
- **路徑段更新**：原範本中「請先讀 `02_Memory/constitution.md`...」應改為「請先讀 `~/Karen_Memory/Dev_Memory/constitution.md`...（若不存在則回退舊路徑 `<工作區>/02_Memory/`，相容期至 2026-09-07）」。
- **套件層主表**：本卡的範本已升級為 ai-dev-skills 獨立 skill 的 `references/handoff-template.md`，跨專案 universal 記憶卡見 [[workflow_handoff_convention]] 於 `~/Karen_Memory/Dev_Memory/workflows/`。原文為本專案首次落實 8 段範本的歷史根源，保留供追溯。
- **首份落實**：`spec-syllable-repeater/handoffs/交接檔-20260707-03-fullstack-code-review_修繕+skills編修+改名.md`（dogfooding 新規範）。
