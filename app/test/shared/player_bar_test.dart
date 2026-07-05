// AI-Generate
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/shared/player/player_bar.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('PlayerBar idle 顯示播放鈕與標題', (tester) async {
    var played = false;
    await tester.pumpWidget(_wrap(PlayerBar(
      title: '第 1 步：skills',
      state: PlayerBarState.idle,
      onPlay: () => played = true,
    )));

    expect(find.text('第 1 步：skills'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow));
    expect(played, isTrue);
  });

  testWidgets('PlayerBar loading 顯示 progress，playing 顯示 stop 鈕',
      (tester) async {
    await tester.pumpWidget(
        _wrap(const PlayerBar(title: 't', state: PlayerBarState.loading)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    var stopped = false;
    await tester.pumpWidget(_wrap(PlayerBar(
      title: 't',
      state: PlayerBarState.playing,
      onStop: () => stopped = true,
    )));
    expect(find.byIcon(Icons.stop), findsOneWidget);
    await tester.tap(find.byIcon(Icons.stop));
    expect(stopped, isTrue);
  });
}
