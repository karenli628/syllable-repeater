id: DEC-20260704-金標準音節數11
type: decision
scope: project
source: syllable-repeater / requirement-analysis（macOS v1 需求成稿）
context: PLAN3.0 §3.3、S1a、§6、§7 原文將金標準例句 `She has excellent communication skills` 寫為「15 音節/14 切點/15 步」。
action: 使用者於 2026-07-04 明示修正為 11；逐字核對音節拆分（she 1 + has 1 + ex·cel·lent 3 + com·mu·ni·ca·tion 5 + skills 1 = 11）確認修正正確，需求成稿全文以 11 音節 → 10 切點 → 11 步為準。
result: requirement.md（syllable-practice-macos-v1_20260704）已以 11 為金標準；修訂歷史與 C3 留痕記載原文 15 有誤。
reasoning: PLAN3.0 原文計數錯誤（communication 為 5 音節非 9）；金標準數字貫穿對齊、疊加、測試、驗收各層，錯一處全錯。
recommendation: 後續 design / task-split / implementation / 測試任何引用金標準例句處，一律用 11 音節/10 切點/11 步；若見 15 即為沿用 PLAN3.0 舊文，須改。第 2 步固定為 `tion skills`（驗證不吸附單字邊界）。
confidence: high
status: active
verified_count: 0
created: 2026-07-04
last_used: 2026-07-06
