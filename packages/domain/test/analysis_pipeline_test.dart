// AI-Generate
import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('AnalysisPipeline（task-split 3.4）', () {
    test('AT-17-01 v1 基線路徑保留金標準音節時間戳（容差基準 ±1ms）', () async {
      final events = await _pipeline(
        decoder: _FakeDecoder(_pcm(seconds: 3)),
        transcriber: _FakeTranscriber((pcm, language, transcript) async {
          return _goldWords;
        }),
      ).analyze(ImportRequest(audioPath: '/tmp/gold.wav')).toList();

      final syllables = events.last.result!.syllables;
      expect(syllables, hasLength(11));
      expect(
        syllables.map((syllable) => [syllable.startMs, syllable.endMs]),
        [
          [0, 200],
          [200, 400],
          [400, 600],
          [600, 800],
          [800, 1000],
          [1000, 1200],
          [1200, 1400],
          [1400, 1600],
          [1600, 1800],
          [1800, 2000],
          [2000, 2300],
        ],
      );
    });

    test('依序回報階段，完成時帶 AlignmentResult 與 waveform peaks', () async {
      final pcm = _pcm(seconds: 3);
      final decoder = _FakeDecoder(pcm);
      final transcriber =
          _FakeTranscriber((decodedPcm, language, transcript) async {
        expect(transcript, 'She has excellent communication skills');
        expect(language, 'en');
        expect(decodedPcm, same(pcm));
        return _goldWords;
      });
      final pipeline = _pipeline(decoder: decoder, transcriber: transcriber);

      final events = await pipeline
          .analyze(ImportRequest(
            audioPath: '/tmp/gold.wav',
            transcript: 'She has excellent communication skills',
            waveformBucketCount: 4,
          ))
          .toList();

      expect(events.map((e) => e.stage), [
        AnalysisStage.decoding,
        AnalysisStage.decoding,
        AnalysisStage.transcribing,
        AnalysisStage.transcribing,
        AnalysisStage.syllabifying,
        AnalysisStage.syllabifying,
        AnalysisStage.done,
      ]);
      expect(decoder.paths, ['/tmp/gold.wav']);
      expect(events.last.result!.syllables, hasLength(11));
      expect(events.last.result!.needsReview, isTrue);
      expect(events.last.waveformPeaks, hasLength(4));
      expect(events.last.error, isNull);
    });

    test('AT-12-09 M1：分離軌只供分析，done 仍分別交還原音與 analysisPcm',
        () async {
      final original = Pcm(
        Int16List.fromList(List<int>.filled(3000, 1200)),
        sampleRate: 1000,
      );
      final vocals = Pcm(
        Int16List.fromList(List<int>.filled(3000, 700)),
        sampleRate: 1000,
      );
      final transcriber =
          _FakeTranscriber((pcm, language, transcript) async {
        expect(pcm, same(vocals), reason: 'ASR 應使用人聲分離 analysisPcm');
        return _goldWords;
      });
      final pipeline = _pipeline(
        decoder: _FakeDecoder(original),
        transcriber: transcriber,
        vocalSeparator: _FakeVocalSeparator(vocals),
      );

      final events = await pipeline
          .analyze(ImportRequest(
            audioPath: '/tmp/song.wav',
            separateVocals: true,
          ))
          .toList();

      expect(events.last.stage, AnalysisStage.done,
          reason: 'pipeline error=${events.last.error}');
      expect(events.last.decodedPcm, same(original),
          reason: '播放／保存／匯出相容欄位必須維持原音');
      expect(events.last.analysisPcm, same(vocals),
          reason: '分析軌必須另欄明示，不得覆蓋原音');
      expect(events.last.audioTracks!.originalPcm, same(original));
      expect(events.last.audioTracks!.analysisPcm, same(vocals));
      expect(events.last.waveformPeaks, isNotEmpty);
    });

    test('分析中第二次呼叫回 ERR_ANALYSIS_IN_PROGRESS', () async {
      final decoder = _HoldingDecoder();
      final transcriber = _FakeTranscriber((pcm, language, transcript) async {
        return _goldWords;
      });
      final pipeline = _pipeline(decoder: decoder, transcriber: transcriber);
      final firstEvents = <AnalysisEvent>[];
      final firstDone = Completer<void>();

      final sub = pipeline
          .analyze(ImportRequest(audioPath: '/tmp/gold.wav'))
          .listen(firstEvents.add, onDone: firstDone.complete);
      await _pumpEvents();

      expect(firstEvents.single.stage, AnalysisStage.decoding);
      final secondEvents = await pipeline
          .analyze(ImportRequest(audioPath: '/tmp/gold.wav'))
          .toList();

      expect(secondEvents, hasLength(1));
      expect(secondEvents.single.stage, AnalysisStage.failed);
      expect(secondEvents.single.error!.code, ErrorCodes.analysisInProgress);

      decoder.complete(_pcm(seconds: 3));
      await firstDone.future;
      await sub.cancel();
    });

    test('轉寫失敗回 failed event，並保留已完成的解碼結果', () async {
      final pcm = _pcm(seconds: 3);
      final pipeline = _pipeline(
        decoder: _FakeDecoder(pcm),
        transcriber: _FakeTranscriber((decodedPcm, language, transcript) async {
          throw const DomainException(ErrorCodes.sidecarCrashed, '辨識引擎異常結束');
        }),
      );

      final events = await pipeline
          .analyze(ImportRequest(audioPath: '/tmp/gold.wav'))
          .toList();

      expect(events.last.stage, AnalysisStage.failed);
      expect(events.last.error!.code, ErrorCodes.sidecarCrashed);
      expect(events.last.decodedPcm, same(pcm));
      expect(events.map((e) => e.stage), contains(AnalysisStage.transcribing));
    });

    test('failed event 帶 checkpoint（含已解碼 PCM），供「重試此階段」用', () async {
      final pcm = _pcm(seconds: 3);
      final pipeline = _pipeline(
        decoder: _FakeDecoder(pcm),
        transcriber: _FakeTranscriber((decodedPcm, language, transcript) async {
          throw const DomainException(ErrorCodes.sidecarCrashed, '辨識引擎異常結束');
        }),
      );

      final events = await pipeline
          .analyze(ImportRequest(audioPath: '/tmp/gold.wav'))
          .toList();

      final failed = events.last;
      expect(failed.checkpoint, isNotNull);
      expect(failed.checkpoint!.decodedPcm, same(pcm));
      expect(failed.checkpoint!.words, isNull);
    });

    test('resume：帶 checkpoint.decodedPcm 時不重跑解碼', () async {
      final pcm = _pcm(seconds: 3);
      final decoder = _FakeDecoder(pcm);
      final transcriber = _FakeTranscriber((pcm, language, transcript) async {
        return _goldWords;
      });
      final pipeline = _pipeline(decoder: decoder, transcriber: transcriber);

      final events = await pipeline
          .analyze(
            ImportRequest(audioPath: '/tmp/gold.wav'),
            resume: PipelineCheckpoint(decodedPcm: pcm),
          )
          .toList();

      expect(decoder.paths, isEmpty, reason: 'decoder 不應被呼叫');
      expect(events.first.stage, AnalysisStage.decoding);
      expect(events.first.progress, 1, reason: 'resume 應直接跳到 decoding(1) 收尾事件');
      expect(events.last.stage, AnalysisStage.done);
      expect(events.last.result!.syllables, hasLength(11));
    });

    test('resume：帶 checkpoint.words 時不重跑轉寫', () async {
      final pcm = _pcm(seconds: 3);
      var transcribeCallCount = 0;
      final transcriber = _FakeTranscriber((pcm, language, transcript) async {
        transcribeCallCount++;
        return _goldWords;
      });
      final pipeline = _pipeline(
        decoder: _FakeDecoder(pcm),
        transcriber: transcriber,
      );

      final events = await pipeline
          .analyze(
            ImportRequest(audioPath: '/tmp/gold.wav'),
            resume: PipelineCheckpoint(
              decodedPcm: pcm,
              words: _goldWords,
            ),
          )
          .toList();

      expect(transcribeCallCount, 0);
      expect(events.last.stage, AnalysisStage.done);
      expect(events.last.result!.syllables, hasLength(11));
    });

    test('AT-17-02：辨識 Registry 缺 ja 時在解碼前 fail-closed', () async {
      final decoder = _FakeDecoder(_pcm(seconds: 3));
      final pipeline = AnalysisPipeline(
        decoder: decoder,
        transcriberRegistry: TranscriberRegistry([
          _FakeTranscriber(
            (pcm, language, transcript) async => _goldWords,
          ),
        ]),
        syllabifierRegistry: SyllabifierRegistry([EnglishSyllabifier()]),
      );

      final events = await pipeline
          .analyze(ImportRequest(audioPath: '/tmp/ja.wav', language: 'ja'))
          .toList();

      expect(events, hasLength(1));
      expect(events.single.stage, AnalysisStage.failed);
      expect(events.single.error!.code, ErrorCodes.languageUnsupported);
      expect(events.single.error!.message, contains('en'));
      expect(decoder.paths, isEmpty, reason: '語言拒絕後不得開始解碼副作用');
    });

    test('AT-17-03：ASR 有 ja、切分器無 ja 時仍在解碼前拒絕', () async {
      final decoder = _FakeDecoder(_pcm(seconds: 3));
      final pipeline = AnalysisPipeline(
        decoder: decoder,
        transcriberRegistry: TranscriberRegistry([
          _FakeTranscriber(
            (pcm, language, transcript) async => _goldWords,
            supportedLanguages: const {'en', 'ja'},
          ),
        ]),
        syllabifierRegistry: SyllabifierRegistry([EnglishSyllabifier()]),
      );

      final events = await pipeline
          .analyze(ImportRequest(audioPath: '/tmp/ja.wav', language: 'ja'))
          .toList();

      expect(events.single.error!.code, ErrorCodes.languageUnsupported);
      expect(events.single.error!.message, contains('音節切分器'));
      expect(decoder.paths, isEmpty, reason: '雙表缺任一不得產生副作用');
    });
  });
}

AnalysisPipeline _pipeline({
  required AnalysisAudioDecoder decoder,
  required TranscriberEngine transcriber,
  AnalysisVocalSeparator? vocalSeparator,
}) =>
    AnalysisPipeline(
      decoder: decoder,
      transcriberRegistry: TranscriberRegistry([transcriber]),
      syllabifierRegistry: SyllabifierRegistry([EnglishSyllabifier()]),
      vocalSeparator: vocalSeparator,
    );

class _FakeDecoder implements AnalysisAudioDecoder {
  final Pcm pcm;
  final paths = <String>[];

  _FakeDecoder(this.pcm);

  @override
  Future<Pcm> decode(String audioPath) async {
    paths.add(audioPath);
    return pcm;
  }
}

class _HoldingDecoder implements AnalysisAudioDecoder {
  final _completer = Completer<Pcm>();

  @override
  Future<Pcm> decode(String audioPath) => _completer.future;

  void complete(Pcm pcm) => _completer.complete(pcm);
}

class _FakeVocalSeparator implements AnalysisVocalSeparator {
  final Pcm pcm;

  _FakeVocalSeparator(this.pcm);

  @override
  Future<SeparatedAudio> separate(
    ImportRequest request, {
    required Pcm decodedPcm,
  }) async =>
      SeparatedAudio(audioPath: '/tmp/vocals.wav', pcm: pcm);
}

class _FakeTranscriber implements TranscriberEngine {
  final Future<List<Word>> Function(
    Pcm pcm,
    String language,
    String? transcript,
  ) _behavior;

  @override
  final Set<String> supportedLanguages;

  _FakeTranscriber(
    this._behavior, {
    this.supportedLanguages = const {'en'},
  });

  @override
  String get engineName => 'fake-local';

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
  }) =>
      _behavior(pcm, language, transcript);
}

Pcm _pcm({required int seconds}) => Pcm(Int16List(44100 * seconds));

Future<void> _pumpEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final _goldWords = [
  Word(text: 'She', startMs: 0, endMs: 200, index: 0),
  Word(text: 'has', startMs: 200, endMs: 400, index: 1),
  Word(text: 'excellent', startMs: 400, endMs: 1000, index: 2),
  Word(text: 'communication', startMs: 1000, endMs: 2000, index: 3),
  Word(text: 'skills', startMs: 2000, endMs: 2300, index: 4),
];
