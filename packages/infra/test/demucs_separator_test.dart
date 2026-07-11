// AI-Generate
// DemucsCppVocalSeparator 錯誤映射與成功路徑單元測試（task-split 3.8）。
// 不呼叫真實 demucs.cpp（真機整合見 demucs_integration_test.dart）。
import 'dart:io';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:infra/infra.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _FakeRunner implements ProcessRunner {
  final Future<SidecarResult> Function() _behavior;
  List<String>? capturedArgs;
  String? capturedExe;

  _FakeRunner(this._behavior);

  @override
  Future<SidecarResult> run(String executable, List<String> args,
      {Duration? timeout}) {
    capturedExe = executable;
    capturedArgs = args;
    return _behavior();
  }
}

class _FakeDecoder implements AnalysisAudioDecoder {
  Pcm result;
  int calls = 0;
  String? lastPath;

  _FakeDecoder(this.result);

  @override
  Future<Pcm> decode(String audioPath) async {
    calls++;
    lastPath = audioPath;
    return result;
  }
}

Matcher _domainError(String code) =>
    throwsA(isA<DomainException>().having((e) => e.code, 'code', code));

DemucsCppVocalSeparator _separator(
  _FakeRunner runner, {
  required String outDir,
  AnalysisAudioDecoder? decoder,
}) {
  return DemucsCppVocalSeparator(
    runner: runner,
    decoder: decoder ?? _FakeDecoder(Pcm(Int16List(44100))),
    demucsCliPath: '/dev/null/demucs.cpp.main',
    modelPath: '/dev/null/ggml-model-htdemucs-4s-f16.bin',
    outputDirectory: outDir,
  );
}

ImportRequest _req() =>
    ImportRequest(audioPath: '/tmp/song.mp3', separateVocals: true);

Pcm _silentPcm({int seconds = 3}) => Pcm(Int16List(44100 * seconds));

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('demucs_sep_test_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('DemucsCppVocalSeparator 錯誤映射', () {
    test('decodedPcm 非 44100Hz → ERR_SEPARATE_FAILED 且不啟動 sidecar', () async {
      final fake = _FakeRunner(() async => SidecarResult(0, [], ''));
      final sep = _separator(fake, outDir: tmp.path);

      await expectLater(
        sep.separate(
          _req(),
          decodedPcm: Pcm(Int16List(16000), sampleRate: 16000),
        ),
        _domainError(ErrorCodes.separateFailed),
      );

      expect(fake.capturedArgs, isNull);
    });

    test('exit>0 → ERR_SEPARATE_FAILED', () async {
      final fake =
          _FakeRunner(() async => SidecarResult(1, [], 'model file not found'));
      final sep = _separator(fake, outDir: tmp.path);
      await expectLater(sep.separate(_req(), decodedPcm: _silentPcm()),
          _domainError(ErrorCodes.separateFailed));
    });

    test('被訊號終止 → ERR_SIDECAR_CRASHED', () async {
      final fake = _FakeRunner(() async => SidecarResult(-9, [], ''));
      final sep = _separator(fake, outDir: tmp.path);
      await expectLater(sep.separate(_req(), decodedPcm: _silentPcm()),
          _domainError(ErrorCodes.sidecarCrashed));
    });

    test('逾時 → ERR_SIDECAR_TIMEOUT', () async {
      final fake = _FakeRunner(
          () async => throw const SidecarFailure('timeout', 'test'));
      final sep = _separator(fake, outDir: tmp.path);
      await expectLater(sep.separate(_req(), decodedPcm: _silentPcm()),
          _domainError(ErrorCodes.sidecarTimeout));
    });

    test('spawn 失敗 → ERR_SIDECAR_CRASHED', () async {
      final fake = _FakeRunner(
          () async => throw const SidecarFailure('spawn', 'ENOENT'));
      final sep = _separator(fake, outDir: tmp.path);
      await expectLater(sep.separate(_req(), decodedPcm: _silentPcm()),
          _domainError(ErrorCodes.sidecarCrashed));
    });

    test('exit=0 但未產出 target_3_vocals.wav → ERR_SEPARATE_FAILED', () async {
      final fake = _FakeRunner(() async => SidecarResult(0, [], ''));
      final sep = _separator(fake, outDir: tmp.path);
      await expectLater(sep.separate(_req(), decodedPcm: _silentPcm()),
          _domainError(ErrorCodes.separateFailed));
    });
  });

  group('DemucsCppVocalSeparator 成功路徑', () {
    test('成功：官方 CLI 產出 target_3_vocals.wav → decoder 讀回', () async {
      final expectedPcm = Pcm(Int16List(44100 * 2)); // 2 秒 silence
      final decoder = _FakeDecoder(expectedPcm);
      // 模擬 CLI 產出：demucs 執行時建 workDir/target_3_vocals.wav
      // 需要在 runner behavior 內建檔（fake runner 執行前）
      String? knownWorkDir;
      Pcm? preparedInput;
      late _FakeRunner fake;
      fake = _FakeRunner(() async {
        // 官方 args: <model-file> <input-audio> <output-dir>
        final inputPath = fake.capturedArgs![1];
        final workDir = fake.capturedArgs![2];
        knownWorkDir = workDir;
        preparedInput = decodeWav(File(inputPath).readAsBytesSync());
        final vocals = File(p.join(workDir, 'target_3_vocals.wav'));
        vocals.createSync(recursive: true);
        vocals.writeAsBytesSync([0, 0, 0, 0]); // 內容不重要，被 fake decoder 忽略
        return SidecarResult(0, [], '');
      });
      final sep = _separator(fake, outDir: tmp.path, decoder: decoder);

      final result = await sep.separate(_req(), decodedPcm: _silentPcm());

      expect(result.audioPath, p.join(knownWorkDir!, 'target_3_vocals.wav'));
      expect(result.pcm, same(expectedPcm));
      expect(decoder.calls, 1);
      expect(decoder.lastPath, result.audioPath);
      expect(preparedInput!.sampleRate, 44100);
      expect(preparedInput!.durationMs, 3000);
      // 驗證 CLI args 對齊 sevagh/demucs.cpp README。
      expect(fake.capturedArgs![0], '/dev/null/ggml-model-htdemucs-4s-f16.bin');
      expect(
          fake.capturedArgs![1], p.join(knownWorkDir!, 'input_44100_mono.wav'));
      expect(fake.capturedArgs![2], knownWorkDir);
      expect(File(fake.capturedArgs![1]).existsSync(), isFalse,
          reason: 'demucs 行程結束後應清除暫存輸入 WAV');
    });

    test('workDir 建於 outputDirectory 下、名稱含 audioPath basename', () async {
      String? capturedWorkDir;
      late _FakeRunner fake;
      fake = _FakeRunner(() async {
        final workDir = fake.capturedArgs![2];
        capturedWorkDir = workDir;
        File(p.join(workDir, 'target_3_vocals.wav'))
            .createSync(recursive: true);
        return SidecarResult(0, [], '');
      });
      final sep = _separator(fake,
          outDir: tmp.path, decoder: _FakeDecoder(_silentPcm()));

      await sep.separate(
          ImportRequest(
              audioPath: '/tmp/My Song! v2.mp3', separateVocals: true),
          decodedPcm: _silentPcm());

      expect(capturedWorkDir, startsWith(tmp.path));
      expect(p.basename(capturedWorkDir!),
          matches(r'^my_song[_-]?v?2?_demucs_\d+$'),
          reason: 'audioPath basename 應被 sanitize 為安全字元');
    });
  });
}
