// AI-Generate
import 'dart:io';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

final practiceAudioBackendProvider = Provider<PracticeAudioBackend>((ref) {
  final backend = JustAudioPracticeBackend();
  ref.onDispose(backend.dispose);
  return backend;
});

final practicePlayerProvider = Provider<PracticePlayback>((ref) {
  return PracticePlayer(backend: ref.watch(practiceAudioBackendProvider));
});

abstract interface class PracticePlayback {
  Future<String> renderStepToFile(
    PracticeStep step,
    Pcm originalPcm, {
    required int repeatN,
  });

  Future<void> playStep(
    PracticeStep step,
    Pcm originalPcm, {
    required int repeatN,
    void Function()? onReady,
  });

  Future<void> stop();
}

abstract interface class PracticeAudioBackend {
  Future<void> setFilePath(String path);
  Future<void> play();
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioPracticeBackend implements PracticeAudioBackend {
  JustAudioPracticeBackend({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> setFilePath(String path) async {
    await _player.setAudioSource(AudioSource.uri(Uri.file(path)));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

class PracticePlayer implements PracticePlayback {
  PracticePlayer({
    required this.backend,
    PracticeEngine? engine,
    this.tempDirectory,
  }) : _engine = engine ?? PracticeEngine();

  final PracticeAudioBackend backend;
  final PracticeEngine _engine;
  final Directory? tempDirectory;

  @override
  Future<String> renderStepToFile(
    PracticeStep step,
    Pcm originalPcm, {
    required int repeatN,
  }) async {
    final renderedOnce = _engine.renderStep(step, originalPcm);
    final repeated = _repeat(renderedOnce, repeatN);
    final wavBytes = encodeWav(repeated);
    final dir =
        tempDirectory ??
        Directory(
          '${Directory.systemTemp.path}${Platform.pathSeparator}syllable_repeater_steps',
        );
    await dir.create(recursive: true);

    final hash = _cacheKey(step, originalPcm, repeatN);
    final file = File('${dir.path}${Platform.pathSeparator}step-$hash.wav');
    if (!await file.exists()) {
      await file.writeAsBytes(wavBytes, flush: true);
    }
    return file.path;
  }

  @override
  Future<void> playStep(
    PracticeStep step,
    Pcm originalPcm, {
    required int repeatN,
    void Function()? onReady,
  }) async {
    await stop();
    final path = await renderStepToFile(step, originalPcm, repeatN: repeatN);
    await backend.setFilePath(path);
    onReady?.call();
    await backend.play();
  }

  @override
  Future<void> stop() => backend.stop();

  Pcm _repeat(Pcm pcm, int repeatN) {
    final samples = Int16List(pcm.samples.length * repeatN);
    for (var i = 0; i < repeatN; i++) {
      samples.setRange(
        i * pcm.samples.length,
        (i + 1) * pcm.samples.length,
        pcm.samples,
      );
    }
    return Pcm(samples, sampleRate: pcm.sampleRate);
  }

  String _cacheKey(PracticeStep step, Pcm originalPcm, int repeatN) {
    final first = originalPcm.samples.isEmpty ? 0 : originalPcm.samples.first;
    final last = originalPcm.samples.isEmpty ? 0 : originalPcm.samples.last;
    final parts = [
      'step=${step.index}',
      'repeat=$repeatN',
      'rate=${originalPcm.sampleRate}',
      'len=${originalPcm.samples.length}',
      'first=$first',
      'last=$last',
      ...step.sourceRanges.map((r) => '${r.startMs}-${r.endMs}'),
    ];
    return _fnv1a32(parts.join('|'));
  }

  String _fnv1a32(String input) {
    var hash = 0x811c9dc5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
