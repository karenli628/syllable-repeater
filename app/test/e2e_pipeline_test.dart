// AI-Generate
// e2e: 用真 sidecar（FFmpeg + whisper.cpp small.en）+ 使用者金標準 mp3 跑通
// UI 端 provider→controller→pipeline 全鏈路，驗證 11 音節與 editor tab 切換。
// 依賴 .local-tools/ 就緒；缺任一項會 markTestSkipped 而非失敗。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/editor/editor_controller.dart';
import 'package:syllable_repeater_app/features/import_analysis/analysis_controller.dart';
import 'package:syllable_repeater_app/main.dart';
import 'package:syllable_repeater_app/shared/infra/infra_analysis_runner.dart';
import 'package:syllable_repeater_app/shared/infra/sidecar_paths.dart';
import 'package:syllable_repeater_app/shared/navigation.dart';

const _goldenMp3 =
    '/Users/karen_files/vibercoding project/syllable repeater/step up your coding skills to a new level.mp3';

void main() {
  testWidgets('e2e: 真檔匯入→分析→11 音節→進入編輯器', (tester) async {
    final paths = SidecarPaths.dev();
    final missing = paths.missingPaths();
    if (missing.isNotEmpty) {
      markTestSkipped('sidecar not ready: ${missing.join(", ")}');
      return;
    }
    if (!File(_goldenMp3).existsSync()) {
      markTestSkipped('golden mp3 missing at $_goldenMp3');
      return;
    }

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(SyllableRepeaterApp(overrides: <Override>[
      analysisRunnerProvider
          .overrideWithValue(InfraAnalysisRunner.fromPaths(paths)),
    ]));

    // 從 ProviderScope 內部後代 element 拿 container；直接找 ProviderScope 本身
    // 會被 containerOf 拒絕（見 Riverpod 3.x 該方法實作）。
    final descendantElement = tester.element(find.byType(MaterialApp));
    final container = ProviderScope.containerOf(descendantElement);

    final controller = container.read(analysisControllerProvider.notifier);
    await controller.selectAudioPath(_goldenMp3);
    await tester.pump();
    expect(container.read(analysisControllerProvider).selectedAudioPath,
        _goldenMp3);
    expect(container.read(analysisControllerProvider).error, isNull,
        reason: 'ffprobe 前置時長檢查應對 3 秒音檔通過');

    // 真 sidecar 走 Process.start，需要真時間；testWidgets 預設 fake time，
    // 要用 tester.runAsync 進入真 async 環境等 pipeline 完成。
    await tester.runAsync(() async {
      await controller.start();
    });
    await tester.pump();

    final finalState = container.read(analysisControllerProvider);

    expect(finalState.status, AnalysisRunStatus.done,
        reason: 'pipeline 應走到 done；error=${finalState.error?.code}');
    expect(finalState.result, isNotNull);
    expect(finalState.result!.syllables.length, 11,
        reason: '金標準句 Step up your coding skills to a new level → 11 音節');

    // 觸發 done 態的「進入編輯器」按鈕（透過 provider 直接切，等同按鈕行為）
    expect(container.read(appShellSelectedIndexProvider),
        AppSection.importAnalysis.sectionIndex);
    container
        .read(appShellSelectedIndexProvider.notifier)
        .select(AppSection.editor.sectionIndex);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(appShellSelectedIndexProvider),
        AppSection.editor.sectionIndex);
    expect(find.text('音節校正'), findsOneWidget);
    // EditorController 自 pipeline done 事件載入 11 音節（listen loadFrom）
    await tester.pump();
    final editorSyllables =
        container.read(editorControllerProvider).syllables;
    expect(editorSyllables.length, 11);
    // UI SyllableChipsRow 應顯示音節文字（金標準句尾 `vel` 為 unique）
    expect(find.text('vel'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
