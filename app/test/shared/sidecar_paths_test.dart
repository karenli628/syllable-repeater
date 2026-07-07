// AI-Generate
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/shared/infra/sidecar_paths.dart';

void main() {
  test('bundled paths map to Contents/Resources/sidecar layout', () {
    final separator = Platform.pathSeparator;
    final paths = SidecarPaths.bundled(
      resourcesRoot:
          '${separator}tmp${separator}App.app'
          '${separator}Contents${separator}Resources',
    );

    expect(
      paths.ffmpegPath,
      '${separator}tmp${separator}App.app${separator}Contents'
      '${separator}Resources${separator}sidecar${separator}bin'
      '${separator}ffmpeg',
    );
    expect(
      paths.ffprobePath,
      endsWith('${separator}sidecar${separator}bin${separator}ffprobe'),
    );
    expect(
      paths.whisperCliPath,
      endsWith('${separator}sidecar${separator}bin${separator}whisper-cli'),
    );
    expect(
      paths.whisperModelPath,
      endsWith(
        '${separator}sidecar${separator}models${separator}ggml-small.en.bin',
      ),
    );
    expect(
      paths.cmudictPath,
      endsWith('${separator}sidecar${separator}data${separator}cmudict.dict'),
    );
    expect(
      paths.demucsCliPath,
      endsWith('${separator}sidecar${separator}bin${separator}demucs.cpp.main'),
    );
    expect(
      paths.demucsModelPath,
      endsWith(
        '${separator}sidecar${separator}models'
        '${separator}ggml-model-htdemucs-4s-f16.bin',
      ),
    );
  });
}
