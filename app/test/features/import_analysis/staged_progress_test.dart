// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/import_analysis/analysis_controller.dart';
import 'package:syllable_repeater_app/features/import_analysis/widgets/staged_progress.dart';

Widget _wrap(AnalysisUiState state) => MaterialApp(
  home: Scaffold(body: StagedProgress(state: state)),
);

void main() {
  testWidgets('AT-12-06 真實讀檔 50% 直接呈現在匯入進度條', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AnalysisUiState(
          selectedAudioPath: '/tmp/audio.wav',
          status: AnalysisRunStatus.loading,
          importProgress: AudioImportProgress(
            stage: AudioImportStage.readingBytes,
            bytesRead: 50,
            totalBytes: 100,
          ),
        ),
      ),
    );

    expect(find.text('讀取音檔資料'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .5,
    );
  });

  testWidgets('AT-12-07 驗證完成後才顯示音檔已就緒', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AnalysisUiState(
          selectedAudioPath: '/tmp/audio.wav',
          status: AnalysisRunStatus.ready,
          importProgress: AudioImportProgress(stage: AudioImportStage.ready),
          readySource: AudioReadySource(
            path: '/tmp/audio.wav',
            bytesRead: 100,
            durationMs: 1000,
          ),
        ),
      ),
    );

    expect(find.text('音檔已就緒'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });
}
