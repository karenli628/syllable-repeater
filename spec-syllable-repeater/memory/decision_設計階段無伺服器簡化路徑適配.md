id: DEC-20260704-設計無伺服器適配
type: decision
scope: project
source: syllable-repeater / fullstack-design（macOS v1）
context: 本專案為純本機單人桌面應用，無 HTTP 後端；fullstack-design 標準以 HTTP API 與 TypeScript 為預設。
action: 走 skill 的「無伺服器端專案簡化路徑」並做三項適配：①「對外介面」＝Domain Layer 公開 API（backend-design.md §3.2 介面 1–19），為前端唯一契約權威；②錯誤契約集中於 §3.2.8 錯誤碼總表（17 碼），前端逐碼對應處理策略；③ 型別對齊以 Dart class 取代 TS interface，UI 直接複用 packages/domain 匯出型別、不另定義（單一真相）。§4 以資料完整性防線為主（M1–M10 對照表含 CT 編號與交付後看守欄）。
result: backend-design.md 與 frontend-design.md 已定稿，介面對齊 8 項自檢全過、零 [需後端設計補充]。
reasoning: 契約權威唯一化可讓 task-split 與 implementation 直接引用「§3.2 介面N」編號追溯，避免前後端各寫一套型別造成欄位漂移。
recommendation: 後續 task-split／implementation／review 引用介面一律用「backend-design.md §3.2.x 介面N」編號；新增 Domain API 必須先補 backend-design.md 再動前端；錯誤碼新增必須同步 §3.2.8 與前端錯誤對照表（功能點 8）。
confidence: high
status: active
verified_count: 0
created: 2026-07-04
last_used: 2026-07-04
