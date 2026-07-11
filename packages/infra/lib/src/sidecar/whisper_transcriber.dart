// AI-Generate
import 'dart:convert';
import 'dart:io';

import 'package:domain/domain.dart';

import 'sidecar_runner.dart';

/// whisper.cpp full JSON → 詞級時間戳（task-split 3.2）。
class WhisperJsonParser {
  const WhisperJsonParser();

  List<Word> parseWords(String jsonText) {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('whisper JSON root must be an object');
    }

    final transcription = decoded['transcription'];
    if (transcription is! List<dynamic>) {
      throw const FormatException('whisper JSON transcription must be a list');
    }

    final words = <Word>[];
    _PendingWord? current;

    for (final segment in transcription) {
      if (segment is! Map<String, dynamic>) {
        continue;
      }
      final tokens = segment['tokens'];
      if (tokens is! List<dynamic>) {
        continue;
      }

      for (final token in tokens) {
        if (token is! Map<String, dynamic>) {
          continue;
        }
        final rawText = token['text'];
        final offsets = token['offsets'];
        if (rawText is! String || offsets is! Map<String, dynamic>) {
          continue;
        }
        if (rawText.startsWith('[_')) {
          continue;
        }

        final normalized = _lettersOnly(rawText);
        if (normalized.isEmpty) {
          continue;
        }
        final from = offsets['from'];
        final to = offsets['to'];
        if (from is! int || to is! int || to <= from) {
          continue;
        }

        if (rawText.startsWith(' ') || current == null) {
          if (current != null) {
            words.add(current.toWord(words.length));
          }
          current = _PendingWord(normalized, from, to);
        } else {
          current.append(normalized, to);
        }
      }
    }

    if (current != null) {
      words.add(current.toWord(words.length));
    }
    return words;
  }

  String _lettersOnly(String tokenText) =>
      tokenText.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
}

/// whisper.cpp CLI 包裝器；開發期預設可關 GPU 以避開 Intel Metal 異常。
class WhisperCppTranscriber {
  final ProcessRunner runner;
  final WhisperJsonParser parser;
  final String whisperCliPath;
  final String modelPath;
  final bool noGpu;
  final Duration timeout;

  const WhisperCppTranscriber({
    required this.runner,
    required this.whisperCliPath,
    required this.modelPath,
    this.parser = const WhisperJsonParser(),
    this.noGpu = false,
    this.timeout = const Duration(seconds: 120),
  });

  Future<List<Word>> transcribe(
    String audioPath, {
    required String outputBasePath,
    String language = 'en',
  }) async {
    final args = [
      '-m',
      modelPath,
      '-f',
      audioPath,
      '-l',
      language,
      '-oj',
      '-ojf',
      '-of',
      outputBasePath,
      if (noGpu) '--no-gpu',
    ];

    final SidecarResult result;
    try {
      result = await runner.run(whisperCliPath, args, timeout: timeout);
    } on SidecarFailure catch (f) {
      if (f.isTimeout) {
        throw const DomainException(
            ErrorCodes.sidecarTimeout, '辨識逾時，可重試或調高逾時設定');
      }
      throw DomainException(
          ErrorCodes.sidecarCrashed, '辨識引擎異常結束，可重試（${f.detail}）');
    }

    if (result.wasKilledBySignal) {
      throw const DomainException(ErrorCodes.sidecarCrashed, '辨識引擎異常結束，可重試');
    }
    if (!result.isSuccess) {
      final tail = result.stderr.length > 300
          ? result.stderr.substring(result.stderr.length - 300)
          : result.stderr;
      throw DomainException(ErrorCodes.transcribeFailed, '辨識失敗，可重試（$tail）');
    }

    final jsonFile = File('$outputBasePath.json');
    if (!jsonFile.existsSync()) {
      throw const DomainException(
          ErrorCodes.transcribeFailed, '辨識失敗：未產生 JSON 結果');
    }
    return parser.parseWords(jsonFile.readAsStringSync());
  }
}

class _PendingWord {
  String text;
  final int startMs;
  int endMs;

  _PendingWord(this.text, this.startMs, this.endMs);

  void append(String suffix, int endMs) {
    text += suffix;
    this.endMs = endMs;
  }

  Word toWord(int index) =>
      Word(text: text, startMs: startMs, endMs: endMs, index: index);
}
