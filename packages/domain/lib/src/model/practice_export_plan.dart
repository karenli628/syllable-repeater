// AI-Generate
import 'practice_units.dart';
import 'time_range.dart';

/// 四層匯出的原音資料源（REQ-21 AT-21-04～07）。
///
/// 型別刻意不提供 Demucs 或錄音選項，從結構上維持 M1／M10。
enum PracticeExportAudioSource {
  currentSentenceOriginal,
  keptSegmentsFromOriginal,
  savedV3SentenceOriginal,
}

/// 四層匯出的排列資料源（REQ-21 AT-21-04～07）。
enum PracticeExportArrangementSource { wholeSentence, currentUnsaved, savedV3 }

/// 四層匯出的單元範圍（REQ-21 AT-21-04～06）。
enum PracticeExportUnitScope { all, selected, current }

/// 音訊來源的不可變身分；只描述原音 provenance，不持有 PCM。
class PracticeExportAudioSourceRef {
  final PracticeExportAudioSource choice;
  final String audioFingerprint;
  final String? lessonId;
  final List<TimeRange> sourceRanges;

  PracticeExportAudioSourceRef({
    required this.choice,
    required this.audioFingerprint,
    this.lessonId,
    required List<TimeRange> sourceRanges,
  }) : sourceRanges = List.unmodifiable(sourceRanges) {
    _validateIdentity(
      audioFingerprint: audioFingerprint,
      lessonId: lessonId,
      sourceRanges: sourceRanges,
      name: 'audioSourceRef',
    );
  }
}

/// 排列來源的不可變內容與 provenance 快照（backend-design.md §3.1.1）。
class PracticeExportArrangementSnapshot {
  final PracticeExportArrangementSource choice;
  final String audioFingerprint;
  final String? lessonId;
  final List<TimeRange> sourceRanges;
  final PracticeUnits units;

  PracticeExportArrangementSnapshot({
    required this.choice,
    required this.audioFingerprint,
    this.lessonId,
    required List<TimeRange> sourceRanges,
    required this.units,
  }) : sourceRanges = List.unmodifiable(sourceRanges) {
    _validateIdentity(
      audioFingerprint: audioFingerprint,
      lessonId: lessonId,
      sourceRanges: sourceRanges,
      name: 'arrangementSnapshot',
    );
    if (units.units.isEmpty) {
      throw ArgumentError('arrangementSnapshot.units 不可為空');
    }
  }
}

/// 四層匯出的不可變計畫（backend-design.md 介面 38；REQ-21）。
class PracticeExportPlan {
  final PracticeExportAudioSourceRef audioSourceRef;
  final PracticeExportArrangementSnapshot arrangementSnapshot;
  final PracticeExportUnitScope unitScope;
  final Set<int> unitIndexes;
  final Map<int, PracticeUnitExportConfig> unitOverrides;

  PracticeExportPlan._({
    required this.audioSourceRef,
    required this.arrangementSnapshot,
    required this.unitScope,
    required Set<int> unitIndexes,
    required Map<int, PracticeUnitExportConfig> unitOverrides,
  })  : unitIndexes = Set.unmodifiable(unitIndexes),
        unitOverrides = Map.unmodifiable(unitOverrides);

  PracticeExportAudioSource get audioSource => audioSourceRef.choice;

  PracticeExportArrangementSource get arrangementSource =>
      arrangementSnapshot.choice;
}

/// 將四層選擇解析成單一快照，並在產生任何檔案前 fail closed。
abstract final class PracticeExportPlanner {
  /// 建立匯出計畫；fingerprint、lessonId 或 range 不相容即拒絕（AT-21-07）。
  static PracticeExportPlan build({
    required PracticeExportAudioSourceRef audioSourceRef,
    required PracticeExportArrangementSnapshot arrangementSnapshot,
    required PracticeExportUnitScope unitScope,
    Set<int> selectedUnitIndices = const {},
    int? currentUnitIndex,
    Map<int, PracticeUnitExportConfig> unitOverrides = const {},
  }) {
    if (!isCompatible(
      audioSourceRef: audioSourceRef,
      arrangementSnapshot: arrangementSnapshot,
    )) {
      throw ArgumentError(
        '匯出音訊與排列來源不相容：fingerprint、lessonId 或 range 不一致',
      );
    }

    final available =
        arrangementSnapshot.units.units.map((unit) => unit.index).toSet();
    if (available.isEmpty || available.any((index) => index < 1)) {
      throw ArgumentError('arrangementSnapshot 必須包含正整數索引的單元');
    }
    final indexes = switch (unitScope) {
      PracticeExportUnitScope.all => available,
      PracticeExportUnitScope.selected => selectedUnitIndices,
      PracticeExportUnitScope.current => {
          if (currentUnitIndex != null) currentUnitIndex,
        },
    };
    if (indexes.isEmpty) {
      throw ArgumentError('$unitScope 至少需要一個單元');
    }
    if (!available.containsAll(indexes)) {
      throw ArgumentError('unitIndexes 包含不存在的單元');
    }
    if (!indexes.containsAll(unitOverrides.keys)) {
      throw ArgumentError('unitOverrides 只能套用在本次匯出的單元');
    }
    for (final config in unitOverrides.values) {
      config.validate();
    }

    return PracticeExportPlan._(
      audioSourceRef: audioSourceRef,
      arrangementSnapshot: arrangementSnapshot,
      unitScope: unitScope,
      unitIndexes: indexes,
      unitOverrides: unitOverrides,
    );
  }

  /// 供 UI 只列出與目前音訊來源相容的排列（frontend-design 功能點 17）。
  static bool isCompatible({
    required PracticeExportAudioSourceRef audioSourceRef,
    required PracticeExportArrangementSnapshot arrangementSnapshot,
  }) {
    if (audioSourceRef.audioFingerprint !=
            arrangementSnapshot.audioFingerprint ||
        audioSourceRef.lessonId != arrangementSnapshot.lessonId) {
      return false;
    }
    return arrangementSnapshot.sourceRanges.every(
      (inner) => audioSourceRef.sourceRanges.any(
        (outer) => outer.startMs <= inner.startMs && outer.endMs >= inner.endMs,
      ),
    );
  }
}

void _validateIdentity({
  required String audioFingerprint,
  required String? lessonId,
  required List<TimeRange> sourceRanges,
  required String name,
}) {
  if (audioFingerprint.trim().isEmpty) {
    throw ArgumentError('$name.audioFingerprint 不可空白');
  }
  if (lessonId != null && lessonId.trim().isEmpty) {
    throw ArgumentError('$name.lessonId 若提供則不可空白');
  }
  if (sourceRanges.isEmpty) {
    throw ArgumentError('$name.sourceRanges 不可為空');
  }
}
