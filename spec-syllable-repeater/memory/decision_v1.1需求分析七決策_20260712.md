id: DEC-20260712-v1.1需求七決策
type: decision
scope: project
source: syllable-repeater / requirement-analysis（v1.1 增量新輪需求成稿）
context: 使用者提出 12 條新功能構想（含後補的模型抽換、錄音暫存、字稿譯文切換、譯文區搬移），經需求分析收斂為 REQ-10～REQ-20 共 11 條，落於 requirements/syllable-practice-macos-v1.1_20260712/。
action: 七項關鍵決策定案——D1 撤回 TTS 分支（違 Non-scope 6 絕對紅線與 M1）；D2 段落標籤跑在 demucs 分離後人聲軌＋手動微調兜底；D3 ASR＋Syllabifier 雙抽層打通多語言基礎（v1.1 只交付英文切分器）；D4 同 Lesson 同音檔切片任意串接明文列入 M1 補述；D5 句尾疊加預設可被自訂排列覆蓋（M12）；D6 錄音暫存例外（明示同意＋TTL＋重啟清空＋不進持久檔，M10 補述）；D7 ASR 僅限本地 sidecar，線上 API 列 Non-scope 11。
result: requirement.md v1.1-draft1 成稿（1085 行、11 REQ、新增 M11–M14 與 M1/M10 補述、Non-scope 8 修訂＋10–13 新增、核心驗收總表 13 條）；11 條全數為交付範圍（使用者拍板「全部都要做」，P0/P1/P2 僅為動工順序）。
reasoning: 增量新輪（情境 B）而非改 v1：改動觸及核心條款，v1 保持凍結可回溯；TTS 撤回是本輪最重要的紅線守護——使用者原提案與產品立身之本（模仿真人原聲）直接衝突，經指出後使用者同意撤回。
recommendation: 後續 fullstack-design / task-split / implementation 引用 v1.1 條款時：金標準 11 音節僅為未編輯預設（M11）；查無語言切分器必須明確拒絕不得默默英文兜底（M14）；設定頁批次「儲存」按鈕維持現況不拆。設計階段待定案：Q1–Q5 見 requirement.md 十五章。
confidence: high
status: active
verified_count: 0
created: 2026-07-12
last_used: 2026-07-13
