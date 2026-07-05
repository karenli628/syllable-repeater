// AI-Generate
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:infra/infra.dart';

import '../../features/import_analysis/analysis_controller.dart';
import 'sidecar_paths.dart';

/// 真實 sidecar pipeline 的 `AnalysisRunner`：組裝 FFmpeg + whisper.cpp
/// + CMUdict + AlignmentEngine，把 `analyze` 委派給 domain `AnalysisPipeline`。
///
/// Domain 純度靠 `packages/domain/test/domain_purity_test.dart` 守；本檔位於
/// app 端，允許 import infra 與 dart:io。
class InfraAnalysisRunner implements AnalysisRunner {
  final AnalysisPipeline _pipeline;

  InfraAnalysisRunner._(this._pipeline);

  factory InfraAnalysisRunner.fromPaths(SidecarPaths paths) {
    Directory(paths.tempDirectory).createSync(recursive: true);
    const runner = SidecarRunner();
    final dictionary = const CmuDictLoader().load(paths.cmudictPath);
    final pipeline = AnalysisPipeline(
      decoder: FfmpegDecoder(runner: runner, ffmpegPath: paths.ffmpegPath),
      transcriber: WhisperAnalysisTranscriber(
        audioPreparer: FfmpegTranscriptionAudioPreparer(
          runner: runner,
          ffmpegPath: paths.ffmpegPath,
          tempDirectory: paths.tempDirectory,
        ),
        transcriber: WhisperCppTranscriber(
          runner: runner,
          whisperCliPath: paths.whisperCliPath,
          modelPath: paths.whisperModelPath,
          noGpu: true,
        ),
        outputDirectory: paths.tempDirectory,
      ),
      alignmentEngine: AlignmentEngine(dictionary: dictionary),
    );
    return InfraAnalysisRunner._(pipeline);
  }

  @override
  Stream<AnalysisEvent> analyze(
    ImportRequest request, {
    PipelineCheckpoint? resume,
  }) =>
      _pipeline.analyze(request, resume: resume);
}
