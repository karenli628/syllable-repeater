// AI-Generate
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test('Pcm 依 TimeRange 取原音 sample 子範圍且不改原 PCM', () {
    final original = Pcm(
      Int16List.fromList(List<int>.generate(1000, (index) => index)),
      sampleRate: 1000,
    );

    final sliced = original.slice(TimeRange(200, 700));

    expect(sliced.sampleRate, 1000);
    expect(sliced.samples.length, 500);
    expect(sliced.samples.first, 200);
    expect(sliced.samples.last, 699);
    expect(original.samples.first, 0);
    expect(original.samples.last, 999);
  });

  test('ImportRequest sourceRange 讓單句分析收到原音切片而非整檔', () async {
    final decoder = _Decoder(
      Pcm(
        Int16List.fromList(List<int>.generate(1000, (index) => index)),
        sampleRate: 1000,
      ),
    );
    final transcriber = _Transcriber();
    final pipeline = AnalysisPipeline(
      decoder: decoder,
      transcriberRegistry: TranscriberRegistry([transcriber]),
      syllabifierRegistry: SyllabifierRegistry([_Syllabifier()]),
    );

    final events = await pipeline
        .analyze(
          ImportRequest(
            audioPath: '/tmp/full-track.wav',
            sourceRange: TimeRange(200, 700),
            transcript: 'hello',
          ),
        )
        .toList();

    expect(events.last.stage, AnalysisStage.done);
    expect(transcriber.seenPcm?.samples.length, 500);
    expect(transcriber.seenPcm?.samples.first, 200);
    expect(transcriber.seenPcm?.samples.last, 699);
    expect(decoder.paths, ['/tmp/full-track.wav']);
  });
}

class _Decoder implements AnalysisAudioDecoder {
  _Decoder(this.pcm);

  final Pcm pcm;
  final paths = <String>[];

  @override
  Future<Pcm> decode(String audioPath) async {
    paths.add(audioPath);
    return pcm;
  }
}

class _Transcriber implements TranscriberEngine {
  Pcm? seenPcm;

  @override
  String get engineName => 'slice-test';

  @override
  Set<String> get supportedLanguages => const {'en'};

  @override
  Future<List<Word>> transcribe(
    Pcm pcm, {
    required String language,
    String? transcript,
  }) async {
    seenPcm = pcm;
    return [
      Word(
          text: transcript ?? 'hello',
          startMs: 0,
          endMs: pcm.durationMs,
          index: 0),
    ];
  }

  @override
  Future<List<Segment>> segment(
    Pcm pcm, {
    required String language,
  }) async =>
      [];
}

class _Syllabifier implements Syllabifier {
  @override
  Set<String> get supportedLanguages => const {'en'};

  @override
  SyllabifyResult syllabify(Word word, {required String language}) =>
      SyllabifyResult(
        syllables: [
          Syllable(
            text: word.text,
            startMs: word.startMs,
            endMs: word.endMs,
            wordIndex: word.index,
            needsReview: false,
          ),
        ],
      );
}
