id: WF-20260706-ai-service-domain-guardrails-ports
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S6-2 AIService 7.2 + hard-guardrails 8.4.3-8.4.5
context: 7.2 AIService 屬 `[需要回報]`，外部服務商契約與 key 安全路徑尚未拍板；但 hard-guardrails #23/#31/#34 已被使用者 REJECT，不能只等真 HTTP/Keychain adapter 才處理。若此時直接加 `http` 或 `flutter_secure_storage`，會超出回報邊界並可能破壞 Domain purity。
action: 先在 Domain 層落地可測 port 與前置防線：`SecureStore` / `AiClient` ports、`AiProviderConfig` / `AiRateLimit` / request-response value types，以及 `AIService.configure/translate/mergeTranslation`。`translate` 在呼叫 client 前依序做 prompt injection fail-closed、HTTPS + official host allowlist、rate limit；失敗一律回 `ERR_AI_CALL_FAILED` 且 fake client calls 為空。真 provider HTTP adapter 與 Keychain adapter 保留到服務商/key 路徑回報後再接。
result: `packages/domain/test/ai_service_test.dart` 7/7 綠，`flutter test packages/domain/test` 61/61 綠，`flutter analyze` No issues。hard-limits-matrix #23/#31/#34 從 `REJECTED_NEEDS_IMPLEMENTATION` 轉 `PARTIAL`，剩 #9/#22 仍擋 guardrails checker。
reasoning: 這種切法同時滿足 TDD 與回報邊界：硬性限制已是會自動拒絕的程式防線，不只是文件；但沒有假裝真外部服務或 Keychain 已完成。把防線放在 Domain AIService 前置層，後續任一 provider adapter 只要走同一服務，就天然繼承 rate limit / allowlist / prompt guard。
recommendation: 後續接真 AI provider 時，infra/app adapter 必須只實作 `AiClient` / `SecureStore`，不得繞過 `AIService.translate` 直接呼叫 HTTP；matrix #23/#31/#34 在真 call path 驗證前維持 `PARTIAL`，不要急著標 `IMPLEMENTED`。若 FP6 需要「使用者確認可疑輸入」，在 UI 層接確認流程；Domain 目前應維持 fail-closed。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
