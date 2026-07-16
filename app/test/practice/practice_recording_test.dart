// AI-Generate
import 'dart:io';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infra/infra.dart';
import 'package:syllable_repeater_app/features/practice/practice_recording.dart';

class _FakeNormalizer implements AnalysisAudioDecoder {
  _FakeNormalizer(this.result);

  final Pcm result;
  int callCount = 0;
  String? lastPath;

  @override
  Future<Pcm> decode(String audioPath) async {
    callCount++;
    lastPath = audioPath;
    return result;
  }
}

void main() {
  test('AT-06-06 等待 macOS WAV 收尾後才回傳可解碼 PCM', () async {
    final dir = Directory.systemTemp.createTempSync('recording_ready_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/attempt.wav');
    await file.writeAsBytes([1, 2, 3, 4], flush: true);

    final expected = Pcm(
      Int16List.fromList([100, -100, 200]),
      sampleRate: 1000,
    );
    Future<void>.delayed(const Duration(milliseconds: 60), () async {
      await file.writeAsBytes(encodeWav(expected), flush: true);
    });

    final decoded = await waitForCompletedRecording(
      file.path,
      attempts: 10,
      retryDelay: const Duration(milliseconds: 20),
    );

    expect(decoded.sampleRate, 1000);
    expect(decoded.samples, expected.samples);
  });

  test('M10 WAV 收尾失敗時不保留來源錄音檔', () async {
    final dir = Directory.systemTemp.createTempSync('recording_failed_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/broken.wav');
    await file.writeAsBytes([1, 2, 3, 4], flush: true);

    await expectLater(
      waitForCompletedRecording(
        file.path,
        attempts: 2,
        retryDelay: Duration.zero,
      ),
      throwsA(isA<DomainException>()),
    );

    expect(file.existsSync(), isFalse);
  });

  test('AT-18-07 非 PCM16 單聲道 WAV 先經 FFmpeg 正規化再解碼', () async {
    final dir = Directory.systemTemp.createTempSync(
      'recording_normalize_test_',
    );
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/plugin-output.wav');
    final unsupported = encodeWav(
      Pcm(Int16List.fromList([10, -10, 20, -20]), sampleRate: 1000),
    );
    ByteData.sublistView(unsupported).setUint16(22, 2, Endian.little);
    await file.writeAsBytes(unsupported, flush: true);

    final expected = Pcm(
      Int16List.fromList([100, -100, 200, -200]),
      sampleRate: 44100,
    );
    final normalizer = _FakeNormalizer(expected);
    final decoded = await waitForCompletedRecording(
      file.path,
      attempts: 3,
      retryDelay: Duration.zero,
      normalizer: normalizer,
      fileIo: AtomicFileIo(tempDirPath: dir.path),
    );

    expect(decoded.samples, expected.samples);
    expect(normalizer.callCount, 1);
    expect(normalizer.lastPath, file.path);
    final normalizedOnDisk = decodeWav(await file.readAsBytes());
    expect(normalizedOnDisk.sampleRate, 44100);
    expect(normalizedOnDisk.samples, expected.samples);
  });
}
