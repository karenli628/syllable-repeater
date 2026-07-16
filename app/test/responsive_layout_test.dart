// AI-Generate
// FP9.1：全域響應式殼層與捲動兜底（REQ-10 / AT-10-01～04）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/main.dart';
import 'package:syllable_repeater_app/shared/responsive_layout.dart';

void main() {
  test('1280px 是並排／堆疊的唯一斷點，邊界兩側方向固定', () {
    expect(ResponsiveLayout.modeForWidth(1280), ResponsiveLayoutMode.wide);
    expect(
      ResponsiveLayout.modeForWidth(1279.99),
      ResponsiveLayoutMode.stacked,
    );
  });

  testWidgets('AT-15-19 macOS 原生最小尺寸下殼層不建立第三層捲動', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ResponsiveLayout(child: const SizedBox(width: 1400, height: 900)),
      ),
    );

    expect(find.byType(Scrollbar), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('寬視窗的內容寬度跟隨可用尺寸，不被固定 1100px 綁死', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ResponsiveLayout(
          child: LayoutBuilder(
            builder: (context, constraints) => Text(
              '${constraints.maxWidth}',
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      ),
    );

    expect(find.text('1600.0'), findsOneWidget);
  });

  testWidgets('雙欄容器在 1280px 以上並排，以下上下堆疊', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveLayout(
          child: ResponsiveTwoPane(primary: Text('波形'), secondary: Text('文字')),
        ),
      ),
    );
    expect(find.byType(Row), findsWidgets);

    tester.view.physicalSize = const Size(1100, 700);
    await tester.pump();
    expect(find.byType(Column), findsWidgets);
  });

  testWidgets('主畫面縮放與切頁不會重建丟失匯入字稿', (tester) async {
    tester.view.physicalSize = const Size(1100, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SyllableRepeaterApp());
    await tester.tap(find.byIcon(Icons.upload_file_outlined));
    // Riverpod 的背景 provider 可能持續更新；此處只需一幀驗證重排後的畫面。
    await tester.pump();

    final transcript = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '字稿（可留空）',
    );
    expect(transcript, findsOneWidget);
    await tester.enterText(transcript, 'state preserved');

    await tester.tap(find.byIcon(Icons.tune_outlined));
    await tester.pump();
    tester.view.physicalSize = const Size(1600, 1000);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.upload_file_outlined));
    await tester.pump();

    final restored = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == '字稿（可留空）',
      ),
    );
    expect(restored.controller?.text, 'state preserved');
  });
}
