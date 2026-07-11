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

其餘守則(紅線、風格、地雷)見 `AGENTS.md`——本檔不放任何規則副本,防止同一事實兩處記而漂移(現況唯一來源:`pipeline-state.md`;守則唯一來源:`AGENTS.md`)。
