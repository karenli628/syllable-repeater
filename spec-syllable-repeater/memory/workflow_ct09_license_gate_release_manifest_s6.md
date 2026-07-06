id: WF-20260706-ct09-license-gate-release-manifest-s6
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S6-10 CT-09 local release gate
context: 使用者最新指示 GitHub 上載若非必要保留到最後；#9 Branch Protection 仍需 GitHub remote/repo，不能本機假完成。S6 收尾仍可推進本機可落地的 M9/CT-09 授權白名單 gate，避免 release 前才發現 GPL/AGPL/非商用或 LGPL static linking 問題。
action: 新增 `scripts/check_licenses.py` 讀取 `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/release/license-manifest.json`；規則擋 GPL/AGPL/CC BY-NC/non-commercial/research-only、bundled Python runtime，且要求 LGPL bundled 元件必須 `linking=dynamic`。新增 `scripts/test_check_licenses.py` 覆蓋 GPL/GPL-3.0 注入、LGPL static linking、bundled Python runtime、空 manifest 與目前 release manifest 形狀；新增 `release/release-checklist.md` 串接本機必跑 gate。同步更新 task-split、execution-log、hard-limits-matrix 與 handoff。
result: `python3 scripts/check_licenses.py spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/release/license-manifest.json` 通過（18 components）；`python3 -m unittest scripts/test_check_licenses.py` 6/6 通過；`git diff --check` 通過；guardrails checker 仍預期只因 #9 Branch Protection 失敗。
reasoning: CT-09 的核心不是文件列名單，而是「注入 GPL 套件會自動擋發布」。用 JSON manifest + stdlib Python checker 可在沒有 GitHub/CI 前先形成本機 policy-as-code；LGPL dynamic linking 被寫成硬規則，能直接保護 FFmpeg release build 邊界。
recommendation: 後續新增任何 Dart/Flutter package、sidecar、模型或 release bundle 內容時，先更新 `release/license-manifest.json` 並重跑 `scripts/check_licenses.py` 與 unittest。不要把 Homebrew GPL FFmpeg 標成 bundled；release FFmpeg 必須改成 LGPL-only dynamic build。GitHub branch protection 仍保留最後 gate，不能把 CT-09 綠當成 #9 完成。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
