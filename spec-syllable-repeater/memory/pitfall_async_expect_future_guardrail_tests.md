id: PF-20260706-async-expect-future-guardrail-tests
type: pitfall
scope: project
source: syllable-repeater / packages/domain/test/ai_service_test.dart
context: S6-2 `ai_service_test.dart` 紅轉綠時，原本用 `expect(service.translate(...), throwsA(...))` 測 Future error，後面立刻斷言 fake client calls；rate-limit 測試還在錯誤 Future 完成前推進 fake clock。
action: 將所有 Future error matcher 改為 `await expectLater(service.translate(...), _domainError(...))`。這讓錯誤 Future 完成後才檢查 fake client calls，也避免第三次 rate-limit 呼叫尚未完成時 clock 被 advance，造成測試誤判第三次外呼成功。
result: `flutter test packages/domain/test/ai_service_test.dart` 由 5/7 失敗轉為 7/7 綠，且 #23/#31/#34 的「不呼叫外部 client」斷言變得可靠。
reasoning: Dart `expect` 可以接 Future matcher，但在 async 測試中若不 `await`，後續 assertion 會與被測 Future 競速；涉及 fake clock / rate limit / no-external-call 的測試尤其容易產生假失敗或假通過。
recommendation: 本專案凡測 `Future` 會丟 `DomainException`，一律用 `await expectLater(future, throwsA(...))`；若後續測 Sidecar/Recorder/AI 等「不得呼叫外部依賴」情境，也要先 await 錯誤 Future，再檢查 fake calls。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
