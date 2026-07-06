// AI-Generate
import 'package:domain/domain.dart';

class FileRecordingAudioSource implements RecordingAudioSource {
  final FileIo fileIo;

  const FileRecordingAudioSource({required this.fileIo});

  @override
  Future<Pcm> readPcm(String path) async {
    final bytes = await fileIo.readBytes(path);
    return decodeWav(bytes, failureMessage: '錄音 WAV 解碼失敗');
  }

  @override
  Future<void> delete(String path) => fileIo.delete(path);
}
