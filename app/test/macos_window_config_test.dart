// AI-Generate
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('frontend-design：macOS 視窗最小內容尺寸固定為 1100x700', () {
    final source = File(
      'macos/Runner/MainFlutterWindow.swift',
    ).readAsStringSync();

    expect(source, contains('contentMinSize = NSSize(width: 1100, height: 700)'));
  });
}
