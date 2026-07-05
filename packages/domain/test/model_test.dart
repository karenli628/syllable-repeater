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

  test('ErrorCodes 與 backend-design §3.2.8 對應（17 碼抽查）', () {
    expect(ErrorCodes.sidecarCrashed, 'ERR_SIDECAR_CRASHED');
    expect(ErrorCodes.archiveRestoreExpired, 'ERR_ARCHIVE_RESTORE_EXPIRED');
  });
}
