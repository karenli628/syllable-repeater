id: WF-20260704-切片對照與schema確認
type: workflow
scope: project
source: syllable-repeater / task-split（macOS v1）
context: 任務拆分須同時滿足①PLAN3.0 垂直切片時序（S0→S6 每片可 demo）、②task-split 標準的模組分類編號、③「schema 任務一律標必須確認」硬性規則——三者可能互相卡住。
action: ①在概覽加「切片↔任務對照表」，模組編號照標準、時序照切片，兩軸並存；②TDD 任務獨立成卡（4.1/4.3/4.5/6.1 先紅）排在對應實作前；③schema 任務 1.2 依規標 [必須確認]，但以開放問題 OQ-3 寫明「新建本機 SQLite 無既有資料，使用者核可本 task-split 即視為確認」解套，不卡流程。
result: task-split.md 一次過標準自檢；30 條後端任務＋13 張前端任務卡，CT-01–10 全數有承接任務。
reasoning: 對照表讓「按模組讀」與「按時序做」兩種視角共存；schema 確認解套法把一次性確認收進核可動作，避免為零風險項目多一輪往返。
recommendation: implementation 階段按依賴表「建議順序①→⑬」執行；動 schema（V2 起）必須另行確認，不得沿用 OQ-3 的一次性核可；每切片末做聯調 demo 再進下一片。
confidence: high
status: active
verified_count: 0
created: 2026-07-04
last_used: 2026-07-04
