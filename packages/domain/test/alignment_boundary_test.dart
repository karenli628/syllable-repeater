// AI-Generate
// updateSyllableBoundary + zero-crossing 吸附 單元測試（task-split 3.6/3.7）。
// 對應 requirement §3.2.7 REQ-02 AT-02-01/02/05 + 邊界越界 argument 檢查。
// AT-02-03（連續拖動）與 AT-02-04（undo）由 UI 端 controller 測試涵蓋。
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

Matcher _domainError(String code) =>
    throwsA(isA<DomainException>().having((e) => e.code, 'code', code));

/// 生成靜態 PCM——全 non-zero 同號，無 zero-crossing。
Pcm _flatPcm({int seconds = 3, int value = 100}) {
  final samples = Int16List(44100 * seconds);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = value;
  }
  return Pcm(samples);
}

/// 在指定 ms 位置放單一 zero-crossing（前為 +100，後為 -100）。
Pcm _zeroCrossingAt(int ms, {int seconds = 3}) {
  final samples = Int16List(44100 * seconds);
  final crossIdx = (ms * 44100) ~/ 1000;
  for (var i = 0; i < samples.length; i++) {
    samples[i] = i < crossIdx ? 100 : -100;
  }
  return Pcm(samples);
}

/// 6 音節樣本（idx 0..5，邊界 idx 0..4）；idx 2 分開 ex / cel（原邊界 600ms）。
List<Syllable> _sample() => [
      Syllable(
          text: 'she',
          startMs: 0,
          endMs: 200,
          wordIndex: 0,
          needsReview: false),
      Syllable(
          text: 'has',
          startMs: 200,
          endMs: 400,
          wordIndex: 1,
          needsReview: false),
      Syllable(
          text: 'ex',
          startMs: 400,
          endMs: 600,
          wordIndex: 2,
          needsReview: true),
      Syllable(
          text: 'cel',
          startMs: 600,
          endMs: 800,
          wordIndex: 2,
          needsReview: true),
      Syllable(
          text: 'lent',
          startMs: 800,
          endMs: 1000,
          wordIndex: 2,
          needsReview: true),
      Syllable(
          text: 'com',
          startMs: 1000,
          endMs: 1200,
          wordIndex: 3,
          needsReview: true),
    ];

void main() {
  group('updateSyllableBoundary（task-split 3.6，介面 2）', () {
    test('AT-02-02 拖越前一音節起點 → ERR_BOUNDARY_INVALID', () {
      final engine = AlignmentEngine();
      final pcm = _flatPcm();
      final syllables = _sample();
      // boundary idx 2 分開 ex/cel；ex.startMs=400；拖至 350 越 ex 起點
      expect(
        () => engine.updateSyllableBoundary(
          current: syllables,
          boundaryIndex: 2,
          newPositionMs: 350,
          pcm: pcm,
        ),
        _domainError(ErrorCodes.boundaryInvalid),
      );
    });

    test('AT-02-05 拖至等於後一音節 endMs（閉端）→ ERR_BOUNDARY_INVALID', () {
      final engine = AlignmentEngine();
      final pcm = _flatPcm();
      final syllables = _sample();
      // boundary idx 2；後音節 cel.endMs=800；拖至 800（開區間拒絕）
      expect(
        () => engine.updateSyllableBoundary(
          current: syllables,
          boundaryIndex: 2,
          newPositionMs: 800,
          pcm: pcm,
        ),
        _domainError(ErrorCodes.boundaryInvalid),
      );
    });

    test(
        'AT-02-01 拖至 640ms、zero-crossing @650ms → snappedMs=650 且落點差 ≤10ms',
        () {
      final engine = AlignmentEngine();
      final pcm = _zeroCrossingAt(650);
      final syllables = _sample();
      final result = engine.updateSyllableBoundary(
        current: syllables,
        boundaryIndex: 2,
        newPositionMs: 640,
        pcm: pcm,
      );
      expect(result.snappedMs, 650);
      expect((result.snappedMs - 640).abs(), lessThanOrEqualTo(10));
    });

    test('被改邊界左右兩音節 needsReview=false（AT-02-01 尾段）', () {
      final engine = AlignmentEngine();
      final pcm = _flatPcm();
      final syllables = _sample();
      final result = engine.updateSyllableBoundary(
        current: syllables,
        boundaryIndex: 2,
        newPositionMs: 650,
        pcm: pcm,
      );
      // idx 2 (ex) 與 idx 3 (cel) needsReview → false
      expect(result.syllables[2].needsReview, isFalse);
      expect(result.syllables[3].needsReview, isFalse);
      // 其他音節 needsReview 不動
      expect(result.syllables[4].needsReview, isTrue,
          reason: 'lent 未被改，needsReview 保留原值');
      expect(result.syllables[5].needsReview, isTrue,
          reason: 'com 未被改');
    });

    test('回傳 syllables 依時間單調遞增、互不重疊', () {
      final engine = AlignmentEngine();
      final pcm = _flatPcm();
      final result = engine.updateSyllableBoundary(
        current: _sample(),
        boundaryIndex: 2,
        newPositionMs: 700,
        pcm: pcm,
      );
      for (var i = 0; i < result.syllables.length - 1; i++) {
        expect(result.syllables[i].endMs, result.syllables[i + 1].startMs,
            reason: '相鄰音節端點相接（M2 疊加語意）');
      }
    });

    test('無 zero-crossing 在 ±10ms 內 → snappedMs=newPositionMs（不吸附）', () {
      final engine = AlignmentEngine();
      final pcm = _flatPcm();
      final result = engine.updateSyllableBoundary(
        current: _sample(),
        boundaryIndex: 2,
        newPositionMs: 660,
        pcm: pcm,
      );
      expect(result.snappedMs, 660);
    });

    test('boundaryIndex 越界 → ArgumentError', () {
      final engine = AlignmentEngine();
      final pcm = _flatPcm();
      final syllables = _sample();
      expect(
          () => engine.updateSyllableBoundary(
                current: syllables,
                boundaryIndex: -1,
                newPositionMs: 500,
                pcm: pcm,
              ),
          throwsA(isA<ArgumentError>()));
      expect(
          () => engine.updateSyllableBoundary(
                current: syllables,
                boundaryIndex: syllables.length - 1,
                newPositionMs: 500,
                pcm: pcm,
              ),
          throwsA(isA<ArgumentError>()));
    });
  });

  group('zero-crossing 純函式（task-split 3.7）', () {
    test('對稱搜尋 ≤±10ms（±441 sample @44.1kHz）', () {
      final pcm = _zeroCrossingAt(1000);
      // 從 990ms 找 → 找到 1000（+10ms 內）
      final result = findNearestZeroCrossingMs(pcm, targetMs: 990);
      expect(result, 1000);
      // 從 1005ms 找 → 也找到 1000（-5ms 內）
      expect(findNearestZeroCrossingMs(pcm, targetMs: 1005), 1000);
    });

    test('目標點本身即 zero-crossing → 回傳原值', () {
      final pcm = _zeroCrossingAt(500);
      expect(findNearestZeroCrossingMs(pcm, targetMs: 500), 500);
    });

    test('±10ms 外無 zero-crossing → 回傳原 targetMs 不吸附', () {
      final pcm = _zeroCrossingAt(500);
      // 從 520ms 找（距 500 20ms） → 超出 ±10 → 回傳 520
      expect(findNearestZeroCrossingMs(pcm, targetMs: 520), 520);
    });

    test('near boundary at start / end 不 crash（邊界 clamp）', () {
      final pcm = _flatPcm();
      expect(() => findNearestZeroCrossingMs(pcm, targetMs: 0), returnsNormally);
      expect(
          () => findNearestZeroCrossingMs(pcm, targetMs: pcm.durationMs),
          returnsNormally);
    });
  });
}
