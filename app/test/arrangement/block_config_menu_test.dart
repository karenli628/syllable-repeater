// AI-Generate
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/arrangement/widgets/block_config_menu.dart';

Widget _wrap({
  required int repeatN,
  required double silenceFactor,
  required void Function(int, double) onChanged,
}) => MaterialApp(
  home: Scaffold(
    body: BlockConfigMenu(
      initialRepeatN: repeatN,
      initialSilenceFactor: silenceFactor,
      onChanged: onChanged,
    ),
  ),
);

void main() {
  testWidgets('AT-15-04 重複次數 stepper 回傳新設定', (tester) async {
    final values = <(int, double)>[];
    await tester.pumpWidget(
      _wrap(
        repeatN: 3,
        silenceFactor: 2,
        onChanged: (repeatN, silence) => values.add((repeatN, silence)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('block-repeat-increment')));
    await tester.pump();

    expect(find.text('4 次'), findsOneWidget);
    expect(values, [(4, 2.0)]);
  });

  testWidgets('AT-15-06 靜音比例以 0.5 遞增，最高 20 才 disabled', (tester) async {
    final values = <(int, double)>[];
    await tester.pumpWidget(
      _wrap(
        repeatN: 10,
        silenceFactor: 20,
        onChanged: (repeatN, silence) => values.add((repeatN, silence)),
      ),
    );

    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('block-repeat-increment')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('block-silence-increment')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('block-silence-decrement')));
    await tester.pump();
    expect(find.text('19.5'), findsOneWidget);
    expect(values, [(10, 19.5)]);
  });

  testWidgets('AT-15-05 可從浮層觸發積木預覽', (tester) async {
    var previewed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlockConfigMenu(
            initialRepeatN: 3,
            initialSilenceFactor: 2,
            onChanged: (_, __) {},
            onPreview: () => previewed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('block-preview')));
    expect(previewed, isTrue);
  });

  testWidgets('AT-15-11 重置鍵回到初始 1 次／1 倍', (tester) async {
    final values = <(int, double)>[];
    await tester.pumpWidget(
      _wrap(
        repeatN: 8,
        silenceFactor: 12,
        onChanged: (repeatN, silence) => values.add((repeatN, silence)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('block-config-reset')));
    await tester.pump();

    expect(find.text('1 次'), findsOneWidget);
    expect(find.text('1.0'), findsOneWidget);
    expect(values, [(1, 1.0)]);
  });
}
