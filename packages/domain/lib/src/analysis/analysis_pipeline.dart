// AI-Generate
import '../alignment/syllabifier_registry.dart';
import '../errors.dart';
import '../model/alignment_result.dart';
import '../model/pcm.dart';
import '../model/syllable.dart';
import '../model/time_range.dart';
import '../model/word.dart';
import '../ports/syllabifier.dart';
import '../ports/transcriber_engine.dart';
import 'transcriber_registry.dart';
import 'waveform_peaks.dart';

/// AnalysisPipeline 編排輸入（backend-design.md §3.2.1 介面 1）。
class ImportRequest {
  final String audioPath;
  final String? transcript;
  final String language;
  final bool separateVocals;
  final int waveformBucketCount;
  final TimeRange? sourceRange;

  ImportRequest({
    required this.audioPath,
    this.transcript,
    this.language = 'en',
    this.separateVocals = false,
    this.waveformBucketCount = 512,
    this.sourceRange,
  }) {
    if (audioPath.trim().isEmpty) {
      throw ArgumentError('ImportRequest.audioPath 不可空白');
    }
    if (waveformBucketCount < 1) {
      throw ArgumentError('waveformBucketCount 必須 >= 1');
    }
    if (language.trim().isEmpty) {
      throw ArgumentError('ImportRequest.language 不可空白');
    }
  }

  ImportRequest copyWith({
    String? audioPath,
    String? transcript,
    String? language,
    bool? separateVocals,
    int? waveformBucketCount,
    TimeRange? sourceRange,
  }) =>
      ImportRequest(
        audioPath: audioPath ?? this.audioPath,
        transcript: transcript ?? this.transcript,
        language: language ?? this.language,
        separateVocals: separateVocals ?? this.separateVocals,
        waveformBucketCount: waveformBucketCount ?? this.waveformBucketCount,
        sourceRange: sourceRange ?? this.sourceRange,
      );
}

enum AnalysisStage {
  decoding,
  separating,
  transcribing,
  syllabifying,
  done,
  failed,
}

/// 原音與分析軌的明確雙欄快照（backend-design.md §3.1.1；M1）。
class AnalysisAudioTracks {
  final Pcm originalPcm;
  final Pcm analysisPcm;

  const AnalysisAudioTracks({
    required this.originalPcm,
    required this.analysisPcm,
  });
}

/// AnalysisPipeline 串流事件（backend-design.md §3.2.1 介面 1）。
class AnalysisEvent {
  final AnalysisStage stage;
  final double progress;
  final AlignmentResult? result;
  final List<WaveformPeak>? waveformPeaks;

  /// 原始匯入／選取區間的 PCM；播放、保存、錄音參考與匯出只可使用此欄（M1）。
  final Pcm? decodedPcm;

  /// 只供 ASR 與分析的 PCM；啟用 Demucs 時可與 [decodedPcm] 不同（AT-12-09）。
  final Pcm? analysisPcm;

  /// 兩軌皆已產生時提供不可混淆的具名快照；舊 consumer 可續用 [decodedPcm]。
  AnalysisAudioTracks? get audioTracks =>
      decodedPcm == null || analysisPcm == null
          ? null
          : AnalysisAudioTracks(
              originalPcm: decodedPcm!,
              analysisPcm: analysisPcm!,
            );
  final DomainException? error;

  /// failed event 攜帶當下已完成階段的中間產物，供 UI 端做「重試此階段」
  /// 時傳回 pipeline，避免整段重跑（REQ-01 AT-01-04：解碼結果保留）。
  final PipelineCheckpoint? checkpoint;

  AnalysisEvent({
    required this.stage,
    required this.progress,
    this.result,
    this.waveformPeaks,
    this.decodedPcm,
    this.analysisPcm,
    this.error,
    this.checkpoint,
  }) {
    if (progress < 0 || progress > 1) {
      throw ArgumentError('AnalysisEvent.progress 需介於 0..1');
    }
    if (stage == AnalysisStage.done && result == null) {
      throw ArgumentError('done event 必須包含 AlignmentResult');
    }
    if (stage == AnalysisStage.failed && error == null) {
      throw ArgumentError('failed event 必須包含 DomainException');
    }
  }

  factory AnalysisEvent.failed(
    DomainException error, {
    Pcm? decodedPcm,
    Pcm? analysisPcm,
    PipelineCheckpoint? checkpoint,
  }) =>
      AnalysisEvent(
        stage: AnalysisStage.failed,
        progress: 1,
        decodedPcm: decodedPcm,
        analysisPcm: analysisPcm,
        error: error,
        checkpoint: checkpoint,
      );
}

/// 分階段 checkpoint：pipeline 失敗時交還已完成階段的產物；UI 「重試此階段」
/// 時再交還 pipeline，跳過已完成的階段。
class PipelineCheckpoint {
  final Pcm? decodedPcm;
  final SeparatedAudio? separated;
  final List<Word>? words;

  const PipelineCheckpoint({this.decodedPcm, this.separated, this.words});

  bool get isEmpty => decodedPcm == null && separated == null && words == null;

  PipelineCheckpoint copyWith({
    Pcm? decodedPcm,
    SeparatedAudio? separated,
    List<Word>? words,
  }) =>
      PipelineCheckpoint(
        decodedPcm: decodedPcm ?? this.decodedPcm,
        separated: separated ?? this.separated,
        words: words ?? this.words,
      );
}

/// 解碼依賴窄介面；Domain 只認 PCM，不認 sidecar 實作。
abstract interface class AnalysisAudioDecoder {
  Future<Pcm> decode(String audioPath);
}

/// 可選人聲分離依賴；S1c 前可不注入，pipeline 會以原音降級續跑。
abstract interface class AnalysisVocalSeparator {
  Future<SeparatedAudio> separate(
    ImportRequest request, {
    required Pcm decodedPcm,
  });
}

class SeparatedAudio {
  final String audioPath;
  final Pcm pcm;

  SeparatedAudio({required this.audioPath, required this.pcm}) {
    if (audioPath.trim().isEmpty) {
      throw ArgumentError('SeparatedAudio.audioPath 不可空白');
    }
  }
}

/// AnalysisPipeline（task-split 3.4）：解碼 → 可選分離 → 轉寫 → 音節切分 → peaks。
class AnalysisPipeline {
  final AnalysisAudioDecoder decoder;
  final TranscriberRegistry transcriberRegistry;
  final SyllabifierRegistry syllabifierRegistry;
  final AnalysisVocalSeparator? vocalSeparator;

  bool _inProgress = false;

  AnalysisPipeline({
    required this.decoder,
    required this.transcriberRegistry,
    required this.syllabifierRegistry,
    this.vocalSeparator,
  });

  Stream<AnalysisEvent> analyze(
    ImportRequest request, {
    PipelineCheckpoint? resume,
  }) async* {
    final TranscriberEngine transcriber;
    final Syllabifier syllabifier;
    try {
      // M14：兩張表必須在解碼、sidecar 或任何其他副作用前同時放行。
      transcriber = transcriberRegistry.resolve(request.language);
      syllabifier = syllabifierRegistry.resolve(request.language);
    } on DomainException catch (error) {
      yield AnalysisEvent.failed(error);
      return;
    }

    if (_inProgress) {
      yield AnalysisEvent.failed(
        const DomainException(ErrorCodes.analysisInProgress, '分析進行中'),
      );
      return;
    }

    _inProgress = true;
    Pcm? decodedPcm = resume?.decodedPcm;
    final decodedFromResume = decodedPcm != null;
    SeparatedAudio? separated = resume?.separated;
    List<Word>? words = resume?.words;

    PipelineCheckpoint currentCheckpoint() => PipelineCheckpoint(
          decodedPcm: decodedPcm,
          separated: separated,
          words: words,
        );

    try {
      if (decodedPcm == null) {
        yield AnalysisEvent(stage: AnalysisStage.decoding, progress: 0);
        decodedPcm = await decoder.decode(request.audioPath);
      }
      if (!decodedFromResume && request.sourceRange != null) {
        decodedPcm = decodedPcm.slice(request.sourceRange!);
      }
      yield AnalysisEvent(
        stage: AnalysisStage.decoding,
        progress: 1,
        decodedPcm: decodedPcm,
        analysisPcm: decodedPcm,
      );

      var transcribePcm = decodedPcm;
      if (request.separateVocals) {
        if (separated == null) {
          yield AnalysisEvent(
            stage: AnalysisStage.separating,
            progress: 0,
            decodedPcm: decodedPcm,
            analysisPcm: decodedPcm,
          );
          if (vocalSeparator != null) {
            separated =
                await vocalSeparator!.separate(request, decodedPcm: decodedPcm);
          }
        }
        if (separated != null) {
          transcribePcm = separated.pcm;
        }
        yield AnalysisEvent(
          stage: AnalysisStage.separating,
          progress: 1,
          decodedPcm: decodedPcm,
          analysisPcm: transcribePcm,
        );
      }

      if (words == null) {
        yield AnalysisEvent(
          stage: AnalysisStage.transcribing,
          progress: 0,
          decodedPcm: decodedPcm,
          analysisPcm: transcribePcm,
        );
        words = await transcriber.transcribe(
          transcribePcm,
          language: request.language,
          transcript: request.transcript,
        );
      }
      yield AnalysisEvent(
        stage: AnalysisStage.transcribing,
        progress: 1,
        decodedPcm: decodedPcm,
        analysisPcm: transcribePcm,
      );

      yield AnalysisEvent(
        stage: AnalysisStage.syllabifying,
        progress: 0,
        decodedPcm: decodedPcm,
        analysisPcm: transcribePcm,
      );
      final syllables = <Syllable>[
        for (final word in words)
          ...syllabifier.syllabify(word, language: request.language).syllables,
      ];
      final result = AlignmentResult(
        words: words,
        syllables: syllables,
        source: 'syllabifier:${syllabifier.runtimeType}',
        confidence: syllables.any((item) => item.needsReview) ? 0.72 : 0.95,
      );
      final peaks = computeWaveformPeaks(
        transcribePcm,
        bucketCount: request.waveformBucketCount,
      );
      yield AnalysisEvent(
        stage: AnalysisStage.syllabifying,
        progress: 1,
        result: result,
        waveformPeaks: peaks,
        decodedPcm: decodedPcm,
        analysisPcm: transcribePcm,
      );

      yield AnalysisEvent(
        stage: AnalysisStage.done,
        progress: 1,
        result: result,
        waveformPeaks: peaks,
        decodedPcm: decodedPcm,
        analysisPcm: transcribePcm,
      );
    } on DomainException catch (e) {
      yield AnalysisEvent.failed(
        e,
        decodedPcm: decodedPcm,
        analysisPcm: separated?.pcm ?? decodedPcm,
        checkpoint: currentCheckpoint(),
      );
    } catch (e) {
      yield AnalysisEvent.failed(
        DomainException(ErrorCodes.decodeFailed, '分析失敗：$e'),
        decodedPcm: decodedPcm,
        analysisPcm: separated?.pcm ?? decodedPcm,
        checkpoint: currentCheckpoint(),
      );
    } finally {
      _inProgress = false;
    }
  }
}
