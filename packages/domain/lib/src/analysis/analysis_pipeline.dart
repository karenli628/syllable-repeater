// AI-Generate
import '../alignment/alignment_engine.dart';
import '../errors.dart';
import '../model/alignment_result.dart';
import '../model/pcm.dart';
import '../model/word.dart';
import 'waveform_peaks.dart';

/// AnalysisPipeline 編排輸入（backend-design.md §3.2.1 介面 1）。
class ImportRequest {
  final String audioPath;
  final String? transcript;
  final bool separateVocals;
  final int waveformBucketCount;

  ImportRequest({
    required this.audioPath,
    this.transcript,
    this.separateVocals = false,
    this.waveformBucketCount = 512,
  }) {
    if (audioPath.trim().isEmpty) {
      throw ArgumentError('ImportRequest.audioPath 不可空白');
    }
    if (waveformBucketCount < 1) {
      throw ArgumentError('waveformBucketCount 必須 >= 1');
    }
  }

  ImportRequest copyWith({
    String? audioPath,
    String? transcript,
    bool? separateVocals,
    int? waveformBucketCount,
  }) =>
      ImportRequest(
        audioPath: audioPath ?? this.audioPath,
        transcript: transcript ?? this.transcript,
        separateVocals: separateVocals ?? this.separateVocals,
        waveformBucketCount: waveformBucketCount ?? this.waveformBucketCount,
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

/// AnalysisPipeline 串流事件（backend-design.md §3.2.1 介面 1）。
class AnalysisEvent {
  final AnalysisStage stage;
  final double progress;
  final AlignmentResult? result;
  final List<WaveformPeak>? waveformPeaks;
  final Pcm? decodedPcm;
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
    PipelineCheckpoint? checkpoint,
  }) =>
      AnalysisEvent(
        stage: AnalysisStage.failed,
        progress: 1,
        decodedPcm: decodedPcm,
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

/// 轉寫依賴窄介面；真實 16k WAV 暫存與 whisper.cpp 呼叫由 infra adapter 負責。
abstract interface class AnalysisTranscriber {
  Future<List<Word>> transcribe(
    ImportRequest request, {
    required Pcm decodedPcm,
  });
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
  final AnalysisTranscriber transcriber;
  final AlignmentEngine alignmentEngine;
  final AnalysisVocalSeparator? vocalSeparator;

  bool _inProgress = false;

  AnalysisPipeline({
    required this.decoder,
    required this.transcriber,
    AlignmentEngine? alignmentEngine,
    this.vocalSeparator,
  }) : alignmentEngine = alignmentEngine ?? AlignmentEngine();

  Stream<AnalysisEvent> analyze(
    ImportRequest request, {
    PipelineCheckpoint? resume,
  }) async* {
    if (_inProgress) {
      yield AnalysisEvent.failed(
        const DomainException(ErrorCodes.analysisInProgress, '分析進行中'),
      );
      return;
    }

    _inProgress = true;
    Pcm? decodedPcm = resume?.decodedPcm;
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
      yield AnalysisEvent(
        stage: AnalysisStage.decoding,
        progress: 1,
        decodedPcm: decodedPcm,
      );

      var transcribeRequest = request;
      var transcribePcm = decodedPcm;
      if (request.separateVocals) {
        if (separated == null) {
          yield AnalysisEvent(
            stage: AnalysisStage.separating,
            progress: 0,
            decodedPcm: decodedPcm,
          );
          if (vocalSeparator != null) {
            separated = await vocalSeparator!
                .separate(request, decodedPcm: decodedPcm);
          }
        }
        if (separated != null) {
          transcribeRequest = request.copyWith(audioPath: separated.audioPath);
          transcribePcm = separated.pcm;
        }
        yield AnalysisEvent(
          stage: AnalysisStage.separating,
          progress: 1,
          decodedPcm: transcribePcm,
        );
      }

      if (words == null) {
        yield AnalysisEvent(
          stage: AnalysisStage.transcribing,
          progress: 0,
          decodedPcm: transcribePcm,
        );
        words = await transcriber.transcribe(
          transcribeRequest,
          decodedPcm: transcribePcm,
        );
      }
      yield AnalysisEvent(
        stage: AnalysisStage.transcribing,
        progress: 1,
        decodedPcm: transcribePcm,
      );

      yield AnalysisEvent(
        stage: AnalysisStage.syllabifying,
        progress: 0,
        decodedPcm: transcribePcm,
      );
      final result = alignmentEngine.alignWords(words);
      final peaks = computeWaveformPeaks(
        transcribePcm,
        bucketCount: request.waveformBucketCount,
      );
      yield AnalysisEvent(
        stage: AnalysisStage.syllabifying,
        progress: 1,
        result: result,
        waveformPeaks: peaks,
        decodedPcm: transcribePcm,
      );

      yield AnalysisEvent(
        stage: AnalysisStage.done,
        progress: 1,
        result: result,
        waveformPeaks: peaks,
        decodedPcm: transcribePcm,
      );
    } on DomainException catch (e) {
      yield AnalysisEvent.failed(
        e,
        decodedPcm: decodedPcm,
        checkpoint: currentCheckpoint(),
      );
    } catch (e) {
      yield AnalysisEvent.failed(
        DomainException(ErrorCodes.decodeFailed, '分析失敗：$e'),
        decodedPcm: decodedPcm,
        checkpoint: currentCheckpoint(),
      );
    } finally {
      _inProgress = false;
    }
  }
}
