# workflow_demucs_cpp_official_cli_contract_s6

source: syllable-repeater / fullstack-code-implementation S6 task 2.1 + 3.8 follow-up, 2026-07-07

context: 先前 `DemucsCppVocalSeparator` 依 Python Demucs/設計推測使用 `--two-stems=vocals -o <dir> --model-dir <dir> <input>`，但 sevagh/demucs.cpp 官方 README 的 C++ CLI 實際為 `demucs.cpp.main model-file input-audio output-dir`，4-source htdemucs vocals 輸出檔是 `target_3_vocals.wav`。若 release bundle 仍沿用舊假設，2.1 staging 可能過但 S1c 真整合會失敗。

action: 將 `DemucsCppVocalSeparator`、`SidecarPaths`、`scripts/prepare_release_sidecars.py`、Release copy phase、fake runner tests、integration test 與 release docs 同步到官方 CLI：bundle binary `bin/demucs.cpp.main`，model `models/ggml-model-htdemucs-4s-f16.bin`，decoder 讀 `target_3_vocals.wav`。`DEMUCS_MODEL_DIR` 暫保留為 legacy env fallback，但新路徑欄位命名為 `demucsModelPath`。

recommendation: 後續處理 demucs.cpp 時一律先讀官方 README 或本卡，不要套 Python Demucs CLI 參數。真 artifact 就緒後先跑 `flutter test packages/infra/test/demucs_integration_test.dart`，再跑 `scripts/prepare_release_sidecars.py` staging 與 Release build phase。
