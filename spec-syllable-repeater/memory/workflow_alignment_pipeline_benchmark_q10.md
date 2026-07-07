# workflow_alignment_pipeline_benchmark_q10

source: syllable-repeater / fullstack-code-implementation S6-13 task 8.3

context: Q10 效能目標原先為「10 秒音檔完整對齊管線 ≤ 60 秒（基準機 Intel i5-8259U）」，需在本機實測後鎖定。使用者提供的 `step up your coding skills to a new level.mp3` 原始長度約 3.48s。

action: 新增 `packages/infra/bin/benchmark_alignment_pipeline.dart`。工具會用 FFmpeg 把使用者 mp3 loop/trim 成 10,000ms WAV，然後量測完整 `AnalysisPipeline`：FFmpeg decode → whisper.cpp small.en `--no-gpu` → CMUdict syllabify → waveform peaks。2026-07-07 在 `Intel(R) Core(TM) i5-8259U CPU @ 2.30GHz` 實測結果：`elapsedMs=4689`（4.689s）、`syllableCount=22`、`waveformPeaks=32`、`status=PASS`。

recommendation: 需要重跑 Q10 時在 `packages/infra` 執行 `dart run bin/benchmark_alignment_pipeline.dart`，並確認 `.local-tools/whisper.cpp/build/bin/whisper-cli`、`.local-tools/whisper.cpp/models/ggml-small.en.bin`、`.local-tools/cmudict/cmudict.dict` 與 FFmpeg 存在。更換模型、晶片、whisper.cpp/FFmpeg 版本或接入 demucs 必須重跑 benchmark，再更新 `requirement.md` 附錄 A Q10 與 `backend-design.md` 風險段落。
