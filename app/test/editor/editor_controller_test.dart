// AI-Generate
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/editor/editor_controller.dart';

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

    test('dragStart→dragUpdate→dragEnd 成功：syllables 更新、undoStack push、'
        'lastSnappedMs 存值', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctl = container.read(editorControllerProvider.notifier);
      ctl.loadFrom(_sample());

      final pcm = _flatPcm();
      ctl.dragStart(2); // boundary 2 分開 ex/cel（原 600ms）
      ctl.dragUpdate(700);
      ctl.dragEnd(pcm);

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
  });
}
