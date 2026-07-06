id: WF-20260706-fp7-ai-key-sidecar-settings-s6
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S6-9 FP7 AI key + sidecar settings
context: 使用者已拍板真 HTTP provider / Keychain adapter 要等服務商契約與 key 安全路徑回報後再接，但 S6 仍需要 settings UI、audit path 與 sidecar timeout config 可測。不能把 key 寫入 pack/progress/DB/log，也不能為了測 UI 提前引入真外呼或平台 Keychain plugin。
action: 新增 `AiSettingsService` app slice，以 `InMemoryAiSecureStore` + `NoopAiClient` 包住 domain `AIService.configure`；settings UI 使用 obscure text field，送出後立即清空欄位，audit metadata 不含 key。Domain 新增 `SidecarConfig(timeoutSeconds)` 與 `ProgressEngine.sidecarConfig/setSidecarConfig`，Drift adapter 以 `app_settings` key `sidecar.timeoutSec` 保存，設定頁用 stepper 修改並寫 `sidecar_config_changed` audit。
result: `progress_settings_test.dart`、`drift_progress_repository_test.dart`、`progress_ui_test.dart` 覆蓋 AI key 清空、`AIService.configure` audit、sidecar timeout 保存與 round-trip；完整回歸為 domain 82/82、infra 67/67（2 sidecar skips）、app 58/58。真 provider/Keychain adapter 仍未實作，符合使用者邊界。
reasoning: 先把 UI、domain port、audit 與 app_settings 通道打通，可以驗證 M10/key 不落地與 #22 audit path，而不需冒險選定未確認的 provider 或儲存方案。`NoopAiClient` 讓任何翻譯真外呼在未確認前 fail-closed，避免測試或手滑造成外部費用與資料外送。
recommendation: 未來接真 provider 時，只替換 `AiClient` / `SecureStore` adapter，不要繞過 `AIService.configure`、rate limit、host allowlist、prompt injection guard 與 audit sink。Key 明文只能進 SecureStore adapter，不能進 app_settings、audit metadata、pack、progress snapshot、logger 或測試 golden。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
