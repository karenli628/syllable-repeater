// AI-Generate
// 自訂排列音訊路徑 TDD-red（REQ-15、M1/M3、guardrails #42）。
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('PracticeEngine.renderBlockRow（backend-design.md 介面 29）', () {
    test('AT-15-05 rain/think 先套積木再套整列，最後無整列靜音', () async {
      final pcm = _rainThinkPcm();
      final rendered = await PracticeEngine().renderBlockRow(
        _rainThinkRow(),
        pcm,
      );

      expect(rendered.sampleRate, 1000);
      expect(rendered.samples, hasLength(95500));
      _expectSilence(rendered, 1500, 4500, label: 'rain 第 1 輪 2 倍靜音');
      _expectSilence(rendered, 89500, 95500, label: '最後保留 think 積木靜音');
      _expectSilence(rendered, 29500, 33000, label: '第 1 次整列後 1 倍靜音');
      _expectSilence(rendered, 62500, 66000, label: '第 2 次整列後 1 倍靜音');
      expect(rendered.samples.last, 0, reason: '最後是積木靜音，不是額外整列靜音');
    });

    test('AT-15-09 非端點 sample 逐段對應回同一份原 PCM', () async {
      final original = _sourcePcm();
      final before = Int16List.fromList(original.samples);
      final rendered = await PracticeEngine().renderBlockRow(
        _configuredRow(),
        original,
      );

      for (final startMs in [0, 1800, 3600]) {
        _expectOriginalSegment(
          rendered: rendered,
          renderedStartMs: startMs,
          original: original,
          range: TimeRange(0, 300),
        );
      }
      for (final startMs in [5400, 7500, 9600, 11700]) {
        _expectOriginalSegment(
          rendered: rendered,
          renderedStartMs: startMs,
          original: original,
          range: TimeRange(300, 650),
        );
      }
      for (final startMs in [13800, 16400, 19000, 21600]) {
        _expectOriginalSegment(
          rendered: rendered,
          renderedStartMs: startMs,
          original: original,
          range: TimeRange(0, 300),
        );
        _expectOriginalSegment(
          rendered: rendered,
          renderedStartMs: startMs + 300,
          original: original,
          range: TimeRange(300, 650),
        );
      }
      expect(original.samples, before, reason: 'M1 渲染不可回寫原 PCM');
    });

    test('AT-15-11 aftern+oon 成組 3 次為 [afternoon]×3', () async {
      final original = _afternoonPcm();
      final row = PracticeRow(
        index: 1,
        repeatN: 1,
        silenceFactor: 0,
        blocks: [
          PracticeBlock(
            syllables: [
              _syllable('aftern', 0, 120, 0),
              _syllable('oon', 120, 200, 0),
            ],
            repeatN: 3,
            silenceFactor: 0,
            isGrouped: true,
          ),
        ],
      );

      final rendered = await PracticeEngine().renderBlockRow(row, original);

      expect(rendered.samples, hasLength(600));
      for (final repeatStartMs in [0, 200, 400]) {
        _expectOriginalSegment(
          rendered: rendered,
          renderedStartMs: repeatStartMs,
          original: original,
          range: TimeRange(0, 120),
        );
        _expectOriginalSegment(
          rendered: rendered,
          renderedStartMs: repeatStartMs + 120,
          original: original,
          range: TimeRange(120, 200),
        );
      }
    });

    test('AT-15-07 呼叫後改新排列不會混入舊列快照', () async {
      final pcm = _sourcePcm();
      final originalRow = _configuredRow();
      final pending = PracticeEngine().renderBlockRow(originalRow, pcm);
      final changed = PracticeArrangement(
        lessonId: 'lesson-a',
        rows: [originalRow],
        updatedAt: _t0,
      ).removeRow(0, updatedAt: _t1);

      final rendered = await pending;

      expect(changed.rows, isEmpty);
      expect(rendered.samples, hasLength(24200), reason: '本次只能完成舊快照');
    });

    test('AT-16-08 匯出 2／1 暫時覆寫 row 3／1，不另包一層', () async {
      final row = _rainThinkRow();
      final units = PracticeUnits(
        mode: PracticeMode.custom,
        units: [CustomPracticeUnit(row)],
        stale: false,
      );

      final exported = await PracticeEngine().renderUnitsExport(
        units,
        _rainThinkPcm(),
        overrides: const {
          1: PracticeUnitExportConfig(repeatN: 2, silenceFactor: 1),
        },
      );

      expect(exported.totalDurationMs, 62500);
      expect(exported.pcm.samples, hasLength(62500));
      _expectSilence(exported.pcm, 29500, 33000,
          label: '本次匯出 row silence 只用 3500×1');
      expect(row.repeatN, 3, reason: '匯出 override 不可回寫原排列');
      expect(row.silenceFactor, 1);
    });

    test('AT-15-15 相鄰 sourceRanges 先合併，不在音節交界重複 fade', () async {
      final original = Pcm(
        Int16List.fromList(List<int>.filled(200, 1000)),
        sampleRate: 1000,
      );
      final row = PracticeRow(
        index: 1,
        repeatN: 1,
        silenceFactor: 0,
        blocks: [
          PracticeBlock(
            syllables: [
              _syllable('rain', 0, 100, 0),
              _syllable('think', 100, 200, 1),
            ],
            repeatN: 1,
            silenceFactor: 0,
            isGrouped: true,
          ),
        ],
      );

      final rendered = await PracticeEngine().renderBlockRow(row, original);

      expect(rendered.samples, hasLength(200));
      expect(rendered.samples.sublist(90, 110), everyElement(1000),
          reason: '相鄰音節 100ms 接點不可被 fade 成瞬間截斷');
    });
  });
}

PracticeRow _configuredRow() {
  final itll = _syllable('itll', 0, 300, 0);
  final rain = _syllable('rain', 300, 650, 1);
  return PracticeRow(
    index: 1,
    repeatN: 1,
    silenceFactor: 0,
    blocks: [
      PracticeBlock(syllables: [itll], repeatN: 3, silenceFactor: 5),
      PracticeBlock(
        syllables: [rain],
        repeatN: 4,
        silenceFactor: 5,
      ),
      PracticeBlock(
        syllables: [itll, rain],
        repeatN: 4,
        silenceFactor: 3,
        isGrouped: true,
      ),
    ],
  );
}

PracticeRow _rainThinkRow() => PracticeRow(
      index: 1,
      repeatN: 3,
      silenceFactor: 1,
      blocks: [
        PracticeBlock(
          syllables: [_syllable('rain', 0, 1500, 0)],
          repeatN: 3,
          silenceFactor: 2,
        ),
        PracticeBlock(
          syllables: [_syllable('think', 1500, 3500, 1)],
          repeatN: 2,
          silenceFactor: 3,
        ),
      ],
    );

Pcm _sourcePcm() {
  final samples = Int16List(650);
  for (var index = 0; index < samples.length; index++) {
    samples[index] = 1000 + index;
  }
  return Pcm(samples, sampleRate: 1000);
}

Pcm _rainThinkPcm() {
  final samples = Int16List(3500);
  for (var index = 0; index < samples.length; index++) {
    samples[index] = 1000 + (index % 20000);
  }
  return Pcm(samples, sampleRate: 1000);
}

Pcm _afternoonPcm() {
  final samples = Int16List(200);
  for (var index = 0; index < samples.length; index++) {
    samples[index] = index < 120 ? 1000 + index : -1000 - index;
  }
  return Pcm(samples, sampleRate: 1000);
}

Syllable _syllable(String text, int startMs, int endMs, int wordIndex) =>
    Syllable(
      text: text,
      startMs: startMs,
      endMs: endMs,
      wordIndex: wordIndex,
      needsReview: false,
    );

void _expectSilence(
  Pcm rendered,
  int startMs,
  int endMs, {
  required String label,
}) {
  final samples = rendered.samples.sublist(
    rendered.sampleIndexAtMs(startMs),
    rendered.sampleIndexAtMs(endMs),
  );
  expect(samples, everyElement(0), reason: '$label 必須全為數位零');
}

void _expectOriginalSegment({
  required Pcm rendered,
  required int renderedStartMs,
  required Pcm original,
  required TimeRange range,
}) {
  final fadeSamples =
      (kZeroCrossingSearchWindowMs * original.sampleRate / 1000).ceil();
  final renderedStart = rendered.sampleIndexAtMs(renderedStartMs);
  final originalStart = original.sampleIndexAtMs(range.startMs);
  final length = original.sampleIndexAtMs(range.endMs) - originalStart;
  for (var offset = fadeSamples; offset < length - fadeSamples; offset++) {
    expect(
      rendered.samples[renderedStart + offset],
      original.samples[originalStart + offset],
      reason: '${range.startMs}-${range.endMs}ms 的 sample $offset 必須來自原 PCM',
    );
  }
}

final _t0 = DateTime.utc(2026, 7, 13, 12);
final _t1 = DateTime.utc(2026, 7, 13, 12, 1);
