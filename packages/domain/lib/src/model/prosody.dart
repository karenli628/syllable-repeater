// AI-Generate
/// 韻律分析結果（backend-design.md §3.1.1 / §3.2.3 介面 7）。
class Prosody {
  final List<double> rhythm;
  final List<double> intensity;
  final List<double> stress;
  final List<double>? pitchContour;
  final bool pitchAvailable;

  Prosody({
    required List<double> rhythm,
    required List<double> intensity,
    required List<double> stress,
    required List<double>? pitchContour,
    required this.pitchAvailable,
  })  : rhythm = List.unmodifiable(rhythm),
        intensity = List.unmodifiable(intensity),
        stress = List.unmodifiable(stress),
        pitchContour =
            pitchContour == null ? null : List.unmodifiable(pitchContour) {
    if (!pitchAvailable && pitchContour != null) {
      throw ArgumentError('pitchAvailable=false 時 pitchContour 必須為 null');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Prosody &&
      _listEquals(other.rhythm, rhythm) &&
      _listEquals(other.intensity, intensity) &&
      _listEquals(other.stress, stress) &&
      _nullableListEquals(other.pitchContour, pitchContour) &&
      other.pitchAvailable == pitchAvailable;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(rhythm),
        Object.hashAll(intensity),
        Object.hashAll(stress),
        pitchContour == null ? null : Object.hashAll(pitchContour!),
        pitchAvailable,
      );
}

bool _nullableListEquals(List<double>? a, List<double>? b) {
  if (a == null || b == null) {
    return a == b;
  }
  return _listEquals(a, b);
}

bool _listEquals(List<double> a, List<double> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
