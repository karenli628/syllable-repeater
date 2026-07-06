// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final lessonSessionControllerProvider =
    NotifierProvider<LessonSessionController, LessonSessionState>(
      LessonSessionController.new,
    );

class LessonSessionState {
  const LessonSessionState({
    this.lesson,
    this.pcm,
    this.waveformPeaks = const [],
    this.sourcePath,
  });

  final Lesson? lesson;
  final Pcm? pcm;
  final List<WaveformPeak> waveformPeaks;
  final String? sourcePath;

  bool get hasLesson => lesson != null && pcm != null;
}

class LessonSessionController extends Notifier<LessonSessionState> {
  static const int waveformBucketCount = 512;

  @override
  LessonSessionState build() => const LessonSessionState();

  Future<void> hydrateLesson(Lesson lesson, {String? sourcePath}) async {
    final pcm = decodeWav(
      lesson.originalAudioBytes,
      failureMessage: '課件 WAV 解碼失敗',
    );
    final peaks = computeWaveformPeaks(pcm, bucketCount: waveformBucketCount);
    state = LessonSessionState(
      lesson: lesson,
      pcm: pcm,
      waveformPeaks: peaks,
      sourcePath: sourcePath,
    );
  }

  void clear() {
    state = const LessonSessionState();
  }
}
