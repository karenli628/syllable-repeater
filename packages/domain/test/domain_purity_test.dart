// AI-Generate
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Domain purity（task-split 8.1 / CT-05 / AT-09-02）', () {
    test('lib 不 import Flutter、infra、sidecar 實作或平台 API', () {
      final root = _domainPackageRoot();
      final libDir = Directory(_join(root.path, 'lib'));

      final violations = <String>[];
      for (final file in _dartFilesUnder(libDir)) {
        final relativePath = _relativeTo(file.path, root.path);
        final lines = file.readAsLinesSync();

        for (var i = 0; i < lines.length; i++) {
          final uri = _importOrExportUri(lines[i]);
          if (uri == null) {
            continue;
          }

          final reason = _forbiddenImportReason(uri);
          if (reason != null) {
            violations.add('$relativePath:${i + 1} imports $uri ($reason)');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'M5 要求 packages/domain/lib/** 維持純 Dart，違規清單：$violations',
      );
    });

    test('pubspec 不宣告 Flutter、infra 或 sidecar 依賴', () {
      final root = _domainPackageRoot();
      final pubspec = File(_join(root.path, 'pubspec.yaml')).readAsLinesSync();
      final violations = <String>[];

      for (var i = 0; i < pubspec.length; i++) {
        final reason = _forbiddenPubspecReason(pubspec[i]);
        if (reason != null) {
          violations.add('pubspec.yaml:${i + 1} $reason');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'M5 要求 domain 依賴白名單不可混入 UI / infra / sidecar：$violations',
      );
    });

    test('防線能辨識 AT-09-02 的違規匯入範例', () {
      expect(
        _forbiddenImportReason('package:flutter/material.dart'),
        isNotNull,
      );
      expect(_forbiddenImportReason('package:infra/infra.dart'), isNotNull);
      expect(_forbiddenImportReason('dart:io'), isNotNull);
      expect(
          _forbiddenImportReason('../sidecar/sidecar_runner.dart'), isNotNull);
    });
  });
}

Directory _domainPackageRoot() {
  final current = Directory.current;
  final currentPubspec = File(_join(current.path, 'pubspec.yaml'));
  if (currentPubspec.existsSync() &&
      currentPubspec.readAsStringSync().contains('name: domain')) {
    return current;
  }

  final workspaceCandidate = Directory(_join(current.path, 'packages/domain'));
  final workspacePubspec = File(_join(workspaceCandidate.path, 'pubspec.yaml'));
  if (workspacePubspec.existsSync() &&
      workspacePubspec.readAsStringSync().contains('name: domain')) {
    return workspaceCandidate;
  }

  throw StateError(
      '找不到 packages/domain 根目錄；請在 workspace 根或 packages/domain 內執行測試。');
}

Iterable<File> _dartFilesUnder(Directory directory) sync* {
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}

String? _importOrExportUri(String line) {
  final match =
      RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''').firstMatch(line);
  return match?.group(1);
}

String? _forbiddenImportReason(String uri) {
  if (uri == 'dart:io') {
    return '禁止直接依賴平台 IO；請走 FileIo 抽象';
  }
  if (uri == 'dart:ffi' ||
      uri == 'dart:html' ||
      uri == 'dart:js' ||
      uri == 'dart:js_util') {
    return '禁止在 Domain 綁定特定平台 API';
  }
  if (uri.startsWith('package:flutter/')) {
    return '禁止 Domain 依賴 Flutter UI 層';
  }
  if (uri.startsWith('package:infra/')) {
    return '禁止 Domain 反向依賴 infra 轉接層';
  }
  if (uri.contains('/sidecar/') ||
      uri.startsWith('sidecar/') ||
      uri.contains('sidecar_runner') ||
      uri.contains('ffmpeg_decoder') ||
      uri.contains('whisper_transcriber')) {
    return '禁止 Domain 匯入 sidecar 實作';
  }
  return null;
}

String? _forbiddenPubspecReason(String line) {
  if (RegExp(r'^\s*flutter\s*:').hasMatch(line)) {
    return '宣告了 flutter 依賴';
  }
  if (RegExp(r'^\s*infra\s*:').hasMatch(line)) {
    return '宣告了 infra 依賴';
  }
  if (line.contains('../infra') || line.contains('packages/infra')) {
    return '指向 infra package 路徑';
  }
  if (RegExp(r'^\s*(ffmpeg|whisper|demucs|sidecar)\s*:').hasMatch(line)) {
    return '宣告了 sidecar 實作依賴';
  }
  return null;
}

String _join(String first, String second) =>
    '$first${Platform.pathSeparator}$second';

String _relativeTo(String path, String root) {
  final prefix = '$root${Platform.pathSeparator}';
  if (path.startsWith(prefix)) {
    return path.substring(prefix.length);
  }
  return path;
}
