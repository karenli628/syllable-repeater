id: WF-20260712-v1.1-incremental-design
type: workflow
scope: project
source: syllable-repeater / fullstack-design（v1.1 增量輪）
context: v1 設計已凍結（backend 介面 1–19、錯誤碼 19 個、前端功能點 1–8）；v1.1 要在不動 v1 的前提下加段落標籤、切點增減、自由編排、雙抽層、錄音暫存。
action: 增量設計三原則落地——①介面編號續編（20–34）、錯誤碼三同步增補（8 碼）、前端功能點續編（9–16），兩檔皆聲明「v1 檔繼續有效，本檔只寫增量」；②關鍵樞紐設計：`effectiveUnits`（介面 30）作為 M12 自動/自訂的唯一判定入口，v1 直呼 buildSteps 處全改經此口；`buildSteps` 簽名不變讓 M11（總數即當時值）自然成立；③結構防線優先：PracticeArrangement 型別綁單一 lessonId（跨檔拼接結構上不可能）、RecordingBuffer 不建 DB 表（持久化結構上不可能）、TranscriberEngine 契約無 URL 欄位（線上 ASR 型別上不可能）。
result: backend-design.md＋frontend-design.md 各一份增量檔（commit effde0e）；.abopack schemaVersion 1→2（+language/+arrangement，舊檔補 en 相容）；新表僅 label_registry(V3)。開放問題 O1~O4/F1~F2 留設計審查。
reasoning: 「型別/schema 上不存在該欄位」是本專案驗證過最硬的防線手法（v1 attempt 無音訊欄位）；v1.1 三個新紅線全部沿用同手法而非跑時檢查。
recommendation: task-split 時每個切片先排「回歸不變性測試」（金標準 ±1ms、v1 全綠不動）再動抽層；EnglishSyllabifier 抽出採「先包舊碼再搬移」兩步走；guardrails #39~#49 逐條對應任務編號。
confidence: high
status: active
verified_count: 0
created: 2026-07-12
last_used: 2026-07-13
