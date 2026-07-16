// AI-Generate
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../analysis/analysis_pipeline.dart';
import '../analysis/transcriber_registry.dart';
import '../analysis/waveform_peaks.dart';
import '../errors.dart';
import '../model/segment.dart';
import '../ports/file_io.dart';
import '../ports/label_registry_repository.dart';
import '../alignment/syllabifier_registry.dart';
import 'label_session.dart';

/// 段落開啟的真實階段（backend-design.md 介面 20；REQ-11／M15）。
enum LabelOpenStage {
  readingFingerprint,
  decoding,
  separatingVocals,
  segmenting,
  buildingWaveform,
  completed,
}

/// 段落開啟進度；未知總量的 sidecar 階段只呈現階段名稱。
class LabelOpenProgress {
  const LabelOpenProgress({
    required this.stage,
    required this.completedUnits,
    this.totalUnits,
  })  : assert(completedUnits >= 0),
        assert(totalUnits == null || totalUnits >= completedUnits);

  final LabelOpenStage stage;
  final int completedUnits;
  final int? totalUnits;

  double? get ratio {
    final total = totalUnits;
    if (total == null || total == 0) return null;
    return completedUnits / total;
  }
}

/// 可降級、但仍有有效工作階段的警告（backend-design.md §3.1.1）。
class LabelOpenWarning {
  final String code;
  final String message;

  /// 建立 openAudio 非致命警告（AT-11-06）。
  const LabelOpenWarning({required this.code, required this.message})
      : assert(code == ErrorCodes.transcribeFailed),
        assert(message != '');
}

/// SegmentEngine.openAudio 的正常結果（backend-design.md 介面 20）。
class LabelOpenResult {
  final LabelSession session;
  final String? existingLabelPath;
  final List<double> peaks;
  final LabelOpenWarning? warning;

  /// 建立不可變的標籤開啟結果（REQ-11）。
  LabelOpenResult({
    required this.session,
    this.existingLabelPath,
    required List<double> peaks,
    this.warning,
  }) : peaks = List.unmodifiable(peaks);
}

/// 自動切句與標籤工作階段入口（backend-design.md 介面 20、REQ-11）。
class SegmentEngine {
  final AnalysisAudioDecoder decoder;
  final FileIo fileIo;
  final TranscriberRegistry transcriberRegistry;
  final SyllabifierRegistry syllabifierRegistry;
  final AnalysisVocalSeparator? vocalSeparator;
  final LabelRegistryRepository? labelRegistryRepository;
  final int waveformBucketCount;

  bool _inProgress = false;

  /// 注入純 Domain ports 與可選本地人聲分離器（M4/M5/M14）。
  SegmentEngine({
    required this.decoder,
    required this.fileIo,
    required this.transcriberRegistry,
    required this.syllabifierRegistry,
    this.vocalSeparator,
    this.labelRegistryRepository,
    this.waveformBucketCount = 512,
  }) {
    if (waveformBucketCount < 1) {
      throw ArgumentError('waveformBucketCount 必須 >= 1');
    }
  }

  /// 開啟音檔並自動切句；ASR 失敗回正常空 session＋警告（AT-11-06）。
  Future<LabelOpenResult> openAudio(
    String path, {
    bool separateVocals = true,
    String language = 'en',
    void Function(LabelOpenProgress progress)? onProgress,
  }) async {
    // M14：必須在讀檔、解碼、sidecar 前先完成雙 Registry 檢查。
    final transcriber = transcriberRegistry.resolve(language);
    syllabifierRegistry.resolve(language);
    if (_inProgress) {
      throw const DomainException(
        ErrorCodes.analysisInProgress,
        '已有切段工作進行中',
      );
    }
    if (path.trim().isEmpty) {
      throw ArgumentError('path 不可空白');
    }

    _inProgress = true;
    try {
      _emitStageStart(onProgress, LabelOpenStage.readingFingerprint);
      final audioBytes = await fileIo.readBytes(path);
      final fingerprint = sha256.convert(audioBytes).toString();
      _emitStageDone(onProgress, LabelOpenStage.readingFingerprint);

      _emitStageStart(onProgress, LabelOpenStage.decoding);
      final decoded = await decoder.decode(path);
      _emitStageDone(onProgress, LabelOpenStage.decoding);
      final existing =
          await labelRegistryRepository?.findByFingerprint(fingerprint);

      var analysisPcm = decoded;
      if (separateVocals && vocalSeparator != null) {
        _emitStageStart(onProgress, LabelOpenStage.separatingVocals);
        try {
          final separated = await vocalSeparator!.separate(
            ImportRequest(
              audioPath: path,
              language: language,
              separateVocals: true,
            ),
            decodedPcm: decoded,
          );
          analysisPcm = separated.pcm;
        } on DomainException {
          // M4：分離器不可用時沿用原音，不拖垮標籤流程。
          analysisPcm = decoded;
        }
        _emitStageDone(onProgress, LabelOpenStage.separatingVocals);
      }

      late LabelSession session;
      LabelOpenWarning? warning;
      _emitStageStart(onProgress, LabelOpenStage.segmenting);
      try {
        final rawSegments = await transcriber.segment(
          analysisPcm,
          language: language,
        );
        session = LabelSession(
          audioFingerprint: fingerprint,
          audioDurationMs: decoded.durationMs,
          language: language,
          separateVocals: separateVocals,
          segments: _fitSegments(rawSegments, decoded.durationMs),
        );
      } catch (_) {
        session = LabelSession(
          audioFingerprint: fingerprint,
          audioDurationMs: decoded.durationMs,
          language: language,
          separateVocals: separateVocals,
          segments: const [],
        );
        warning = const LabelOpenWarning(
          code: ErrorCodes.transcribeFailed,
          message: '切段失敗，可重試或手動切段',
        );
      }
      _emitStageDone(onProgress, LabelOpenStage.segmenting);

      _emitStageStart(onProgress, LabelOpenStage.buildingWaveform);
      final peaks = computeWaveformPeaks(
        decoded,
        bucketCount: waveformBucketCount,
      )
          .map((peak) => math.max(peak.min.abs(), peak.max.abs()))
          .toList(growable: false);
      _emitStageDone(onProgress, LabelOpenStage.buildingWaveform);
      _emitStageDone(onProgress, LabelOpenStage.completed);

      return LabelOpenResult(
        session: session,
        existingLabelPath: existing?.labelPath,
        peaks: peaks,
        warning: warning,
      );
    } finally {
      _inProgress = false;
    }
  }

  void _emitStageStart(
    void Function(LabelOpenProgress progress)? onProgress,
    LabelOpenStage stage,
  ) {
    onProgress?.call(
      LabelOpenProgress(stage: stage, completedUnits: 0),
    );
  }

  void _emitStageDone(
    void Function(LabelOpenProgress progress)? onProgress,
    LabelOpenStage stage,
  ) {
    onProgress?.call(
      LabelOpenProgress(stage: stage, completedUnits: 1, totalUnits: 1),
    );
  }

  List<Segment> _fitSegments(List<Segment> input, int durationMs) {
    final fitted = <Segment>[];
    for (final segment in input) {
      if (segment.startMs >= durationMs) {
        continue;
      }
      final endMs = math.min(segment.endMs, durationMs);
      if (endMs <= segment.startMs) {
        continue;
      }
      fitted.add(segment.copyWith(endMs: endMs));
    }
    return List.unmodifiable(fitted);
  }
}
