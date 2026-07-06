// AI-Generate
import 'dart:typed_data';

import '../alignment/zero_crossing.dart';
import '../errors.dart';
import '../model/pcm.dart';
import '../model/practice_step.dart';
import '../model/syllable.dart';
import '../model/time_range.dart';
import 'practice_export_audio.dart';

/// PracticeEngine（backend-design.md §3.2.2）。
/// M2：步數等於音節數；第 n 步為句尾倒數 n 個音節，不做單字邊界吸附。
class PracticeEngine {
  static const minRepeatN = 1;
  static const maxRepeatN = 10;

  List<PracticeStep> buildSteps(List<Syllable> syllables, int repeatN) {
    _validateRepeatN(repeatN);
    if (syllables.isEmpty) {
      return const [];
    }

    return List.generate(syllables.length, (offset) {
      final index = offset + 1;
      final stepSyllables = List<Syllable>.unmodifiable(
          syllables.sublist(syllables.length - index));
      final ranges = _mergeAdjacentRanges(stepSyllables.map((s) => s.range));
      final durationMs =
          ranges.fold<int>(0, (sum, range) => sum + range.durationMs);
      return PracticeStep(
        index: index,
        syllables: stepSyllables,
        sourceRanges: ranges,
        totalDurationMs: durationMs * repeatN,
      );
    });
  }

  Pcm renderStep(PracticeStep step, Pcm originalPcm) {
    final pieces = <Int16List>[];
    var totalSamples = 0;

    for (final range in step.sourceRanges) {
      final startSample = originalPcm.sampleIndexAtMs(range.startMs);
      final endSample = originalPcm.sampleIndexAtMs(range.endMs);
      if (startSample < 0 ||
          endSample > originalPcm.samples.length ||
          startSample >= endSample) {
        throw ArgumentError(
            'sourceRange 超出 PCM 範圍：${range.startMs}..${range.endMs}ms');
      }

      final segment = Int16List.fromList(
        originalPcm.samples.sublist(startSample, endSample),
      );
      _applySegmentEdgeFade(
        segment,
        sampleRate: originalPcm.sampleRate,
        fadeIn: _needsBoundaryFade(originalPcm, range.startMs),
        fadeOut: _needsBoundaryFade(originalPcm, range.endMs),
      );
      pieces.add(segment);
      totalSamples += segment.length;
    }

    final rendered = Int16List(totalSamples);
    var offset = 0;
    for (final piece in pieces) {
      rendered.setRange(offset, offset + piece.length, piece);
      offset += piece.length;
    }
    return Pcm(rendered, sampleRate: originalPcm.sampleRate);
  }

  PracticeExportAudio renderExportStep(PracticeStep step, Pcm originalPcm) {
    final pcm = _renderRepeatedStep(step, originalPcm);
    return PracticeExportAudio(
      pcm: pcm,
      totalDurationMs: step.totalDurationMs,
      silenceGapsMs: const [],
    );
  }

  PracticeExportAudio renderMergedExport(
    List<PracticeStep> steps,
    Pcm originalPcm,
  ) {
    if (steps.isEmpty) {
      throw ArgumentError('export steps 不可為空');
    }

    final pieces = <Int16List>[];
    final silenceGapsMs = <int>[];
    var totalSamples = 0;
    var totalDurationMs = 0;

    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      final stepPcm = _renderRepeatedStep(step, originalPcm);
      pieces.add(stepPcm.samples);
      totalSamples += stepPcm.samples.length;
      totalDurationMs += step.totalDurationMs;

      if (i < steps.length - 1) {
        final gapMs = step.totalDurationMs;
        final gapSamples = _sampleCountForMs(gapMs, originalPcm.sampleRate);
        pieces.add(Int16List(gapSamples));
        totalSamples += gapSamples;
        totalDurationMs += gapMs;
        silenceGapsMs.add(gapMs);
      }
    }

    final merged = Int16List(totalSamples);
    var offset = 0;
    for (final piece in pieces) {
      merged.setRange(offset, offset + piece.length, piece);
      offset += piece.length;
    }

    return PracticeExportAudio(
      pcm: Pcm(merged, sampleRate: originalPcm.sampleRate),
      totalDurationMs: totalDurationMs,
      silenceGapsMs: silenceGapsMs,
    );
  }

  PracticeStep singleSyllableStep(Syllable syllable) {
    return PracticeStep(
      index: 1,
      syllables: [syllable],
      sourceRanges: [syllable.range],
      totalDurationMs: syllable.range.durationMs,
    );
  }

  Pcm _renderRepeatedStep(PracticeStep step, Pcm originalPcm) {
    final once = renderStep(step, originalPcm);
    final repeatCount = _repeatCountFor(step);
    if (repeatCount == 1) {
      return once;
    }

    final samples = Int16List(once.samples.length * repeatCount);
    var offset = 0;
    for (var i = 0; i < repeatCount; i++) {
      samples.setRange(offset, offset + once.samples.length, once.samples);
      offset += once.samples.length;
    }
    return Pcm(samples, sampleRate: once.sampleRate);
  }

  int _repeatCountFor(PracticeStep step) {
    final singleDurationMs =
        step.sourceRanges.fold<int>(0, (sum, range) => sum + range.durationMs);
    if (singleDurationMs <= 0) {
      throw ArgumentError('PracticeStep sourceRanges duration 必須大於 0');
    }
    if (step.totalDurationMs % singleDurationMs != 0) {
      throw ArgumentError(
          'PracticeStep.totalDurationMs 必須為 sourceRanges 時長的整數倍');
    }
    return step.totalDurationMs ~/ singleDurationMs;
  }

  int _sampleCountForMs(int durationMs, int sampleRate) =>
      (durationMs * sampleRate) ~/ 1000;

  void _validateRepeatN(int repeatN) {
    if (repeatN < minRepeatN || repeatN > maxRepeatN) {
      throw const DomainException(
        ErrorCodes.repeatNOutOfRange,
        '重複次數須為 1–10',
      );
    }
  }

  List<TimeRange> _mergeAdjacentRanges(Iterable<TimeRange> ranges) {
    final merged = <TimeRange>[];
    for (final range in ranges) {
      if (merged.isNotEmpty && merged.last.endMs == range.startMs) {
        final previous = merged.removeLast();
        merged.add(TimeRange(previous.startMs, range.endMs));
      } else {
        merged.add(range);
      }
    }
    return List.unmodifiable(merged);
  }

  bool _needsBoundaryFade(Pcm pcm, int boundaryMs) {
    final nearest = findNearestZeroCrossingMs(pcm, targetMs: boundaryMs);
    return nearest != boundaryMs || !_isExactZeroCrossing(pcm, boundaryMs);
  }

  bool _isExactZeroCrossing(Pcm pcm, int boundaryMs) {
    final index = pcm.sampleIndexAtMs(boundaryMs);
    if (index <= 0 || index >= pcm.samples.length) {
      return false;
    }
    final previous = pcm.samples[index - 1];
    final current = pcm.samples[index];
    return previous == 0 ||
        current == 0 ||
        (previous < 0 && current > 0) ||
        (previous > 0 && current < 0);
  }

  void _applySegmentEdgeFade(
    Int16List segment, {
    required int sampleRate,
    required bool fadeIn,
    required bool fadeOut,
  }) {
    if (segment.isEmpty) {
      return;
    }
    final maxFadeSamples =
        ((kZeroCrossingSearchWindowMs * sampleRate) / 1000).ceil();
    final fadeSamples = maxFadeSamples < segment.length ~/ 2
        ? maxFadeSamples
        : segment.length ~/ 2;
    if (fadeSamples <= 0) {
      return;
    }

    if (fadeIn) {
      for (var i = 0; i < fadeSamples; i++) {
        segment[i] = (segment[i] * i / fadeSamples).round();
      }
    }
    if (fadeOut) {
      final start = segment.length - fadeSamples;
      for (var i = 0; i < fadeSamples; i++) {
        segment[start + i] =
            (segment[start + i] * (fadeSamples - i - 1) / fadeSamples).round();
      }
    }
  }
}
