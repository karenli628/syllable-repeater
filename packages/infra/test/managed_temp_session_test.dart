// AI-Generate
import 'dart:io';

import 'package:infra/infra.dart';
import 'package:test/test.dart';

void main() {
  group('ManagedTempSession（AT-10-07／guardrails #62）', () {
    test('啟動清除未鎖定舊 session，但不碰另一個仍存活 session', () async {
      final root = await Directory.systemTemp.createTemp('managed-temp-root-');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final stale = Directory('${root.path}/session-stale')
        ..createSync(recursive: true);
      File('${stale.path}/.lease').writeAsStringSync('stale');
      File('${stale.path}/old.wav').writeAsBytesSync([1, 2, 3]);

      final first = await ManagedTempSession.start(rootDirectory: root);
      final second = await ManagedTempSession.start(rootDirectory: root);

      expect(stale.existsSync(), isFalse);
      expect(first.directory.existsSync(), isTrue,
          reason: '檔案鎖保護仍在執行的 session');
      await second.dispose();
      expect(second.directory.existsSync(), isFalse);
      await first.dispose();
    });

    test('operation 與 session 清理不會刪除使用者保存檔', () async {
      final root = await Directory.systemTemp.createTemp('managed-temp-root-');
      final userDir = await Directory.systemTemp.createTemp('user-pack-root-');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
        if (await userDir.exists()) await userDir.delete(recursive: true);
      });
      final userPack = File('${userDir.path}/lesson.abopack')
        ..writeAsBytesSync([9, 8, 7]);
      final session = await ManagedTempSession.start(rootDirectory: root);
      final operations = <Directory>[];
      for (var index = 0; index < 20; index++) {
        final operation = await session.createOperationDirectory('whisper');
        File('${operation.path}/input-$index.wav').writeAsBytesSync([index]);
        operations.add(operation);
      }

      for (final operation in operations) {
        await session.deleteOperationDirectory(operation);
        expect(operation.existsSync(), isFalse);
      }
      expect(userPack.readAsBytesSync(), [9, 8, 7]);

      await session.dispose();
      expect(userPack.readAsBytesSync(), [9, 8, 7]);
    });
  });
}
