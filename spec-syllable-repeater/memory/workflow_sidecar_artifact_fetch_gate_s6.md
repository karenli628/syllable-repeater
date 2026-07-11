id: WF-20260707-sidecar-artifact-fetch-gate-s6
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation task 2.1 S6-15, 2026-07-07
context: 2.1 已有 `scripts/prepare_release_sidecars.py` staging gate，但缺「取得 release artifacts」這一層的 policy-as-code；QwenASR 借鏡要求 SHA-256 pinning、LGPL-shared FFmpeg 來源與拒絕 SSL CERT_NONE，而 `docs/codex/prompts.md` 又明定來源 URL 選定前須列候選與授權證據等使用者確認。
action: 新增 `scripts/fetch_sidecar_artifacts.py` 作為 artifact acquisition gate：manifest 內每個可下載工件必須宣告 URL＋SHA-256＋授權三元組，只允許 HTTPS 且使用系統預設憑證驗證；拒絕 TLS/CERT 驗證降級欄位、非 HTTPS URL、缺 SHA-256、GPL/AGPL/非商用授權與 LGPL static artifact。demucs.cpp 若沒有核可官方二進位來源，改用 `manualBuild` contract 列 upstream sourceUrl、expectedLocalPath 與本機 build/check 指令。新增 `scripts/test_fetch_sidecar_artifacts.py` 並接入 `scripts/ci_core_checks.sh`。
result: `python3 -m unittest scripts/test_check_licenses.py scripts/test_prepare_release_sidecars.py scripts/test_fetch_sidecar_artifacts.py` 通過 15 tests；`bash scripts/ci_core_checks.sh` 在非 sandbox 下通過（domain 82、infra 69、app 61、`flutter analyze` 無問題）。`python3 scripts/fetch_sidecar_artifacts.py --inventory-only` 正確 fail-closed：whisper-cli、`ggml-small.en.bin`、CMUdict 已存在；release-safe FFmpeg/ffprobe、demucs.cpp.main、htdemucs model 缺件，因此 2.1 仍未勾選。
reasoning: M9 的風險不只在 staging 時把 GPL/static FFmpeg 擋掉，也在「下載來源」階段可能被錯誤 URL、缺 SHA、TLS 驗證降級或未確認授權污染。把下載 manifest schema 先做成 gate，可讓使用者確認來源前不硬寫 URL，確認後又能靠測試防止未來退化成 `CERT_NONE` 或未 pin hash。
recommendation: 後續收 2.1 時，先列出 LGPL shared FFmpeg/ffprobe 與 demucs/model 候選來源＋授權證據給使用者確認；確認後才建立 `release/sidecar-artifacts.json`，填入真 URL、64 位 SHA-256、license/linking/dest。跑順序固定為：`fetch_sidecar_artifacts.py --inventory-only` → 有 manifest 時 `fetch_sidecar_artifacts.py` → `prepare_release_sidecars.py --dry-run` → `prepare_release_sidecars.py` → 勾 task-split 2.1。若 `fetch` 或 `prepare` fail-closed，不得改 gate 或塞 `/usr/local/bin/ffmpeg`。
confidence: high
status: active
verified_count: 1
created: 2026-07-07
last_used: 2026-07-07
