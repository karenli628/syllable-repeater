// AI-Generate
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Transcriber policy（task-split 1.4 / #45 / #46）', () {
    test('AT-12-03 workspace 不含 TTS 依賴', () {
      final root = _workspaceRoot();
      final pubspecs = [
        File('${root.path}/pubspec.yaml'),
        File('${root.path}/app/pubspec.yaml'),
        File('${root.path}/packages/domain/pubspec.yaml'),
        File('${root.path}/packages/infra/pubspec.yaml'),
      ];
      final forbidden = RegExp(
        r'(^|\s)(flutter_tts|just_audio_tts|text_to_speech|tts|sherpa_onnx_tts)(\s|:|$)',
        caseSensitive: false,
      );

      final violations = <String>[];
      for (final pubspec in pubspecs) {
        if (!pubspec.existsSync()) {
          continue;
        }
        for (final line in pubspec.readAsLinesSync()) {
          if (forbidden.hasMatch(line)) {
            violations.add('${pubspec.path}: $line');
          }
        }
      }

      expect(violations, isEmpty, reason: 'D1 TTS 永不回歸；違規依賴：$violations');
    });

    test('AT-17-06 Domain Transcriber 契約沒有網路或 URL 欄位', () {
      final root = Directory('${_workspaceRoot().path}/packages/domain/lib');
      final violations = <String>[];
      for (final file in _dartFiles(root)) {
        final lowerName = file.path.toLowerCase();
        if (!lowerName.contains('transcrib')) {
          continue;
        }
        final content = file.readAsStringSync();
        if (RegExp(r"(?:dart:io|package:http|https?://|endpoint|baseUrl)",
                caseSensitive: false)
            .hasMatch(content)) {
          violations.add(_relativeTo(file.path, _workspaceRoot().path));
        }
      }

      expect(violations, isEmpty,
          reason: 'D7 僅本地 ASR；Domain Transcriber 不得帶 HTTP/URL：$violations');
    });
  });
}

Directory _workspaceRoot() {
  var current = Directory.current.absolute;
  while (true) {
    if (File('${current.path}/pubspec.yaml').existsSync() &&
        Directory('${current.path}/spec-syllable-repeater').existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError('找不到 workspace 根目錄：${Directory.current.path}');
    }
    current = parent;
  }
}

Iterable<File> _dartFiles(Directory root) sync* {
  if (!root.existsSync()) {
    return;
  }
  for (final entity in root.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}

String _relativeTo(String path, String root) {
  final prefix = '$root${Platform.pathSeparator}';
  return path.startsWith(prefix) ? path.substring(prefix.length) : path;
}
