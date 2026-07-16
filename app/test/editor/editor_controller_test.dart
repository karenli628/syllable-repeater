// AI-Generate
import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/editor/editor_controller.dart';
import 'package:syllable_repeater_app/features/editor/prosody_analysis_runner.dart';

Pcm _flatPcm({int seconds = 3, int value = 100}) {
  final samples = Int16List(44100 * seconds);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = value;
  }
  return Pcm(samples);
}

List<Syllable> _sample() => [
  Syllable(
    text: 'she',
    startMs: 0,
    endMs: 200,
    wordIndex: 0,
    needsReview: false,
  ),
  Syllable(
    text: 'has',
    startMs: 200,
    endMs: 400,
    wordIndex: 1,
    needsReview: false,
  ),
  Syllable(
    text: 'ex',
    startMs: 400,
    endMs: 600,
    wordIndex: 2,
    needsReview: true,
  ),
  Syllable(
    text: 'cel',
    startMs: 600,
    endMs: 800,
    wordIndex: 2,
    needsReview: true,
  ),
  Syllable(
    text: 'lent',
    startMs: 800,
    endMs: 1000,
    wordIndex: 2,
    needsReview: true,
  ),
];

void main() {
  group('EditorController', () {
    test('loadFrom 初始化 syllables 並清空 undoStack', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctl = container.read(editorControllerProvider.notifier);
      ctl.loadFrom(_sample());

      final state = container.read(editorControllerProvider);
      expect(state.syllables.length, 5);
      expect(state.undoStack, isEmpty);
      expect(state.canUndo, isFalse);
      expect(state.prosody, isNull);
    });

    test('loadFrom 帶 PCM 時自動分析 prosody；pitch 抽不到不進 error', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctl = container.read(editorControllerProvider.notifier);
      ctl.loadFrom(_sample(), pcm: Pcm(Int16List(44100 * 2)));

      final state = container.read(editorControllerProvider);
      expect(state.prosodyValue, isNotNull);
      expect(state.prosodyValue!.rhythm, hasLength(5));
      expect(state.prosodyValue!.pitchAvailable, isFalse);
      expect(state.error, isNull);
      expect(state.showProsodyOverlay, isTrue);
    });

    test('setProsodyOverlay 切換韻律疊圖顯示狀態', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctl = container.read(editorControllerProvider.notifier);
      ctl.setProsodyOverlay(false);
      expect(
        container.read(editorControllerProvider).showProsodyOverlay,
        isFalse,
      );

      ctl.setProsodyOverlay(true);
      expect(
        container.read(editorControllerProvider).showProsodyOverlay,
        isTrue,
      );
    });

    test('AT-17-01 波形框選輸出半開時間範圍，首個 overlap 音節成為焦點', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctl = container.read(editorControllerProvider.notifier);
      ctl.loadFrom(_sample());

      ctl.beginTimeSelection(450);
      ctl.updateTimeSelection(850);
      ctl.endTimeSelection();

      final state = container.read(editorControllerProvider);
      expect(state.selectedTimeRange, TimeRange(450, 850));
      expect(state.selectedSyllableIndex, 2);
      final overlapped = state.syllables
          .where(
            (syllable) =>
                syllable.startMs < state.selectedTimeRange!.endMs &&
                syllable.endMs > state.selectedTimeRange!.startMs,
          )
          .map((syllable) => syllable.text);
      expect(overlapped, ['ex', 'cel', 'lent']);
    });

    test('AT-13-08 removeBoundary 提交後立即清空拖曳預覽', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctl = container.read(editorControllerProvider.notifier);
      ctl.loadLesson(_lessonWithArrangement(), pcm: _flatPcm());
      ctl.selectSyllable(2);
      ctl.dragStart(2);

      ctl.removeBoundary(2);

      final state = container.read(editorControllerProvider);
      expect(state.syllables, hasLength(4));
      expect(state.syllables[2].text, 'ex cel');
      expect(state.syllables[2].needsReview, isTrue);
      expect(state.selectedSyllableIndex, isNull);
      expect(state.undoStack, hasLength(1));
      expect(state.arrangement!.staleFlag, isTrue);
      expect(state.draggingBoundaryIndex, isNull);
      expect(state.draggingPreviewMs, isNull);
    });

    test('AT-13-08 insertBoundary 提交後立即清空拖曳預覽', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctl = container.read(editorControllerProvider.notifier);
      ctl.loadFrom(_sample());
      ctl.selectSyllable(3);
      ctl.dragStart(2);

      ctl.insertBoundary(2, 500, _flatPcm());

      final state = container.read(editorControllerProvider);
      expect(state.syllables, hasLength(6));
      expect(state.syllables[2].endMs, 500);
      expect(state.syllables[3].text, isEmpty);
      expect(state.syllables[3].needsReview, isTrue);
      expect(state.selectedSyllableIndex, 4);
      expect(state.undoStack, hasLength(1));
      expect(state.draggingBoundaryIndex, isNull);
      expect(state.draggingPreviewMs, isNull);
    });

    test('updateSyllableText 保留原文、空字串標記 needsReview 並可 undo', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctl = container.read(editorControllerProvider.notifier);
      ctl.loadFrom(_sample());

      ctl.updateSyllableText(2, 'excellent');
      var state = container.read(editorControllerProvider);
      expect(state.syllables[2].text, 'excellent');
      expect(state.syllables[2].originalText, 'ex');
      expect(state.syllables[2].needsReview, isFalse);

      ctl.updateSyllableText(2, '');
      state = container.read(editorControllerProvider);
      expect(state.syllables[2].text, isEmpty);
      expect(state.syllables[2].needsReview, isTrue);
      expect(state.undoStack, hasLength(2));

      ctl.undo();
      state = container.read(editorControllerProvider);
      expect(state.syllables[2].text, 'excellent');
      expect(state.syllables[2].originalText, 'ex');
    });

    test('校正 undo 最多保留最近四步，且排列 undo 不混入其中', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctl = container.read(editorControllerProvider.notifier);
      ctl.loadLesson(_lessonWithArrangement(), pcm: _flatPcm());

      for (var i = 0; i < 5; i++) {
        ctl.updateSyllableText(i, 'edited-$i');
      }

      var state = container.read(editorControllerProvider);
      expect(state.undoStack, hasLength(4));
      expect(state.arrangement!.undoDepth, 0);
      for (var i = 0; i < 4; i++) {
        ctl.undo();
      }
      state = container.read(editorControllerProvider);
      expect(state.syllables[0].text, 'edited-0');
      expect(state.syllables[4].text, 'lent');
      expect(state.canUndo, isFalse);
    });

    test('dragStart→dragUpdate→dragEnd 成功：syllables 更新、undoStack push、'
        'lastSnappedMs 存值', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctl = container.read(editorControllerProvider.notifier);
      ctl.loadFrom(_sample());

      final pcm = _flatPcm();
      ctl.dragStart(2); // boundary 2 分開 ex/cel（原 600ms）
      ctl.dragUpdate(700);
      ctl.dragEnd(pcm);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(editorControllerProvider);
      expect(state.isDragging, isFalse);
      expect(state.syllables[2].endMs, 700);
      expect(state.syllables[3].startMs, 700);
      expect(state.syllables[2].needsReview, isFalse);
      expect(state.syllables[3].needsReview, isFalse);
      expect(state.lastSnappedMs, 700);
      expect(state.undoStack, hasLength(1), reason: '成功更新後 undoStack 記一筆原快照');
      expect(state.error, isNull);
      expect(state.prosodyValue, isNotNull);
      expect(state.prosodyValue!.rhythm, hasLength(5));
    });

    test('AT-13-09 切點先提交，只有最後一代背景音韻結果可回寫', () async {
      final runner = _ControlledProsodyAnalysisRunner();
      final container = ProviderContainer(
        overrides: [prosodyAnalysisRunnerProvider.overrideWithValue(runner)],
      );
      addTearDown(container.dispose);
      final ctl = container.read(editorControllerProvider.notifier);
      ctl.loadLesson(_lessonWithArrangement(), pcm: _flatPcm());
      ctl.dragStart(2);

      ctl.removeBoundary(2);

      var state = container.read(editorControllerProvider);
      expect(state.syllables, hasLength(4), reason: '不得等待音韻分析才提交切點');
      expect(state.draggingBoundaryIndex, isNull);
      expect(state.draggingPreviewMs, isNull);
      expect(state.prosody, isA<AsyncLoading<Prosody>>());
      expect(runner.requests, hasLength(1));

      ctl.updateSyllableText(0, 'latest');
      expect(runner.requests, hasLength(2));

      runner.complete(
        0,
        _prosody(marker: 1, syllableCount: runner.requests[0].length),
      );
      await Future<void>.delayed(Duration.zero);
      state = container.read(editorControllerProvider);
      expect(state.prosody, isA<AsyncLoading<Prosody>>(), reason: '舊世代不得倒灌');

      runner.complete(
        1,
        _prosody(marker: 2, syllableCount: runner.requests[1].length),
      );
      await Future<void>.delayed(Duration.zero);
      state = container.read(editorControllerProvider);
      expect(state.syllables.first.text, 'latest');
      expect(state.prosodyValue!.intensity, [2]);
    });

    test('dragEnd 遇 ERR_BOUNDARY_INVALID：syllables 回彈、error 曝光', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctl = container.read(editorControllerProvider.notifier);
      ctl.loadFrom(_sample());
      final original = container.read(editorControllerProvider).syllables;

      final pcm = _flatPcm();
      ctl.dragStart(2);
      ctl.dragUpdate(350); // 越 ex 起點 400
      ctl.dragEnd(pcm);

      final state = container.read(editorControllerProvider);
      expect(state.syllables, equals(original));
      expect(state.error, isNotNull);
      expect(state.error!.code, ErrorCodes.boundaryInvalid);
      expect(state.undoStack, isEmpty, reason: '失敗不入 undo');
    });

    test('連續拖動只送最終值（AT-02-03）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctl = container.read(editorControllerProvider.notifier);
      ctl.loadFrom(_sample());

      final pcm = _flatPcm();
      ctl.dragStart(2);
      ctl.dragUpdate(650);
      ctl.dragUpdate(670);
      ctl.dragUpdate(700); // 最終值
      ctl.dragEnd(pcm);

      final state = container.read(editorControllerProvider);
      expect(state.syllables[2].endMs, 700);
      expect(state.undoStack, hasLength(1), reason: '只 push 一次原快照');
    });

    test('undo 從堆疊 pop 還原 syllables（AT-02-04）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctl = container.read(editorControllerProvider.notifier);
      ctl.loadFrom(_sample());
      final original = container.read(editorControllerProvider).syllables;

      final pcm = _flatPcm();
      ctl.dragStart(2);
      ctl.dragUpdate(700);
      ctl.dragEnd(pcm);
      expect(container.read(editorControllerProvider).syllables[2].endMs, 700);

      ctl.undo();
      final restored = container.read(editorControllerProvider).syllables;
      expect(restored, equals(original));
      expect(container.read(editorControllerProvider).canUndo, isFalse);
      expect(container.read(editorControllerProvider).lastSnappedMs, isNull);
    });

    test('dragEnd 無 PCM 時清拖動、不更動 syllables', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctl = container.read(editorControllerProvider.notifier);
      ctl.loadFrom(_sample());
      final original = container.read(editorControllerProvider).syllables;

      ctl.dragStart(2);
      ctl.dragUpdate(700);
      ctl.dragEnd(null);

      final state = container.read(editorControllerProvider);
      expect(state.isDragging, isFalse);
      expect(state.syllables, equals(original));
      expect(state.error, isNull);
      expect(state.undoStack, isEmpty);
    });

    test('dragStart 於無效 boundary index → 無效果', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctl = container.read(editorControllerProvider.notifier);
      ctl.loadFrom(_sample());

      ctl.dragStart(-1);
      ctl.dragStart(_sample().length - 1);

      expect(container.read(editorControllerProvider).isDragging, isFalse);
    });

    test('AT-15-08 音節刪除成功只標 Arrangement stale，不自動重排', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctl = container.read(editorControllerProvider.notifier);
      ctl.loadLesson(_lessonWithArrangement(), pcm: _flatPcm());
      final before = container.read(editorControllerProvider).arrangement!;
      final edited = AlignmentEngine().removeBoundary(
        _alignmentResult(container.read(editorControllerProvider).syllables),
        0,
      );

      ctl.applySyllableEdit(edited, updatedAt: _t1);

      final state = container.read(editorControllerProvider);
      expect(state.syllables, hasLength(4));
      expect(state.arrangement!.staleFlag, isTrue);
      expect(state.arrangement!.rows, hasLength(before.rows.length));
      expect(
        state.arrangement!.rows.first.blocks.first.syllables.first.text,
        before.rows.first.blocks.first.syllables.first.text,
      );
    });

    test('AT-15-08 拖動但總數未變不誤標 stale', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctl = container.read(editorControllerProvider.notifier);
      ctl.loadLesson(_lessonWithArrangement(), pcm: _flatPcm());

      ctl.dragStart(2);
      ctl.dragUpdate(700);
      ctl.dragEnd(_flatPcm());

      expect(
        container.read(editorControllerProvider).arrangement!.staleFlag,
        isFalse,
      );
    });

    test('AT-15-08 明示保留清旗標；重新生成則依新音節數取代排列', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctl = container.read(editorControllerProvider.notifier);
      ctl.loadLesson(_lessonWithArrangement(), pcm: _flatPcm());
      final edited = AlignmentEngine().removeBoundary(
        _alignmentResult(container.read(editorControllerProvider).syllables),
        0,
      );
      ctl.applySyllableEdit(edited, updatedAt: _t1);

      ctl.keepCurrentArrangement(updatedAt: _t2);
      var state = container.read(editorControllerProvider);
      expect(state.arrangement!.staleFlag, isFalse);
      expect(state.arrangement!.rows, hasLength(5), reason: '保留不得重排');

      ctl.applySyllableEdit(
        _alignmentResult([...state.syllables, _extraSyllable()]),
        updatedAt: _t3,
      );
      ctl.regenerateArrangement(updatedAt: _t4);
      state = container.read(editorControllerProvider);
      expect(state.syllables, hasLength(5));
      expect(state.arrangement!.rows, hasLength(5));
      expect(state.arrangement!.staleFlag, isFalse);
      expect(state.arrangement!.undoDepth, 0);
    });
  });
}

AlignmentResult _alignmentResult(List<Syllable> syllables) => AlignmentResult(
  words: const [],
  syllables: syllables,
  source: 'editor-test',
  confidence: 1,
);

Lesson _lessonWithArrangement() {
  final syllables = _sample();
  return Lesson(
    id: 'lesson-a',
    title: 'Lesson A',
    audioRelPath: 'audio/original.wav',
    originalAudioBytes: Uint8List.fromList([1]),
    contentHash: 'hash-a',
    words: [Word(text: 'sample', startMs: 0, endMs: 1000, index: 0)],
    syllables: syllables,
    translations: const [],
    prosody: null,
    practiceConfig: const PracticeConfig(repeatN: 3),
    arrangement: PracticeEngine().generateArrangement(
      syllables,
      lessonId: 'lesson-a',
      updatedAt: _t0,
    ),
    updatedAt: _t0,
  );
}

Syllable _extraSyllable() => Syllable(
  text: 'again',
  startMs: 1000,
  endMs: 1200,
  wordIndex: 0,
  needsReview: true,
);

final _t0 = DateTime.utc(2026, 7, 13, 11);
final _t1 = DateTime.utc(2026, 7, 13, 11, 1);
final _t2 = DateTime.utc(2026, 7, 13, 11, 2);
final _t3 = DateTime.utc(2026, 7, 13, 11, 3);
final _t4 = DateTime.utc(2026, 7, 13, 11, 4);

class _ControlledProsodyAnalysisRunner implements ProsodyAnalysisRunner {
  final List<List<Syllable>> requests = [];
  final List<Completer<Prosody>> _completers = [];

  @override
  Future<Prosody> analyze(Pcm pcm, List<Syllable> syllables) {
    requests.add(List<Syllable>.unmodifiable(syllables));
    final completer = Completer<Prosody>();
    _completers.add(completer);
    return completer.future;
  }

  void complete(int index, Prosody prosody) =>
      _completers[index].complete(prosody);
}

Prosody _prosody({required double marker, required int syllableCount}) =>
    Prosody(
      rhythm: List<double>.filled(syllableCount, marker),
      intensity: [marker],
      stress: List<double>.filled(syllableCount, marker),
      pitchContour: null,
      pitchAvailable: false,
    );
