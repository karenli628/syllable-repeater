// AI-Generate
import 'dart:async';
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infra/infra.dart';
import 'package:record/record.dart';

import '../../shared/infra/sidecar_paths.dart';

final practiceRecorderProvider = Provider<PracticeRecorder>((ref) {
  final paths = SidecarPaths.dev();
  final recorder = RecordPracticeRecorder(tempDirectory: paths.tempDirectory);
  ref.onDispose(recorder.dispose);
  return recorder;
});

final practiceComparisonServiceProvider = Provider<PracticeComparisonService>((
  ref,
) {
  final paths = SidecarPaths.dev();
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

  Future<String?> stop();

  Future<void> cancel();

  Future<void> dispose();
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
  final AudioRecorder _recorder;
  StreamSubscription<Amplitude>? _amplitudeSub;
  StreamController<double>? _levels;
  String? _recordingPath;

  RecordPracticeRecorder({required this.tempDirectory, AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

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
  Future<String?> stop() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    final path = await _recorder.stop();
    _recordingPath = null;
    return path;
  }

  @override
  Future<void> cancel() async {
    final path = _recordingPath;
    await stop();
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
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
