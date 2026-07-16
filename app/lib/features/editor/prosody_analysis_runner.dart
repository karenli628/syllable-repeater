// AI-Generate
import 'dart:isolate';

import 'package:domain/domain.dart';

/// 音韻分析背景執行介面（frontend-design 功能點 12；AT-13-09）。
abstract interface class ProsodyAnalysisRunner {
  /// 在 UI isolate 之外分析唯讀 PCM；不得改寫來源音訊（M1）。
  Future<Prosody> analyze(Pcm pcm, List<Syllable> syllables);
}

/// 以 Dart isolate 執行既有純 Dart [ProsodyAnalyzer]。
class IsolateProsodyAnalysisRunner implements ProsodyAnalysisRunner {
  const IsolateProsodyAnalysisRunner(this._analyzer);

  final ProsodyAnalyzer _analyzer;

  @override
  Future<Prosody> analyze(Pcm pcm, List<Syllable> syllables) => Isolate.run(
    () => _analyzer.analyze(pcm, syllables),
    debugName: 'editor-prosody-analysis',
  );
}
