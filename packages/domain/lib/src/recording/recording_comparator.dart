// AI-Generate
import 'dart:math' as math;

import '../errors.dart';
import '../model/comparison_result.dart';
import '../model/pcm.dart';
import '../model/practice_step.dart';
import '../model/syllable.dart';
import '../model/time_range.dart';
import '../ports/recording_audio_source.dart';
import '../practice/practice_engine.dart';

/// RecordingComparator（backend-design.md §3.2.4）。
///
/// 比對只讀原音與錄音 PCM；錄音暫存檔刪除透過 [RecordingAudioSource] port
/// 在 `finally` 保證執行，Domain 本身不 import `dart:io`（M5/M10）。
class RecordingComparator {
  static const minRecordingDurationMs = 200;

  final RecordingAudioSource audioSource;
  final PracticeEngine practiceEngine;

  RecordingComparator({
    required this.audioSource,
    PracticeEngine? practiceEngine,
  }) : practiceEngine = practiceEngine ?? PracticeEngine();

  Future<ComparisonResult> compare(
    String userRecordingPath,
    List<Syllable> syllables,
    PracticeStep step,
    Pcm originalPcm,
  ) async {
    try {
      _validateStepSyllables(syllables, step);
      final userPcm = await audioSource.readPcm(userRecordingPath);
      if (userPcm.durationMs < minRecordingDurationMs) {
        throw const DomainException(
          ErrorCodes.recordingTooShort,
          '錄音過短，請重錄（至少 0.2 秒）',
        );
      }

      final referencePcm =
          practiceEngine.renderExportStep(step, originalPcm).pcm;
      final userWave = _normalizedWave(userPcm);
      final referenceWave = _normalizedWave(referencePcm);
      final userRhythmCurve = _rmsCurve(userPcm, maxBuckets: 160);
      final referenceRhythmCurve = _rmsCurve(referencePcm, maxBuckets: 160);
      final userPitch = _pitchContour(userPcm);
      final referencePitch = _pitchContour(referencePcm);

      final rhythmDelta =
          _normalizedDtwDistance(userRhythmCurve, referenceRhythmCurve);
      final intonationDelta = userPitch.isEmpty || referencePitch.isEmpty
          ? 0.0
          : _normalizedDtwDistance(userPitch, referencePitch);

      return ComparisonResult(
        rhythmDelta: rhythmDelta,
        intonationDelta: intonationDelta,
        overlayData: OverlayData(
          userWave: userWave,
          referenceWave: referenceWave,
          userPitch: userPitch,
          referencePitch: referencePitch,
          diffRanges: _diffRanges(
            _waveCurve(userPcm, maxBuckets: 160),
            _waveCurve(referencePcm, maxBuckets: 160),
            referenceDurationMs: referencePcm.durationMs,
          ),
        ),
        score: _score(rhythmDelta, intonationDelta),
      );
    } finally {
      await audioSource.delete(userRecordingPath);
    }
  }

  void _validateStepSyllables(List<Syllable> syllables, PracticeStep step) {
    final known =
        syllables.map((s) => '${s.text}:${s.startMs}-${s.endMs}').toSet();
    for (final syllable in step.syllables) {
      final key = '${syllable.text}:${syllable.startMs}-${syllable.endMs}';
      if (!known.contains(key)) {
        throw ArgumentError('PracticeStep.syllables 必須來自整句 syllables');
      }
    }
  }

  List<double> _normalizedWave(Pcm pcm) {
    return List<double>.unmodifiable(
      pcm.samples.map((sample) => sample / 32768.0),
    );
  }

  List<double> _rmsCurve(Pcm pcm, {required int maxBuckets}) {
    if (pcm.samples.isEmpty) {
      return const [];
    }
    final bucketCount = math.min(maxBuckets, pcm.samples.length);
    final curve = <double>[];
    for (var bucket = 0; bucket < bucketCount; bucket++) {
      final start = (bucket * pcm.samples.length) ~/ bucketCount;
      final end = ((bucket + 1) * pcm.samples.length) ~/ bucketCount;
      curve.add(_normalizedRms(pcm, start, math.max(start + 1, end)));
    }
    return List.unmodifiable(curve);
  }

  List<double> _waveCurve(Pcm pcm, {required int maxBuckets}) {
    if (pcm.samples.isEmpty) {
      return const [];
    }
    final bucketCount = math.min(maxBuckets, pcm.samples.length);
    final curve = <double>[];
    for (var bucket = 0; bucket < bucketCount; bucket++) {
      final start = (bucket * pcm.samples.length) ~/ bucketCount;
      final end = ((bucket + 1) * pcm.samples.length) ~/ bucketCount;
      final center = math.min(pcm.samples.length - 1, (start + end) ~/ 2);
      curve.add(pcm.samples[center] / 32768.0);
    }
    return List.unmodifiable(curve);
  }

  double _normalizedRms(Pcm pcm, int start, int end) {
    var sumSquares = 0.0;
    for (var i = start; i < end && i < pcm.samples.length; i++) {
      final normalized = pcm.samples[i] / 32768.0;
      sumSquares += normalized * normalized;
    }
    return math.sqrt(sumSquares / math.max(1, end - start));
  }

  List<double> _pitchContour(Pcm pcm) {
    if (pcm.samples.isEmpty) {
      return const [];
    }
    final windowSamples = math.max(32, (80 * pcm.sampleRate) ~/ 1000);
    final hopSamples = math.max(1, windowSamples ~/ 2);
    final minLag = math.max(1, pcm.sampleRate ~/ 400);
    final maxLag = math.max(minLag + 1, pcm.sampleRate ~/ 60);
    final pitches = <double>[];

    for (var start = 0;
        start + windowSamples + maxLag < pcm.samples.length;
        start += hopSamples) {
      if (_normalizedRms(pcm, start, start + windowSamples) < 0.02) {
        continue;
      }
      var bestLag = -1;
      var bestScore = 0.0;
      for (var lag = minLag; lag <= maxLag; lag++) {
        final score = _autocorrelationScore(pcm, start, windowSamples, lag);
        if (score > bestScore) {
          bestScore = score;
          bestLag = lag;
        }
      }
      if (bestLag > 0 && bestScore >= 0.65) {
        pitches.add(pcm.sampleRate / bestLag);
      }
    }
    return List.unmodifiable(pitches);
  }

  double _autocorrelationScore(
    Pcm pcm,
    int start,
    int windowSamples,
    int lag,
  ) {
    var cross = 0.0;
    var energyA = 0.0;
    var energyB = 0.0;
    for (var i = 0; i < windowSamples; i++) {
      final a = pcm.samples[start + i].toDouble();
      final b = pcm.samples[start + i + lag].toDouble();
      cross += a * b;
      energyA += a * a;
      energyB += b * b;
    }
    if (energyA <= 0 || energyB <= 0) {
      return 0.0;
    }
    return cross / math.sqrt(energyA * energyB);
  }

  double _normalizedDtwDistance(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty) {
      return 0.0;
    }
    var previous = List<double>.filled(b.length + 1, double.infinity);
    previous[0] = 0.0;

    for (var i = 1; i <= a.length; i++) {
      final current = List<double>.filled(b.length + 1, double.infinity);
      for (var j = 1; j <= b.length; j++) {
        final cost = (a[i - 1] - b[j - 1]).abs();
        current[j] = cost +
            math.min(
              previous[j],
              math.min(current[j - 1], previous[j - 1]),
            );
      }
      previous = current;
    }
    return previous[b.length] / math.max(a.length, b.length);
  }

  List<TimeRange> _diffRanges(
    List<double> userCurve,
    List<double> referenceCurve, {
    required int referenceDurationMs,
  }) {
    final count = math.min(userCurve.length, referenceCurve.length);
    if (count == 0 || referenceDurationMs <= 0) {
      return const [];
    }

    final ranges = <TimeRange>[];
    int? rangeStartBucket;
    const threshold = 0.08;
    for (var i = 0; i < count; i++) {
      final isDifferent = (userCurve[i] - referenceCurve[i]).abs() > threshold;
      if (isDifferent && rangeStartBucket == null) {
        rangeStartBucket = i;
      } else if (!isDifferent && rangeStartBucket != null) {
        ranges
            .add(_bucketRange(rangeStartBucket, i, count, referenceDurationMs));
        rangeStartBucket = null;
      }
    }
    if (rangeStartBucket != null) {
      ranges.add(
          _bucketRange(rangeStartBucket, count, count, referenceDurationMs));
    }
    return List.unmodifiable(ranges);
  }

  TimeRange _bucketRange(
    int startBucket,
    int endBucket,
    int bucketCount,
    int durationMs,
  ) {
    final startMs = (startBucket * durationMs) ~/ bucketCount;
    final endMs = math.max(
      startMs + 1,
      (endBucket * durationMs) ~/ bucketCount,
    );
    return TimeRange(startMs, endMs);
  }

  double _score(double rhythmDelta, double intonationDelta) {
    final penalty = (rhythmDelta + intonationDelta).clamp(0.0, 1.0);
    return (1.0 - penalty) * 100.0;
  }
}
