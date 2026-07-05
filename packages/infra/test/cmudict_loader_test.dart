// AI-Generate
import 'dart:io';

import 'package:infra/infra.dart';
import 'package:test/test.dart';

void main() {
  test('CmuDictLoader 從檔案載入 CMUdict lines', () async {
    final dir = await Directory.systemTemp.createTemp('cmudict-test-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/cmudict.dict')..writeAsStringSync('''
;;; comment
HELLO  HH AH0 L OW1
WORLD  W ER1 L D
''');

    final dict = const CmuDictLoader().load(file.path);

    expect(dict.lookup('hello')?.syllableCount, 2);
    expect(dict.lookup('world')?.syllableCount, 1);
  });

  test('CmuDictLoader 找不到檔案時明確失敗', () {
    expect(
      () => const CmuDictLoader().load('/tmp/not-exists-cmudict.dict'),
      throwsA(isA<FileSystemException>()),
    );
  });
}
