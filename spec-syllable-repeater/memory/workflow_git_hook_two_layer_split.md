id: WF-20260705-git-hook-two-layer-split
type: workflow
scope: project
source: syllable-repeater / hard-guardrails skill 首輪
context: 2026-07-05 使用者選「現在 git init + 裝 pre-commit」。skill 建議把 hard-limits-matrix check + secret scan + `.env` 誤送檢查全放 pre-commit。實務問題：5 條 REJECTED_NEEDS_IMPLEMENTATION 未實作前，matrix check 會擋任何 commit——包含開發過程中的 WIP commit。這違反「本機 commit 是開發動作、不是交付動作」的直覺分工。
action: 把 hook 拆兩層——**pre-commit**（`.githooks/pre-commit`）只放本機保存的最小檢查：①簡易金鑰樣式掃描（api_key/secret/password/token + 16+ 字元）②`.env` 誤送擋下（憲法 C6）；**pre-push**（`.githooks/pre-push`）放「交付前」檢查：hard-limits-matrix 檢查（跑 `scripts/check_guardrails.py`）。兩層皆走 `git config core.hooksPath .githooks`（本專案已設定）。`--no-verify` 繞過寫進 pre-push 訊息但明訂「不建議、違反 skill 精神」。
result: 本機 WIP commit 不擋（開發流暢）；推遠端／交付前才擋（skill 鐵律 4 語意上的正確落點）；`.env`／API key 這種絕不能進版控的仍在 pre-commit 就擋——即時性最強。實測：commit 未進行前無驗證負擔；假若 push 出手，5 條 REJECTED 未實作前會被擋。
reasoning: skill 鐵律 4「適用但未實作即阻擋交付」的關鍵字是「交付」——commit 到本機 repo 不是交付，push 到遠端才是。secret scan 反過來——洩露金鑰不能等到 push，必須 commit 前就擋（一旦寫進 git object，即便未 push 也可能因誤操作或 backup 逃逸）。所以「什麼擋在什麼時機」按「不可逆風險」而非「檢查耗時」分。
recommendation: 未來加更多檢查時遵循同樣分工：①不可逆風險（金鑰洩露、`.env`）→ pre-commit；②交付前必須通過（matrix、`flutter analyze`、`flutter test`）→ pre-push。CI（若使用者未來推 GitHub）跑同樣的 pre-push 檢查。想暫時繞過 `--no-verify` 一定要記錄理由（違反 skill 精神時使用者要能追溯）。
confidence: high
status: active
verified_count: 1
created: 2026-07-05
last_used: 2026-07-05
