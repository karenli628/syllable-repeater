// AI-Generate
// M4 崩潰隔離之核心測試（CT-04 / AT-01-04 單元層級）：
// sidecar 無論非零結束、被 kill -9、逾時、起不來，Runner 都以「回傳失敗」收場，
// 測試行程（= App 替身）絕不崩潰。
import 'package:infra/infra.dart';
import 'package:test/test.dart';

void main() {
  const runner = SidecarRunner(defaultTimeout: Duration(seconds: 10));

  group('SidecarRunner（M4 崩潰隔離）', () {
    test('正常結束：exit 0、stdout 完整收集（二進位安全）', () async {
      final r = await runner.run('/bin/sh', ['-c', 'printf hello']);
      expect(r.isSuccess, isTrue);
      expect(String.fromCharCodes(r.stdout), 'hello');
    });

    test('非零結束：回傳 exitCode，不拋例外', () async {
      final r = await runner.run('/bin/sh', ['-c', 'echo boom >&2; exit 3']);
      expect(r.exitCode, 3);
      expect(r.wasKilledBySignal, isFalse);
      expect(r.stderr, contains('boom'));
    });

    test('kill -9 自殺（模擬 sidecar 崩潰）：回傳負 exitCode，App 不崩', () async {
      final r = await runner.run('/bin/sh', ['-c', 'kill -9 \$\$']);
      expect(r.wasKilledBySignal, isTrue,
          reason: 'POSIX 被訊號終止應為負 exitCode（CT-04）');
    });

    test('逾時：SIGKILL 回收並拋 SidecarFailure(timeout)，不懸掛', () async {
      final sw = Stopwatch()..start();
      await expectLater(
        runner.run('/bin/sh', ['-c', 'sleep 30'],
            timeout: const Duration(milliseconds: 300)),
        throwsA(isA<SidecarFailure>()
            .having((f) => f.isTimeout, 'isTimeout', isTrue)),
      );
      sw.stop();
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)),
          reason: '逾時後應立即回收，不等 sleep 跑完');
    });

    test('執行檔不存在：SidecarFailure(spawn)，App 不崩', () async {
      await expectLater(
        runner.run('/nonexistent/sidecar-binary', []),
        throwsA(isA<SidecarFailure>()
            .having((f) => f.kind, 'kind', 'spawn')),
      );
    });
  });
}
