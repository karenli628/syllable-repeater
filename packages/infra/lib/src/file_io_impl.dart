// AI-Generate
import 'dart:io';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:path/path.dart' as p;

/// FileIo 的 macOS 實作（task-split 1.3）。
///
/// 寫入防線（backend-design §4.2.1）：
/// - 原子寫入 = 同目錄暫存檔 + rename（同一 volume 內 rename 為原子操作）；
///   任何失敗路徑都會清掉暫存檔，不留半成品（AT-08-08、AT-04-04）。
/// - temp 目錄由本類管理，App 啟動時 [clearTemp] 清空（M10 巡檢：無殘留錄音）。
class AtomicFileIo implements FileIo {
  /// 受管理的暫存目錄（如 ~/Library/Application Support/SyllableRepeater/temp）。
  final String tempDirPath;

  int _tempCounter = 0;

  AtomicFileIo({required this.tempDirPath});

  @override
  Future<Uint8List> readBytes(String path) => File(path).readAsBytes();

  @override
  Future<void> writeBytesAtomic(String path, Uint8List bytes) async {
    final dir = p.dirname(path);
    final tmp = File(p.join(dir,
        '.${p.basename(path)}.tmp-${DateTime.now().microsecondsSinceEpoch}'));
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(path);
    } catch (e) {
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {
          // 清理失敗不掩蓋原始錯誤。
        }
      }
      rethrow;
    }
  }

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<String> createTempFilePath(String suffix) async {
    await Directory(tempDirPath).create(recursive: true);
    return p.join(tempDirPath,
        'tmp-${DateTime.now().microsecondsSinceEpoch}-${_tempCounter++}$suffix');
  }

  @override
  Future<void> clearTemp() async {
    final dir = Directory(tempDirPath);
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {
        // 個別檔案清不掉不阻斷啟動；下次啟動再試。
      }
    }
  }
}
