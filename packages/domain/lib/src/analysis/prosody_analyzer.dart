// AI-Generate
import 'dart:math' as math;

import '../model/pcm.dart';
import '../model/prosody.dart';
import '../model/syllable.dart';

/// ProsodyAnalyzer（backend-design.md §3.2.3）。
///
/// 只讀 PCM，不產生、不改寫音訊；pitch 抽不到時降級為
/// `pitchAvailable=false`，rhythm/intensity/stress 仍照常回傳。
class ProsodyAnalyzer {
  static const defaultIntensityWindowMs = 20;

  final int intensityWindowMs;

  const ProsodyAnalyzer({this.intensityWindowMs = defaultIntensityWindowMs});

  Prosody analyze(Pcm pcm, List<Syllable> syllables) {
    final rhythm = _rhythm(syllables, pcm);
    final intensity = _intensity(pcm);
    final stress = _stress(pcm, syllables, rhythm);
    final pitchContour = _pitchContour(pcm);

    return Prosody(
      rhythm: rhythm,
      intensity: intensity,
      stress: stress,
      pitchContour: pitchContour.isEmpty ? null : pitchContour,
      pitchAvailable: pitchContour.isNotEmpty,
    );
  }

  List<double> _rhythm(List<Syllable> syllables, Pcm pcm) {
    if (syllables.isEmpty) {
      return const [];
    }

    final validDurations = <int>[];
    for (final syllable in syllables) {
      if (_sampleCount(pcm, syllable) > 0) {
        validDurations.add(syllable.endMs - syllable.startMs);
      }
    }
    final averageDuration =
        validDurations.isEmpty ? 0 : validDurations.reduce((a, b) => a + b) /
            validDurations.length;

    return List.unmodifiable(syllables.map((syllable) {
      if (_sampleCount(pcm, syllable) <= 0 || averageDuration <= 0) {
        return double.nan;
      }
      return (syllable.endMs - syllable.startMs) / averageDuration;
    }));
  }

  List<double> _intensity(Pcm pcm) {
    if (pcm.samples.isEmpty) {
      return const [];
    }
    final windowSamples = math.max(
      1,
      (intensityWindowMs * pcm.sampleRate) ~/ 1000,
    );
    final rmsValues = <double>[];
    for (var start = 0; start < pcm.samples.length; start += windowSamples) {
      final end = math.min(start + windowSamples, pcm.samples.length);
      rmsValues.add(_normalizedRms(pcm, start, end));
    }
    return List.unmodifiable(rmsValues);
  }

  List<double> _stress(Pcm pcm, List<Syllable> syllables, List<double> rhythm) {
    if (syllables.isEmpty) {
      return const [];
    }

    final energies = <double>[];
    for (final syllable in syllables) {
      final range = _sampleRange(pcm, syllable);
      if (range == null) {
        energies.add(double.nan);
      } else {
        energies.add(_normalizedRms(pcm, range.start, range.end));
      }
    }

    final finiteEnergies = energies.where((v) => v.isFinite).toList();
    final maxEnergy = finiteEnergies.isEmpty
        ? 0.0
        : finiteEnergies.reduce((a, b) => a > b ? a : b);

    return List.unmodifiable(List.generate(syllables.length, (i) {
      final energy = energies[i];
      final rhythmValue = rhythm[i];
      if (!energy.isFinite || !rhythmValue.isFinite) {
        return double.nan;
      }
      if (maxEnergy <= 0) {
        return 0.0;
      }
      final energyWeight = energy / maxEnergy;
      final durationWeight = math.min(rhythmValue, 2.0) / 2.0;
      return energyWeight * durationWeight;
    }));
  }

  List<double> _pitchContour(Pcm pcm) {
    if (pcm.samples.isEmpty) {
      return const [];
    }

    final windowSamples = math.max(32, (80 * pcm.sampleRate) ~/ 1000);
    final hopSamples = math.max(1, windowSamples ~/ 2);
    final minLag = math.max(1, pcm.sampleRate ~/ 400);
    final maxLag = math.max(minLag + 1, pcm.sampleRate ~/ 60);
    final pitches = <double>[];

    for (var start = 0;
        start + windowSamples + maxLag < pcm.samples.length;
        start += hopSamples) {
      final rms = _normalizedRms(pcm, start, start + windowSamples);
      if (rms < 0.02) {
        continue;
      }

      var bestLag = -1;
      var bestScore = 0.0;
      for (var lag = minLag; lag <= maxLag; lag++) {
        final score = _autocorrelationScore(pcm, start, windowSamples, lag);
        if (score > bestScore) {
          bestScore = score;
          bestLag = lag;
        }
      }

      if (bestLag > 0 && bestScore >= 0.65) {
        pitches.add(pcm.sampleRate / bestLag);
      }
    }

    return List.unmodifiable(pitches);
  }

  double _autocorrelationScore(
    Pcm pcm,
    int start,
    int windowSamples,
    int lag,
  ) {
    var cross = 0.0;
    var energyA = 0.0;
    var energyB = 0.0;
    for (var i = 0; i < windowSamples; i++) {
      final a = pcm.samples[start + i].toDouble();
      final b = pcm.samples[start + i + lag].toDouble();
      cross += a * b;
      energyA += a * a;
      energyB += b * b;
    }
    if (energyA <= 0 || energyB <= 0) {
      return 0;
    }
    return cross / math.sqrt(energyA * energyB);
  }

  double _normalizedRms(Pcm pcm, int start, int end) {
    if (start >= end) {
      return double.nan;
    }
    var sumSquares = 0.0;
    for (var i = start; i < end; i++) {
      final normalized = pcm.samples[i] / 32768.0;
      sumSquares += normalized * normalized;
    }
    return math.sqrt(sumSquares / (end - start));
  }

  ({int start, int end})? _sampleRange(Pcm pcm, Syllable syllable) {
    final start = pcm.sampleIndexAtMs(syllable.startMs).clamp(
          0,
          pcm.samples.length,
        );
    final end = pcm.sampleIndexAtMs(syllable.endMs).clamp(
          0,
          pcm.samples.length,
        );
    if (start >= end) {
      return null;
    }
    return (start: start, end: end);
  }

  int _sampleCount(Pcm pcm, Syllable syllable) {
    final range = _sampleRange(pcm, syllable);
    return range == null ? 0 : range.end - range.start;
  }
}
