// AI-Generate

/// 課件內練習設定（backend-design.md §3.1.1 Lesson.practiceConfig）。
class PracticeConfig {
  final int repeatN;

  const PracticeConfig({required this.repeatN})
      : assert(repeatN >= 1 && repeatN <= 10);

  PracticeConfig.checked({required this.repeatN}) {
    if (repeatN < 1 || repeatN > 10) {
      throw ArgumentError('PracticeConfig.repeatN 必須介於 1..10');
    }
  }

  Map<String, dynamic> toJson() => {'repeatN': repeatN};

  factory PracticeConfig.fromJson(Map<String, dynamic> json) =>
      PracticeConfig.checked(repeatN: json['repeatN'] as int);

  @override
  bool operator ==(Object other) =>
      other is PracticeConfig && other.repeatN == repeatN;

  @override
  int get hashCode => repeatN.hashCode;
}
