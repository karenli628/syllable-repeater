// AI-Generate
import 'dart:io';

import 'package:path/path.dart' as p;

/// 管理 App 單次執行的暫存生命週期（backend-design §1.5；guardrails #62）。
///
/// 每個 session 以非阻塞檔案鎖表示仍存活；新 session 只清除能取得鎖的
/// 舊目錄，因此多開 App 時不會互刪仍在使用的暫存資料。
class ManagedTempSession {
  static final Set<String> _activeDirectories = <String>{};

  ManagedTempSession._({
    required this.rootDirectory,
    required this.directory,
    required RandomAccessFile lease,
  }) : _lease = lease;

  final Directory rootDirectory;
  final Directory directory;
  RandomAccessFile? _lease;

  /// 清除已失效 session，並建立、鎖定本次 session 目錄。
  static Future<ManagedTempSession> start({
    required Directory rootDirectory,
  }) async {
    await rootDirectory.create(recursive: true);
    await _deleteUnlockedSessions(rootDirectory);
    final token = '$pid-${DateTime.now().microsecondsSinceEpoch}';
    final directory = Directory(p.join(rootDirectory.path, 'session-$token'));
    await directory.create(recursive: true);
    final leaseFile = File(p.join(directory.path, '.lease'));
    final lease = await leaseFile.open(mode: FileMode.append);
    await lease.lock(FileLock.exclusive);
    _activeDirectories.add(p.normalize(directory.absolute.path));
    return ManagedTempSession._(
      rootDirectory: rootDirectory,
      directory: directory,
      lease: lease,
    );
  }

  /// 建立受管理的單次作業目錄；名稱只用於人類診斷。
  Future<Directory> createOperationDirectory(String purpose) async {
    final safePurpose =
        purpose.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9_-]+'), '-');
    if (safePurpose.isEmpty) {
      throw ArgumentError('purpose 不可空白，got "$purpose"');
    }
    final operation = Directory(
      p.join(
        directory.path,
        '$safePurpose-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await operation.create(recursive: true);
    return operation;
  }

  /// 只允許刪除本 session 內的作業目錄，避免誤刪使用者目的地。
  Future<void> deleteOperationDirectory(Directory operation) async {
    if (!p.isWithin(directory.path, operation.path)) {
      throw ArgumentError(
        'operation 必須位於目前 session，got ${operation.path}',
      );
    }
    if (await operation.exists()) await operation.delete(recursive: true);
  }

  /// 結束本次 session；釋放鎖後刪除整個 session 快取。
  Future<void> dispose() async {
    final lease = _lease;
    if (lease == null) return;
    _lease = null;
    _activeDirectories.remove(p.normalize(directory.absolute.path));
    try {
      await lease.unlock();
    } finally {
      await lease.close();
    }
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  static Future<void> _deleteUnlockedSessions(Directory root) async {
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory ||
          !p.basename(entity.path).startsWith('session-')) {
        continue;
      }
      if (_activeDirectories.contains(p.normalize(entity.absolute.path))) {
        continue;
      }
      final leaseFile = File(p.join(entity.path, '.lease'));
      if (!await leaseFile.exists()) {
        await entity.delete(recursive: true);
        continue;
      }
      RandomAccessFile? lease;
      var mayDelete = false;
      try {
        lease = await leaseFile.open(mode: FileMode.append);
        await lease.lock(FileLock.exclusive);
        mayDelete = true;
        await lease.unlock();
      } on FileSystemException {
        mayDelete = false;
      } finally {
        await lease?.close();
      }
      if (mayDelete && await entity.exists()) {
        await entity.delete(recursive: true);
      }
    }
  }
}
