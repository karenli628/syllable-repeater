// AI-Generate
// `.abopack v3` 複合封包與四層匯出計畫 TDD（REQ-21／Task 10.4、10.7）。
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('CourseBundleEngine（REQ-21／M1／M10）', () {
    test('AT-21-01 v3 可同時保存原始音訊、標籤、單句、排列與最新進度', () async {
      final io = _MemoryFileIo();
      final lesson = _lesson();
      final arrangement = PracticeArrangement(
        lessonId: lesson.id,
        rows: [
          PracticeRow(
            index: 1,
            blocks: [PracticeBlock(syllables: lesson.syllables)],
          ),
        ],
        updatedAt: DateTime.utc(2026, 7, 15, 9),
      );
      final bundle = CourseBundle(
        courseName: '英文課',
        sourceAudioName: 'AAA.m4a',
        audioFingerprint: 'sha256-full-original',
        audioDurationMs: 8000,
        originalAudioBytes: Uint8List.fromList([9, 8, 7, 6]),
        labels: CourseLabels(
          language: 'en',
          separateVocals: true,
          segments: [
            Segment(
              id: 's1',
              startMs: 1000,
              endMs: 3000,
              text: 'rain think',
              language: 'en',
              confidence: 0.9,
              disposition: SegmentDisposition.kept,
            ),
            Segment(
              id: 'noise',
              startMs: 3000,
              endMs: 4000,
              text: 'sound',
              language: 'en',
              confidence: 0.4,
              disposition: SegmentDisposition.discarded,
              note: '狀聲詞',
            ),
          ],
        ),
        sentenceLesson: lesson,
        sentenceSourceRange: TimeRange(1000, 2000),
        arrangement: arrangement,
        latestProgress: PortableLatestProgress(
          lastCompletedUnitIndex: 1,
          difficulty: Difficulty.easy,
          intervalIndex: 3,
          nextDue: DateTime.utc(2026, 7, 22),
          updatedAt: DateTime.utc(2026, 7, 15, 10),
          rhythmScore: 0.8,
          intonationScore: 0.7,
        ),
      );

      await CourseBundleEngine(fileIo: io).write(bundle, '/tmp/v3.abopack');
      final restored =
          await CourseBundleEngine(fileIo: io).read('/tmp/v3.abopack');

      expect(restored.originalAudioBytes, [9, 8, 7, 6]);
      expect(restored.labels!.segments, hasLength(2));
      expect(restored.labels!.segments.last.disposition,
          SegmentDisposition.discarded);
      expect(restored.sentenceLesson!.originalAudioBytes,
          lesson.originalAudioBytes);
      expect(restored.sentenceSourceRange, TimeRange(1000, 2000));
      expect(restored.arrangement!.rows.single.repeatN, 3);
      expect(restored.latestProgress!.difficulty, Difficulty.easy);
      expect(restored.latestProgress!.lastCompletedUnitIndex, 1);
    });

    test('AT-21-02 v3 只含必要原始音訊也可開啟', () async {
      final io = _MemoryFileIo();
      final bundle = CourseBundle(
        courseName: '只有原音',
        sourceAudioName: 'raw.m4a',
        audioFingerprint: 'fingerprint',
        audioDurationMs: 1000,
        originalAudioBytes: Uint8List.fromList([1, 2, 3]),
      );

      await CourseBundleEngine(fileIo: io).write(bundle, '/tmp/audio.abopack');
      final restored =
          await CourseBundleEngine(fileIo: io).read('/tmp/audio.abopack');

      expect(restored.labels, isNull);
      expect(restored.sentenceLesson, isNull);
      expect(restored.arrangement, isNull);
      expect(restored.latestProgress, isNull);
    });

    test('AT-21-03 v1／v2 舊課件可轉成 v3 聚合讀取', () async {
      final io = _MemoryFileIo();
      final lesson = _lesson();
      await LessonPackEngine(fileIo: io).write(lesson, '/tmp/v2.abopack');

      final restored =
          await CourseBundleEngine(fileIo: io).read('/tmp/v2.abopack');

      expect(restored.sentenceLesson!.id, lesson.id);
      expect(restored.originalAudioBytes, lesson.originalAudioBytes);
      expect(restored.arrangement, lesson.arrangement);
    });

    test('AT-21-08 可攜進度與封包不得夾帶顯示偏好、attempt 或錄音', () async {
      final io = _MemoryFileIo();
      final bundle = CourseBundle(
        courseName: '隱私檢查',
        sourceAudioName: 'raw.wav',
        audioFingerprint: 'fingerprint',
        audioDurationMs: 1000,
        originalAudioBytes: Uint8List.fromList([1, 2, 3]),
        latestProgress: PortableLatestProgress(
          lastCompletedUnitIndex: 1,
          difficulty: Difficulty.normal,
          intervalIndex: 0,
          nextDue: DateTime.utc(2026, 7, 15),
          updatedAt: DateTime.utc(2026, 7, 15),
        ),
      );

      await CourseBundleEngine(fileIo: io).write(bundle, '/tmp/safe.abopack');
      final text =
          String.fromCharCodes(io.bytesAt('/tmp/safe.abopack')).toLowerCase();
      for (final forbidden in [
        'transcriptdisplay',
        'attempts',
        'recording',
        'pcmPath'.toLowerCase(),
        'api_key',
      ]) {
        expect(text, isNot(contains(forbidden)));
      }
    });
  });

  group('PracticeExportPlan 四層選擇（REQ-21）', () {
    test('AT-21-05 已保存 v3＋指定單元＋匯出覆寫不寫回來源設定', () {
      final override = const PracticeUnitExportConfig(
        repeatN: 2,
        silenceFactor: 1.5,
      );
      final savedUnits = PracticeUnits(
        mode: PracticeMode.auto,
        units: PracticeEngine()
            .buildSteps(_lesson().syllables, 1)
            .map(AutoPracticeUnit.new)
            .toList(growable: false),
        stale: false,
      );
      final plan = PracticeExportPlanner.build(
        audioSourceRef: PracticeExportAudioSourceRef(
          choice: PracticeExportAudioSource.savedV3SentenceOriginal,
          audioFingerprint: 'fingerprint-A',
          lessonId: 'lesson-1',
          sourceRanges: [TimeRange(42300, 45100)],
        ),
        arrangementSnapshot: PracticeExportArrangementSnapshot(
          choice: PracticeExportArrangementSource.savedV3,
          audioFingerprint: 'fingerprint-A',
          lessonId: 'lesson-1',
          sourceRanges: [TimeRange(42300, 45100)],
          units: savedUnits,
        ),
        unitScope: PracticeExportUnitScope.selected,
        selectedUnitIndices: const {2},
        unitOverrides: {2: override},
      );

      expect(plan.arrangementSnapshot.units, same(savedUnits));
      expect(plan.unitOverrides[2]!.repeatN, 2);
      expect(plan.unitOverrides[2]!.silenceFactor, 1.5);
    });

    test('AT-21-04 目前草稿快照不會誤用 v3 舊排列', () {
      final currentUnits = PracticeUnits(
        mode: PracticeMode.auto,
        units: PracticeEngine()
            .buildSteps(_lesson().syllables, 1)
            .map(AutoPracticeUnit.new)
            .toList(growable: false),
        stale: false,
      );
      final plan = PracticeExportPlanner.build(
        audioSourceRef: PracticeExportAudioSourceRef(
          choice: PracticeExportAudioSource.currentSentenceOriginal,
          audioFingerprint: 'fingerprint-A',
          lessonId: 'lesson-1',
          sourceRanges: [TimeRange(42300, 45100)],
        ),
        arrangementSnapshot: PracticeExportArrangementSnapshot(
          choice: PracticeExportArrangementSource.currentUnsaved,
          audioFingerprint: 'fingerprint-A',
          lessonId: 'lesson-1',
          sourceRanges: [TimeRange(42300, 45100)],
          units: currentUnits,
        ),
        unitScope: PracticeExportUnitScope.current,
        currentUnitIndex: 2,
      );

      expect(plan.unitIndexes, const {2});
      expect(
        plan.arrangementSnapshot.choice,
        PracticeExportArrangementSource.currentUnsaved,
      );
    });

    test('AT-21-06 保留段只輸出勾選的第 2、4 段且覆寫不回寫來源', () {
      final steps = [
        for (var i = 1; i <= 4; i++)
          PracticeStep(
            index: i,
            syllables: [
              Syllable(
                text: 'segment-$i',
                startMs: i * 1000,
                endMs: i * 1000 + 500,
                wordIndex: 0,
                needsReview: false,
              ),
            ],
            sourceRanges: [TimeRange(i * 1000, i * 1000 + 500)],
            totalDurationMs: 500,
          ),
      ];
      final keptUnits = PracticeUnits(
        mode: PracticeMode.wholeSentence,
        units: steps
            .map((step) => WholeSentencePracticeUnit(step))
            .toList(growable: false),
        stale: false,
      );
      const override = PracticeUnitExportConfig(
        repeatN: 2,
        silenceFactor: 1,
      );
      final plan = PracticeExportPlanner.build(
        audioSourceRef: PracticeExportAudioSourceRef(
          choice: PracticeExportAudioSource.keptSegmentsFromOriginal,
          audioFingerprint: 'fingerprint-A',
          sourceRanges: [TimeRange(0, 6000)],
        ),
        arrangementSnapshot: PracticeExportArrangementSnapshot(
          choice: PracticeExportArrangementSource.wholeSentence,
          audioFingerprint: 'fingerprint-A',
          sourceRanges: steps.expand((step) => step.sourceRanges).toList(),
          units: keptUnits,
        ),
        unitScope: PracticeExportUnitScope.selected,
        selectedUnitIndices: const {2, 4},
        unitOverrides: const {2: override, 4: override},
      );

      expect(plan.unitIndexes, const {2, 4});
      expect(plan.unitOverrides[2]!.repeatN, 2);
      expect((keptUnits.units[1] as WholeSentencePracticeUnit).repeatN, 3);
    });

    test('AT-21-07 fingerprint、lessonId 或 range 錯配皆明確拒絕', () {
      final units = PracticeUnits(
        mode: PracticeMode.auto,
        units: PracticeEngine()
            .buildSteps(_lesson().syllables, 1)
            .map(AutoPracticeUnit.new)
            .toList(growable: false),
        stale: false,
      );
      PracticeExportArrangementSnapshot arrangement({
        String fingerprint = 'fingerprint-A',
        String? lessonId = 'lesson-1',
        TimeRange? range,
      }) =>
          PracticeExportArrangementSnapshot(
            choice: PracticeExportArrangementSource.currentUnsaved,
            audioFingerprint: fingerprint,
            lessonId: lessonId,
            sourceRanges: [range ?? TimeRange(42300, 45100)],
            units: units,
          );
      final audio = PracticeExportAudioSourceRef(
        choice: PracticeExportAudioSource.currentSentenceOriginal,
        audioFingerprint: 'fingerprint-A',
        lessonId: 'lesson-1',
        sourceRanges: [TimeRange(42300, 45100)],
      );

      for (final incompatible in [
        arrangement(fingerprint: 'fingerprint-B'),
        arrangement(lessonId: 'lesson-2'),
        arrangement(range: TimeRange(45100, 45200)),
      ]) {
        expect(
          () => PracticeExportPlanner.build(
            audioSourceRef: audio,
            arrangementSnapshot: incompatible,
            unitScope: PracticeExportUnitScope.all,
          ),
          throwsArgumentError,
        );
      }
    });

    test('選取範圍沒有單元時拒絕', () {
      final units = PracticeUnits(
        mode: PracticeMode.auto,
        units: [
          AutoPracticeUnit(
            PracticeEngine().buildSteps(_lesson().syllables, 1).first,
          ),
        ],
        stale: false,
      );

      expect(
        () => PracticeExportPlanner.build(
          audioSourceRef: PracticeExportAudioSourceRef(
            choice: PracticeExportAudioSource.currentSentenceOriginal,
            audioFingerprint: 'fingerprint-A',
            lessonId: 'lesson-1',
            sourceRanges: [TimeRange(0, 1000)],
          ),
          arrangementSnapshot: PracticeExportArrangementSnapshot(
            choice: PracticeExportArrangementSource.currentUnsaved,
            audioFingerprint: 'fingerprint-A',
            lessonId: 'lesson-1',
            sourceRanges: [TimeRange(0, 1000)],
            units: units,
          ),
          unitScope: PracticeExportUnitScope.selected,
        ),
        throwsArgumentError,
      );
    });
  });
}

Lesson _lesson() {
  final syllables = [
    Syllable(
      text: 'rain',
      startMs: 0,
      endMs: 500,
      wordIndex: 0,
      needsReview: false,
    ),
    Syllable(
      text: 'think',
      startMs: 500,
      endMs: 1000,
      wordIndex: 1,
      needsReview: false,
    ),
  ];
  return Lesson(
    id: 'lesson-1',
    title: 'rain think',
    audioRelPath: 'audio/sentence.wav',
    originalAudioBytes: Uint8List.fromList([4, 5, 6]),
    contentHash: 'stale',
    words: [
      Word(text: 'rain', startMs: 0, endMs: 500, index: 0),
      Word(text: 'think', startMs: 500, endMs: 1000, index: 1),
    ],
    syllables: syllables,
    translations: const [],
    prosody: null,
    practiceConfig: const PracticeConfig(repeatN: 3),
    updatedAt: DateTime.utc(2026, 7, 15),
  );
}

class _MemoryFileIo implements FileIo {
  final _files = <String, Uint8List>{};

  Uint8List bytesAt(String path) => _files[path]!;

  @override
  Future<void> clearTemp() async {}

  @override
  Future<String> createTempFilePath(String suffix) async => '/tmp/x$suffix';

  @override
  Future<void> delete(String path) async => _files.remove(path);

  @override
  Future<bool> exists(String path) async => _files.containsKey(path);

  @override
  Future<Uint8List> readBytes(String path) async => _files[path]!;

  @override
  Future<void> writeBytesAtomic(String path, Uint8List bytes) async {
    _files[path] = Uint8List.fromList(bytes);
  }
}
