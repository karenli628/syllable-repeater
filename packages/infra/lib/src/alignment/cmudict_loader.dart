// AI-Generate
import 'dart:io';

import 'package:domain/domain.dart';

/// 從本機 CMUdict 檔案載入音節字典（task-split 3.1）。
class CmuDictLoader {
  const CmuDictLoader();

  SyllableDictionary load(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('找不到 CMUdict 檔案', path);
    }
    return SyllableDictionary.fromCmuDictLines(file.readAsLinesSync());
  }
}
