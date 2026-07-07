#!/bin/sh
# AI-Generate
set -eu

if [ "${CONFIGURATION:-}" != "Release" ]; then
  echo "[sidecar] skip sidecar copy for ${CONFIGURATION:-unknown} build"
  exit 0
fi

SRC="${PROJECT_DIR}/Runner/Resources/sidecar"
DEST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/sidecar"

required_paths="
sidecar-manifest.json
bin/ffmpeg
bin/ffprobe
bin/whisper-cli
bin/demucs.cpp.main
models/ggml-small.en.bin
models/ggml-model-htdemucs-4s-f16.bin
data/cmudict.dict
"

for rel in $required_paths; do
  if [ ! -e "${SRC}/${rel}" ]; then
    echo "[sidecar] missing ${SRC}/${rel}" >&2
    echo "[sidecar] run scripts/prepare_release_sidecars.py before release build" >&2
    exit 1
  fi
done

mkdir -p "$DEST"
rsync -a --delete "${SRC}/" "${DEST}/"
echo "[sidecar] copied release sidecars to ${DEST}"
