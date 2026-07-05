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
    demucsCliPath: '/dev/null/demucs.cpp',
    modelDir: '/dev/null/models',
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
    test('exit>0 → ERR_DECODE_FAILED', () async {
      final fake = _FakeRunner(
          () async => SidecarResult(1, [], 'model file not found'));
      final sep = _separator(fake, outDir: tmp.path);
      await expectLater(
          sep.separate(_req(), decodedPcm: _silentPcm()),
          _domainError(ErrorCodes.decodeFailed));
    });

    test('被訊號終止 → ERR_SIDECAR_CRASHED', () async {
      final fake = _FakeRunner(() async => SidecarResult(-9, [], ''));
      final sep = _separator(fake, outDir: tmp.path);
      await expectLater(
          sep.separate(_req(), decodedPcm: _silentPcm()),
          _domainError(ErrorCodes.sidecarCrashed));
    });

    test('逾時 → ERR_SIDECAR_TIMEOUT', () async {
      final fake = _FakeRunner(
          () async => throw const SidecarFailure('timeout', 'test'));
      final sep = _separator(fake, outDir: tmp.path);
      await expectLater(
          sep.separate(_req(), decodedPcm: _silentPcm()),
          _domainError(ErrorCodes.sidecarTimeout));
    });

    test('spawn 失敗 → ERR_SIDECAR_CRASHED', () async {
      final fake = _FakeRunner(
          () async => throw const SidecarFailure('spawn', 'ENOENT'));
      final sep = _separator(fake, outDir: tmp.path);
      await expectLater(
          sep.separate(_req(), decodedPcm: _silentPcm()),
          _domainError(ErrorCodes.sidecarCrashed));
    });

    test('exit=0 但未產出 vocals.wav → ERR_DECODE_FAILED', () async {
      final fake = _FakeRunner(() async => SidecarResult(0, [], ''));
      final sep = _separator(fake, outDir: tmp.path);
      await expectLater(
          sep.separate(_req(), decodedPcm: _silentPcm()),
          _domainError(ErrorCodes.decodeFailed));
    });
  });

  group('DemucsCppVocalSeparator 成功路徑', () {
    test('成功：CLI 產出 vocals.wav → decoder 讀回 → SeparatedAudio', () async {
      final expectedPcm = Pcm(Int16List(44100 * 2)); // 2 秒 silence
      final decoder = _FakeDecoder(expectedPcm);
      // 模擬 CLI 產出：demucs 執行時建 workDir/vocals.wav
      // 需要在 runner behavior 內建檔（fake runner 執行前）
      String? knownWorkDir;
      late _FakeRunner fake;
      fake = _FakeRunner(() async {
        // args 內 `-o <workDir>` 位置為 index 2
        final workDir = fake.capturedArgs![2];
        knownWorkDir = workDir;
        final vocals = File(p.join(workDir, 'vocals.wav'));
        vocals.createSync(recursive: true);
        vocals.writeAsBytesSync([0, 0, 0, 0]); // 內容不重要，被 fake decoder 忽略
        return SidecarResult(0, [], '');
      });
      final sep = _separator(fake, outDir: tmp.path, decoder: decoder);

      final result = await sep.separate(_req(), decodedPcm: _silentPcm());

      expect(result.audioPath, p.join(knownWorkDir!, 'vocals.wav'));
      expect(result.pcm, same(expectedPcm));
      expect(decoder.calls, 1);
      expect(decoder.lastPath, result.audioPath);
      // 驗證 CLI args 對齊 backend-design 契約
      expect(fake.capturedArgs, containsAllInOrder(['--two-stems=vocals', '-o']));
      expect(fake.capturedArgs, contains('/tmp/song.mp3'));
    });

    test('workDir 建於 outputDirectory 下、名稱含 audioPath basename', () async {
      String? capturedWorkDir;
      late _FakeRunner fake;
      fake = _FakeRunner(() async {
        final workDir = fake.capturedArgs![2];
        capturedWorkDir = workDir;
        File(p.join(workDir, 'vocals.wav')).createSync(recursive: true);
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
