// AI-Generate
import 'package:domain/domain.dart';

/// 系統時鐘實作（task-split 1.4）。
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// 測試用假時鐘：CT-08（167h/169h 邊界）等時間敏感測試注入。
class FixedClock implements Clock {
  DateTime current;

  FixedClock(this.current);

  @override
  DateTime now() => current;

  void advance(Duration d) => current = current.add(d);
}
