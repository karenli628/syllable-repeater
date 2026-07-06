// AI-Generate
// RecordingComparator TDD-red 測試（task-split 6.1/6.2）。
// 對應 requirement REQ-06 AT-06-01/02/04 與 CT-10。
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

Matcher _domainError(String code) =>
    throwsA(isA<DomainException>().having((e) => e.code, 'code', code));

class _FakeRecordingAudioSource implements RecordingAudioSource {
  final Map<String, Pcm> recordings = {};
  final Set<String> deleted = {};
  final Set<String> readFailures = {};

  @override
  Future<Pcm> readPcm(String path) async {
    if (readFailures.contains(path)) {
      throw const DomainException(ErrorCodes.decodeFailed, '錄音解碼失敗');
    }
    final pcm = recordings[path];
    if (pcm == null) {
      throw const DomainException(ErrorCodes.decodeFailed, '找不到錄音');
    }
    return pcm;
  }

  @override
  Future<void> delete(String path) async {
    deleted.add(path);
  }
}

List<Syllable> _thankYouVeryMuchSyllables() => [
      Syllable(
        text: 'thank',
        startMs: 0,
        endMs: 200,
        wordIndex: 0,
        needsReview: false,
      ),
      Syllable(
        text: 'you',
        startMs: 200,
        endMs: 400,
        wordIndex: 1,
        needsReview: false,
      ),
      Syllable(
        text: 've',
        startMs: 400,
        endMs: 600,
        wordIndex: 2,
        needsReview: true,
      ),
      Syllable(
        text: 'ry',
        startMs: 600,
        endMs: 800,
        wordIndex: 2,
        needsReview: true,
      ),
      Syllable(
        text: 'much',
        startMs: 800,
        endMs: 1200,
        wordIndex: 3,
        needsReview: false,
      ),
    ];

Pcm _indexedPcm({int durationMs = 1200, int sampleRate = 1000}) {
  final samples = Int16List(durationMs * sampleRate ~/ 1000);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = i;
  }
  return Pcm(samples, sampleRate: sampleRate);
}

Pcm _sinePcm({
  required int durationMs,
  int sampleRate = 1000,
  double hz = 100,
  int amplitude = 12000,
}) {
  final samples = Int16List(durationMs * sampleRate ~/ 1000);
  for (var i = 0; i < samples.length; i++) {
    final t = i / sampleRate;
    samples[i] = (math.sin(2 * math.pi * hz * t) * amplitude).round();
  }
  return Pcm(samples, sampleRate: sampleRate);
}

List<double> _normalizedSamples(Pcm pcm) =>
    pcm.samples.map((sample) => sample / 32768.0).toList(growable: false);

void main() {
  group('RecordingComparator（task-split 6.1/6.2，REQ-06）', () {
    test('6.1 依 step 時間戳從整句原音切出正確基準片段，成功後刪錄音', () async {
      final audio = _FakeRecordingAudioSource();
      final original = _indexedPcm();
      final steps =
          PracticeEngine().buildSteps(_thankYouVeryMuchSyllables(), 1);
      final step3 = steps[2]; // ve ry much = 400..1200ms
      final userPcm = PracticeEngine().renderStep(step3, original);
      audio.recordings['/tmp/attempt.wav'] = userPcm;

      final result = await RecordingComparator(audioSource: audio).compare(
        '/tmp/attempt.wav',
        _thankYouVeryMuchSyllables(),
        step3,
        original,
      );

      expect(result.overlayData.referenceWave,
          _normalizedSamples(PracticeEngine().renderStep(step3, original)));
      expect(result.overlayData.userWave, _normalizedSamples(userPcm));
      expect(result.overlayData.diffRanges, isEmpty);
      expect(result.rhythmDelta, closeTo(0, 0.0001));
      expect(audio.deleted, contains('/tmp/attempt.wav'));
    });

    test('AT-06-02 錄音 <0.2s 拒絕、不產結果，仍 finally 刪錄音', () async {
      final audio = _FakeRecordingAudioSource();
      audio.recordings['/tmp/short.wav'] = _sinePcm(durationMs: 100);
      final step =
          PracticeEngine().buildSteps(_thankYouVeryMuchSyllables(), 1).first;

      await expectLater(
        RecordingComparator(audioSource: audio).compare(
          '/tmp/short.wav',
          _thankYouVeryMuchSyllables(),
          step,
          _indexedPcm(),
        ),
        _domainError(ErrorCodes.recordingTooShort),
      );

      expect(audio.deleted, contains('/tmp/short.wav'));
    });

    test('CT-10 解碼失敗時仍 finally 刪錄音', () async {
      final audio = _FakeRecordingAudioSource()
        ..readFailures.add('/tmp/bad.wav');
      final step =
          PracticeEngine().buildSteps(_thankYouVeryMuchSyllables(), 1).first;

      await expectLater(
        RecordingComparator(audioSource: audio).compare(
          '/tmp/bad.wav',
          _thankYouVeryMuchSyllables(),
          step,
          _indexedPcm(),
        ),
        _domainError(ErrorCodes.decodeFailed),
      );

      expect(audio.deleted, contains('/tmp/bad.wav'));
    });

    test('6.2 DTW 差異輸出 diffRanges；10 秒錄音於 2 秒內完成', () async {
      final audio = _FakeRecordingAudioSource();
      final syllable = Syllable(
        text: 'long',
        startMs: 0,
        endMs: 10000,
        wordIndex: 0,
        needsReview: false,
      );
      final step = PracticeEngine().buildSteps([syllable], 1).single;
      final reference = _sinePcm(durationMs: 10000, hz: 100);
      final shifted = _sinePcm(durationMs: 10000, hz: 180);
      audio.recordings['/tmp/long.wav'] = shifted;

      final stopwatch = Stopwatch()..start();
      final result = await RecordingComparator(audioSource: audio).compare(
        '/tmp/long.wav',
        [syllable],
        step,
        reference,
      );
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(result.overlayData.diffRanges, isNotEmpty);
      expect(result.rhythmDelta, greaterThanOrEqualTo(0));
      expect(result.intonationDelta, greaterThan(0));
      expect(audio.deleted, contains('/tmp/long.wav'));
    });
  });
}
