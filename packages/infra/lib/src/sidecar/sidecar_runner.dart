// AI-Generate
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// sidecar 行程一次執行的完成結果（行程有跑完，不論 exit code）。
class SidecarResult {
  /// POSIX：>=0 正常結束碼；<0 表示被訊號終止（如 kill -9 → -9）。
  final int exitCode;

  /// stdout 原始 bytes（二進位安全，供 PCM 等資料流）。
  final List<int> stdout;

  /// stderr 文字（UTF-8 寬鬆解碼），供錯誤診斷。
  final String stderr;

  const SidecarResult(this.exitCode, this.stdout, this.stderr);

  bool get isSuccess => exitCode == 0;

  /// 被訊號終止（POSIX 上 Process.exitCode 為負值）＝「sidecar 崩潰」。
  bool get wasKilledBySignal => exitCode < 0;
}

/// sidecar 無法完成執行（逾時或根本起不來）。
/// 注意：這是「回傳失敗」的載體——依 M4，任何 sidecar 問題都不得讓 App 崩潰。
class SidecarFailure implements Exception {
  /// 'timeout' | 'spawn'
  final String kind;
  final String detail;

  const SidecarFailure(this.kind, this.detail);

  bool get isTimeout => kind == 'timeout';

  @override
  String toString() => 'SidecarFailure($kind): $detail';
}

/// 供上層（解碼器等）依賴的窄介面，測試可注入假實作。
abstract interface class ProcessRunner {
  Future<SidecarResult> run(String executable, List<String> args,
      {Duration? timeout});
}

/// sidecar 行程執行器（task-split 2.2；M4 崩潰隔離）。
///
/// 行為契約（backend-design §3.2.1 依賴介面、CT-04）：
/// - 行程跑完（含非零 exit、被訊號殺）→ 回傳 [SidecarResult]，由呼叫端解讀。
/// - 逾時 → SIGKILL 回收行程，拋 [SidecarFailure]('timeout')。
/// - 執行檔不存在/無法啟動 → 拋 [SidecarFailure]('spawn')。
/// - 本類**絕不**讓例外以未捕捉形式逃逸成 App 崩潰。
class SidecarRunner implements ProcessRunner {
  /// 預設逾時（app_settings：sidecar.timeoutSec，預設 120s）。
  final Duration defaultTimeout;

  const SidecarRunner({this.defaultTimeout = const Duration(seconds: 120)});

  @override
  Future<SidecarResult> run(String executable, List<String> args,
      {Duration? timeout}) async {
    final Process process;
    try {
      process = await Process.start(executable, args);
    } on ProcessException catch (e) {
      throw SidecarFailure('spawn', '無法啟動 $executable：${e.message}');
    }

    final stdoutBytes = <int>[];
    final stderrBuf = StringBuffer();
    final stdoutDone = process.stdout
        .listen(stdoutBytes.addAll)
        .asFuture<void>()
        .catchError((_) {});
    final stderrDone = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(stderrBuf.write)
        .asFuture<void>()
        .catchError((_) {});

    final effectiveTimeout = timeout ?? defaultTimeout;
    final int exitCode;
    try {
      exitCode = await process.exitCode.timeout(effectiveTimeout);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      // 等待行程真正回收，避免殭屍行程；此時不再限時（SIGKILL 必然終止）。
      await process.exitCode;
      await Future.wait([stdoutDone, stderrDone]);
      throw SidecarFailure(
          'timeout', '$executable 逾時（>${effectiveTimeout.inSeconds}s），已強制回收');
    }

    await Future.wait([stdoutDone, stderrDone]);
    return SidecarResult(exitCode, stdoutBytes, stderrBuf.toString());
  }
}
