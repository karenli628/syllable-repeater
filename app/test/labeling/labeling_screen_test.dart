// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/labeling/labeling_controller.dart';
import 'package:syllable_repeater_app/features/labeling/labeling_screen.dart';

void main() {
  testWidgets('AT-11-10 段落標籤顯示真實階段，未知總量不捏造百分比', (tester) async {
    final controller = _FakeLabelingController(
      const LabelingUiState(
        audioPath: '/opening.wav',
        status: LabelingRunStatus.opening,
        progress: LabelOpenProgress(
          stage: LabelOpenStage.decoding,
          completedUnits: 0,
        ),
      ),
    );
    await _pump(
      tester,
      controller: controller,
      picker: _FakeLabelingFilePicker(),
    );

    expect(find.text('解碼音檔'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.descendant(
              of: find.byKey(const ValueKey('labeling-real-progress')),
              matching: find.byType(LinearProgressIndicator),
            ),
          )
          .value,
      isNull,
    );
  });

  testWidgets('dirty 開新音檔選擇取消時保留原 session', (tester) async {
    final controller = _FakeLabelingController(_dirtyState());
    final picker = _FakeLabelingFilePicker(audioPath: '/new.wav');
    await _pump(tester, controller: controller, picker: picker);

    expect(find.text('選擇音檔'), findsNothing);
    await tester.tap(find.text('瀏覽'));
    await tester.pumpAndSettle();
    expect(find.text('有未儲存的標籤'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(controller.openedPaths, isEmpty);
    expect(controller.state.audioPath, '/old.wav');
    expect(controller.state.dirty, isTrue);
  });

  testWidgets('dirty 選擇放棄後才開啟新音檔且不寫標籤', (tester) async {
    final controller = _FakeLabelingController(_dirtyState());
    final picker = _FakeLabelingFilePicker(audioPath: '/new.wav');
    await _pump(tester, controller: controller, picker: picker);

    await tester.tap(find.text('瀏覽'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放棄並開啟'));
    await tester.pumpAndSettle();

    expect(controller.openedPaths, ['/new.wav']);
    expect(picker.savedPaths, isEmpty);
  });

  testWidgets('dirty 選擇儲存後開啟會先寫入再載入新音檔', (tester) async {
    final controller = _FakeLabelingController(_dirtyState());
    final picker = _FakeLabelingFilePicker(
      audioPath: '/new.wav',
      savePath: '/tmp/old.abolabel',
    );
    await _pump(tester, controller: controller, picker: picker);

    await tester.tap(find.text('瀏覽'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存後開啟'));
    await tester.pumpAndSettle();

    expect(picker.savedPaths, ['/tmp/old.abolabel']);
    expect(controller.openedPaths, ['/new.wav']);
    expect(controller.state.dirty, isFalse);
  });

  testWidgets('找到既有標籤時選擇載入會替換 session', (tester) async {
    final controller = _FakeLabelingController(
      _dirtyState().copyWith(
        session: _cleanSession('saved'),
        existingLabelPath: '/tmp/existing.abolabel',
      ),
      loadOnRequest: true,
    );
    final picker = _FakeLabelingFilePicker(audioPath: '/new.wav');
    await _pump(tester, controller: controller, picker: picker);

    await tester.tap(find.text('瀏覽'));
    await tester.pumpAndSettle();
    // Fake openAudio exposes the existing path; screen must present the prompt.
    expect(find.text('找到既有標籤'), findsOneWidget);
    await tester.tap(find.text('載入'));
    await tester.pumpAndSettle();
    expect(controller.loadedExisting, isTrue);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeLabelingController controller,
  required _FakeLabelingFilePicker picker,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        labelingControllerProvider.overrideWith(() => controller),
        labelingFilePickerProvider.overrideWithValue(picker),
      ],
      child: const MaterialApp(home: Scaffold(body: LabelingScreen())),
    ),
  );
  await tester.pump();
}

LabelingUiState _dirtyState() => LabelingUiState(
  audioPath: '/old.wav',
  session: _dirtySession(),
  status: LabelingRunStatus.ready,
);

LabelSession _dirtySession() {
  final session = _cleanSession('old');
  session.insertBoundary(1500);
  return session;
}

LabelSession _cleanSession(String text) => LabelSession(
  audioFingerprint: 'e' * 64,
  audioDurationMs: 3000,
  segments: [
    Segment(
      id: 'segment-1',
      startMs: 0,
      endMs: 3000,
      text: text,
      language: 'en',
      confidence: 0,
    ),
  ],
);

class _FakeLabelingController extends LabelingController {
  _FakeLabelingController(this.initial, {this.loadOnRequest = false});

  final LabelingUiState initial;
  final bool loadOnRequest;
  final List<String> openedPaths = [];
  bool loadedExisting = false;

  @override
  LabelingUiState build() => initial;

  @override
  Future<void> openAudio(
    String path, {
    bool separateVocals = true,
    String language = 'en',
  }) async {
    openedPaths.add(path);
    state = state.copyWith(
      audioPath: path,
      status: LabelingRunStatus.ready,
      existingLabelPath: loadOnRequest ? '/tmp/existing.abolabel' : null,
    );
  }

  @override
  Future<bool> saveLabel(String destPath) async {
    state.session?.markSaved();
    state = state.copyWith(existingLabelPath: destPath);
    return true;
  }

  @override
  Future<bool> loadExistingLabel() async {
    loadedExisting = true;
    state = state.copyWith(
      session: _cleanSession('loaded'),
      existingLabelPath: null,
    );
    return true;
  }
}

class _FakeLabelingFilePicker implements LabelingFilePicker {
  _FakeLabelingFilePicker({this.audioPath, this.savePath});

  final String? audioPath;
  final String? savePath;
  final List<String> savedPaths = [];

  @override
  Future<String?> pickAudioPath() async => audioPath;

  @override
  Future<String?> pickLabelOpenPath() async => null;

  @override
  Future<String?> pickLabelSavePath() async {
    if (savePath != null) savedPaths.add(savePath!);
    return savePath;
  }
}
