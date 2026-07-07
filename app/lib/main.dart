// AI-Generate
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:infra/infra.dart';

import 'features/import_analysis/analysis_controller.dart';
import 'shared/infra/infra_analysis_runner.dart';
import 'shared/infra/sidecar_paths.dart';
import 'shared/tokens.dart';
import 'shell/app_shell.dart';

void main() {
  final paths = SidecarPaths.current();
  final overrides = <Override>[
    // demucs 為選用（task-split 3.8）；未就緒時 pipeline 走「跳過分離降級」，
    // 但 UI 端要能顯示「未就緒，將降級使用原音」提示，故在此無條件覆寫。
    demucsReadyProvider.overrideWithValue(paths.demucsAvailable()),
  ];
  if (paths.missingPaths().isEmpty) {
    overrides
      ..add(
        analysisRunnerProvider.overrideWithValue(
          InfraAnalysisRunner.fromPaths(paths),
        ),
      )
      ..add(
        audioDurationProbeProvider.overrideWithValue(
          FfprobeDurationProbe(
            runner: const SidecarRunner(),
            ffprobePath: paths.ffprobePath,
          ),
        ),
      );
  }

  runApp(SyllableRepeaterApp(overrides: overrides));
}

class SyllableRepeaterApp extends StatelessWidget {
  const SyllableRepeaterApp({super.key, this.overrides = const []});

  final List<Override> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        title: 'Syllable Repeater',
        debugShowCheckedModeBanner: false,
        theme: AppTokens.lightTheme(),
        darkTheme: AppTokens.darkTheme(),
        home: const AppShell(),
      ),
    );
  }
}
