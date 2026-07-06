// AI-Generate
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/editor/editor_controller.dart';
import 'package:syllable_repeater_app/features/editor/editor_screen.dart';

List<Syllable> _sample() => [
  Syllable(
    text: 'she',
    startMs: 0,
    endMs: 500,
    wordIndex: 0,
    needsReview: false,
  ),
  Syllable(
    text: 'has',
    startMs: 500,
    endMs: 1000,
    wordIndex: 1,
    needsReview: false,
  ),
];

void main() {
  testWidgets('AT-05-02：pitch unavailable 顯示徽章而非錯誤', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(editorControllerProvider.notifier)
        .loadFrom(_sample(), pcm: Pcm(Int16List(1000), sampleRate: 1000));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: EditorScreen())),
      ),
    );

    expect(find.text('音高不可用'), findsOneWidget);
    expect(find.text('韻律疊圖'), findsOneWidget);
    expect(container.read(editorControllerProvider).error, isNull);
  });
}
