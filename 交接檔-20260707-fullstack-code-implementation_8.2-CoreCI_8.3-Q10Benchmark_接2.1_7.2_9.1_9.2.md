# 交接檔 — fullstack-code-implementation 8.2 Core CI + 8.3 Q10 Benchmark

> 給下一個 coding agent：本檔接續 2026-07-07 session。請先依專案慣例讀 `02_Memory/constitution.md`、`preferences.md`、`MEMORY.md`，再讀 `spec-syllable-repeater/memory/` 中與本輪相關的 memory，尤其 `workflow_github_actions_core_ci_gate_s6.md`、`workflow_alignment_pipeline_benchmark_q10.md`、`workflow_flutter_workspace_dart_test_gotcha.md`、`pitfall_dart_sdk_sandbox_cpuinfo_crash.md`、`workflow_git_hook_two_layer_split.md`。

## 本輪完成

- GitHub repo 已存在且為 public：`https://github.com/karenli628/syllable-repeater`。`main` branch ruleset `main branch protection`（id `18580116`）active，阻止 deletion 與 non-fast-forward；依使用者限制未做 force-push 測試。
- 8.2 已完成：新增 `.github/workflows/ci.yml` 與 `scripts/ci_core_checks.sh`，GitHub Actions run `28808859106`（commit `62a0695`）通過。core gate 內容：guardrails checker、CT-09 license gate、license unittest、domain/infra/app tests、`flutter analyze`。
- 8.3 已完成：新增 `packages/infra/bin/benchmark_alignment_pipeline.dart`。在 `Intel(R) Core(TM) i5-8259U CPU @ 2.30GHz` 實測 10,000ms benchmark audio 完整 `AnalysisPipeline`，結果 `elapsedMs=4689`（4.689s）、`syllableCount=22`、`waveformPeaks=32`、`status=PASS`。
- 已回填 Q10：`requirement.md` v1.3、REQ-01 3.2.6、附錄 A Q10、`backend-design.md` 效能目標與風險段落均已改為「10 秒音檔完整對齊管線 ≤ 60 秒」且已實測鎖定。
- 已更新：`task-split.md` 8.2/8.3 勾選完成；`execution-log.md` 新增 S6-12/S6-13；`hard-limits-matrix.md` #8 CI 轉 IMPLEMENTED，統計為 IMPLEMENTED 8、PARTIAL 19。

## 驗證紀錄

- `dart run bin/benchmark_alignment_pipeline.dart`（於 `packages/infra`，非 sandbox）：通過，4.689s。
- `git diff --check`：通過。
- `python3 scripts/check_guardrails.py ...`：通過，37 rows，IMPLEMENTED 8、PARTIAL 19。
- `python3 scripts/check_licenses.py ...`：通過，18 components。
- `python3 -m unittest scripts/test_check_licenses.py`：6/6 通過。
- 本輪嘗試 `bash scripts/ci_core_checks.sh` 的非 sandbox 執行被 Codex 自動審核因額度/權限限制擋下；sandbox 執行卡在 Flutter SDK cache 寫入 `/usr/local/share/flutter/bin/cache/*`。`dart analyze` sandbox 也觸發已知 `cpuinfo_macos.cc` crash。這是既有工具鏈限制；先前遠端 GitHub Actions 在 commit `62a0695` 已全綠。

## 下一步順序

1. **2.1 sidecar release bundle**：整備 x86_64 sidecar 二進位到 `Contents/Resources/sidecar/`，FFmpeg 必須是 LGPL build 且動態連結；whisper.cpp、demucs.cpp 與授權告知要同步。這是 9.1 的前置。
2. **7.2 AIService 真 adapter**：目前 Domain ports、fake client、rate-limit/network/prompt guardrails 已完成；真 HTTP adapter 與 Keychain adapter 必須等 provider/key 安全路徑回報後再接，不要自行假定供應商或 key 儲存方案。
3. **9.1 macOS release build x86_64**：依使用者 2026-07-05 拍板，Release/DebugProfile entitlements 的 App Sandbox 需要改 `false` 才能讓 sidecar 與本機路徑工作；不要新增 `temporary-exception.files.absolute-path.*`。
4. **9.2 unsigned package + Gatekeeper guide**：免簽章路線已定，需撰寫 `xattr -cr` 或右鍵開啟的使用者說明，並做實機驗收。

## 不要做

- 不要重做 7.1/7.3/7.4/7.5/7.6 或 8.2/8.3。
- 不要 force push，不要覆蓋遠端歷史。
- 不要把 API key、audio、recording path、絕對路徑寫進 pack/progress/DB/log。
- 不要未確認就新增 audit schema；#22 已有人類確認並落地 Drift `audit_log`。
- 不要把 release 實機 gate 因 GitHub Actions 綠燈而誤勾完成；9.1/9.2 仍待做。
