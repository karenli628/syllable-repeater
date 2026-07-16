// AI-Generate
import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/labeling/labeling_controller.dart';

void main() {
  test('AT-11-14 clip 後 seek 相對 0ms，位置串流換回全檔絕對毫秒', () async {
    final backend = _FakeLabelingAudioBackend();
    final preview = JustAudioLabelingSegmentPreview(backend: backend);
    final positions = <int>[];
    final subscription = preview.positionsMs.listen(positions.add);
    addTearDown(subscription.cancel);
    final segment = Segment(
      id: 'middle',
      startMs: 2000,
      endMs: 3500,
      text: 'middle',
      language: 'en',
      confidence: 1,
    );

    await preview.play('/tmp/source.wav', segment);
    backend.emitRelativePosition(400);
    await Future<void>.delayed(Duration.zero);

    expect(backend.loadedPath, '/tmp/source.wav');
    expect(backend.clipStart, const Duration(milliseconds: 2000));
    expect(backend.clipEnd, const Duration(milliseconds: 3500));
    expect(backend.seekPosition, Duration.zero);
    expect(positions, [2400]);
  });
}

class _FakeLabelingAudioBackend implements LabelingAudioBackend {
  final _positions = StreamController<Duration>.broadcast();
  String? loadedPath;
  Duration? clipStart;
  Duration? clipEnd;
  Duration? seekPosition;

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Future<void> setFilePath(String path) async => loadedPath = path;

  @override
  Future<void> setClip({required Duration start, required Duration end}) async {
    clipStart = start;
    clipEnd = end;
  }

  @override
  Future<void> seek(Duration position) async => seekPosition = position;

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  void emitRelativePosition(int milliseconds) {
    _positions.add(Duration(milliseconds: milliseconds));
  }
}
