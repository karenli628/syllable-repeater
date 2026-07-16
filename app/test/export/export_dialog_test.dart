// AI-Generate
import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infra/infra.dart';
import 'package:syllable_repeater_app/features/export/export_dialog.dart';

class _FakeExportService implements PracticeExportService {
  _FakeExportService({this.error, this.gate});

  final DomainException? error;
  final Completer<void>? gate;
  int exportStepCount = 0;
  int exportMergedCount = 0;
  int exportUnitsCount = 0;
  PracticeUnits? lastUnits;
  Map<int, PracticeUnitExportConfig>? lastOverrides;
  List<PracticeStep>? lastMergedSteps;

  @override
  Future<PracticeExportResult> exportUnits(
    PracticeUnits units,
    Pcm originalPcm,
    String destPath, {
    Map<int, PracticeUnitExportConfig> overrides = const {},
  }) async {
    exportUnitsCount++;
    lastUnits = units;
    lastOverrides = Map.unmodifiable(overrides);
    final autoSteps = units.units
        .whereType<AutoPracticeUnit>()
        .map((unit) => unit.step)
        .toList();
    if (autoSteps.isNotEmpty) {
      exportMergedCount++;
      lastMergedSteps = autoSteps;
    }
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return PracticeExportResult(
      path: destPath,
      totalDurationMs: 20400,
      silenceGapsMs: const [1200, 1800, 2400, 3000],
    );
  }

  @override
  Future<PracticeExportResult> exportMerged(
    List<PracticeStep> steps,
    Pcm originalPcm,
    String destPath,
  ) async {
    exportMergedCount++;
    lastMergedSteps = steps;
    if (gate != null) {
      await gate!.future;
    }
    if (error != null) {
      throw error!;
    }
    return PracticeExportResult(
      path: destPath,
      totalDurationMs: 20400,
      silenceGapsMs: const [1200, 1800, 2400, 3000],
    );
  }

  @override
  Future<PracticeExportResult> exportStep(
    PracticeStep step,
    Pcm originalPcm,
    String destPath,
  ) async {
    exportStepCount++;
    if (error != null) {
      throw error!;
    }
    return PracticeExportResult(
      path: destPath,
      totalDurationMs: step.totalDurationMs,
      silenceGapsMs: const [],
    );
  }
}

class _FakePicker implements ExportSaveLocationPicker {
  _FakePicker(this.path);

  final String? path;
  int pickCount = 0;

  @override
  Future<String?> pickMp3Path({required String suggestedName}) async {
    pickCount++;
    return path;
  }
}

class _NoopRevealer implements ExportedFileRevealer {
  @override
  Future<void> reveal(String path) async {}
}

List<Syllable> _syllables() => [
  Syllable(
    text: 'thank',
    startMs: 0,
    endMs: 200,
    wordIndex: 0,
    needsReview: false,
  ),
  Syllable(
    text: 'you',
    startMs: 200,
    endMs: 400,
    wordIndex: 1,
    needsReview: false,
  ),
  Syllable(
    text: 've',
    startMs: 400,
    endMs: 600,
    wordIndex: 2,
    needsReview: true,
  ),
  Syllable(
    text: 'ry',
    startMs: 600,
    endMs: 800,
    wordIndex: 2,
    needsReview: true,
  ),
  Syllable(
    text: 'much',
    startMs: 800,
    endMs: 1200,
    wordIndex: 3,
    needsReview: false,
  ),
];

Pcm _pcm() => Pcm(
  Int16List.fromList(List.generate(1200, (i) => 1000 + i)),
  sampleRate: 1000,
);

List<PracticeStep> _steps() => PracticeEngine().buildSteps(_syllables(), 3);

Future<void> _pumpDialog(
  WidgetTester tester, {
  required _FakeExportService service,
  _FakePicker? picker,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        practiceExportServiceProvider.overrideWithValue(service),
        exportSaveLocationPickerProvider.overrideWithValue(
          picker ?? _FakePicker('/tmp/practice.mp3'),
        ),
        exportedFileRevealerProvider.overrideWithValue(_NoopRevealer()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: PracticeExportDialog(steps: _steps(), originalPcm: _pcm()),
        ),
      ),
    ),
  );
}

Future<void> _pumpCustomDialog(
  WidgetTester tester, {
  required _FakeExportService service,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        practiceExportServiceProvider.overrideWithValue(service),
        exportSaveLocationPickerProvider.overrideWithValue(
          _FakePicker('/tmp/custom-practice.mp3'),
        ),
        exportedFileRevealerProvider.overrideWithValue(_NoopRevealer()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: PracticeExportDialog(
            steps: const [],
            units: PracticeUnits(
              mode: PracticeMode.custom,
              units: [
                CustomPracticeUnit(
                  PracticeRow(
                    index: 1,
                    blocks: [
                      PracticeBlock(
                        syllables: [
                          Syllable(
                            text: 'custom',
                            startMs: 0,
                            endMs: 200,
                            wordIndex: 0,
                            needsReview: false,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              stale: false,
            ),
            originalPcm: _pcm(),
          ),
        ),
      ),
    ),
  );
}

Finder _exportButton() => find.widgetWithText(FilledButton, '匯出');

void main() {
  group('PracticeExportDialog（FP5）', () {
    testWidgets('AT-21-07 頁面只顯示與所選音訊 provenance 相容的排列', (tester) async {
      final customUnits = PracticeUnits(
        mode: PracticeMode.custom,
        units: [
          CustomPracticeUnit(
            PracticeRow(
              index: 1,
              blocks: [
                PracticeBlock(syllables: [_syllables().first]),
              ],
            ),
          ),
        ],
        stale: false,
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showPracticeExportDialog(
                  context,
                  steps: _steps(),
                  originalPcm: _pcm(),
                  audioSources: {
                    PracticeExportAudioSource
                        .currentSentenceOriginal: PracticeExportAudioCandidate(
                      pcm: _pcm(),
                      ref: PracticeExportAudioSourceRef(
                        choice:
                            PracticeExportAudioSource.currentSentenceOriginal,
                        audioFingerprint: 'fingerprint-A',
                        lessonId: 'current-lesson',
                        sourceRanges: [TimeRange(0, 5000)],
                      ),
                    ),
                    PracticeExportAudioSource
                        .savedV3SentenceOriginal: PracticeExportAudioCandidate(
                      pcm: _pcm(),
                      ref: PracticeExportAudioSourceRef(
                        choice:
                            PracticeExportAudioSource.savedV3SentenceOriginal,
                        audioFingerprint: 'fingerprint-A',
                        lessonId: 'saved-lesson',
                        sourceRanges: [TimeRange(10000, 15000)],
                      ),
                    ),
                  },
                  arrangementSources: {
                    PracticeExportAudioSource.currentSentenceOriginal: {
                      PracticeExportArrangementSource
                          .wholeSentence: PracticeExportArrangementCandidate(
                        snapshot: PracticeExportArrangementSnapshot(
                          choice: PracticeExportArrangementSource.wholeSentence,
                          audioFingerprint: 'fingerprint-A',
                          lessonId: 'current-lesson',
                          sourceRanges: [TimeRange(0, 5000)],
                          units: PracticeUnits(
                            mode: PracticeMode.auto,
                            units: _steps().map(AutoPracticeUnit.new).toList(),
                            stale: false,
                          ),
                        ),
                      ),
                      PracticeExportArrangementSource
                          .currentUnsaved: PracticeExportArrangementCandidate(
                        snapshot: PracticeExportArrangementSnapshot(
                          choice:
                              PracticeExportArrangementSource.currentUnsaved,
                          audioFingerprint: 'fingerprint-A',
                          lessonId: 'current-lesson',
                          sourceRanges: [TimeRange(0, 5000)],
                          units: customUnits,
                        ),
                      ),
                    },
                    PracticeExportAudioSource.savedV3SentenceOriginal: {
                      PracticeExportArrangementSource.savedV3:
                          PracticeExportArrangementCandidate(
                            snapshot: PracticeExportArrangementSnapshot(
                              choice: PracticeExportArrangementSource.savedV3,
                              audioFingerprint: 'fingerprint-A',
                              lessonId: 'saved-lesson',
                              sourceRanges: [TimeRange(10000, 15000)],
                              units: customUnits,
                            ),
                          ),
                    },
                  },
                ),
                child: const Text('開啟四層匯出'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('開啟四層匯出'));
      await tester.pumpAndSettle();

      expect(find.text('目前單句原音'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<PracticeExportAudioSource>));
      await tester.pumpAndSettle();
      expect(find.text('已儲存 v3 單句原音'), findsOneWidget);
      await tester.tap(find.text('已儲存 v3 單句原音'));
      await tester.pumpAndSettle();
      expect(find.text('已儲存 v3 排列'), findsOneWidget);
      await tester.tap(
        find.byType(DropdownButton<PracticeExportArrangementSource>),
      );
      await tester.pumpAndSettle();
      expect(find.text('目前未儲存排列'), findsNothing);
    });

    testWidgets('AT-16-09 顯示資料源、排列、範圍與單元設定四層', (tester) async {
      await _pumpCustomDialog(tester, service: _FakeExportService());

      expect(find.text('1. 音訊資料源'), findsOneWidget);
      expect(find.text('2. 排列資料源'), findsOneWidget);
      expect(find.text('3. 匯出範圍'), findsOneWidget);
      expect(find.text('4. 各單元最後調整'), findsOneWidget);
      expect(find.text('目前單句原音'), findsOneWidget);
      expect(find.text('目前未儲存排列'), findsOneWidget);
    });

    testWidgets('AT-04-07 可一鍵全部取消並恢復全部選取', (tester) async {
      await _pumpDialog(tester, service: _FakeExportService());

      expect(find.text('已選 5/5'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '全部取消'));
      await tester.pump();

      expect(find.text('已選 0/5'), findsOneWidget);
      expect(tester.widget<FilledButton>(_exportButton()).onPressed, isNull);

      await tester.tap(find.widgetWithText(TextButton, '全部選取'));
      await tester.pump();
      expect(find.text('已選 5/5'), findsOneWidget);
    });

    testWidgets('未勾選任何步驟時匯出 disabled', (tester) async {
      await _pumpDialog(tester, service: _FakeExportService());

      await tester.tap(find.widgetWithText(OutlinedButton, '選擇位置'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, '全部取消'));
      await tester.pump();

      final button = tester.widget<FilledButton>(_exportButton());
      expect(button.onPressed, isNull);
    });

    testWidgets('勾選多步匯出成功後顯示總長與 silenceGapsMs', (tester) async {
      final service = _FakeExportService();
      await _pumpDialog(tester, service: service);

      await tester.tap(find.widgetWithText(OutlinedButton, '選擇位置'));
      await tester.pump();
      await tester.tap(_exportButton());
      await tester.pumpAndSettle();

      expect(service.exportMergedCount, 1);
      expect(service.lastMergedSteps, hasLength(5));
      expect(find.text('總長 20400 ms'), findsOneWidget);
      expect(find.text('靜音間隔：1200, 1800, 2400, 3000 ms'), findsOneWidget);
      expect(find.textContaining('/tmp/practice.mp3'), findsWidgets);
    });

    testWidgets('目的地不可寫錯誤就地顯示，並保留勾選狀態', (tester) async {
      final service = _FakeExportService(
        error: const DomainException(
          ErrorCodes.exportDestUnwritable,
          '目的地無法寫入',
        ),
      );
      await _pumpDialog(tester, service: service);

      await tester.tap(find.widgetWithText(OutlinedButton, '選擇位置'));
      await tester.pump();
      await tester.tap(_exportButton());
      await tester.pumpAndSettle();

      expect(find.text('無法寫入匯出位置'), findsOneWidget);
      final first = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, '第 1 單元：much'),
      );
      expect(first.value, isTrue);
    });

    testWidgets('匯出中顯示進度且匯出按鈕 disabled', (tester) async {
      final gate = Completer<void>();
      final service = _FakeExportService(gate: gate);
      await _pumpDialog(tester, service: service);

      await tester.tap(find.widgetWithText(OutlinedButton, '選擇位置'));
      await tester.pump();
      await tester.tap(_exportButton());
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(tester.widget<FilledButton>(_exportButton()).onPressed, isNull);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('總長 20400 ms'), findsOneWidget);
    });

    testWidgets('FP14.2 custom 選取項走 PracticeUnits 匯出且保留 row', (tester) async {
      final service = _FakeExportService();
      await _pumpCustomDialog(tester, service: service);

      expect(find.text('第 1 單元：custom'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, '選擇位置'));
      await tester.pump();
      await tester.tap(_exportButton());
      await tester.pumpAndSettle();

      expect(service.exportUnitsCount, 1);
      expect(service.lastUnits?.mode, PracticeMode.custom);
      expect(service.lastUnits?.units.single, isA<CustomPracticeUnit>());
      expect(service.lastOverrides?[1]?.repeatN, 3);
      expect(service.lastOverrides?[1]?.silenceFactor, 1);
    });

    testWidgets('AT-16-08 逐單元調整只送出本次匯出覆寫', (tester) async {
      final service = _FakeExportService();
      await _pumpCustomDialog(tester, service: service);

      expect(
        find.byKey(const ValueKey('export-unit-1-repeat-value')),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('export-unit-1-repeat-down')),
      );
      await tester.tap(find.byKey(const ValueKey('export-unit-1-repeat-down')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('export-unit-1-silence-down')),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, '選擇位置'));
      await tester.pump();
      await tester.tap(_exportButton());
      await tester.pumpAndSettle();

      expect(service.lastOverrides?[1]?.repeatN, 2);
      expect(service.lastOverrides?[1]?.silenceFactor, 0.5);
      final original = service.lastUnits!.units.single as CustomPracticeUnit;
      expect(original.row.repeatN, 3, reason: '匯出設定不得回寫 row');
      expect(original.row.silenceFactor, 1);
    });
  });
}
