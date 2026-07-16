// AI-Generate
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('SyllabifierRegistry（AT-17-01～AT-17-03）', () {
    test('AT-17-03：轉寫器支援 ja 但切分器缺席時仍 fail-closed', () {
      final transcribers = TranscriberRegistry([
        _FakeTranscriberEngine(
          engineName: 'bilingual-fixture',
          supportedLanguages: const {'en', 'ja'},
        ),
      ]);
      final syllabifiers = SyllabifierRegistry([EnglishSyllabifier()]);

      expect(transcribers.resolve('ja').engineName, 'bilingual-fixture');
      expect(
        () => syllabifiers.resolve('ja'),
        throwsA(
          isA<DomainException>()
              .having(
                  (error) => error.code, 'code', ErrorCodes.languageUnsupported)
              .having((error) => error.message, 'message', contains('en'))
              .having((error) => error.message, 'message', contains('ja')),
        ),
      );
    });

    test('AT-17-01：金標準經 EnglishSyllabifier 仍為 11 音節', () {
      final syllabifier = SyllabifierRegistry([
        EnglishSyllabifier(),
      ]).resolve('en');
      final syllables = <Syllable>[
        for (final word in _goldenWords)
          ...syllabifier.syllabify(word, language: 'en').syllables,
      ];

      expect(syllables, hasLength(11));
      expect(syllables, orderedEquals(_goldenSyllables));
    });
  });
}

final _goldenWords = <Word>[
  Word(text: 'She', startMs: 0, endMs: 200, index: 0),
  Word(text: 'has', startMs: 200, endMs: 400, index: 1),
  Word(text: 'excellent', startMs: 400, endMs: 1000, index: 2),
  Word(text: 'communication', startMs: 1000, endMs: 2000, index: 3),
  Word(text: 'skills', startMs: 2000, endMs: 2400, index: 4),
];

final _goldenSyllables = AlignmentEngine().alignWords(_goldenWords).syllables;

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
  }) async =>
      const [];
}
