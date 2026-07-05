id: DEC-20260704-平台順序與手機雙路徑
type: decision
scope: project
source: syllable-repeater / requirement-analysis（macOS v1 需求成稿）
context: PLAN3.0 §2 原定「Windows v1、macOS 後」，S8 將 macOS sidecar 重編/簽章列為 Phase 3。
action: 使用者於 2026-07-04 指示：桌面優先且 macOS v1 首發（S8 之 macOS 簽章/notarization 併入 v1）；Windows 延後（時程待確認）；手機端 Phase 2 保留 PWA（Flutter Web）與 App Store/Play Store 原生 App 雙路徑，最終擇一或並行待 Phase 2 決定。
result: requirement.md 之 REQ-09 以架構約束落地：Domain 純 Dart、檔案 IO 走抽象介面（保 Web 編譯可能）、sidecar 僅桌面註冊、.abopack/.aboprogress 平台中立。
reasoning: 手機端能力集（讀 pack、疊加播放、錄音比對、SRS）不依賴 sidecar，故雙路徑可行；PWA 有 iOS Safari 音訊/錄音限制，須 PoC，商店 App 為保底。
recommendation: 設計與實作階段一律以 macOS 為建置目標；Domain 內禁止 dart:io 直接耦合與 flutter import（CI 防線 AT-09-02）；Phase 2 啟動先做 PWA 音訊 PoC 再定通路。
confidence: high
status: active
verified_count: 0
created: 2026-07-04
last_used: 2026-07-04
