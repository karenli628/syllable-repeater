// AI-Generate
// WAV encoder 純函式測試（task-split S2-5）。
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

String _ascii(Uint8List bytes, int start, int length) =>
    String.fromCharCodes(bytes.sublist(start, start + length));

void main() {
  group('encodeWav', () {
    test('寫出 RIFF/WAVE 16-bit mono little-endian header 與 sample data', () {
      final pcm =
          Pcm(Int16List.fromList([-32768, -1, 0, 1, 32767]), sampleRate: 16000);

      final wav = encodeWav(pcm);
      final data = ByteData.sublistView(wav);

      expect(_ascii(wav, 0, 4), 'RIFF');
      expect(data.getUint32(4, Endian.little), 36 + 10);
      expect(_ascii(wav, 8, 4), 'WAVE');
      expect(_ascii(wav, 12, 4), 'fmt ');
      expect(data.getUint32(16, Endian.little), 16);
      expect(data.getUint16(20, Endian.little), 1);
      expect(data.getUint16(22, Endian.little), 1);
      expect(data.getUint32(24, Endian.little), 16000);
      expect(data.getUint32(28, Endian.little), 32000);
      expect(data.getUint16(32, Endian.little), 2);
      expect(data.getUint16(34, Endian.little), 16);
      expect(_ascii(wav, 36, 4), 'data');
      expect(data.getUint32(40, Endian.little), 10);

      expect(data.getInt16(44, Endian.little), -32768);
      expect(data.getInt16(46, Endian.little), -1);
      expect(data.getInt16(48, Endian.little), 0);
      expect(data.getInt16(50, Endian.little), 1);
      expect(data.getInt16(52, Endian.little), 32767);
    });

    test('空 PCM 仍產生合法 WAV header', () {
      final wav = encodeWav(Pcm(Int16List(0)));
      final data = ByteData.sublistView(wav);

      expect(wav, hasLength(44));
      expect(_ascii(wav, 0, 4), 'RIFF');
      expect(_ascii(wav, 8, 4), 'WAVE');
      expect(data.getUint32(4, Endian.little), 36);
      expect(data.getUint32(40, Endian.little), 0);
    });
  });

  group('decodeWav', () {
    test('讀回 encodeWav 輸出的 16-bit mono PCM', () {
      final pcm = Pcm(Int16List.fromList([-32768, -12, 0, 12, 32767]),
          sampleRate: 22050);

      final decoded = decodeWav(encodeWav(pcm));

      expect(decoded.sampleRate, 22050);
      expect(decoded.samples, [-32768, -12, 0, 12, 32767]);
    });

    test('不合法 WAV 映射 ERR_DECODE_FAILED', () {
      expect(
        () => decodeWav(Uint8List.fromList([1, 2, 3])),
        throwsA(
          isA<DomainException>().having(
            (e) => e.code,
            'code',
            ErrorCodes.decodeFailed,
          ),
        ),
      );
    });
  });
}
