// AI-Generate
import 'dart:io';

import 'package:path/path.dart' as p;

/// 找出 Syllable Repeater workspace 根目錄，供真 sidecar 測試定位 fixture。
Directory findRepoRoot({Directory? start}) {
  final envRoot = Platform.environment['SYLLABLE_REPEATER_DEV_ROOT'];
  if (envRoot != null && envRoot.isNotEmpty) {
    return Directory(envRoot).absolute;
  }

  var current = (start ?? Directory.current).absolute;
  while (true) {
    final pubspec = File(p.join(current.path, 'pubspec.yaml'));
    final specDir = Directory(p.join(current.path, 'spec-syllable-repeater'));
    if (pubspec.existsSync() && specDir.existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError(
        '找不到 syllable_repeater_workspace 根目錄：${Directory.current.path}',
      );
    }
    current = parent;
  }
}

/// 回傳 `.local-tools/fixtures/` 內指定音檔。
File fixtureAudio(String fileName, {Directory? root}) => File(
      p.join(
        (root ?? findRepoRoot()).path,
        '.local-tools',
        'fixtures',
        fileName,
      ),
    );
