# Release Checklist — Syllable Repeater macOS v1

> AI-Generate
> 本檔是 task 8.2 / CT-09 的發布 gate 清單。GitHub Actions 與 branch protection 已於 2026-07-07 接上；release 實機 gate 仍需本檔逐項核對。

## 必跑 Gate

1. `python3 scripts/check_licenses.py spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/release/license-manifest.json`
2. `python3 -m unittest scripts/test_check_licenses.py scripts/test_prepare_release_sidecars.py scripts/test_fetch_sidecar_artifacts.py scripts/test_make_release_zip.py`
3. `flutter test packages/domain/test`
4. `flutter test packages/infra/test`
5. `cd app && flutter test`
6. `flutter analyze`
7. `python3 scripts/check_guardrails.py spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/decision-log.md`

## Sidecar staging

- 先跑 `python3 scripts/fetch_sidecar_artifacts.py --inventory-only` 盤點本機工件；`release/sidecar-artifacts.json` 已記錄官方 source/manual build contract 與 htdemucs model SHA-256，模型下載走 `python3 scripts/fetch_sidecar_artifacts.py`。此腳本要求每個可下載工件都有 URL＋SHA-256＋授權三元組，且只接受 HTTPS 憑證正常驗證。
- manual build artifact 也必須 pin source：FFmpeg 8.1.2 source tarball 使用 `sourceSha256=464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c`；demucs.cpp `v0.0.4-alpha` 使用 `sourceCommit=84e62f07ff77c5058a3493f7f9702cde606dae76`。
- `fetch_sidecar_artifacts.py` 會拒絕 TLS/CERT 驗證降級欄位、非 HTTPS URL、缺 SHA-256、GPL/AGPL/非商用授權、LGPL static artifact；demucs.cpp 若沒有核可的官方二進位來源，維持本機編譯檢查並列出 upstream build 指令。
- 先用 `scripts/prepare_release_sidecars.py` 產生 `app/macos/Runner/Resources/sidecar/` staging 內容；實際 binaries/models/dictionaries 由 `.gitignore` 擋住，不進版控。
- `prepare_release_sidecars.py` 會先跑 CT-09 license manifest gate，再拒絕 `--enable-gpl` / `--enable-nonfree` 或非 shared 的 FFmpeg/ffprobe。
- `fetch_sidecar_artifacts.py` 產生 prepare 指令時，若 `.local-tools/release-sidecars/ffmpeg/lib` 存在，會預設加入 `--ffmpeg-lib-dir`；該 lib 目錄必須含 FFmpeg shared dylib 與 `libmp3lame.0.dylib`，並由 `prepare_release_sidecars.py` 修補 bundle 內 Mach-O rpath/install name。
- macOS Release build phase 會檢查 `sidecar-manifest.json`、`bin/ffmpeg`、`bin/ffprobe`、`bin/whisper-cli`、`bin/demucs.cpp.main`、`models/ggml-small.en.bin`、`models/ggml-model-htdemucs-4s-f16.bin`、`data/cmudict.dict`，缺任一項即中止 release build。

### 2026-07-07 本機 staging snapshot

- `python3 scripts/fetch_sidecar_artifacts.py --inventory-only` ✅：FFmpeg/ffprobe、whisper-cli、Whisper small.en model、CMUdict、demucs.cpp.main、htdemucs 4-source model 皆存在。
- `python3 scripts/prepare_release_sidecars.py ... --dry-run` ✅；`python3 scripts/fetch_sidecar_artifacts.py --run-prepare` ✅，輸出 `app/macos/Runner/Resources/sidecar/sidecar-manifest.json` 與本機 staging 工件。
- FFmpeg/ffprobe 由官方 FFmpeg 8.1.2 source build：`--enable-shared --disable-static --disable-gpl --disable-nonfree --enable-libmp3lame`；`otool -L` 顯示 staged binary 以 `@rpath/libav*.dylib` 與 `@rpath/libmp3lame.0.dylib` 載入 bundled shared dylib。
- demucs.cpp.main 為 Mach-O x86_64；`otool -L` 只顯示系統 `Accelerate.framework`、`libc++`、`libSystem`。
- 本機沒有 `gpg`，FFmpeg `.asc` 已保留但未做 PGP 驗章；發正式版前若環境有 `gpg`，可依 FFmpeg 官方 release verification 補驗。SHA-256 pinning 與 CT-09 license gate 已通過。

### 2026-07-08 AI adapter dependency snapshot

- task 7.2 新增 `flutter_secure_storage` / `flutter_secure_storage_darwin` / `flutter_secure_storage_platform_interface`（BSD-3-Clause），僅用於 macOS Keychain AI key 儲存。
- task 7.2 新增 `http` / `http_parser`（BSD-3-Clause），僅用於 `OpenAiResponsesClient`，且所有真外呼必經 Domain `AIService` 的 HTTPS allowlist、rate limit、prompt-injection guard 與 audit sink。
- `python3 scripts/check_licenses.py spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/release/license-manifest.json` ✅（25 components）。

### 2026-07-11 Release build / unsigned package snapshot

- `flutter build macos --release --no-pub` ✅，產物：`app/build/macos/Build/Products/Release/syllable_repeater_app.app`（634MB）。
- 產物主執行檔：`file .../Contents/MacOS/syllable_repeater_app` = Mach-O 64-bit executable x86_64；Release config 固定 `ARCHS = x86_64` / `ONLY_ACTIVE_ARCH = YES`，未產 universal/Apple Silicon build。
- 環境踩坑：Flutter SDK `gen_snapshot_x64` 若帶 `com.apple.quarantine`，會在 AOT 階段 0% CPU / 40K RSS 卡住，甚至 `gen_snapshot_x64 --version` 也無輸出；本輪以 `xattr -d com.apple.quarantine /usr/local/share/flutter/bin/cache/artifacts/engine/darwin-x64-release/gen_snapshot_x64` 修復後 release build 通過。
- bundle 內 `Contents/Resources/sidecar/` 已包含 `sidecar-manifest.json`、`bin/ffmpeg`、`bin/ffprobe`、`bin/whisper-cli`、`bin/demucs.cpp.main`、`models/ggml-small.en.bin`、`models/ggml-model-htdemucs-4s-f16.bin`、`data/cmudict.dict`。
- bundle 內 `ffmpeg -version` / `ffprobe -version` ✅：`--enable-shared --disable-static --disable-gpl --disable-nonfree --enable-libmp3lame`；`otool -L` 顯示 FFmpeg 以 `@rpath/libav*.dylib` 與 dynamic `@rpath/libmp3lame.0.dylib` 載入，demucs.cpp.main 只連系統 `Accelerate.framework`、`libc++`、`libSystem`。
- `python3 scripts/make_release_zip.py --dry-run` ✅；`python3 scripts/make_release_zip.py` ✅，輸出 `dist/SyllableRepeater-macos-x86_64-unsigned.zip`（524MB）與 `.sha256`。
- 發版 zip SHA-256：`38de745c051c7d19f11c254fe0406055979dbca7c4e6c07ef4474f2f670db8a2`。
- `bash scripts/ci_core_checks.sh` ✅：guardrails 37 items、CT-09 25 components、Python 22 tests、domain 82、infra 69 + 2 skips、app 67 + 1 skip、`flutter analyze` No issues。

## Unsigned zip packaging

- 先跑 `cd app && flutter build macos --release` 產生 `app/build/macos/Build/Products/Release/syllable_repeater_app.app`。
- 再跑 `python3 scripts/make_release_zip.py`；腳本會先檢查 `.app`、`Contents/MacOS/syllable_repeater_app`、`Contents/Resources/sidecar/sidecar-manifest.json`、ffmpeg/ffprobe/whisper/demucs/model/cmudict 必要檔，缺任一項即中止。
- 打包使用 macOS `ditto -c -k --sequesterRsrc --keepParent`，輸出 `dist/SyllableRepeater-macos-x86_64-unsigned.zip` 與 `.sha256`。
- 使用者安裝/略過 Gatekeeper 說明見 `release/README-unsigned-macos.md`。

## CT-09 人工核對

- FFmpeg release build 必須是 LGPL-only build 且 dynamic linking。
- FFmpeg 的 MP3 export 依賴 LAME `libmp3lame`，必須以 dynamic linking 隨 bundle staging；不得使用 LAME GPL decoding path。
- Homebrew FFmpeg 只能作為 dev-only 工具，不得隨 App 發布。
- release bundle 不得包含 GPL、AGPL、CC BY-NC、non-commercial、research-only 授權元件或模型。
- release bundle 不得引入 bundled Python runtime。
- Whisper model weights 必須保留 MIT 授權告知；本案使用 `ggml-small.en.bin`。
