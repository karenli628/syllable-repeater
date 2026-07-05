id: DEC-20260704-macOS免簽章發布
type: decision
scope: project
source: syllable-repeater / requirement+design+task-split 三檔同步修訂
context: task-split.md 任務 9.2 原假設使用者持有 Apple Developer 帳號（$99/年）走簽章＋notarization；使用者實際沒有該帳號，也不想現在申請。曾詢問「手機版可以 PWA，桌面版可否比照」。
action: 說明「桌面版走 PWA」不成立的原因——手機 PWA 免簽章是因為 REQ-09 已定義手機端不跑 sidecar，但桌面版核心功能（REQ-01 匯入分析）本質依賴 FFmpeg/whisper.cpp/demucs.cpp 原生執行檔，做成網頁形式需額外設計本機橋接服務（架構變更，不在 v1 範圍）。以 AskUserQuestion 提供四選項：①免簽章＋略過 Gatekeeper（推薦）②免費 Apple ID Personal Team ad-hoc 簽章（限本機、7 天過期）③桌面 PWA（架構變更）④延後付費申請。使用者選①。已同步回寫 requirement.md（v1.2：REQ-09 平台順序、Non-scope 新增第 9 項、AT-09-03、N3 節點）、backend-design.md（§1.3 約束、§5.1 風險新增第 7 項、§6 開放問題）、task-split.md（任務 9.2 改為打包未簽章 build＋略過 Gatekeeper 操作說明，風險分層由 [必須確認] 降為 [需要回報]，依賴表移除 Apple 帳號依賴，OQ-4 標記已解決）。
result: 三份文件對「簽章/notarization」描述一致，任務 9.2 不再阻塞於 Apple Developer 帳號；升級路徑（未來取得帳號後補簽章）保留於 Non-scope「重新評估時機」欄。
reasoning: 本專案線上服務判準為「否」（純本機單人），不需要對外分發給陌生使用者，Gatekeeper 警告只需自己/親友手動略過一次即可，免簽章的風險（分發摩擦）可接受；此決策不影響 M1–M10 任何核心維持原則。
recommendation: 之後若要向陌生使用者分發或上架 Mac App Store，才需要重新評估此決策、申請 Developer ID；日常開發與自用/親友測試不需要再提起這個話題。若使用者之後提到「要分享給不熟的人」或「上架」，才需要重新觸發此決策點。
confidence: high
status: active
verified_count: 0
created: 2026-07-04
last_used: 2026-07-04
