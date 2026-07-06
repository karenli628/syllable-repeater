// AI-Generate
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/editor/editor_controller.dart';
import 'package:syllable_repeater_app/features/library/lesson_pack_service.dart';
import 'package:syllable_repeater_app/features/library/library_screen.dart';
import 'package:syllable_repeater_app/features/pack_translate/lesson_session_controller.dart';
import 'package:syllable_repeater_app/features/practice/practice_controller.dart';
import 'package:syllable_repeater_app/features/practice/widgets/settle_bar.dart';
import 'package:syllable_repeater_app/features/progress/ai_settings_service.dart';
import 'package:syllable_repeater_app/features/progress/progress_service.dart';
import 'package:syllable_repeater_app/features/progress/progress_settings_screen.dart';
import 'package:syllable_repeater_app/shared/navigation.dart';

void main() {
  testWidgets('LibraryScreen 顯示 ProgressService dueList 結果', (tester) async {
    final service = _FakeProgressService(
      due: [
        DueGroup(
          groupId: 'group-a',
          lessonTitle: 'Communication Skills',
          nextDue: DateTime.utc(2026, 7, 6, 9),
          priority: 3,
        ),
      ],
    );

    await _pump(tester, service: service, child: const LibraryScreen());
    await tester.pumpAndSettle();

    expect(find.text('Communication Skills'), findsOneWidget);
    expect(find.text('困難'), findsOneWidget);
  });

  testWidgets('LibraryScreen 歸檔前顯示確認對話框', (tester) async {
    final service = _FakeProgressService(
      due: [
        DueGroup(
          groupId: 'group-a',
          lessonTitle: 'Communication Skills',
          nextDue: DateTime.utc(2026, 7, 6, 9),
          priority: 3,
        ),
      ],
    );

    await _pump(tester, service: service, child: const LibraryScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('歸檔 Communication Skills'));
    await tester.pumpAndSettle();

    expect(find.text('歸檔練習組'), findsOneWidget);
    expect(find.textContaining('168 小時內可恢復'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '歸檔'));
    await tester.pumpAndSettle();

    expect(service.archiveCalls, ['group-a']);
  });

  testWidgets('LibraryScreen 顯示課件清單並可切到練習/編輯', (tester) async {
    final service = _FakeProgressService();
    final packService = _FakeLessonPackService();
    final lessons = [
      LessonLibraryEntry(
        id: 'lesson-a',
        title: 'Saved Lesson',
        packPath: '/tmp/saved.abopack',
        updatedAt: DateTime.utc(2026, 7, 6),
      ),
    ];

    await _pump(
      tester,
      service: service,
      packService: packService,
      lessons: lessons,
      showNavigationProbe: true,
      child: const LibraryScreen(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved Lesson'), findsOneWidget);
    expect(find.text('saved.abopack'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '練習'));
    await tester.pumpAndSettle();
    expect(find.text('selected=3'), findsOneWidget);
    expect(packService.openedPaths, ['/tmp/saved.abopack']);

    await tester.tap(find.widgetWithText(OutlinedButton, '編輯'));
    await tester.pumpAndSettle();
    expect(find.text('selected=2'), findsOneWidget);
    expect(packService.openedPaths, [
      '/tmp/saved.abopack',
      '/tmp/saved.abopack',
    ]);
  });

  testWidgets('LibraryScreen 儲存課件會帶入手動譯文', (tester) async {
    final service = _FakeProgressService();
    final packService = _FakeLessonPackService();
    final packPicker = _FakeLessonPackFilePicker(
      savePath: '/tmp/saved.abopack',
    );

    await _pump(
      tester,
      service: service,
      packService: packService,
      packPicker: packPicker,
      draftBuilder: (manual) => _sampleLesson(manualTranslation: manual),
      child: const LibraryScreen(),
    );
    await tester.pumpAndSettle();

    await _scrollLibraryToPackPanel(tester);
    await tester.enterText(find.byType(TextField), '手動譯文');
    final saveButton = find.widgetWithText(OutlinedButton, '儲存課件');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(packService.savedPaths, ['/tmp/saved.abopack']);
    expect(packService.savedLessons.single.translations.single.text, '手動譯文');
    expect(find.textContaining('已儲存：/tmp/saved.abopack'), findsOneWidget);
  });

  testWidgets('LibraryScreen 開啟損毀課件不覆蓋現有譯文', (tester) async {
    final service = _FakeProgressService();
    final packService = _FakeLessonPackService(
      openError: const DomainException(ErrorCodes.packCorrupted, '課件損毀，無法開啟'),
    );
    final packPicker = _FakeLessonPackFilePicker(
      openPath: '/tmp/broken.abopack',
    );

    await _pump(
      tester,
      service: service,
      packService: packService,
      packPicker: packPicker,
      child: const LibraryScreen(),
    );
    await tester.pumpAndSettle();

    await _scrollLibraryToPackPanel(tester);
    await tester.enterText(find.byType(TextField), '保留中的譯文');
    final openButton = find.widgetWithText(OutlinedButton, '開啟課件');
    await tester.tap(openButton);
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, '保留中的譯文');
    expect(find.text('課件損毀，無法開啟'), findsOneWidget);
  });

  testWidgets('LibraryScreen 開啟課件會 hydrate editor 與 practice', (tester) async {
    final service = _FakeProgressService();
    final packService = _FakeLessonPackService();
    final packPicker = _FakeLessonPackFilePicker(
      openPath: '/tmp/saved.abopack',
    );

    final container = await _pump(
      tester,
      service: service,
      packService: packService,
      packPicker: packPicker,
      child: const LibraryScreen(),
    );
    await tester.pumpAndSettle();

    await _scrollLibraryToPackPanel(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, '開啟課件'));
    await tester.pumpAndSettle();

    expect(
      container.read(lessonSessionControllerProvider).lesson?.id,
      'lesson-a',
    );
    expect(
      container.read(editorControllerProvider).syllables.single.text,
      'Saved',
    );
    expect(container.read(practiceControllerProvider).decodedPcm?.samples, [
      0,
      1,
      2,
      3,
    ]);
    expect(container.read(practiceControllerProvider).steps, hasLength(1));
  });

  testWidgets('LibraryScreen ⌘O 與 ⌘S 觸發開啟/儲存課件', (tester) async {
    final service = _FakeProgressService();
    final packService = _FakeLessonPackService();
    final packPicker = _FakeLessonPackFilePicker(
      openPath: '/tmp/opened.abopack',
      savePath: '/tmp/saved.abopack',
    );

    await _pump(
      tester,
      service: service,
      packService: packService,
      packPicker: packPicker,
      draftBuilder: (manual) => _sampleLesson(manualTranslation: manual),
      child: const LibraryScreen(),
    );
    await tester.pumpAndSettle();
    await _scrollLibraryToPackPanel(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(packService.openedPaths, ['/tmp/opened.abopack']);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(packService.savedPaths, ['/tmp/saved.abopack']);
  });

  testWidgets('ProgressSettingsScreen 讀寫 reminderConfig', (tester) async {
    final service = _FakeProgressService(config: ReminderConfig.defaults);

    await _pump(
      tester,
      service: service,
      child: const ProgressSettingsScreen(),
    );
    await tester.pumpAndSettle();

    expect(find.text('15'), findsOneWidget);
    await tester.tap(find.byTooltip('每次分鐘 +1'));
    await tester.pump();
    final saveButton = find.widgetWithText(FilledButton, '儲存');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(service.savedConfig?.minutesPerSession, 16);
    expect(service.savedConfig?.failCapPerSession, 5);
    expect(service.savedConfig?.dailySessions, 2);
  });

  testWidgets('ProgressSettingsScreen 儲存 AI key 後清空欄位並可調 sidecar timeout', (
    tester,
  ) async {
    final service = _FakeProgressService(
      config: ReminderConfig.defaults,
      sidecarConfig: SidecarConfig.defaults,
    );
    final aiSettings = _FakeAiSettingsService();

    await _pump(
      tester,
      service: service,
      aiSettingsService: aiSettings,
      child: const ProgressSettingsScreen(),
    );
    await tester.pumpAndSettle();

    final aiKeyFieldFinder = find.byType(TextField);
    await tester.enterText(aiKeyFieldFinder, 'sk-local-value');
    await tester.tap(find.widgetWithText(FilledButton, '儲存 AI key'));
    await tester.pumpAndSettle();

    expect(aiSettings.configuredCredentials, ['sk-local-value']);
    final aiKeyField = tester.widget<TextField>(aiKeyFieldFinder);
    expect(aiKeyField.controller?.text, isEmpty);

    expect(find.text('120'), findsOneWidget);
    final sidecarIncrement = find.byTooltip('Sidecar 逾時秒數 +1');
    await tester.ensureVisible(sidecarIncrement);
    await tester.tap(sidecarIncrement);
    await tester.pump();
    final saveButton = find.widgetWithText(FilledButton, '儲存');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(service.savedSidecarConfig?.timeoutSeconds, 121);
  });

  testWidgets('ProgressSettingsScreen 匯出與匯入進度', (tester) async {
    final service = _FakeProgressService(
      importSummary: MergeSummary(
        applied: 2,
        skipped: 1,
        resetLessons: const ['lesson-a'],
      ),
    );
    final picker = _FakeProgressFilePicker(
      exportPath: '/tmp/progress.aboprogress',
      importPath: '/tmp/incoming.aboprogress',
    );

    await _pump(
      tester,
      service: service,
      picker: picker,
      child: const ProgressSettingsScreen(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('匯出進度'));
    await tester.pumpAndSettle();

    expect(service.exportPaths, ['/tmp/progress.aboprogress']);
    expect(
      find.textContaining('已匯出：/tmp/progress.aboprogress'),
      findsOneWidget,
    );

    await tester.tap(find.text('匯入進度'));
    await tester.pumpAndSettle();

    expect(service.importPaths, ['/tmp/incoming.aboprogress']);
    expect(find.text('匯入摘要'), findsOneWidget);
    expect(find.text('套用 2，略過 1'), findsWidgets);
    expect(find.text('重置課件：lesson-a'), findsWidgets);
  });

  testWidgets('S6 demo round-trip：pack、settle、progress 與 settings 串接', (
    tester,
  ) async {
    final service = _FakeProgressService(
      due: [
        DueGroup(
          groupId: 'lesson-a-step-1',
          lessonTitle: 'Saved Lesson',
          nextDue: DateTime.utc(2026, 7, 6, 9),
          priority: 2,
        ),
      ],
      importSummary: MergeSummary(
        applied: 1,
        skipped: 0,
        resetLessons: const ['lesson-a'],
      ),
    );
    final packService = _FakeLessonPackService();
    final packPicker = _FakeLessonPackFilePicker(
      openPath: '/tmp/opened.abopack',
      savePath: '/tmp/saved.abopack',
    );
    final progressPicker = _FakeProgressFilePicker(
      exportPath: '/tmp/progress.aboprogress',
      importPath: '/tmp/incoming.aboprogress',
    );
    final aiSettings = _FakeAiSettingsService();

    final libraryContainer = await _pump(
      tester,
      service: service,
      packService: packService,
      packPicker: packPicker,
      child: const LibraryScreen(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved Lesson'), findsOneWidget);
    await _scrollLibraryToPackPanel(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, '開啟課件'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '手動 round-trip');
    await tester.tap(find.widgetWithText(OutlinedButton, '儲存課件'));
    await tester.pumpAndSettle();

    expect(packService.openedPaths, ['/tmp/opened.abopack']);
    expect(packService.savedPaths, ['/tmp/saved.abopack']);
    expect(
      packService.savedLessons.single.translations.single.text,
      '手動 round-trip',
    );
    expect(
      libraryContainer.read(lessonSessionControllerProvider).lesson?.id,
      'lesson-a',
    );

    final group = PracticeGroup(
      id: 'lesson-a-step-1',
      profileId: 'profile-local',
      courseId: 'course-local',
      lessonId: 'lesson-a',
      name: '第 1 步',
      stepRange: const StepRange(startStepIndex: 1, endStepIndex: 1),
      updatedAt: DateTime.utc(2026, 7, 6),
    );
    await _pump(
      tester,
      service: service,
      child: SettleBar(groupId: group.id, group: group),
    );
    await tester.tap(find.text('普通'));
    await tester.pumpAndSettle();

    expect(service.ensureCalls.map((item) => item.id), ['lesson-a-step-1']);
    expect(service.settleCalls, [('lesson-a-step-1', Difficulty.normal)]);

    await _pump(
      tester,
      service: service,
      picker: progressPicker,
      aiSettingsService: aiSettings,
      child: const ProgressSettingsScreen(),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sk-round-trip');
    await tester.tap(find.widgetWithText(FilledButton, '儲存 AI key'));
    await tester.pumpAndSettle();
    expect(aiSettings.configuredCredentials, ['sk-round-trip']);

    await tester.tap(find.text('匯出進度'));
    await tester.pumpAndSettle();
    expect(service.exportPaths, ['/tmp/progress.aboprogress']);

    await tester.tap(find.text('匯入進度'));
    await tester.pumpAndSettle();
    expect(service.importPaths, ['/tmp/incoming.aboprogress']);
    expect(find.text('匯入摘要'), findsOneWidget);
    await tester.tap(find.text('關閉'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Sidecar 逾時秒數 +1'));
    await tester.tap(find.byTooltip('Sidecar 逾時秒數 +1'));
    await tester.pump();
    final saveButton = find.widgetWithText(FilledButton, '儲存');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(service.savedConfig?.minutesPerSession, 15);
    expect(service.savedSidecarConfig?.timeoutSeconds, 121);
  });

  testWidgets('ProgressSettingsScreen 顯示歸檔倒數並可恢復未過期項目', (tester) async {
    final service = _FakeProgressService(
      archived: [
        ArchivedGroup(
          groupId: 'group-a',
          lessonTitle: 'Archived Lesson',
          groupName: 'group-a',
          archivedAt: DateTime.utc(2026, 7, 1),
          restoreExpiresAt: DateTime.utc(2026, 7, 8),
          remainingRestoreWindow: const Duration(hours: 24),
          expired: false,
        ),
        ArchivedGroup(
          groupId: 'group-b',
          lessonTitle: 'Expired Lesson',
          groupName: 'group-b',
          archivedAt: DateTime.utc(2026, 6, 20),
          restoreExpiresAt: DateTime.utc(2026, 6, 27),
          remainingRestoreWindow: Duration.zero,
          expired: true,
        ),
      ],
    );

    await _pump(
      tester,
      service: service,
      child: const ProgressSettingsScreen(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Archived Lesson'), findsOneWidget);
    expect(find.text('剩餘 24 小時 可恢復'), findsOneWidget);
    expect(find.text('Expired Lesson'), findsOneWidget);
    expect(find.text('已超過 168 小時'), findsOneWidget);

    final restoreButtons = find.widgetWithText(FilledButton, '恢復');
    expect(restoreButtons, findsNWidgets(2));
    expect(tester.widget<FilledButton>(restoreButtons.at(1)).onPressed, isNull);

    await tester.tap(restoreButtons.first);
    await tester.pumpAndSettle();

    expect(service.restoreCalls, ['group-a']);
  });

  testWidgets('SettleBar 呼叫 settle 並顯示 nextDue', (tester) async {
    final service = _FakeProgressService();

    await _pump(
      tester,
      service: service,
      child: const SettleBar(groupId: 'group-a'),
    );

    await tester.tap(find.text('普通'));
    await tester.pumpAndSettle();

    expect(service.settleCalls, [('group-a', Difficulty.normal)]);
    expect(find.textContaining('下次：7/8 09:00'), findsOneWidget);
  });

  testWidgets('SettleBar 結算前會建立 PracticeGroup', (tester) async {
    final service = _FakeProgressService();
    final group = PracticeGroup(
      id: 'lesson-a-step-1',
      profileId: 'profile-local',
      courseId: 'course-local',
      lessonId: 'lesson-a',
      name: '第 1 步',
      stepRange: const StepRange(startStepIndex: 1, endStepIndex: 1),
      updatedAt: DateTime.utc(2026, 7, 6),
    );

    await _pump(
      tester,
      service: service,
      child: SettleBar(groupId: group.id, group: group),
    );

    await tester.tap(find.text('普通'));
    await tester.pumpAndSettle();

    expect(service.ensureCalls.map((item) => item.id), ['lesson-a-step-1']);
    expect(service.settleCalls, [('lesson-a-step-1', Difficulty.normal)]);
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required ProgressService service,
  ProgressFilePicker? picker,
  LessonPackService? packService,
  LessonPackFilePicker? packPicker,
  LessonDraftBuilder? draftBuilder,
  AiSettingsService? aiSettingsService,
  List<LessonLibraryEntry>? lessons,
  bool showNavigationProbe = false,
  required Widget child,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        progressServiceProvider.overrideWithValue(service),
        if (picker != null)
          progressFilePickerProvider.overrideWithValue(picker),
        if (packService != null)
          lessonPackServiceProvider.overrideWithValue(packService),
        if (packPicker != null)
          lessonPackFilePickerProvider.overrideWithValue(packPicker),
        if (draftBuilder != null)
          currentLessonDraftBuilderProvider.overrideWithValue(draftBuilder),
        if (aiSettingsService != null)
          aiSettingsServiceProvider.overrideWithValue(aiSettingsService),
        if (lessons != null)
          libraryLessonEntriesProvider.overrideWith((ref) async => lessons),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: showNavigationProbe
              ? Column(
                  children: [
                    Consumer(
                      builder: (context, ref, _) => Text(
                        'selected=${ref.watch(appShellSelectedIndexProvider)}',
                      ),
                    ),
                    Expanded(child: child),
                  ],
                )
              : child,
        ),
      ),
    ),
  );
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

Future<void> _scrollLibraryToPackPanel(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, -320));
  await tester.pumpAndSettle();
}

class _FakeProgressService implements ProgressService {
  _FakeProgressService({
    this.due = const [],
    this.archived = const [],
    this.config = ReminderConfig.defaults,
    SidecarConfig sidecarConfig = SidecarConfig.defaults,
    MergeSummary? importSummary,
  }) : currentSidecarConfig = sidecarConfig,
       importSummary =
           importSummary ??
           MergeSummary(applied: 0, skipped: 0, resetLessons: const []);

  final List<DueGroup> due;
  final List<ArchivedGroup> archived;
  ReminderConfig config;
  SidecarConfig currentSidecarConfig;
  final MergeSummary importSummary;
  ReminderConfig? savedConfig;
  SidecarConfig? savedSidecarConfig;
  final settleCalls = <(String, Difficulty)>[];
  final ensureCalls = <PracticeGroup>[];
  final archiveCalls = <String>[];
  final restoreCalls = <String>[];
  final exportPaths = <String>[];
  final importPaths = <String>[];

  @override
  Future<void> archive(String groupId) async {
    archiveCalls.add(groupId);
  }

  @override
  Future<List<ArchivedGroup>> archivedGroups(DateTime now) async => archived;

  @override
  Future<List<DueGroup>> dueList(DateTime now) async => due;

  @override
  Future<void> ensurePracticeGroup(PracticeGroup group) async {
    ensureCalls.add(group);
  }

  @override
  Future<String> exportProgress(String destPath) async {
    exportPaths.add(destPath);
    return destPath;
  }

  @override
  Future<MergeSummary> importProgress(String path) async {
    importPaths.add(path);
    return importSummary;
  }

  @override
  Future<ReminderConfig> reminderConfig() async => config;

  @override
  Future<SidecarConfig> sidecarConfig() async => currentSidecarConfig;

  @override
  Future<void> restore(String groupId) async {
    restoreCalls.add(groupId);
  }

  @override
  Future<ReminderConfig> saveReminderConfig(ReminderConfig config) async {
    savedConfig = config;
    this.config = config;
    return config;
  }

  @override
  Future<SidecarConfig> saveSidecarConfig(SidecarConfig config) async {
    savedSidecarConfig = config;
    currentSidecarConfig = config;
    return config;
  }

  @override
  Future<SrsState> settle(String groupId, Difficulty difficulty) async {
    settleCalls.add((groupId, difficulty));
    return SrsState(
      groupId: groupId,
      intervalIndex: 2,
      nextDue: DateTime.utc(2026, 7, 8, 9),
      difficulty: difficulty,
      updatedAt: DateTime.utc(2026, 7, 6, 9),
    );
  }
}

class _FakeAiSettingsService implements AiSettingsService {
  final configuredCredentials = <String>[];

  @override
  Future<void> configureCredential(String credential) async {
    configuredCredentials.add(credential);
  }
}

class _FakeLessonPackService implements LessonPackService {
  _FakeLessonPackService({this.openError});

  final Object? openError;
  final savedLessons = <Lesson>[];
  final savedPaths = <String>[];
  final openedPaths = <String>[];

  @override
  Future<Lesson> open(String path) async {
    openedPaths.add(path);
    final error = openError;
    if (error != null) {
      throw error;
    }
    return _sampleLesson(manualTranslation: '已開啟譯文');
  }

  @override
  Future<String> save(Lesson lesson, String path) async {
    savedLessons.add(lesson);
    savedPaths.add(path);
    return path;
  }
}

class _FakeLessonPackFilePicker implements LessonPackFilePicker {
  const _FakeLessonPackFilePicker({this.openPath, this.savePath});

  final String? openPath;
  final String? savePath;

  @override
  Future<String?> pickOpenPath() async => openPath;

  @override
  Future<String?> pickSavePath() async => savePath;
}

class _FakeProgressFilePicker implements ProgressFilePicker {
  _FakeProgressFilePicker({this.exportPath, this.importPath});

  final String? exportPath;
  final String? importPath;

  @override
  Future<String?> pickExportPath() async => exportPath;

  @override
  Future<String?> pickImportPath() async => importPath;
}

Lesson _sampleLesson({String manualTranslation = ''}) {
  final translation = manualTranslation.trim();
  return Lesson(
    id: 'lesson-a',
    title: 'Saved Lesson',
    audioRelPath: 'audio/original.wav',
    originalAudioBytes: encodeWav(
      Pcm(Int16List.fromList([0, 1, 2, 3]), sampleRate: 1000),
    ),
    contentHash: '',
    words: [Word(text: 'Saved', startMs: 0, endMs: 400, index: 0)],
    syllables: [
      Syllable(
        text: 'Saved',
        startMs: 0,
        endMs: 400,
        wordIndex: 0,
        needsReview: false,
      ),
    ],
    translations: translation.isEmpty
        ? const []
        : [
            Translation(
              text: translation,
              source: TranslationSource.manual,
              createdAt: DateTime.utc(2026, 7, 6),
            ),
          ],
    prosody: null,
    practiceConfig: const PracticeConfig(repeatN: 3),
    updatedAt: DateTime.utc(2026, 7, 6),
  );
}
