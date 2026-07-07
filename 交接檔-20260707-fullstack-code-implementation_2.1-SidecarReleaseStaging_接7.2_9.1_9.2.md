# 交接檔 — fullstack-code-implementation 2.1 Sidecar Release Staging

> 給下一個 coding agent：本檔接續 2026-07-07 session。請先讀 `02_Memory/constitution.md`、`preferences.md`、`MEMORY.md`，再讀本專案 `spec-syllable-repeater/memory/` 相關記憶，特別是 `workflow_release_sidecar_staging_gate_s6.md`、`workflow_github_actions_core_ci_gate_s6.md`、`workflow_alignment_pipeline_benchmark_q10.md`、`workflow_ct09_license_gate_release_manifest_s6.md`、`workflow_flutter_workspace_dart_test_gotcha.md`、`pitfall_dart_sdk_sandbox_cpuinfo_crash.md`。

## 本輪完成

- 已提交並推送 8.2/8.3 commit：`4127816 chore: record core CI and Q10 benchmark`。
- GitHub Actions Core CI run `28835057771` 於 commit `4127816` 通過，job `CT-01..CT-10 and guardrails` 耗時 2m1s。
- 2.1 已完成可落地防線：
  - `SidecarPaths.current()` / `SidecarPaths.bundled()`：Release AOT 走 `Contents/Resources/sidecar/`；Debug/Test 走 `.local-tools/`。
  - `scripts/prepare_release_sidecars.py`：staging 前跑 CT-09 license gate，拒絕 GPL/nonfree 或非 shared FFmpeg/ffprobe，產出 `sidecar-manifest.json`。
  - `scripts/test_prepare_release_sidecars.py`：覆蓋 GPL FFmpeg 被拒絕與合法 fake bundle 產出 release layout。
  - `app/macos/Runner/Scripts/copy_release_sidecars.sh` + Xcode Release build phase：Release build 缺 sidecar staging 即 fail-closed；Debug/Profile 跳過。
  - `release/license-manifest.json` 補 `OpenAI Whisper small.en model`（MIT）。
- 實體 binaries/models 不進 git：`app/macos/Runner/Resources/sidecar/.gitignore` 只允許 README/gitignore。

## 驗證紀錄

- `python3 scripts/check_licenses.py .../release/license-manifest.json` ✅（19 components）
- `python3 -m unittest scripts/test_check_licenses.py scripts/test_prepare_release_sidecars.py` ✅（8 tests）
- `flutter test app/test/shared/sidecar_paths_test.dart` ✅
- `python3 scripts/prepare_release_sidecars.py ... --dry-run` 對目前本機 artifact 狀態正確失敗：`.local-tools/demucs.cpp/build/bin/demucs.cpp` 與 `ggml-model-htdemucs` 不存在。
- `/usr/local/bin/ffmpeg -version` 顯示 `--enable-gpl`，此 Homebrew build 只能 dev-only，不可 release bundled。

## 目前 2.1 狀態

2.1 尚未勾完成。原因不是 code 未接，而是 release 實體 artifacts 未就緒：

- 需要 LGPL-only、shared/dynamic FFmpeg + ffprobe。
- 需要 demucs.cpp x86_64 binary。
- 需要 htdemucs ggml model artifact。
- whisper.cpp CLI、whisper dylibs、`ggml-small.en.bin`、CMUdict 本機目前有，但 release staging 必須等 FFmpeg/demucs 一起就緒後再跑。

## 下一步順序

1. **2.1 收尾**：取得 LGPL-only FFmpeg/ffprobe 與 demucs.cpp artifacts 後，重跑 `scripts/prepare_release_sidecars.py`；成功後再勾 2.1。
2. **7.2 AIService 真 adapter**：目前仍等待 provider/key 安全路徑回報；不要自行假定供應商或 key 儲存方案。
3. **9.1 macOS release build x86_64**：需先完成 2.1 staging；依既有決策 release 前要處理 App Sandbox。
4. **9.2 unsigned package + Gatekeeper guide**：免簽章路線已定，需做使用者可理解的略過 Gatekeeper 說明與實機驗收。

## 不要做

- 不要把 `/usr/local/bin/ffmpeg` 或 Homebrew GPL FFmpeg 放進 release bundle。
- 不要把 `.local-tools/`、模型檔、音訊檔、sidecar binaries commit 進 git。
- 不要繞過 `prepare_release_sidecars.py` 或 Release build phase 的 fail-closed 檢查。
- 不要把 2.1 或 9.1 標完成，除非實體 release staging 與 release build 都有證據。
