id: DEC-20260705-sidecar-paths-dev-env-override
type: decision
scope: project
source: syllable-repeater / fullstack-code-implementation Frontend FP2 收尾
context: S1a 收尾要把真 `AnalysisPipeline` 注入 UI，但 sidecar（FFmpeg / whisper-cli / cmudict / model）在開發期位於 `.local-tools/`，發布期須改為 `Contents/Resources/sidecar/`（M9 授權合規）。同時 widget test 環境不該去載 sidecar，否則 test 會因缺路徑而失敗。
action: 建立 `app/lib/shared/infra/sidecar_paths.dart` 內單一 `SidecarPaths.dev()` factory：優先讀 env var（`SYLLABLE_REPEATER_DEV_ROOT`／`FFMPEG_PATH`／`FFPROBE_PATH`／`WHISPER_CLI_PATH`／`WHISPER_MODEL_PATH`／`CMUDICT_PATH`／`SYLLABLE_REPEATER_TEMP_DIR`），無設值時 fallback 到專案根絕對路徑常數與 `Directory.systemTemp.path` 下的子資料夾；新增 `missingPaths()` 檢查所有依賴檔存在性。`main.dart` 邏輯：`paths.missingPaths().isEmpty` 才把 `analysisRunnerProvider` / `audioDurationProbeProvider` 覆寫成真 sidecar 版；否則保留 `PreviewAnalysisRunner` 預設。widget test 走 `SyllableRepeaterApp()` 建構子直接 pump，不執行 `main()`、也不覆寫 provider，因此不受 sidecar 路徑影響。
result: `main.dart` 於本機自動注入真 pipeline；widget test 4/4 仍以 preview runner 通過；使用者搬專案／換路徑只要設 env var 就能重定位，不必改 code。
reasoning: 硬編絕對路徑最簡單但沒彈性；env var 覆寫給了跨機／跨環境選項；`missingPaths()` 讓 provider override 有 fail-closed 的分岔——沒 sidecar 就退回 preview，不會讓 UI 起不來。M9 授權合規上線時只要新增 `SidecarPaths.bundled()` factory 讀 `Contents/Resources/sidecar/`，main.dart 判斷邏輯不動。
recommendation: 之後所有 sidecar 依賴一律走 `SidecarPaths` 集中；env var 命名維持 `SYLLABLE_REPEATER_` 前綴；發布前把 `SidecarPaths.bundled()` 加入並改 `main.dart` 優先用 bundled。**不要**把絕對路徑常數改為 `Directory.current`——Flutter macOS 執行時 `Directory.current` 不是專案根。
confidence: high
status: active
verified_count: 1
created: 2026-07-05
last_used: 2026-07-05
