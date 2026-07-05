// AI-Generate
/// Syllable Repeater 領域層公開介面（backend-design.md §3.2 為契約權威）。
library;

export 'src/errors.dart';
export 'src/alignment/alignment_engine.dart';
export 'src/alignment/zero_crossing.dart';
export 'src/analysis/analysis_pipeline.dart';
export 'src/analysis/waveform_peaks.dart';
export 'src/model/alignment_result.dart';
export 'src/model/pcm.dart';
export 'src/model/syllable.dart';
export 'src/model/time_range.dart';
export 'src/model/word.dart';
export 'src/ports/clock.dart';
export 'src/ports/file_io.dart';
export 'src/ports/waveform_peaks_cache.dart';
