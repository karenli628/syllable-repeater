id: PIT-20260713-v11-incremental-spec-drift
type: pitfall
scope: project
source: syllable-repeater / task-split（v1.1 增量輪）
context: v1.1 requirement r1 已把錄音暫存 TTL 定案為 10 分鐘，backend/frontend design 也已同步；但 requirement 核心驗收總表與 Q5、guardrails #43 仍殘留 30 分鐘舊值。通讀設計時另發現顯示偏好儲存位置、跨 Lesson 型別防線、非致命 ASR 降級、最小 Segment 錯誤碼與 LabelRegistry port 等契約缺口。
action: task-split 不替產品或設計默默選邊；先建立 DFT-01～DFT-09 漂移登錄，把受影響實作任務標為 [必須確認]，並要求使用 fullstack-code-review 變更防線七題同步修正需求／設計／matrix 後才動工。
result: 57 項任務在實作前已明確區分「可直接做／需要回報／必須確認」；guardrails #39～#50 全數有任務落點，9 個跨文件漂移不會被 implementation 隱性固化成程式行為。
reasoning: 增量規格最容易只修正文主段，漏掉核心總表、待確認清單與 matrix 補完計畫；若 task-split 只摘功能、不反向比對驗收與防線，舊值會一路進測試，最後形成三同步的錯誤版本。
recommendation: 下一次增量 task-split 必做四向核對：①修訂歷史／決策值 ②各 REQ 驗收表 ③核心驗收總表 ④guardrails 補完計畫；再檢查每個跨層資料流是否有 Domain port、每個拒絕分支是否有明確錯誤碼、每個結構防線是否真的能寫出負向測試。發現不一致先列 DFT＋阻塞任務，不在 task-split 內臆測裁決。
confidence: high
status: active
verified_count: 0
created: 2026-07-13
last_used: 2026-07-13
