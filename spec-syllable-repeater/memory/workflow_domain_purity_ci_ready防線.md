id: WF-20260705-domain-purity-ci-ready
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation 8.1
context: task-split 8.1 要求 domain 包於無 Flutter 容器跑 `dart test`，並加依賴白名單檢查；本專案目前尚未 `git init`，也沒有 GitHub Actions / 遠端 CI 落點，因此不能把 8.1 直接等同於雲端 CI。
action: 將 M5 檢查落在 `packages/domain/test/domain_purity_test.dart`，讓 domain package 自身的 `dart test` 掃描 `packages/domain/lib/**` import/export 與 `packages/domain/pubspec.yaml`。檢查拒絕 `dart:io`、`dart:ffi`、`dart:html`、`dart:js`、`package:flutter/`、`package:infra/` 與 sidecar 實作路徑，並用 AT-09-02 違規匯入範例驗證防線會報錯。
result: 8.1 以本地 CI-ready 防線完成；domain `dart test` 從 12/12 增為 15/15 並通過，`dart analyze` 無問題。`task-split.md` 8.1 已勾選，`execution-log.md` 已記錄雲端 CI 待 git/repo 決策後再接。
reasoning: 在尚未建立 git repo 前，最小可落地的硬防線是把檢查放進 domain 測試套件；這能立即守住 M5，且未來接 GitHub Actions 時只要跑同一個 `dart test` 即可沿用，不需要再發明另一套規則。
recommendation: 後續新增 Domain API 或移動檔案時，先跑 `cd packages/domain && dart test`；若未來使用者同意 `git init` / GitHub repo，再把同一條指令接入 GitHub Actions。不要把 GitHub Actions 未建立誤寫成已完成，只能稱為本地 CI-ready 防線。
confidence: high
status: active
verified_count: 1
created: 2026-07-05
last_used: 2026-07-05
