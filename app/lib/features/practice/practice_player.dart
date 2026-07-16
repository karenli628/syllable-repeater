// AI-Generate
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../shared/infra/sidecar_paths.dart';

final practiceAudioBackendProvider = Provider<PracticeAudioBackend>((ref) {
  final backend = JustAudioPracticeBackend();
  ref.onDispose(backend.dispose);
  return backend;
});

final practiceAudioSessionProvider = Provider<PracticeAudioSessionCoordinator>(
  (ref) => AudioSessionPracticeCoordinator(),
);

final practicePlayerProvider = Provider<PracticePlayback>((ref) {
  final paths = SidecarPaths.current();
  final player = PracticePlayer(
    backend: ref.watch(practiceAudioBackendProvider),
    audioSession: ref.watch(practiceAudioSessionProvider),
    tempDirectory: Directory(
      '${paths.tempDirectory}${Platform.pathSeparator}practice-cache',
    ),
  );
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
});

/// 錄音與播放共用的工作階段交接介面（backend-design.md 介面 33；REQ-18）。
abstract interface class PracticeAudioSessionCoordinator {
  Future<void> prepareForRecording();

  Future<void> finishRecording();

  Future<void> prepareForPlayback();

  Future<void> finishPlayback();
}

/// 以 audio_session 協調 record 與 just_audio 的狀態切換（AT-18-08）。
class AudioSessionPracticeCoordinator
    implements PracticeAudioSessionCoordinator {
  bool _recordingActive = false;
  bool _playbackActive = false;

  @override
  Future<void> prepareForRecording() async {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration.speech().copyWith(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      ),
    );
    if (!await session.setActive(true)) {
      throw const DomainException(ErrorCodes.decodeFailed, '無法啟用錄音工作階段');
    }
    _recordingActive = true;
  }

  @override
  Future<void> finishRecording() async {
    if (!_recordingActive) return;
    _recordingActive = false;
    final session = await AudioSession.instance;
    await session.setActive(false);
  }

  @override
  Future<void> prepareForPlayback() async {
    await finishRecording();
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    if (!await session.setActive(true)) {
      throw const DomainException(ErrorCodes.decodeFailed, '無法啟用播放工作階段');
    }
    _playbackActive = true;
  }

  @override
  Future<void> finishPlayback() async {
    if (!_playbackActive) return;
    _playbackActive = false;
    final session = await AudioSession.instance;
    await session.setActive(false);
  }
}

class _NoopPracticeAudioSessionCoordinator
    implements PracticeAudioSessionCoordinator {
  const _NoopPracticeAudioSessionCoordinator();

  @override
  Future<void> finishPlayback() async {}

  @override
  Future<void> finishRecording() async {}

  @override
  Future<void> prepareForPlayback() async {}

  @override
  Future<void> prepareForRecording() async {}
}

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

  Future<String> renderRowToFile(PracticeRow row, Pcm originalPcm);

  Future<void> playRow(
    PracticeRow row,
    Pcm originalPcm, {
    void Function()? onReady,
  });

  Future<void> playPcm(Pcm pcm, {void Function()? onReady});

  Future<void> stop();
}

abstract interface class PracticeAudioBackend {
  Future<void> setFilePath(String path);

  /// Future 必須在播放完成、停止或失敗後才結束（AT-18-08）。
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
    PracticeAudioSessionCoordinator? audioSession,
    PracticeEngine? engine,
    this.tempDirectory,
  }) : audioSession =
           audioSession ?? const _NoopPracticeAudioSessionCoordinator(),
       _engine = engine ?? PracticeEngine();

  final PracticeAudioBackend backend;
  final PracticeAudioSessionCoordinator audioSession;
  final PracticeEngine _engine;
  final Directory? tempDirectory;
  int _playRunId = 0;

  /// 停止播放並清除本 session 的練習 WAV 快取（guardrails #62）。
  Future<void> dispose() async {
    await stop();
    final directory = tempDirectory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

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
    final runId = ++_playRunId;
    await backend.stop();
    final path = await renderStepToFile(step, originalPcm, repeatN: repeatN);
    if (runId != _playRunId) return;
    await backend.setFilePath(path);
    if (runId != _playRunId) return;
    onReady?.call();
    if (runId != _playRunId) return;
    await _playToCompletion();
  }

  @override
  Future<String> renderRowToFile(PracticeRow row, Pcm originalPcm) async {
    final rendered = await _engine.renderBlockRow(row, originalPcm);
    final dir =
        tempDirectory ??
        Directory(
          '${Directory.systemTemp.path}${Platform.pathSeparator}syllable_repeater_steps',
        );
    await dir.create(recursive: true);
    final file = File(
      '${dir.path}${Platform.pathSeparator}row-${_rowCacheKey(row, originalPcm)}.wav',
    );
    if (!await file.exists()) {
      await file.writeAsBytes(encodeWav(rendered), flush: true);
    }
    return file.path;
  }

  @override
  Future<void> playRow(
    PracticeRow row,
    Pcm originalPcm, {
    void Function()? onReady,
  }) async {
    final runId = ++_playRunId;
    await backend.stop();
    final path = await renderRowToFile(row, originalPcm);
    if (runId != _playRunId) return;
    await backend.setFilePath(path);
    if (runId != _playRunId) return;
    onReady?.call();
    if (runId != _playRunId) return;
    await _playToCompletion();
  }

  @override
  Future<void> playPcm(Pcm pcm, {void Function()? onReady}) async {
    final runId = ++_playRunId;
    await backend.stop();
    final dir =
        tempDirectory ??
        Directory(
          '${Directory.systemTemp.path}${Platform.pathSeparator}syllable_repeater_steps',
        );
    await dir.create(recursive: true);
    final file = File(
      '${dir.path}${Platform.pathSeparator}'
      'recording-preview-${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    try {
      await file.writeAsBytes(encodeWav(pcm), flush: true);
      if (runId != _playRunId) return;
      await backend.setFilePath(file.path);
      if (runId != _playRunId) return;
      onReady?.call();
      if (runId != _playRunId) return;
      await _playToCompletion();
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  @override
  Future<void> stop() async {
    _playRunId++;
    try {
      await backend.stop();
    } finally {
      await audioSession.finishPlayback();
    }
  }

  Future<void> _playToCompletion() async {
    await audioSession.prepareForPlayback();
    try {
      await backend.play();
    } finally {
      await audioSession.finishPlayback();
    }
  }

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

  String _rowCacheKey(PracticeRow row, Pcm originalPcm) {
    final parts = <String>[
      'row=${row.index}',
      'rate=${originalPcm.sampleRate}',
      'len=${originalPcm.samples.length}',
    ];
    for (final block in row.blocks) {
      parts
        ..add('repeat=${block.repeatN}')
        ..add('silence=${block.silenceFactor}')
        ..add('grouped=${block.isGrouped}')
        ..addAll(
          block.sourceRanges.map((range) => '${range.startMs}-${range.endMs}'),
        );
    }
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
