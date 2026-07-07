# workflow_release_sidecar_staging_gate_s6

source: syllable-repeater / fullstack-code-implementation S6-14 task 2.1

context: 2.1 要把 x86_64 sidecar 放進 macOS App bundle `Contents/Resources/sidecar/`，但現有 `/usr/local/bin/ffmpeg` 是 Homebrew GPL build（`--enable-gpl`），且 `.local-tools/demucs.cpp` binary/model 尚未就緒。不能為了 release build 把 GPL FFmpeg 或缺件 silently 放進 bundle。

action: 新增 `SidecarPaths.bundled/current()`，Release AOT 走 `Contents/Resources/sidecar/`、Debug/Test 走 `.local-tools/`。新增 `scripts/prepare_release_sidecars.py`：先跑 CT-09 license manifest gate，再拒絕 `--enable-gpl` / `--enable-nonfree` 或非 shared FFmpeg/ffprobe，並 staging `bin/`、`lib/`、`models/`、`data/` 與 `sidecar-manifest.json`。macOS Release build phase 跑 `app/macos/Runner/Scripts/copy_release_sidecars.sh`，缺 ffmpeg/ffprobe/whisper/demucs/model/cmudict/manifest 任一項就 fail-closed；實體 sidecar staging 內容由 `.gitignore` 擋住不進版控。

recommendation: 後續拿到 LGPL-only FFmpeg/ffprobe 與 demucs.cpp artifacts 後，用 `scripts/prepare_release_sidecars.py` staging；若它拒絕 GPL/nonfree 或缺件，不要繞過。2.1 只有在 staging 成功、Release build phase 能 copy bundle、`scripts/check_licenses.py` 與 `scripts/test_prepare_release_sidecars.py` 都綠時才能勾完成。
