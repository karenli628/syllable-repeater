// AI-Generate
import 'dart:typed_data';

/// 檔案 IO 抽象（task-split 1.3；M5：Domain 不直接依賴 dart:io，
/// 保留 Phase 2 手機端 PWA/商店 App 雙路徑之編譯可能，REQ-09）。
///
/// 實作要求（backend-design.md §4.2.1 寫入防線）：
/// - [writeBytesAtomic] 必須 temp→原子搬移，中斷不留半成品（AT-08-08、AT-04-04）。
abstract interface class FileIo {
  Future<Uint8List> readBytes(String path);

  /// 原子寫入：先寫同目錄暫存檔，成功後 rename 至 [path]；失敗不得留下半成品。
  Future<void> writeBytesAtomic(String path, Uint8List bytes);

  Future<bool> exists(String path);

  Future<void> delete(String path);

  /// 於受管理的 temp 目錄建立暫存檔路徑（App 啟動時 [clearTemp] 清空）。
  Future<String> createTempFilePath(String suffix);

  /// 清空 temp 目錄（App 啟動時呼叫；M10 巡檢項：temp 無殘留錄音）。
  Future<void> clearTemp();
}
