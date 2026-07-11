// AI-Generate
id: WF-20260707-ffmpeg-lgpl-shared-sidecar-staging-s6
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation task 2.1 S6-16, 2026-07-07
context: Syllable Repeater 2.1 要把 FFmpeg/ffprobe 放入 macOS release sidecar staging，M9 要求 LGPL dynamic/shared build，且不得把本機 `/usr/local/bin/ffmpeg` 的 GPL build 放進 release。repo 路徑含空白，FFmpeg 8.1.2 source 若直接在 repo 下 configure/make 會遇到 upstream build script 對含空白 prefix/path 的 shell parsing 問題。
action: 下載 FFmpeg 8.1.2 官方 source tarball 並記錄 SHA-256 `464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c`；改在 `/private/tmp/syllable_ffmpeg_src_20260707` 這類無空白路徑 configure/make/install，configure 使用 `--enable-shared --disable-static --disable-gpl --disable-nonfree --enable-libmp3lame`，install prefix 也放無空白 tmp；再將 `bin/`、`lib/` 與 Homebrew `libmp3lame.0.dylib` 複製到 `.local-tools/release-sidecars/ffmpeg/`，由 `prepare_release_sidecars.py` 修補 Mach-O rpath/install name。
result: `.local-tools/release-sidecars/ffmpeg/bin/ffmpeg -version` 顯示 LGPL shared build 且無 `--enable-gpl`/`--enable-nonfree`；`otool -L` 顯示 staged FFmpeg 以 `@rpath/libav*.dylib` 與 `@rpath/libmp3lame.0.dylib` 載入 bundled shared dylib。`python3 scripts/fetch_sidecar_artifacts.py --inventory-only` 與 `python3 scripts/fetch_sidecar_artifacts.py --run-prepare` 皆通過，2.1 release sidecar staging 實體工件補齊。
reasoning: M9 風險同時來自授權旗標、dynamic linking、建置來源與 Mach-O install name。把 configure/build 放在無空白 tmp 路徑可避開 FFmpeg upstream build shell 對 repo path spaces 的問題；把輸出複製回 `.local-tools/release-sidecars/ffmpeg/` 再由 staging script 統一 patch，能維持 repo layout 並避免 release binary 仍指向 `/private/tmp` 或 `/usr/local` dylib。
recommendation: 下次重建 release FFmpeg 時，不要在含空白 repo 路徑內直接 build；使用無空白 tmp source/prefix，先驗 `ffmpeg -version` 無 GPL/nonfree 且 shared，再驗 `otool -L` 都是 `@rpath`/系統路徑。manifest 的 manualBuild 必須保留 `sourceSha256`；若本機有 `gpg`，再用 FFmpeg `.asc` 補 PGP 驗章，但不得以缺 gpg 為理由改用 GPL Homebrew binary。
confidence: high
status: active
verified_count: 1
created: 2026-07-07
last_used: 2026-07-07
