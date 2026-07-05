// AI-Generate
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:path/path.dart' as p;

/// [WaveformPeaksCache] 的檔案系統實作（frontend-design 三-3、S1b task-split 拍板）。
///
/// 落點：`<tempDirectory>/waveform-<key>.json`；走 [FileIo] 原子寫入避免半成品。
/// key 由呼叫端從音檔內容衍生（例如 path＋size＋mtime 的 hash）；本類不做 key 生成。
///
/// 檔案格式：`{"schemaVersion":1,"peaks":[[min,max],[min,max],...]}`；欄位新增後
/// 舊格式檔案讀不到即當快取 miss（不擋流程，UI 端會 fallback 重算）。
class FileWaveformPeaksCache implements WaveformPeaksCache {
  static const _schemaVersion = 1;

  final FileIo fileIo;
  final String directory;

  const FileWaveformPeaksCache({required this.fileIo, required this.directory});

  String _pathFor(String key) {
    final safe = _sanitizeKey(key);
    return p.join(directory, 'waveform-$safe.json');
  }

  @override
  Future<List<WaveformPeak>?> load(String key) async {
    final path = _pathFor(key);
    if (!await fileIo.exists(path)) return null;
    try {
      final bytes = await fileIo.readBytes(path);
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['schemaVersion'] != _schemaVersion) return null;
      final raw = decoded['peaks'];
      if (raw is! List) return null;
      final peaks = <WaveformPeak>[];
      for (final item in raw) {
        if (item is! List || item.length != 2) return null;
        final min = (item[0] as num).toDouble();
        final max = (item[1] as num).toDouble();
        peaks.add(WaveformPeak(min, max));
      }
      return List.unmodifiable(peaks);
    } catch (_) {
      // 檔案毀損／schema 不符一律當作 miss，讓上層 fallback 重算即可；不擋 UI。
      return null;
    }
  }

  @override
  Future<void> save(String key, List<WaveformPeak> peaks) async {
    await Directory(directory).create(recursive: true);
    final payload = {
      'schemaVersion': _schemaVersion,
      'peaks': [
        for (final peak in peaks) [peak.min, peak.max],
      ],
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    await fileIo.writeBytesAtomic(_pathFor(key), bytes);
  }

  static String _sanitizeKey(String key) {
    // 只保留檔名安全字元，避免呼叫端傳入含 `/` 或空白的路徑衍生 key。
    return key.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
  }
}
