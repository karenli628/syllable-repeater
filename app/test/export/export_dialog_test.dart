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
  List<PracticeStep>? lastMergedSteps;

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

Finder _exportButton() => find.widgetWithText(FilledButton, '匯出');

void main() {
  group('PracticeExportDialog（FP5）', () {
    testWidgets('未勾選任何步驟時匯出 disabled', (tester) async {
      await _pumpDialog(tester, service: _FakeExportService());

      await tester.tap(find.widgetWithText(OutlinedButton, '選擇位置'));
      await tester.pump();
      for (var i = 1; i <= 5; i++) {
        await tester.tap(find.textContaining('第 $i 步'));
        await tester.pump();
      }

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
        find.widgetWithText(CheckboxListTile, '第 1 步：much'),
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
  });
}
