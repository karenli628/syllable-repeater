// AI-Generate
// FfprobeDurationProbe 單元測試（task-split 前端 FP2 剩餘：10 分鐘時長前置檢查）。
// 以假 Runner 驗證錯誤映射與時長解析，不依賴真實 ffprobe。
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

SidecarResult _successResult(String stdoutText) => SidecarResult(
      0,
      Uint8List.fromList(stdoutText.codeUnits),
      '',
    );

void main() {
  group('FfprobeDurationProbe 錯誤映射', () {
    test('副檔名白名單外 → ERR_UNSUPPORTED_FORMAT，且不呼叫 sidecar', () async {
      final fake = _FakeRunner(() async => _successResult('1.0'));
      final probe = FfprobeDurationProbe(runner: fake, ffprobePath: 'ffprobe');
      await expectLater(
          probe.probe('/tmp/a.ogg'), _domainError(ErrorCodes.unsupportedFormat));
      expect(fake.capturedArgs, isNull, reason: '前置驗證應擋在 sidecar 之前');
    });

    test('exit>0 → ERR_DECODE_FAILED', () async {
      final fake = _FakeRunner(() async => SidecarResult(
          1, Uint8List(0), 'moov atom not found'));
      final probe = FfprobeDurationProbe(runner: fake, ffprobePath: 'ffprobe');
      await expectLater(
          probe.probe('/tmp/broken.mp3'), _domainError(ErrorCodes.decodeFailed));
    });

    test('被訊號終止 → ERR_SIDECAR_CRASHED', () async {
      final fake = _FakeRunner(() async => SidecarResult(-9, Uint8List(0), ''));
      final probe = FfprobeDurationProbe(runner: fake, ffprobePath: 'ffprobe');
      await expectLater(
          probe.probe('/tmp/a.mp3'), _domainError(ErrorCodes.sidecarCrashed));
    });

    test('逾時 → ERR_SIDECAR_TIMEOUT', () async {
      final fake = _FakeRunner(
          () async => throw const SidecarFailure('timeout', 'test'));
      final probe = FfprobeDurationProbe(runner: fake, ffprobePath: 'ffprobe');
      await expectLater(
          probe.probe('/tmp/a.mp3'), _domainError(ErrorCodes.sidecarTimeout));
    });

    test('spawn 失敗 → ERR_SIDECAR_CRASHED', () async {
      final fake = _FakeRunner(
          () async => throw const SidecarFailure('spawn', 'ENOENT'));
      final probe = FfprobeDurationProbe(runner: fake, ffprobePath: 'ffprobe');
      await expectLater(
          probe.probe('/tmp/a.mp3'), _domainError(ErrorCodes.sidecarCrashed));
    });

    test('stdout 非數字 → ERR_DECODE_FAILED', () async {
      final fake = _FakeRunner(() async => _successResult('N/A'));
      final probe = FfprobeDurationProbe(runner: fake, ffprobePath: 'ffprobe');
      await expectLater(
          probe.probe('/tmp/a.mp3'), _domainError(ErrorCodes.decodeFailed));
    });

    test('時長 > 10 分鐘 → ERR_FILE_TOO_LONG（Q8 邊界）', () async {
      final fake = _FakeRunner(() async => _successResult('600.001'));
      final probe = FfprobeDurationProbe(runner: fake, ffprobePath: 'ffprobe');
      await expectLater(
          probe.probe('/tmp/a.mp3'), _domainError(ErrorCodes.fileTooLong));
    });
  });

  group('FfprobeDurationProbe 成功路徑', () {
    test('回傳 Duration；args 帶正確 format=duration 選項', () async {
      final fake = _FakeRunner(() async => _successResult('3.482\n'));
      final probe = FfprobeDurationProbe(runner: fake, ffprobePath: 'ffprobe');

      final duration = await probe.probe('/tmp/a.mp3');

      expect(duration, const Duration(milliseconds: 3482));
      expect(fake.capturedArgs,
          containsAllInOrder(['-show_entries', 'format=duration']));
    });

    test('10 分鐘（含端點）→ 通過（Q8 邊界另一側）', () async {
      final fake = _FakeRunner(() async => _successResult('600'));
      final probe = FfprobeDurationProbe(runner: fake, ffprobePath: 'ffprobe');

      final duration = await probe.probe('/tmp/a.wav');

      expect(duration, const Duration(minutes: 10));
    });
  });
}
