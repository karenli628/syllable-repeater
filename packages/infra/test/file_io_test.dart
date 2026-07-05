// AI-Generate
// 原子寫入防線測試（backend-design §4.2.1；AT-04-04 / AT-08-08 之基礎層）。
import 'dart:io';
import 'dart:typed_data';

import 'package:infra/infra.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory workDir;
  late AtomicFileIo io;

  setUp(() async {
    workDir = await Directory.systemTemp.createTemp('fileio_test');
    io = AtomicFileIo(tempDirPath: p.join(workDir.path, 'temp'));
  });

  tearDown(() async {
    await workDir.delete(recursive: true);
  });

  group('AtomicFileIo', () {
    test('原子寫入後可完整讀回，且目錄無暫存殘留', () async {
      final target = p.join(workDir.path, 'out.bin');
      final data = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      await io.writeBytesAtomic(target, data);

      expect(await io.readBytes(target), data);
      final leftovers = workDir
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).contains('.tmp-'));
      expect(leftovers, isEmpty, reason: '不得留下半成品暫存檔');
    });

    test('寫入不可寫目錄：拋錯且不留半成品（AT-04-04 基礎）', () async {
      final roDir = Directory(p.join(workDir.path, 'ro'))..createSync();
      Process.runSync('chmod', ['555', roDir.path]);
      addTearDown(() => Process.runSync('chmod', ['755', roDir.path]));

      final target = p.join(roDir.path, 'out.bin');
      await expectLater(
          io.writeBytesAtomic(target, Uint8List.fromList([1, 2, 3])),
          throwsA(isA<FileSystemException>()));
      expect(roDir.listSync(), isEmpty, reason: '失敗路徑不得留下任何檔案');
    });

    test('temp 檔案建立與 clearTemp 清空（M10 巡檢基礎）', () async {
      final t1 = await io.createTempFilePath('.wav');
      final t2 = await io.createTempFilePath('.wav');
      expect(t1, isNot(t2));
      await File(t1).writeAsBytes([1]);
      await File(t2).writeAsBytes([2]);

      await io.clearTemp();
      expect(Directory(io.tempDirPath).listSync(), isEmpty,
          reason: 'App 啟動清空 temp：不得殘留任何暫存（含錄音）');
    });

    test('覆寫既有檔案：內容為新值（rename 覆蓋語意）', () async {
      final target = p.join(workDir.path, 'out.bin');
      await io.writeBytesAtomic(target, Uint8List.fromList([1]));
      await io.writeBytesAtomic(target, Uint8List.fromList([2, 3]));
      expect(await io.readBytes(target), [2, 3]);
    });
  });
}
