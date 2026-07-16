id: WF-20260712-v1.1-incremental-matrix-baseline
type: workflow
scope: project
source: syllable-repeater / hard-guardrails（v1.1 增量輪）
context: v1 matrix（37 items）已凍結交付；v1.1 新增 M11~M14 與補述條款需要 guardrails 落點，但設計/實作尚未開始，程式落點不存在。
action: 採「增量 matrix」方案（A）：新開 v1.1_20260712/guardrails/hard-limits-matrix.md 只列 #38~#50 新增項，v1 表保持凍結繼續有效；需求階段的誠實狀態＝BLOCKED（附補完計畫＋落點切片）或 PARTIAL（v1 機制部分覆蓋）；ci_core_checks.sh 與 pre-push 改為雙表檢查（v1.1 表存在才驗，向後相容）。
result: 13 items（4 PARTIAL / 9 BLOCKED / 0 NOT_REVIEWED）全過 check_guardrails.py；commit 2c2e7c5。#38 毀滅性指令防護的 3a/3b 配方留待使用者批准。
reasoning: 增量表尊重 v1 凍結、版本邊界清楚；「BLOCKED＋補完計畫＋落點切片」讓需求階段的 matrix 不變成空頭支票——task-split 時每條 BLOCKED 必須對應任務編號，實作完成回寫 IMPLEMENTED。
recommendation: task-split 階段逐條把 #39~#50 排進任務（標 [必須確認] 的對照本表）；實作切片完成時回寫狀態並重算統計。新錯誤碼（如 ERR_LANGUAGE_UNSUPPORTED）走三同步，防 v1 I-002 錯誤碼借用漂移重演。下一輪新需求沿用增量表模式（v1.2 從 #51 起）。
confidence: high
status: active
verified_count: 0
created: 2026-07-12
last_used: 2026-07-13
