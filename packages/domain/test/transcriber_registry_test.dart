// AI-Generate
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('TranscriberRegistry（AT-17-02／AT-17-03）', () {
    test('AT-17-02：已註冊 en 時可解析，且公開集合不可變', () {
      final english = _FakeTranscriberEngine(
        engineName: 'local-whisper',
        supportedLanguages: const {'en'},
      );
      final registry = TranscriberRegistry([english]);

      expect(registry.resolve('en'), same(english));
      expect(registry.registeredLanguages, {'en'});
      expect(
        () => registry.registeredLanguages.add('ja'),
        throwsUnsupportedError,
      );
    });

    test('AT-17-03：未註冊語言 fail-closed，錯誤列出已註冊語言', () {
      final registry = TranscriberRegistry([
        _FakeTranscriberEngine(
          engineName: 'local-whisper',
          supportedLanguages: const {'en'},
        ),
      ]);

      expect(
        () => registry.resolve('ja'),
        throwsA(
          isA<DomainException>()
              .having(
                  (error) => error.code, 'code', ErrorCodes.languageUnsupported)
              .having((error) => error.message, 'message', contains('en'))
              .having((error) => error.message, 'message', contains('ja')),
        ),
      );
    });
  });
}

class _FakeTranscriberEngine implements TranscriberEngine {
  @override
  final String engineName;

  @override
  final Set<String> supportedLanguages;

  _FakeTranscriberEngine({
    required this.engineName,
    required Set<String> supportedLanguages,
  }) : supportedLanguages = Set.unmodifiable(supportedLanguages);

  @override
  Future<List<Segment>> segment(
    Pcm pcm, {
    required String language,
  }) async =>
      const [];

  @override
  Future<List<Word>> transcribe(
    Pcm pcm, {
    required String language,
    String? transcript,
  }) async {
    expect(pcm.samples, isA<Int16List>());
    return const [];
  }
}
