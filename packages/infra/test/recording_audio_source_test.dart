// AI-Generate
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:infra/infra.dart';
import 'package:test/test.dart';

class _FakeFileIo implements FileIo {
  final Map<String, Uint8List> files = {};
  final Set<String> deleted = {};

  @override
  Future<Uint8List> readBytes(String path) async => files[path]!;

  @override
  Future<void> writeBytesAtomic(String path, Uint8List bytes) async {
    files[path] = bytes;
  }

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<void> delete(String path) async {
    deleted.add(path);
    files.remove(path);
  }

  @override
  Future<String> createTempFilePath(String suffix) async =>
      '/tmp/recording$suffix';

  @override
  Future<void> clearTemp() async {
    files.clear();
  }
}

void main() {
  group('FileRecordingAudioSource', () {
    test('讀取 16-bit mono WAV 為 Pcm', () async {
      final io = _FakeFileIo();
      final pcm = Pcm(Int16List.fromList([0, -1234, 2345]), sampleRate: 16000);
      io.files['/tmp/recording.wav'] = encodeWav(pcm);

      final source = FileRecordingAudioSource(fileIo: io);
      final decoded = await source.readPcm('/tmp/recording.wav');

      expect(decoded.sampleRate, 16000);
      expect(decoded.samples, [0, -1234, 2345]);
    });

    test('解碼失敗映射 ERR_DECODE_FAILED', () async {
      final io = _FakeFileIo();
      io.files['/tmp/bad.wav'] = Uint8List.fromList([1, 2, 3]);

      final source = FileRecordingAudioSource(fileIo: io);

      await expectLater(
        source.readPcm('/tmp/bad.wav'),
        throwsA(
          isA<DomainException>().having(
            (e) => e.code,
            'code',
            ErrorCodes.decodeFailed,
          ),
        ),
      );
    });

    test('delete 轉交 FileIo，供 RecordingComparator finally 清除暫存錄音', () async {
      final io = _FakeFileIo();
      final source = FileRecordingAudioSource(fileIo: io);

      await source.delete('/tmp/recording.wav');

      expect(io.deleted, contains('/tmp/recording.wav'));
    });
  });
}
