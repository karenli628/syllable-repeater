// AI-Generate
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('TimeRange 構造驗證（backend-design §3.1.1 值物件不變式）', () {
    test('合法區間', () {
      final r = TimeRange(2650, 3150);
      expect(r.durationMs, 500);
    });

    test('start >= end 拒絕', () {
      expect(() => TimeRange(100, 100), throwsArgumentError);
      expect(() => TimeRange(200, 100), throwsArgumentError);
    });

    test('負值拒絕', () {
      expect(() => TimeRange(-1, 100), throwsArgumentError);
    });
  });

  group('Pcm 時長計算', () {
    test('44100 樣本 @44.1kHz = 1000ms', () {
      final pcm = Pcm(Int16List(44100));
      expect(pcm.durationMs, 1000);
      expect(pcm.sampleIndexAtMs(500), 22050);
    });
  });

  test('ErrorCodes 與 backend-design §3.2.8 完整 26 碼集合一致', () {
    expect(ErrorCodes.all, hasLength(26));
    expect(ErrorCodes.all.toSet(), hasLength(26));
    expect(ErrorCodes.sidecarCrashed, 'ERR_SIDECAR_CRASHED');
    expect(ErrorCodes.archiveRestoreExpired, 'ERR_ARCHIVE_RESTORE_EXPIRED');
    expect(ErrorCodes.languageUnsupported, 'ERR_LANGUAGE_UNSUPPORTED');
    expect(ErrorCodes.labelCorrupted, 'ERR_LABEL_CORRUPTED');
    expect(
      ErrorCodes.labelFingerprintMismatch,
      'ERR_LABEL_FINGERPRINT_MISMATCH',
    );
    expect(ErrorCodes.segmentTooClose, 'ERR_SEGMENT_TOO_CLOSE');
    expect(ErrorCodes.boundaryTooClose, 'ERR_BOUNDARY_TOO_CLOSE');
    expect(ErrorCodes.syllableMinCount, 'ERR_SYLLABLE_MIN_COUNT');
    expect(
      ErrorCodes.blockConfigOutOfRange,
      'ERR_BLOCK_CONFIG_OUT_OF_RANGE',
    );
  });
}
