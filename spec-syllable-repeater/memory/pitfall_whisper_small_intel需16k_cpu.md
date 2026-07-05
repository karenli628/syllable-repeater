id: PIT-20260704-whisper-small-intel-16k-cpu
type: pitfall
scope: project
source: syllable-repeater / fullstack-code-implementation S1a
context: 使用者指定 whisper app 僅使用 small 版模型；在 Intel i5-8259U macOS 14 上，以 whisper.cpp `ggml-small.en.bin` 對使用者提供的 `step up your coding skills to a new level.mp3` 做 S1a 實測。
action: 初跑直接餵 MP3 並使用預設 Metal/GPU，輸出異常 `JO�identsidents`；改用 FFmpeg 先轉 16k mono WAV，並以 `--no-gpu` 執行 whisper-cli。
result: `16k mono wav + --no-gpu + small.en` 正確辨識 `Step up your coding skills to a new level.`，耗時約 3.48 秒；輸出 JSON 位於 `.local-tools/s1a/step_up_small_cpu.json`，模型位於 `.local-tools/whisper.cpp/models/ggml-small.en.bin`。
reasoning: 此為本專案在目前 Intel Mac 開發機上的 sidecar 實測坑；可能與 MP3 輸入/Metal backend/硬體組合有關，不能推廣成所有 Mac 的通用規則。
recommendation: 後續 S1a `AnalysisPipeline` 在此開發機先固定走「輸入音檔 → FFmpeg 轉 16k mono WAV 暫存檔 → whisper-cli `--no-gpu`」；未來若改 Apple Silicon、升級 whisper.cpp 或換模型，需重新實測後再調整。
confidence: high
status: active
verified_count: 0
created: 2026-07-04
last_used: 2026-07-04
