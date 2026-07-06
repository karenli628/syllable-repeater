id: WF-20260706-export-ct03-domain-infra-fp5
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S3 PracticeEngine export + FP5
context: S3 要同時落地 REQ-04/M3/CT-03（合併匯出段落間靜音＝前一步 totalDurationMs，±20ms）與 M1/M5（音訊仍來自 renderStep 原聲 copy，Domain 不可 import dart:io/Process/infra）。backend-design 的 exportStep/exportMerged 文字含 FFmpeg 與 destPath，但現有 domain_purity_test 會擋平台 IO。
action: 先新增 `packages/domain/test/practice_export_test.dart` 讓 `PracticeEngine.renderMergedExport` 缺失紅燈；再在 domain 新增 `PracticeExportAudio` 與 `PracticeEngine.renderExportStep/renderMergedExport`，只做 PCM 組裝、repeat 推回、sample-count zero silence 與 silenceGapsMs。接著在 infra 新增 `PracticeExporter`，把 `PracticeExportAudio` 轉 WAV temp input，呼叫 FFmpeg runner `libmp3lame` 輸出 MP3 bytes，再用 `FileIo.writeBytesAtomic` 寫 destPath，並用同 destPath in-memory lock 擋重入。FP5 則把 `PracticeExportService`、save location picker、Finder revealer 都抽 provider，widget test 全用 fake。
result: `flutter test packages/domain/test` 41/41 ✅；`flutter test packages/infra/test` 55/55 ✅（2 sidecar skips）；`cd app && flutter test` 31/31 ✅；`flutter analyze` No issues。S3 task-split 4.5/4.6/FP5 已勾選；guardrails checker 仍因 5 條 REJECTED 預期失敗。
reasoning: 把「匯出音訊規則」與「MP3 檔案副作用」分層，可以同時滿足設計的介面語意與 M5 domain purity。CT-03 的最硬部分其實是 sample-count silence gap，不需要真 FFmpeg 即可在 domain 紅綠測；FFmpeg/atomic/reentry 屬 infra adapter 單測，用 fake runner/fileIo 比真 sidecar 更穩。FP5 也必須抽 provider，否則 widget test 會啟動平台存檔對話框或 Finder。
recommendation: 後續改 export 或接 S5/S6 時，不要把 destPath/FFmpeg/Process/File IO 放回 `packages/domain`；先跑 `flutter test packages/domain/test/practice_export_test.dart` 守 CT-03，再跑 infra exporter test 守 MP3/atomic/reentry。UI 新增匯出相關行為時一律透過 `PracticeExportService` / picker / revealer provider fake 測，不要在 widget test 呼叫真 `file_selector` 或 `/usr/bin/open`。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
