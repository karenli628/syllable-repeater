id: PF-20260707-error-code-semantic-drift
type: pitfall
scope: project
source: syllable-repeater / fullstack-code-review 全專案 QA 第 1 輪（發現 I-002）
context: backend-design §3.2.8 是 17 個錯誤碼的單一權威表，前端 error_messages.dart 依 code 顯示文案。實作 whisper/demucs wrapper 與 practice_controller 時，因表上沒有「轉寫失敗/分離失敗/播放失敗」專屬碼，就近借用了 ERR_DECODE_FAILED。
action: 全專案 QA 抓到借用點：whisper_transcriber.dart:136/141（exit≠0、JSON 未產出）、demucs_separator.dart:82/88、analysis_pipeline.dart:279（泛型 catch）、practice_controller.dart 多處（播放失敗、前置狀態）。UI 依碼映射顯示「解碼失敗，請確認音檔可播放」，誤導使用者排錯方向。
result: 記為 important（I-002）。修法＝小型變更防線後三同步：backend-design §3.2.8 增 ERR_TRANSCRIBE_FAILED / ERR_SEPARATE_FAILED → errors.dart → error_messages.dart（注意 app/test 有「17 碼數量」斷言要同步改）→ frontend-design 功能點 8 → wrapper 測試斷言。可直接用 docs/codex/prompts.md 的 P1 提示詞執行。
reasoning: 「表上沒有合適的碼」的正確反應是走三同步新增，而不是借語意最近的碼——借用當下最省事，但錯誤碼是前後端對齊契約，借用＝文案語意被稀釋，之後每個新場景都會繼續借，漂移不可逆。
recommendation: 日後任何模組遇到「§3.2.8 沒有我要的碼」：①先確認是否真是新語意（不是既有碼的子情境）；②是→先改設計檔再改碼（順序不可反）；③全文搜尋該新碼確保 errors.dart / error_messages.dart / 兩份設計檔 / 碼數斷言測試五處同步。UI 端不確定碼時寧可顯示 DomainException.message 也不要借碼。
confidence: high
status: active
verified_count: 1
created: 2026-07-07
last_used: 2026-07-07
