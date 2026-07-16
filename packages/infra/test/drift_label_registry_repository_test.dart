// AI-Generate
// DriftLabelRegistryRepository：REQ-11/OQ-6 標籤索引持久化測試。
import 'package:domain/domain.dart' as domain;
import 'package:drift/native.dart';
import 'package:infra/infra.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftLabelRegistryRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftLabelRegistryRepository(db);
  });

  tearDown(() => db.close());

  test('AT-11-03 查無指紋時回傳 null', () async {
    expect(await repository.findByFingerprint('sha256-missing'), isNull);
  });

  test('AT-11-03 upsert 後可依音檔指紋讀回四欄索引', () async {
    final updatedAt = DateTime.utc(2026, 7, 13, 9, 30);

    await repository.upsert(
      domain.LabelRegistryRecord(
        audioFingerprint: 'sha256-audio-a',
        labelPath: '/labels/audio-a.abolabel',
        segmentCount: 12,
        updatedAt: updatedAt,
      ),
    );

    final loaded = await repository.findByFingerprint('sha256-audio-a');
    expect(loaded?.audioFingerprint, 'sha256-audio-a');
    expect(loaded?.labelPath, '/labels/audio-a.abolabel');
    expect(loaded?.segmentCount, 12);
    expect(loaded?.updatedAt, updatedAt);
  });

  test('AT-11-03 同指紋再次 upsert 只更新既有 row', () async {
    final first = DateTime.utc(2026, 7, 13, 9, 30);
    final second = DateTime.utc(2026, 7, 13, 9, 40);
    await repository.upsert(
      domain.LabelRegistryRecord(
        audioFingerprint: 'sha256-audio-a',
        labelPath: '/labels/old.abolabel',
        segmentCount: 8,
        updatedAt: first,
      ),
    );

    await repository.upsert(
      domain.LabelRegistryRecord(
        audioFingerprint: 'sha256-audio-a',
        labelPath: '/labels/new.abolabel',
        segmentCount: 11,
        updatedAt: second,
      ),
    );

    final rows = await db.select(db.labelRegistry).get();
    expect(rows, hasLength(1));
    expect(rows.single.labelPath, '/labels/new.abolabel');
    expect(rows.single.segmentCount, 11);
    expect(rows.single.updatedAt, second.millisecondsSinceEpoch);
  });
}
