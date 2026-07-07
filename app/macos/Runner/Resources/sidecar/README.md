# Release Sidecar Staging

AI-Generate

This directory is the local staging source for macOS release sidecars.
Generated binaries, models, dictionaries, dylibs, and `sidecar-manifest.json`
are intentionally ignored by git.

Prepare it with:

```bash
python3 scripts/prepare_release_sidecars.py \
  --ffmpeg /path/to/lgpl/ffmpeg \
  --ffprobe /path/to/lgpl/ffprobe \
  --ffmpeg-lib-dir /path/to/lgpl/ffmpeg-libs \
  --whisper-cli .local-tools/whisper.cpp/build/bin/whisper-cli \
  --whisper-model .local-tools/whisper.cpp/models/ggml-small.en.bin \
  --whisper-lib-dir .local-tools/whisper.cpp/build/bin \
  --cmudict .local-tools/cmudict/cmudict.dict \
  --demucs-cli /path/to/demucs.cpp \
  --demucs-model /path/to/ggml-model-htdemucs
```

The script rejects GPL/nonfree FFmpeg builds. Homebrew FFmpeg is dev-only
unless its `ffmpeg -version` output proves an LGPL-only shared build.
