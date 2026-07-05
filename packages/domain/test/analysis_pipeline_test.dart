// AI-Generate
import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('AnalysisPipeline（task-split 3.4）', () {
    test('依序回報階段，完成時帶 AlignmentResult 與 waveform peaks', () async {
      final pcm = _pcm(seconds: 3);
      final decoder = _FakeDecoder(pcm);
      final transcriber = _FakeTranscriber((request, decodedPcm) async {
        expect(request.transcript, 'She has excellent communication skills');
        expect(decodedPcm, same(pcm));
        return _goldWords;
      });
      final pipeline =
          AnalysisPipeline(decoder: decoder, transcriber: transcriber);

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

    test('分析中第二次呼叫回 ERR_ANALYSIS_IN_PROGRESS', () async {
      final decoder = _HoldingDecoder();
      final transcriber =
          _FakeTranscriber((request, decodedPcm) async => _goldWords);
      final pipeline =
          AnalysisPipeline(decoder: decoder, transcriber: transcriber);
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
      final pipeline = AnalysisPipeline(
        decoder: _FakeDecoder(pcm),
        transcriber: _FakeTranscriber((request, decodedPcm) async {
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
      final pipeline = AnalysisPipeline(
        decoder: _FakeDecoder(pcm),
        transcriber: _FakeTranscriber((request, decodedPcm) async {
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
      final transcriber = _FakeTranscriber((r, d) async => _goldWords);
      final pipeline =
          AnalysisPipeline(decoder: decoder, transcriber: transcriber);

      final events = await pipeline
          .analyze(
            ImportRequest(audioPath: '/tmp/gold.wav'),
            resume: PipelineCheckpoint(decodedPcm: pcm),
          )
          .toList();

      expect(decoder.paths, isEmpty, reason: 'decoder 不應被呼叫');
      expect(events.first.stage, AnalysisStage.decoding);
      expect(events.first.progress, 1,
          reason: 'resume 應直接跳到 decoding(1) 收尾事件');
      expect(events.last.stage, AnalysisStage.done);
      expect(events.last.result!.syllables, hasLength(11));
    });

    test('resume：帶 checkpoint.words 時不重跑轉寫', () async {
      final pcm = _pcm(seconds: 3);
      var transcribeCallCount = 0;
      final transcriber = _FakeTranscriber((r, d) async {
        transcribeCallCount++;
        return _goldWords;
      });
      final pipeline = AnalysisPipeline(
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
  });
}

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

class _FakeTranscriber implements AnalysisTranscriber {
  final Future<List<Word>> Function(ImportRequest request, Pcm decodedPcm)
      _behavior;

  _FakeTranscriber(this._behavior);

  @override
  Future<List<Word>> transcribe(
    ImportRequest request, {
    required Pcm decodedPcm,
  }) =>
      _behavior(request, decodedPcm);
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
