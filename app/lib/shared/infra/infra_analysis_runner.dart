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
    final decoder = FfmpegDecoder(runner: runner, ffmpegPath: paths.ffmpegPath);
    // demucs 為選用（task-split 3.8 + memory `decision_hard_guardrails_matrix_20260705`）；
    // 未就緒時 vocalSeparator 傳 null，pipeline 自動走「跳過分離用原音」降級
    // （backend-design §5 第 704 行、M4）。
    final vocalSeparator = paths.demucsAvailable()
        ? DemucsCppVocalSeparator(
            runner: runner,
            decoder: decoder,
            inputPreparer: FfmpegDemucsAudioPreparer(
              runner: runner,
              ffmpegPath: paths.ffmpegPath,
            ),
            demucsCliPath: paths.demucsCliPath,
            modelPath: paths.demucsModelPath,
            outputDirectory: paths.tempDirectory,
          )
        : null;
    final transcriber = WhisperAnalysisTranscriber(
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
    );
    final pipeline = AnalysisPipeline(
      decoder: decoder,
      transcriberRegistry: TranscriberRegistry([transcriber]),
      syllabifierRegistry: SyllabifierRegistry([
        EnglishSyllabifier(
          alignmentEngine: AlignmentEngine(dictionary: dictionary),
        ),
      ]),
      vocalSeparator: vocalSeparator,
    );
    return InfraAnalysisRunner._(pipeline);
  }

  @override
  Stream<AnalysisEvent> analyze(
    ImportRequest request, {
    PipelineCheckpoint? resume,
  }) => _pipeline.analyze(request, resume: resume);
}
