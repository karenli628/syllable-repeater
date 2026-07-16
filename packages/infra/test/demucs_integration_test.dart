// AI-Generate
@Tags(['sidecar'])
library;

import 'dart:io';

import 'package:domain/domain.dart';
import 'package:infra/infra.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_support/repo_fixture.dart';

/// S1c 真整合測試（task-split 3.8）：`.local-tools/demucs.cpp/` 就緒時對使用者
/// mp3 跑真 demucs.cpp CLI + FFmpeg 讀回 vocals PCM；缺失即 skip。
void main() {
  test('S1c demo：真 demucs.cpp 分離出 vocals → 解碼回 PCM 非空', () async {
    final root = findRepoRoot();
    final ffmpeg = _firstExisting([
      '/usr/local/bin/ffmpeg',
      '/opt/homebrew/bin/ffmpeg',
    ]);
    final demucsCli = File(p.join(
      root.path,
      '.local-tools/demucs.cpp/build/demucs.cpp.main',
    ));
    final modelPath = File(p.join(
      root.path,
      '.local-tools/demucs.cpp/ggml-demucs/ggml-model-htdemucs-4s-f16.bin',
    ));
    final audio = fixtureAudio(
      'voice and music.mp3',
      root: root,
    );

    if (ffmpeg == null) {
      markTestSkipped('FFmpeg not installed');
      return;
    }
    if (!demucsCli.existsSync()) {
      markTestSkipped('demucs.cpp local build not installed (S1c 使用者本機事宜)');
      return;
    }
    if (!modelPath.existsSync()) {
      markTestSkipped('demucs.cpp htdemucs model not installed');
      return;
    }
    if (!audio.existsSync()) {
      markTestSkipped('user audio file not found');
      return;
    }

    final workRoot = Directory(p.join(
      root.path,
      '.local-tools/s1c/demucs_integration',
    ));
    workRoot.createSync(recursive: true);

    const runner = SidecarRunner(defaultTimeout: Duration(seconds: 240));
    final decoder = FfmpegDecoder(runner: runner, ffmpegPath: ffmpeg.path);
    final separator = DemucsCppVocalSeparator(
      runner: runner,
      decoder: decoder,
      inputPreparer: FfmpegDemucsAudioPreparer(
        runner: runner,
        ffmpegPath: ffmpeg.path,
      ),
      demucsCliPath: demucsCli.path,
      modelPath: modelPath.path,
      outputDirectory: workRoot.path,
    );

    final request = ImportRequest(
      audioPath: audio.path,
      separateVocals: true,
    );
    final decodedPcm = await decoder.decode(audio.path);

    final result = await separator.separate(request, decodedPcm: decodedPcm);

    expect(result.audioPath, endsWith('target_3_vocals.wav'));
    expect(File(result.audioPath).existsSync(), isFalse,
        reason: 'AT-10-07：PCM 讀回後即刪除 Demucs 中介檔');
    expect(result.pcm.samples, isNotEmpty);
    expect(result.pcm.sampleRate, 44100);
    expect(result.pcm.durationMs, greaterThan(1000),
        reason: '含人聲與音樂的 fixture 分離後應仍有可分析 vocals');
  }, timeout: const Timeout(Duration(minutes: 5)));
}

File? _firstExisting(List<String> paths) {
  for (final p in paths) {
    final f = File(p);
    if (f.existsSync()) return f;
  }
  return null;
}
