// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/shared/error/error_messages.dart';

void main() {
  test('AT-11-08 v1.1 26 個現行錯誤碼均有非未知 UI 文案映射', () {
    expect(ErrorMessages.mappedCodeCount, 26);
    for (final code in ErrorCodes.all) {
      expect(
        ErrorMessages.fromCode(code).title,
        isNot('發生未知錯誤'),
        reason: '$code 必須有 frontend-design 功能點 8 的映射',
      );
    }
  });
}
