// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final lessonSessionControllerProvider =
    NotifierProvider<LessonSessionController, LessonSessionState>(
      LessonSessionController.new,
    );

class LessonSessionState {
  const LessonSessionState({
    this.courseBundle,
    this.lesson,
    this.pcm,
    this.courseOriginalPcm,
    this.waveformPeaks = const [],
    this.sourcePath,
  });

  final CourseBundle? courseBundle;
  final Lesson? lesson;
  final Pcm? pcm;
  final Pcm? courseOriginalPcm;
  final List<WaveformPeak> waveformPeaks;
  final String? sourcePath;

  bool get hasLesson => lesson != null && pcm != null;
}

class LessonSessionController extends Notifier<LessonSessionState> {
  static const int waveformBucketCount = 512;

  @override
  LessonSessionState build() => const LessonSessionState();

  /// 還原 `.abopack v3`；只有原始音訊時保留封包內容但不假造 Lesson（REQ-21）。
  Future<void> hydrateCourseBundle(
    CourseBundle bundle, {
    String? sourcePath,
    Pcm? originalPcm,
  }) async {
    final lesson = bundle.sentenceLesson;
    if (lesson == null) {
      state = LessonSessionState(
        courseBundle: bundle,
        courseOriginalPcm: originalPcm,
        sourcePath: sourcePath,
      );
      return;
    }
    final decoded = _decodeLesson(lesson);
    state = LessonSessionState(
      courseBundle: bundle,
      lesson: lesson,
      pcm: decoded.pcm,
      courseOriginalPcm: originalPcm,
      waveformPeaks: decoded.peaks,
      sourcePath: sourcePath,
    );
  }

  Future<void> hydrateLesson(Lesson lesson, {String? sourcePath}) async {
    final decoded = _decodeLesson(lesson);
    state = LessonSessionState(
      lesson: lesson,
      pcm: decoded.pcm,
      waveformPeaks: decoded.peaks,
      sourcePath: sourcePath,
    );
  }

  ({Pcm pcm, List<WaveformPeak> peaks}) _decodeLesson(Lesson lesson) {
    final pcm = decodeWav(
      lesson.originalAudioBytes,
      failureMessage: '課件 WAV 解碼失敗',
    );
    return (
      pcm: pcm,
      peaks: computeWaveformPeaks(pcm, bucketCount: waveformBucketCount),
    );
  }

  void clear() {
    state = const LessonSessionState();
  }
}
