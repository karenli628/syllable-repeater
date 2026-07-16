// AI-Generate
import 'dart:async';
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infra/infra.dart';
import 'package:record/record.dart';

import '../../shared/infra/sidecar_paths.dart';

final practiceRecorderProvider = Provider<PracticeRecorder>((ref) {
  final paths = SidecarPaths.current();
  final recorder = RecordPracticeRecorder(
    tempDirectory: paths.tempDirectory,
    normalizer: FfmpegDecoder(
      runner: const SidecarRunner(),
      ffmpegPath: paths.ffmpegPath,
    ),
    fileIo: AtomicFileIo(tempDirPath: paths.tempDirectory),
  );
  ref.onDispose(recorder.dispose);
  return recorder;
});

final practiceComparisonServiceProvider = Provider<PracticeComparisonService>((
  ref,
) {
  final paths = SidecarPaths.current();
  return DomainPracticeComparisonService(
    comparator: RecordingComparator(
      audioSource: FileRecordingAudioSource(
        fileIo: AtomicFileIo(tempDirPath: paths.tempDirectory),
      ),
    ),
  );
});

abstract interface class PracticeRecorder {
  Stream<double> get levels;

  Future<String> start();

  Future<CompletedPracticeRecording?> stop();

  Future<void> cancel();

  Future<void> dispose();
}

class CompletedPracticeRecording {
  const CompletedPracticeRecording({required this.path, required this.pcm});

  final String path;
  final Pcm pcm;
}

abstract interface class PracticeComparisonService {
  Future<ComparisonResult> compare({
    required String userRecordingPath,
    required List<Syllable> syllables,
    required PracticeStep step,
    required Pcm originalPcm,
  });
}

class DomainPracticeComparisonService implements PracticeComparisonService {
  final RecordingComparator comparator;

  const DomainPracticeComparisonService({required this.comparator});

  @override
  Future<ComparisonResult> compare({
    required String userRecordingPath,
    required List<Syllable> syllables,
    required PracticeStep step,
    required Pcm originalPcm,
  }) {
    return comparator.compare(userRecordingPath, syllables, step, originalPcm);
  }
}

class RecordPracticeRecorder implements PracticeRecorder {
  final String tempDirectory;
  final AnalysisAudioDecoder normalizer;
  final FileIo fileIo;
  final AudioRecorder _recorder;
  StreamSubscription<Amplitude>? _amplitudeSub;
  StreamController<double>? _levels;
  String? _recordingPath;

  RecordPracticeRecorder({
    required this.tempDirectory,
    required this.normalizer,
    required this.fileIo,
    AudioRecorder? recorder,
  }) : _recorder = recorder ?? AudioRecorder();

  @override
  Stream<double> get levels =>
      (_levels ??= StreamController<double>.broadcast()).stream;

  @override
  Future<String> start() async {
    if (!await _recorder.hasPermission()) {
      throw const DomainException(
        ErrorCodes.micPermissionDenied,
        '請至系統設定開啟麥克風權限',
      );
    }

    final dir = Directory(tempDirectory);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final path =
        '${dir.path}/recording-${DateTime.now().microsecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );
    _recordingPath = path;
    _levels ??= StreamController<double>.broadcast();
    _amplitudeSub?.cancel();
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amplitude) {
          final normalized = ((amplitude.current + 60) / 60).clamp(0.0, 1.0);
          _levels?.add(normalized);
        });
    return path;
  }

  @override
  Future<CompletedPracticeRecording?> stop() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    final path = await _recorder.stop() ?? _recordingPath;
    _recordingPath = null;
    if (path == null) {
      return null;
    }
    try {
      final pcm = await waitForCompletedRecording(
        path,
        normalizer: normalizer,
        fileIo: fileIo,
      );
      return CompletedPracticeRecording(path: path, pcm: pcm);
    } catch (_) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }

  @override
  Future<void> cancel() async {
    final path = _recordingPath;
    _recordingPath = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    try {
      await _recorder.cancel();
    } finally {
      if (path != null) {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        }
      }
    }
  }

  @override
  Future<void> dispose() async {
    await _amplitudeSub?.cancel();
    await _levels?.close();
    await _recorder.dispose();
  }
}

/// 等待 macOS 錄音外掛完成 WAV header/data 收尾（REQ-06／AT-06-06）。
Future<Pcm> waitForCompletedRecording(
  String path, {
  int attempts = 25,
  Duration retryDelay = const Duration(milliseconds: 40),
  AnalysisAudioDecoder? normalizer,
  FileIo? fileIo,
}) async {
  if ((normalizer == null) != (fileIo == null)) {
    throw ArgumentError('normalizer 與 fileIo 必須同時提供');
  }
  DomainException? lastError;
  int? previousByteLength;
  for (var attempt = 0; attempt < attempts; attempt++) {
    final file = File(path);
    if (await file.exists()) {
      try {
        final bytes = await file.readAsBytes();
        try {
          return decodeWav(bytes, failureMessage: '錄音 WAV 解碼失敗');
        } on DomainException catch (error) {
          lastError = error;
        }

        // macOS record 外掛在部分環境會交付 stereo/float WAV。
        // 先等檔案長度連續兩次不變，再交給受管 FFmpeg 轉成
        // PCM16 mono，避免解碼尚未寫完的 WAV header/data。
        if (normalizer != null &&
            fileIo != null &&
            previousByteLength == bytes.length) {
          try {
            final normalized = await normalizer.decode(path);
            await fileIo.writeBytesAtomic(path, encodeWav(normalized));
            return normalized;
          } on DomainException catch (error) {
            lastError = error;
          }
        }
        previousByteLength = bytes.length;
      } on DomainException catch (error) {
        lastError = error;
      }
    }
    if (attempt + 1 < attempts) {
      await Future<void>.delayed(retryDelay);
    }
  }
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
  throw lastError ?? const DomainException(ErrorCodes.decodeFailed, '錄音檔未完成寫入');
}
