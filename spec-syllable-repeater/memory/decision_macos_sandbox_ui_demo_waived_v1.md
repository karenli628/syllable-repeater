id: DEC-20260705-macos-sandbox-ui-demo-waived-v1
type: decision
scope: project
source: syllable-repeater / fullstack-code-implementation FP2 e2e
context: `flutter build macos --debug` 成功，`open <app>.app` 開啟後畫面全黑。診斷發現 `app/macos/Runner/DebugProfile.entitlements` 與 `Release.entitlements` 皆有 `com.apple.security.app-sandbox: true`。sandbox 開著就無法讀 `.local-tools/whisper.cpp`、`.local-tools/cmudict`、也無法 spawn `/usr/local/bin/ffmpeg`；主程式 `main()` 內 `File.existsSync()` 對系統路徑觸發權限錯誤導致 runApp 前崩潰。相對地，`app/test/e2e_pipeline_test.dart` 走 dart VM 不透過 App bundle，不吃 sandbox，e2e 通過。
action: 使用者於 2026-07-05 拍板走「方案 3：不動 App，只靠 e2e widget test」；不在本輪關閉 sandbox 或加 sandbox exceptions。真 App macOS UI demo 列為 waived 至 M9 授權合規/發布規劃時再決策。任務 9.1/9.2（macOS release build＋免簽章路線）落地前必須先解 sandbox：Debug + Release entitlements 皆需拿掉 `com.apple.security.app-sandbox`（走與 requirement Q4「免簽章＋略過 Gatekeeper」一致的路線）。
result: 本輪 code 面完成標準：`flutter analyze` No issues、domain 18/18、infra 39/39、app 5/5（含 e2e_pipeline_test 真檔 11 音節→切 editor tab）；App 本體 macOS demo 明確標為「未親眼驗收」，記入 execution-log 與交接檔，避免下 session 誤以為已 demo 過。
reasoning: 本專案為本機自用桌面工具＋免簽章路線，sandbox 提供的隔離對本情境沒收益卻直接擋 sidecar。但「關 sandbox」屬安全模型變更，宜與 M9 授權合規、Release build、Gatekeeper 說明文件一起做，避免本輪 patchwork 又要在 M9 重新校對。widget test e2e 已用 `tester.runAsync` 覆蓋真檔 pipeline，程式正確性不打折。
recommendation: 未來 session 若使用者想「親眼看 App 跑」，先做兩件事：①`app/macos/Runner/DebugProfile.entitlements` 與 `Release.entitlements` 內 `com.apple.security.app-sandbox` 從 `true` 改 `false`；②`flutter clean && flutter build macos --debug && open <app>.app`。這是任務 9.1/9.2 的前置。**不要**在保留 sandbox 的情況下加 `temporary-exception.files.absolute-path.*`——這種 exception 只在簽章 App 內生效，未簽章路線下無效。
confidence: high
status: active
verified_count: 1
created: 2026-07-05
last_used: 2026-07-05
