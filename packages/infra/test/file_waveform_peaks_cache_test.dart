// AI-Generate
// FileWaveformPeaksCache 單元測試（task-split S1b FP3 peaks 快取）。
// 走真檔案系統（tmp 目錄）驗 save→load round-trip 與毀損 miss。
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:infra/infra.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp
        .createTempSync('waveformmakeCache_test_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  FileWaveformPeaksCache makeCache() => FileWaveformPeaksCache(
        fileIo: AtomicFileIo(tempDirPath: tmp.path),
        directory: tmp.path,
      );

  test('save→load round-trip：peaks 位元組級相等', () async {
    final cache = makeCache();
    final peaks = [
      WaveformPeak(-0.5, 0.7),
      WaveformPeak(-0.9, 0.2),
      WaveformPeak(-0.1, 0.99),
    ];
    await cache.save('golden', peaks);
    final loaded = await cache.load('golden');
    expect(loaded, isNotNull);
    expect(loaded!.length, peaks.length);
    for (var i = 0; i < peaks.length; i++) {
      expect(loaded[i].min, closeTo(peaks[i].min, 1e-9));
      expect(loaded[i].max, closeTo(peaks[i].max, 1e-9));
    }
  });

  test('未存在的 key → null', () async {
    final cache = makeCache();
    expect(await cache.load('missing'), isNull);
  });

  test('毀損檔案 → 當 miss，不擲例外', () async {
    final cache = makeCache();
    final file = File(p.join(tmp.path, 'waveform-broken.json'));
    file.writeAsStringSync('{"schemaVersion":1,"peaks":"not-a-list"}');
    expect(await cache.load('broken'), isNull);
  });

  test('schemaVersion 不符 → 當 miss', () async {
    final cache = makeCache();
    final file = File(p.join(tmp.path, 'waveform-oldv.json'));
    file.writeAsStringSync('{"schemaVersion":999,"peaks":[]}');
    expect(await cache.load('oldv'), isNull);
  });

  test('key 內含斜線／空白會被 sanitize（不逃出目錄）', () async {
    final cache = makeCache();
    await cache.save('../evil path/x', [WaveformPeak(0, 0.1)]);
    // 檔案應在 tmp 內，不在 tmp 上層
    final entries = tmp.listSync().map((e) => p.basename(e.path)).toList();
    expect(entries.any((n) => n.startsWith('waveform-') && n.endsWith('.json')),
        isTrue);
    final loaded = await cache.load('../evil path/x');
    expect(loaded, isNotNull);
  });
}
