// AI-Generate
import 'dart:typed_data';

import '../errors.dart';
import '../model/pcm.dart';

/// 將 16-bit mono PCM 包成 RIFF/WAVE bytes。
/// Domain 只產生 bytes，不碰檔案系統或播放器。
Uint8List encodeWav(Pcm pcm) {
  const bytesPerSample = 2;
  const channelCount = 1;
  const bitsPerSample = 16;
  const headerBytes = 44;
  final dataBytes = pcm.samples.length * bytesPerSample;
  final bytes = Uint8List(headerBytes + dataBytes);
  final data = ByteData.sublistView(bytes);

  _writeAscii(bytes, 0, 'RIFF');
  data.setUint32(4, 36 + dataBytes, Endian.little);
  _writeAscii(bytes, 8, 'WAVE');
  _writeAscii(bytes, 12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channelCount, Endian.little);
  data.setUint32(24, pcm.sampleRate, Endian.little);
  data.setUint32(
      28, pcm.sampleRate * channelCount * bytesPerSample, Endian.little);
  data.setUint16(32, channelCount * bytesPerSample, Endian.little);
  data.setUint16(34, bitsPerSample, Endian.little);
  _writeAscii(bytes, 36, 'data');
  data.setUint32(40, dataBytes, Endian.little);

  var offset = headerBytes;
  for (final sample in pcm.samples) {
    data.setInt16(offset, sample, Endian.little);
    offset += bytesPerSample;
  }
  return bytes;
}

void _writeAscii(Uint8List bytes, int offset, String value) {
  for (var i = 0; i < value.length; i++) {
    bytes[offset + i] = value.codeUnitAt(i);
  }
}

/// 讀取 RIFF/WAVE 16-bit mono PCM bytes。
///
/// 支援有額外 chunk 的 WAV；不碰檔案系統，供 pack hydrate 與 infra 錄音讀取共用。
Pcm decodeWav(
  Uint8List bytes, {
  String failureMessage = 'WAV 解碼失敗',
}) {
  try {
    if (bytes.length < 44 ||
        _ascii(bytes, 0, 4) != 'RIFF' ||
        _ascii(bytes, 8, 12) != 'WAVE') {
      throw const FormatException('not a RIFF/WAVE file');
    }

    var offset = 12;
    int? sampleRate;
    int? dataOffset;
    int? dataLength;
    while (offset + 8 <= bytes.length) {
      final chunkId = _ascii(bytes, offset, offset + 4);
      final chunkSize = _uint32(bytes, offset + 4);
      final chunkDataOffset = offset + 8;
      if (chunkDataOffset + chunkSize > bytes.length) {
        throw const FormatException('invalid WAV chunk size');
      }

      if (chunkId == 'fmt ') {
        final audioFormat = _uint16(bytes, chunkDataOffset);
        final channels = _uint16(bytes, chunkDataOffset + 2);
        sampleRate = _uint32(bytes, chunkDataOffset + 4);
        final bitsPerSample = _uint16(bytes, chunkDataOffset + 14);
        if (audioFormat != 1 || channels != 1 || bitsPerSample != 16) {
          throw const FormatException('only PCM 16-bit mono WAV supported');
        }
      } else if (chunkId == 'data') {
        dataOffset = chunkDataOffset;
        dataLength = chunkSize;
      }

      offset = chunkDataOffset + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (sampleRate == null || dataOffset == null || dataLength == null) {
      throw const FormatException('missing fmt/data chunk');
    }
    if (dataLength.isOdd) {
      throw const FormatException('16-bit PCM data must be even length');
    }

    final sampleCount = dataLength ~/ 2;
    final samples = Int16List(sampleCount);
    final data =
        ByteData.sublistView(bytes, dataOffset, dataOffset + dataLength);
    for (var i = 0; i < sampleCount; i++) {
      samples[i] = data.getInt16(i * 2, Endian.little);
    }
    return Pcm(samples, sampleRate: sampleRate);
  } catch (error) {
    throw DomainException(ErrorCodes.decodeFailed, '$failureMessage：$error');
  }
}

String _ascii(Uint8List bytes, int start, int end) =>
    String.fromCharCodes(bytes.sublist(start, end));

int _uint16(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes, offset, offset + 2).getUint16(0, Endian.little);

int _uint32(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes, offset, offset + 4).getUint32(0, Endian.little);
