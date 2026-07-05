// AI-Generate
// FFmpeg 解碼契約單元測試（task-split 2.3）：以假 Runner 驗證錯誤映射與 PCM 解析，
// 不依賴真實 ffmpeg（真機整合見 ffmpeg_integration_test.dart）。
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:infra/infra.dart';
import 'package:test/test.dart';

class _FakeRunner implements ProcessRunner {
  final Future<SidecarResult> Function() _behavior;
  List<String>? capturedArgs;

  _FakeRunner(this._behavior);

  @override
  Future<SidecarResult> run(String executable, List<String> args,
      {Duration? timeout}) {
    capturedArgs = args;
    return _behavior();
  }
}

Matcher _domainError(String code) =>
    throwsA(isA<DomainException>().having((e) => e.code, 'code', code));

void main() {
  group('FfmpegDecoder 錯誤映射（backend-design §3.2.8）', () {
    test('副檔名白名單外 → ERR_UNSUPPORTED_FORMAT，且不呼叫 sidecar', () async {
      final fake = _FakeRunner(() async => const SidecarResult(0, [], ''));
      final d = FfmpegDecoder(runner: fake, ffmpegPath: 'ffmpeg');
      await expectLater(d.decode('/tmp/a.ogg'),
          _domainError(ErrorCodes.unsupportedFormat));
      expect(fake.capturedArgs, isNull, reason: '前置驗證應擋在 sidecar 之前');
    });

    test('exit>0（0 byte 損毀檔情境）→ ERR_DECODE_FAILED（AT-01-03）', () async {
      final fake = _FakeRunner(
          () async => const SidecarResult(1, [], 'invalid data'));
      final d = FfmpegDecoder(runner: fake, ffmpegPath: 'ffmpeg');
      await expectLater(
          d.decode('/tmp/broken.mp3'), _domainError(ErrorCodes.decodeFailed));
    });

    test('被訊號終止（kill -9）→ ERR_SIDECAR_CRASHED（AT-01-04）', () async {
      final fake =
          _FakeRunner(() async => const SidecarResult(-9, [], ''));
      final d = FfmpegDecoder(runner: fake, ffmpegPath: 'ffmpeg');
      await expectLater(
          d.decode('/tmp/a.mp3'), _domainError(ErrorCodes.sidecarCrashed));
    });

    test('逾時 → ERR_SIDECAR_TIMEOUT', () async {
      final fake = _FakeRunner(
          () async => throw const SidecarFailure('timeout', 'test'));
      final d = FfmpegDecoder(runner: fake, ffmpegPath: 'ffmpeg');
      await expectLater(
          d.decode('/tmp/a.mp3'), _domainError(ErrorCodes.sidecarTimeout));
    });

    test('解碼成功：s16le bytes → Pcm，44100 樣本 = 1000ms', () async {
      final bytes = Int16List(44100).buffer.asUint8List();
      final fake =
          _FakeRunner(() async => SidecarResult(0, bytes.toList(), ''));
      final d = FfmpegDecoder(runner: fake, ffmpegPath: 'ffmpeg');
      final pcm = await d.decode('/tmp/a.wav');
      expect(pcm.durationMs, 1000);
      expect(pcm.samples.length, 44100);
      expect(fake.capturedArgs, containsAllInOrder(['-f', 's16le']));
    });

    test('超過 10 分鐘（Q8 邊界）→ ERR_FILE_TOO_LONG', () async {
      // 10 分鐘 + 1 秒的樣本數（僅配置長度，不佔實際運算）。
      final samples = Int16List((10 * 60 + 1) * 44100);
      final fake = _FakeRunner(() async =>
          SidecarResult(0, samples.buffer.asUint8List().toList(), ''));
      final d = FfmpegDecoder(runner: fake, ffmpegPath: 'ffmpeg');
      await expectLater(
          d.decode('/tmp/long.wav'), _domainError(ErrorCodes.fileTooLong));
    });

    test('恰 10 分鐘（Q8 含邊界）→ 成功', () async {
      final samples = Int16List(10 * 60 * 44100);
      final fake = _FakeRunner(() async =>
          SidecarResult(0, samples.buffer.asUint8List().toList(), ''));
      final d = FfmpegDecoder(runner: fake, ffmpegPath: 'ffmpeg');
      final pcm = await d.decode('/tmp/max.wav');
      expect(pcm.durationMs, 600000);
    });
  });
}
