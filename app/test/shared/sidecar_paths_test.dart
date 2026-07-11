// AI-Generate
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/shared/infra/sidecar_paths.dart';

SidecarPaths _pathsWithMissingArtifacts() => SidecarPaths(
      ffmpegPath: '/nonexistent/ffmpeg',
      ffprobePath: '/nonexistent/ffprobe',
      whisperCliPath: '/nonexistent/whisper-cli',
      whisperModelPath: '/nonexistent/whisper-model',
      cmudictPath: '/nonexistent/cmudict',
      demucsCliPath: '/nonexistent/demucs',
      demucsModelPath: '/nonexistent/demucs-model',
      tempDirectory: '/tmp/sr-test',
    );

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

  group('diagnose（S-001 / 借鏡 QwenASR 就緒狀態）', () {
    test('回傳 7 個元件（5 必需 + 2 選用）且順序穩定', () {
      final statuses = _pathsWithMissingArtifacts().diagnose();
      expect(statuses.map((s) => s.id), [
        'ffmpeg',
        'ffprobe',
        'whisper-cli',
        'whisper-model',
        'cmudict',
        'demucs-cli',
        'demucs-model',
      ]);
      expect(statuses.where((s) => s.required).length, 5);
      expect(statuses.where((s) => !s.required).length, 2);
    });

    test('缺件時 exists=false、required 項 blocking=true、選用項 blocking=false', () {
      final statuses = _pathsWithMissingArtifacts().diagnose();
      final ffmpeg = statuses.firstWhere((s) => s.id == 'ffmpeg');
      final demucs = statuses.firstWhere((s) => s.id == 'demucs-cli');

      expect(ffmpeg.exists, false);
      expect(ffmpeg.blocking, true);
      expect(demucs.exists, false);
      expect(demucs.blocking, false);
      expect(ffmpeg.acquisitionHint, contains('LGPL'));
      expect(demucs.acquisitionHint, contains('降級'));
    });

    test('已存在檔案時 ready=true、blocking=false', () async {
      final dir =
          await Directory.systemTemp.createTemp('sidecar-diagnose-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final f = File('${dir.path}/present')..writeAsStringSync('ok');
      final status = SidecarComponentStatus(
        id: 'test',
        label: 'test',
        path: f.path,
        exists: File(f.path).existsSync(),
        required: true,
        acquisitionHint: '',
      );

      expect(status.ready, true);
      expect(status.blocking, false);
    });
  });
}
