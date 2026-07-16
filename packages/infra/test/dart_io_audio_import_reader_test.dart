// AI-Generate
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:infra/infra.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('audio-import-reader-');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('AT-12-06/07：真實 bytes 讀完並驗證格式／時長後才 ready', () async {
    final path = '${tempDir.path}/fixture.wav';
    await File(path).writeAsBytes([1, 2, 3, 4, 5]);
    final probe = _FakeDurationProbe(const Duration(milliseconds: 1234));
    final reader = DartIoAudioImportReader(durationProbe: probe);

    final events = await reader.readAndValidate(path).toList();

    expect(events.map((event) => event.progress.stage), [
      AudioImportStage.readingBytes,
      AudioImportStage.validatingFormat,
      AudioImportStage.validatingDuration,
      AudioImportStage.ready,
    ]);
    expect(events.first.progress.bytesRead, 5);
    expect(events.first.progress.totalBytes, 5);
    expect(events.first.progress.ratio, 1);
    expect(
        events
            .take(events.length - 1)
            .every((event) => event.readySource == null),
        isTrue);
    expect(events.last.readySource?.bytesRead, 5);
    expect(events.last.readySource?.durationMs, 1234);
    expect(probe.paths, [path]);
  });

  test('AT-12-08：空檔 fail-closed，stream 不得先發 ready', () async {
    final path = '${tempDir.path}/empty.wav';
    await File(path).writeAsBytes(const []);
    final reader = DartIoAudioImportReader(
      durationProbe: _FakeDurationProbe(const Duration(seconds: 1)),
    );
    final events = <AudioImportEvent>[];

    final run = () async {
      await for (final event in reader.readAndValidate(path)) {
        events.add(event);
      }
    }();
    await expectLater(
      run,
      throwsA(
        isA<DomainException>().having(
          (error) => error.code,
          'code',
          ErrorCodes.decodeFailed,
        ),
      ),
    );

    expect(events.any((event) => event.readySource != null), isFalse);
  });
}

class _FakeDurationProbe implements AudioDurationProbe {
  _FakeDurationProbe(this.duration);

  final Duration duration;
  final paths = <String>[];

  @override
  Future<Duration> probe(String audioPath) async {
    paths.add(audioPath);
    return duration;
  }
}
