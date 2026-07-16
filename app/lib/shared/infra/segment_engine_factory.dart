// AI-Generate
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:infra/infra.dart';

import 'sidecar_paths.dart';

/// 由既有 sidecar 組裝 SegmentEngine（backend-design.md 介面 20）。
///
/// 這個 factory 只負責 wiring；實際開檔、指紋、ASR warning 與 session
/// 規則仍由 Domain 的 SegmentEngine 維持，避免 UI 另寫一套分析流程。
SegmentEngine buildSegmentEngine({
  required SidecarPaths paths,
  required AppDatabase database,
}) {
  Directory(paths.tempDirectory).createSync(recursive: true);
  const runner = SidecarRunner();
  final dictionary = const CmuDictLoader().load(paths.cmudictPath);
  final decoder = FfmpegDecoder(runner: runner, ffmpegPath: paths.ffmpegPath);
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

  return SegmentEngine(
    decoder: decoder,
    fileIo: AtomicFileIo(tempDirPath: paths.tempDirectory),
    transcriberRegistry: TranscriberRegistry([transcriber]),
    syllabifierRegistry: SyllabifierRegistry([
      EnglishSyllabifier(
        alignmentEngine: AlignmentEngine(dictionary: dictionary),
      ),
    ]),
    vocalSeparator: vocalSeparator,
    labelRegistryRepository: DriftLabelRegistryRepository(database),
  );
}
