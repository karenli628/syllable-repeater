// AI-Generate
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'practice_config.dart';
import 'practice_arrangement.dart';
import 'prosody.dart';
import 'syllable.dart';
import 'translation.dart';
import 'word.dart';

/// 一個可攜 `.abopack` 課件聚合（backend-design.md §3.1.1）。
///
/// [audioRelPath] 永遠是 pack 內相對路徑；原音 bytes 放在
/// [originalAudioBytes]，避免 Domain 透過本機絕對路徑讀檔而破壞 M5/REQ-09。
class Lesson {
  final String id;
  final String title;
  final String language;
  final String audioRelPath;
  final Uint8List originalAudioBytes;
  final String contentHash;
  final List<Word> words;
  final List<Syllable> syllables;
  final List<Translation> translations;
  final Prosody? prosody;
  final PracticeConfig practiceConfig;
  final PracticeArrangement? arrangement;
  final DateTime updatedAt;

  Lesson({
    required this.id,
    required this.title,
    this.language = 'en',
    required this.audioRelPath,
    required Uint8List originalAudioBytes,
    required this.contentHash,
    required List<Word> words,
    required List<Syllable> syllables,
    required List<Translation> translations,
    required this.prosody,
    required this.practiceConfig,
    this.arrangement,
    required this.updatedAt,
  })  : originalAudioBytes = Uint8List.fromList(originalAudioBytes),
        words = List.unmodifiable(words),
        syllables = List.unmodifiable(syllables),
        translations = List.unmodifiable(translations) {
    if (id.trim().isEmpty) {
      throw ArgumentError('Lesson.id 不可空白');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError('Lesson.title 不可空白');
    }
    if (language.trim().isEmpty) {
      throw ArgumentError('Lesson.language 不可空白');
    }
    _validateRelativePackPath(audioRelPath);
    if (originalAudioBytes.isEmpty) {
      throw ArgumentError('Lesson.originalAudioBytes 不可為空');
    }
    if (words.isEmpty) {
      throw ArgumentError('Lesson.words 不可為空');
    }
    if (syllables.isEmpty) {
      throw ArgumentError('Lesson.syllables 不可為空');
    }
  }

  Lesson withContentHash() => copyWith(contentHash: recomputeContentHash());

  Lesson copyWith({
    String? id,
    String? title,
    String? language,
    String? audioRelPath,
    Uint8List? originalAudioBytes,
    String? contentHash,
    List<Word>? words,
    List<Syllable>? syllables,
    List<Translation>? translations,
    Prosody? prosody,
    PracticeConfig? practiceConfig,
    Object? arrangement = _unset,
    DateTime? updatedAt,
  }) =>
      Lesson(
        id: id ?? this.id,
        title: title ?? this.title,
        language: language ?? this.language,
        audioRelPath: audioRelPath ?? this.audioRelPath,
        originalAudioBytes: originalAudioBytes ?? this.originalAudioBytes,
        contentHash: contentHash ?? this.contentHash,
        words: words ?? this.words,
        syllables: syllables ?? this.syllables,
        translations: translations ?? this.translations,
        prosody: prosody ?? this.prosody,
        practiceConfig: practiceConfig ?? this.practiceConfig,
        arrangement: identical(arrangement, _unset)
            ? this.arrangement
            : arrangement as PracticeArrangement?,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// M6 進度局部重置依據：原音 bytes + syllables 結構的 SHA-256。
  String recomputeContentHash() {
    final bytes = BytesBuilder(copy: false)
      ..add(originalAudioBytes)
      ..add(utf8.encode(jsonEncode(_contentHashJson())));
    return sha256.convert(bytes.takeBytes()).toString();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'language': language,
        'audioRelPath': audioRelPath,
        'contentHash': contentHash,
        'words': words.map(_wordToJson).toList(growable: false),
        'syllables': syllables.map(_syllableToJson).toList(growable: false),
        'translations':
            translations.map((t) => t.toJson()).toList(growable: false),
        'prosody': prosody == null ? null : _prosodyToJson(prosody!),
        'practiceConfig': practiceConfig.toJson(),
        'arrangement': arrangement?.toJson(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Lesson.fromJson(
    Map<String, dynamic> json, {
    required Uint8List originalAudioBytes,
  }) =>
      Lesson(
        id: json['id'] as String,
        title: json['title'] as String,
        language: (json['language'] as String?) ?? 'en',
        audioRelPath: json['audioRelPath'] as String,
        originalAudioBytes: originalAudioBytes,
        contentHash: json['contentHash'] as String,
        words: (json['words'] as List<dynamic>)
            .map((item) => _wordFromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        syllables: (json['syllables'] as List<dynamic>)
            .map((item) => _syllableFromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        translations: (json['translations'] as List<dynamic>)
            .map((item) => Translation.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        prosody: json['prosody'] == null
            ? null
            : _prosodyFromJson(json['prosody'] as Map<String, dynamic>),
        practiceConfig: PracticeConfig.fromJson(
            json['practiceConfig'] as Map<String, dynamic>),
        arrangement: json['arrangement'] == null
            ? null
            : PracticeArrangement.fromJson(
                json['arrangement'] as Map<String, dynamic>),
        updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      );

  Map<String, dynamic> _contentHashJson() => {
        'syllables': syllables.map(_syllableToJson).toList(growable: false),
      };
}

void _validateRelativePackPath(String path) {
  if (path.trim().isEmpty) {
    throw ArgumentError('pack 內路徑不可空白');
  }
  if (path.startsWith('/') ||
      path.startsWith(r'\') ||
      path.contains('..') ||
      path.contains('\\')) {
    throw ArgumentError('pack 內路徑必須是安全相對路徑: $path');
  }
}

Map<String, dynamic> _wordToJson(Word word) => {
      'text': word.text,
      'startMs': word.startMs,
      'endMs': word.endMs,
      'index': word.index,
    };

Word _wordFromJson(Map<String, dynamic> json) => Word(
      text: json['text'] as String,
      startMs: json['startMs'] as int,
      endMs: json['endMs'] as int,
      index: json['index'] as int,
    );

Map<String, dynamic> _syllableToJson(Syllable syllable) => {
      'text': syllable.text,
      if (syllable.originalText != null) 'originalText': syllable.originalText,
      'startMs': syllable.startMs,
      'endMs': syllable.endMs,
      'wordIndex': syllable.wordIndex,
      'needsReview': syllable.needsReview,
    };

Syllable _syllableFromJson(Map<String, dynamic> json) => Syllable(
      text: json['text'] as String,
      originalText: json['originalText'] as String?,
      startMs: json['startMs'] as int,
      endMs: json['endMs'] as int,
      wordIndex: json['wordIndex'] as int,
      needsReview: json['needsReview'] as bool,
    );

Map<String, dynamic> _prosodyToJson(Prosody prosody) => {
      'rhythm': prosody.rhythm,
      'intensity': prosody.intensity,
      'stress': prosody.stress,
      'pitchContour': prosody.pitchContour,
      'pitchAvailable': prosody.pitchAvailable,
    };

Prosody _prosodyFromJson(Map<String, dynamic> json) => Prosody(
      rhythm: (json['rhythm'] as List<dynamic>).cast<double>(),
      intensity: (json['intensity'] as List<dynamic>).cast<double>(),
      stress: (json['stress'] as List<dynamic>).cast<double>(),
      pitchContour: json['pitchContour'] == null
          ? null
          : (json['pitchContour'] as List<dynamic>).cast<double>(),
      pitchAvailable: json['pitchAvailable'] as bool,
    );

const _unset = Object();
