// AI-Generate
import 'dart:typed_data';

import '../alignment/zero_crossing.dart';
import '../errors.dart';
import '../model/pcm.dart';
import '../model/practice_arrangement.dart';
import '../model/practice_step.dart';
import '../model/practice_units.dart';
import '../model/syllable.dart';
import '../model/time_range.dart';
import 'practice_export_audio.dart';

/// PracticeEngine（backend-design.md §3.2.2）。
/// M2：步數等於音節數；第 n 步為句尾倒數 n 個音節，不做單字邊界吸附。
class PracticeEngine {
  static const minRepeatN = 1;
  static const maxRepeatN = 10;

  /// 依句尾疊加規則建立可自由編輯的初始排列（backend-design.md 介面 27）。
  PracticeArrangement generateArrangement(
    List<Syllable> syllables, {
    required String lessonId,
    required DateTime updatedAt,
  }) {
    final rows = List.generate(syllables.length, (offset) {
      final suffix = syllables.sublist(syllables.length - offset - 1);
      return PracticeRow(
        index: offset + 1,
        blocks: suffix
            .map((syllable) => PracticeBlock(syllables: [syllable]))
            .toList(growable: false),
      );
    });
    return PracticeArrangement(
      lessonId: lessonId,
      rows: rows,
      updatedAt: updatedAt,
    );
  }

  /// M12 的唯一完整單句／自訂排列判定入口（backend-design.md 介面 30）。
  PracticeUnits effectiveUnits(
    List<Syllable> syllables, {
    required TimeRange fullSentenceRange,
    PracticeArrangement? arrangement,
  }) {
    if (syllables.isEmpty) {
      throw ArgumentError('effectiveUnits.syllables 不可為空');
    }
    if (arrangement == null || arrangement.rows.isEmpty) {
      final step = PracticeStep(
        index: 1,
        syllables: syllables,
        sourceRanges: [fullSentenceRange],
        totalDurationMs: fullSentenceRange.durationMs,
      );
      return PracticeUnits(
        mode: PracticeMode.wholeSentence,
        units: [WholeSentencePracticeUnit(step)],
        stale: false,
      );
    }
    return PracticeUnits(
      mode: PracticeMode.custom,
      units:
          arrangement.rows.map(CustomPracticeUnit.new).toList(growable: false),
      stale: arrangement.staleFlag,
    );
  }

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

    // AT-15-15：同一句中首尾相接的音節先視為一段原音切片，避免每個
    // 音節交界都套 fade 而產生可聽見的瞬間截斷。
    final sourceRanges = _mergeAdjacentRanges(step.sourceRanges);
    for (final range in sourceRanges) {
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

  /// 渲染單列自訂排列（backend-design.md 介面 29；REQ-15/M1/M3）。
  ///
  /// 每塊只走既有 [renderStep] 原聲切片路徑，再依設定重複並接數位零
  /// 靜音；[row] 是本次播放的 immutable 快照，不會讀取後續排列狀態。
  Future<Pcm> renderBlockRow(PracticeRow row, Pcm originalPcm) async {
    final inner = _renderRowInner(row, originalPcm);
    return _applyOuterConfig(
      inner,
      sourceDurationMs: row.sourceDurationMs,
      repeatN: row.repeatN,
      silenceFactor: row.silenceFactor,
    );
  }

  Pcm _renderRowInner(PracticeRow row, Pcm originalPcm) {
    final snapshot = List<PracticeBlock>.of(row.blocks);
    final pieces = <Int16List>[];
    var totalSamples = 0;

    for (final block in snapshot) {
      final step = PracticeStep(
        index: row.index,
        syllables: block.syllables,
        sourceRanges: block.sourceRanges,
        totalDurationMs: block.sourceDurationMs,
      );
      final once = renderStep(step, originalPcm);
      final silenceSamples = _sampleCountForMs(
        block.silenceDurationMs,
        originalPcm.sampleRate,
      );
      for (var repeat = 0; repeat < block.repeatN; repeat++) {
        pieces.add(once.samples);
        totalSamples += once.samples.length;
        if (silenceSamples > 0) {
          pieces.add(Int16List(silenceSamples));
          totalSamples += silenceSamples;
        }
      }
    }

    final rendered = Int16List(totalSamples);
    var offset = 0;
    for (final piece in pieces) {
      rendered.setRange(offset, offset + piece.length, piece);
      offset += piece.length;
    }
    return Pcm(rendered, sampleRate: originalPcm.sampleRate);
  }

  Pcm _applyOuterConfig(
    Pcm inner, {
    required int sourceDurationMs,
    required int repeatN,
    required double silenceFactor,
  }) {
    final config = PracticeUnitExportConfig(
      repeatN: repeatN,
      silenceFactor: silenceFactor,
    )..validate();
    final silenceMs = (sourceDurationMs * config.silenceFactor).round();
    final silenceSamples = _sampleCountForMs(silenceMs, inner.sampleRate);
    final totalSamples = inner.samples.length * config.repeatN +
        silenceSamples * (config.repeatN - 1);
    final rendered = Int16List(totalSamples);
    var offset = 0;
    for (var repeat = 0; repeat < config.repeatN; repeat++) {
      rendered.setRange(offset, offset + inner.samples.length, inner.samples);
      offset += inner.samples.length;
      if (repeat < config.repeatN - 1 && silenceSamples > 0) {
        offset += silenceSamples;
      }
    }
    return Pcm(rendered, sampleRate: inner.sampleRate);
  }

  /// 組裝一或多個 custom 單元供匯出（REQ-16；M1/M3 自訂軌）。
  Future<PracticeExportAudio> renderCustomExport(
    List<PracticeRow> rows,
    Pcm originalPcm,
  ) async {
    if (rows.isEmpty) {
      throw ArgumentError('custom export rows 不可為空');
    }
    return renderUnitsExport(
      PracticeUnits(
        mode: PracticeMode.custom,
        units: rows.map(CustomPracticeUnit.new).toList(growable: false),
        stale: false,
      ),
      originalPcm,
    );
  }

  /// 依單元快照與本次覆寫組裝匯出 PCM（REQ-16 AT-16-05/08）。
  ///
  /// 覆寫只取代 whole sentence／row 外層，積木內層不變；多單元之間
  /// 仍依 M3 插入前一個已渲染單元的完整時長，最後單元後不插入。
  Future<PracticeExportAudio> renderUnitsExport(
    PracticeUnits effective,
    Pcm originalPcm, {
    Map<int, PracticeUnitExportConfig> overrides = const {},
  }) async {
    if (effective.units.isEmpty) {
      throw ArgumentError('export units 不可為空');
    }
    final pieces = <Int16List>[];
    final silenceGapsMs = <int>[];
    var totalSamples = 0;
    for (var index = 0; index < effective.units.length; index++) {
      final unit = effective.units[index];
      final override = overrides[unit.index];
      override?.validate();
      final rendered = switch (unit) {
        AutoPracticeUnit(:final step) => _renderRepeatedStep(step, originalPcm),
        WholeSentencePracticeUnit(
          :final step,
          :final repeatN,
          :final silenceFactor,
        ) =>
          _applyOuterConfig(
            renderStep(step, originalPcm),
            sourceDurationMs: step.sourceRanges.fold(
              0,
              (total, range) => total + range.durationMs,
            ),
            repeatN: override?.repeatN ?? repeatN,
            silenceFactor: override?.silenceFactor ?? silenceFactor,
          ),
        CustomPracticeUnit(:final row) => _applyOuterConfig(
            _renderRowInner(row, originalPcm),
            sourceDurationMs: row.sourceDurationMs,
            repeatN: override?.repeatN ?? row.repeatN,
            silenceFactor: override?.silenceFactor ?? row.silenceFactor,
          ),
      };
      pieces.add(rendered.samples);
      totalSamples += rendered.samples.length;

      if (index < effective.units.length - 1) {
        final gapMs = _durationMsForSamples(
          rendered.samples.length,
          rendered.sampleRate,
        );
        final gapSamples = _sampleCountForMs(gapMs, originalPcm.sampleRate);
        pieces.add(Int16List(gapSamples));
        totalSamples += gapSamples;
        silenceGapsMs.add(gapMs);
      }
    }
    final samples = Int16List(totalSamples);
    var offset = 0;
    for (final piece in pieces) {
      samples.setRange(offset, offset + piece.length, piece);
      offset += piece.length;
    }
    return PracticeExportAudio(
      pcm: Pcm(samples, sampleRate: originalPcm.sampleRate),
      totalDurationMs: _durationMsForSamples(
        totalSamples,
        originalPcm.sampleRate,
      ),
      silenceGapsMs: silenceGapsMs,
    );
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

  int _durationMsForSamples(int sampleCount, int sampleRate) =>
      (sampleCount * 1000) ~/ sampleRate;

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
