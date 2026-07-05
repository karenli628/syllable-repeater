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
  final paths = SidecarPaths.dev();
  final overrides = <Override>[];
  if (paths.missingPaths().isEmpty) {
    overrides
      ..add(
        analysisRunnerProvider
            .overrideWithValue(InfraAnalysisRunner.fromPaths(paths)),
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
