id: WF-20260705-analysis-pipeline-port-adapter
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S1a AnalysisPipeline
context: backend-design 將 `AnalysisPipeline` 放在 Domain，但實際 FFmpeg/whisper.cpp sidecar wrapper 位於 infra；同時 M5 要求 Domain 純 Dart，不可 import sidecar、dart:io 或平台 API。
action: 以 Domain port + Infra adapter 解套：`packages/domain/lib/src/analysis/analysis_pipeline.dart` 只定義 `ImportRequest`、`AnalysisEvent`、`AnalysisAudioDecoder`、`AnalysisTranscriber` 等抽象與流程；`packages/infra/lib/src/analysis/analysis_pipeline_adapters.dart` 負責 FFmpeg 轉 16k mono WAV、呼叫 `WhisperCppTranscriber(noGpu: true)`，`FfmpegDecoder` 只實作 domain 解碼 port。
result: Domain fake-port 測試可單獨驗證事件順序、重入鎖與失敗保留 PCM；Infra 整合測試以使用者 mp3 跑完整 pipeline，輸出 11 音節與 waveform peaks。M5 未破壞。
reasoning: 把「編排」與「sidecar 實作」拆開，可讓 Domain 保持可測且跨平台；同時仍能把 Intel Mac 上 small.en 需 16k WAV + `--no-gpu` 的實測坑落在 infra adapter。
recommendation: 後續接前端 FP2 時直接注入 `AnalysisPipeline(decoder: FfmpegDecoder, transcriber: WhisperAnalysisTranscriber, alignmentEngine: AlignmentEngine(CmuDictLoader...))`；S1c demucs 只需新增 `AnalysisVocalSeparator` adapter，不要讓 Domain 直接 import demucs/Process/File。
confidence: high
status: active
verified_count: 1
created: 2026-07-05
last_used: 2026-07-05
