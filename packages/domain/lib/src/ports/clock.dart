// AI-Generate
/// 時間源抽象（task-split 1.4）。
/// M8 歸檔 168h 判定與 SRS 排程一律經本介面取得時間，使測試可注入假時鐘（CT-08）。
abstract interface class Clock {
  DateTime now();
}
