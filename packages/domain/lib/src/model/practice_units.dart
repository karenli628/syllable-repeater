// AI-Generate
import 'practice_arrangement.dart';
import 'practice_step.dart';

/// 練習單元來源模式（backend-design.md 介面 30；REQ-16/M12）。
///
/// [auto] 只保留給 v1 相容匯出入口；v1.1 畫面 0 列時使用
/// [wholeSentence]，一鍵生成後使用 [custom]。
enum PracticeMode { auto, wholeSentence, custom }

/// auto／custom 共用的練習單元型別（backend-design.md 介面 30）。
sealed class PracticeUnit {
  int get index;
}

/// 既有句尾疊加單元；完整保留 v1 [PracticeStep] 語意。
final class AutoPracticeUnit implements PracticeUnit {
  final PracticeStep step;

  const AutoPracticeUnit(this.step);

  @override
  int get index => step.index;
}

/// 自由排列為 0 列時的完整單句隱含單元（REQ-16 AT-16-01）。
final class WholeSentencePracticeUnit implements PracticeUnit {
  final PracticeStep step;
  final int repeatN;
  final double silenceFactor;

  WholeSentencePracticeUnit(
    this.step, {
    this.repeatN = PracticeRow.defaultRepeatN,
    this.silenceFactor = PracticeRow.defaultSilenceFactor,
  }) {
    PracticeUnitExportConfig(
      repeatN: repeatN,
      silenceFactor: silenceFactor,
    ).validate();
  }

  @override
  int get index => step.index;
}

/// 使用者自訂排列單元；一列即一個練習單元。
final class CustomPracticeUnit implements PracticeUnit {
  final PracticeRow row;

  const CustomPracticeUnit(this.row);

  @override
  int get index => row.index;
}

/// 本次匯出才生效的整列外層覆寫（REQ-16 AT-16-08）。
class PracticeUnitExportConfig {
  final int repeatN;
  final double silenceFactor;

  const PracticeUnitExportConfig({
    required this.repeatN,
    required this.silenceFactor,
  })  : assert(repeatN >= PracticeBlock.minRepeatN &&
            repeatN <= PracticeBlock.maxRepeatN),
        assert(silenceFactor >= PracticeBlock.minSilenceFactor &&
            silenceFactor <= PracticeBlock.maxSilenceFactor);

  /// Domain 入口使用的完整驗證，包含 0.5 級距（AT-15-06）。
  void validate() {
    if (repeatN < PracticeBlock.minRepeatN ||
        repeatN > PracticeBlock.maxRepeatN) {
      throw ArgumentError('repeatN 須為 1–10，got $repeatN');
    }
    final steps = silenceFactor / PracticeBlock.silenceFactorStep;
    if (!silenceFactor.isFinite ||
        silenceFactor < PracticeBlock.minSilenceFactor ||
        silenceFactor > PracticeBlock.maxSilenceFactor ||
        (steps - steps.round()).abs() >= 0.000000001) {
      throw ArgumentError('silenceFactor 須為 0–20 且每次 0.5，got $silenceFactor');
    }
  }
}

/// M12 唯一模式判定結果（backend-design.md 介面 30）。
class PracticeUnits {
  final PracticeMode mode;
  final List<PracticeUnit> units;
  final bool stale;

  PracticeUnits({
    required this.mode,
    required List<PracticeUnit> units,
    required this.stale,
  }) : units = List.unmodifiable(units) {
    final matchesMode = switch (mode) {
      PracticeMode.auto => units.every((unit) => unit is AutoPracticeUnit),
      PracticeMode.wholeSentence =>
        units.every((unit) => unit is WholeSentencePracticeUnit),
      PracticeMode.custom => units.every((unit) => unit is CustomPracticeUnit),
    };
    if (!matchesMode) {
      throw ArgumentError('PracticeUnits.units 必須全部符合 mode=$mode');
    }
    if (mode != PracticeMode.custom && stale) {
      throw ArgumentError('$mode PracticeUnits.stale 必須為 false');
    }
  }
}
