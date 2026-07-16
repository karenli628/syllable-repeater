// AI-Generate

/// 分析成功後建立且在草稿生命週期保持不變的課件身分
/// （backend-design.md 介面 36；REQ-15／guardrails #53）。
class DraftLessonIdentity {
  DraftLessonIdentity({required this.lessonId}) {
    if (lessonId.trim().isEmpty) {
      throw ArgumentError('DraftLessonIdentity.lessonId 不可空白');
    }
  }

  final String lessonId;
}
