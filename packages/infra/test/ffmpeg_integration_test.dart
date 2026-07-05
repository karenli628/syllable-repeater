// AI-Generate
// S0 demo 整合測試：真實 FFmpeg 經 Process.start 解碼取得時長
//（需求成稿 §5 S0 完成定義）。找不到 ffmpeg 時整組 skip（CI 於任務 2.1 完成後常駐）。
@Tags(['sidecar'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:infra/infra.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// 產生 1 秒 440Hz 單聲道 16-bit 44.1kHz WAV。
Uint8List _makeTestWav() {
  const sampleRate = 44100;
  const seconds = 1;
  const numSamples = sampleRate * seconds;
  final samples = Int16List(numSamples);
  for (var i = 0; i < numSamples; i++) {
    samples[i] =
        (32767 * 0.3 * _sin(2 * 3.141592653589793 * 440 * i / sampleRate))
            .round();
  }
  final dataBytes = samples.buffer.asUint8List();
  final header = BytesBuilder();
  void writeString(String s) => header.add(s.codeUnits);
  void writeU32(int v) =>
      header.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void writeU16(int v) =>
      header.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

  writeString('RIFF');
  writeU32(36 + dataBytes.length);
  writeString('WAVE');
  writeString('fmt ');
  writeU32(16);
  writeU16(1); // PCM
  writeU16(1); // mono
  writeU32(sampleRate);
  writeU32(sampleRate * 2); // byte rate
  writeU16(2); // block align
  writeU16(16); // bits
  writeString('data');
  writeU32(dataBytes.length);
  header.add(dataBytes);
  return header.toBytes();
}

double _sin(double x) {
  // 泰勒級數夠用（測試音訊內容不影響時長斷言）。
  final xn = x % (2 * 3.141592653589793);
  double term = xn, sum = xn;
  for (var n = 1; n <= 9; n++) {
    term *= -xn * xn / ((2 * n) * (2 * n + 1));
    sum += term;
  }
  return sum;
}

String? _findFfmpeg() {
  final env = Platform.environment['SYLLABLE_FFMPEG'];
  if (env != null && File(env).existsSync()) return env;
  final which = Process.runSync('which', ['ffmpeg']);
  if (which.exitCode == 0) {
    final path = (which.stdout as String).trim();
    if (path.isNotEmpty) return path;
  }
  return null;
}

void main() {
  final ffmpeg = _findFfmpeg();

  group('S0 demo：FFmpeg 真實解碼', () {
    test('1 秒測試 WAV → durationMs ≈ 1000（±20ms）', () async {
      final dir = await Directory.systemTemp.createTemp('ffmpeg_it');
      addTearDown(() => dir.delete(recursive: true));
      final wavPath = p.join(dir.path, 'tone.wav');
      await File(wavPath).writeAsBytes(_makeTestWav());

      final decoder = FfmpegDecoder(
          runner: const SidecarRunner(), ffmpegPath: ffmpeg!);
      final pcm = await decoder.decode(wavPath);
      expect((pcm.durationMs - 1000).abs(), lessThanOrEqualTo(20));
    });
  },
      skip: ffmpeg == null
          ? 'ffmpeg 未安裝（任務 2.1 完成後本組轉為常駐）'
          : false);
}
