import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_app_lock/data/focus_behavior_settings_model.dart';
import 'package:project_app_lock/data/lock_session_model.dart';
import 'package:project_app_lock/data/study_content_model.dart';
import 'package:project_app_lock/data/task_model.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/features/focus_session/focus_session_screen.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';
import 'package:project_app_lock/features/focus_session/lock_session_repository.dart';
import 'package:project_app_lock/features/focus_session/study_attempt_store.dart';

import '../../fakes/fake_app_lock_gateway.dart';
import '../../fakes/fake_focus_behavior_settings_repository.dart';
import '../../fakes/fake_protected_app_selection_repository.dart';
import '../../fakes/fake_task_repository.dart';

void main() {
  late LockSessionRepository sessionRepository;
  late FakeTaskRepository taskRepository;
  late FocusSessionStore store;
  final now = DateTime.utc(2026, 9, 4, 8);

  setUp(() async {
    await sl.reset();
    sessionRepository = LockSessionRepository();
    taskRepository = FakeTaskRepository();
    await taskRepository.set(
      'task-1',
      TaskModel(
        id: 'task-1',
        title: 'Write report',
        durationMinutes: 25,
        createdAt: now,
      ),
    );
    await sessionRepository.set(
      'session-1',
      LockSessionModel(
        id: 'session-1',
        taskId: 'task-1',
        taskTitle: 'Write report',
        packageIds: const <String>['one.app', 'two.app'],
        startedAt: now,
        endsAt: now.add(const Duration(minutes: 25)),
        state: LockSessionState.active,
      ),
    );
    store = FocusSessionStore(
      sessionRepository: sessionRepository,
      taskRepository: taskRepository,
      selectionRepository: FakeProtectedAppSelectionRepository(),
      gateway: FakeAppLockGateway(),
      installedAppsGateway: FakeAppLockGateway(),
      settingsRepository: FakeFocusBehaviorSettingsRepository(),
      now: () => now,
    );
    sl.registerSingleton<FocusSessionStore>(store);
    sl.registerSingleton<StudyAttemptStore>(
      StudyAttemptStore(
        sessionRepository: sessionRepository,
        focusSessionStore: store,
      ),
    );
  });

  tearDown(() async {
    store.dispose();
    sessionRepository.dispose();
    taskRepository.close();
    await sl.reset();
  });

  testWidgets('shows the restored task, countdown, and locked app count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const FocusSessionScreen(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Write report'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('2 apps locked'), findsOneWidget);
    expect(find.text('Complete task and unlock'), findsOneWidget);
    expect(tester.takeException(), isNull);

    store.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renders a flashcard recall and answer reveal', (tester) async {
    final semantics = tester.ensureSemantics();
    final session = await sessionRepository.getById('session-1');
    await sessionRepository.set(
      'session-1',
      session!.copyWith(
        studyContent: const SessionStudyContentModel(
          format: StudyFormat.flashcards,
          items: <StudyItemModel>[
            StudyItemModel(
              id: 'card-1',
              prompt: 'Card front',
              answer: 'Card back',
            ),
          ],
        ),
        studyProgress: StudyProgressModel.empty(),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: FocusSessionScreen()));
    await tester.pump();
    await tester.pump();

    expect(find.text('Card 1 of 1'), findsOneWidget);
    expect(find.text('Front'), findsOneWidget);
    expect(find.text('Your recall'), findsOneWidget);
    expect(find.bySemanticsLabel('Reveal answer'), findsOneWidget);
    expect(find.text('Card back'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Recall');
    await tester.pump();
    await tester.tap(find.text('Reveal answer'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Card back'), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);

    await tester.tap(find.text('Correct'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Study complete'), findsOneWidget);
    expect(find.text('1 correct · 0 needs review'), findsOneWidget);

    semantics.dispose();
    store.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'uses the snapshotted Back policy and hides locked app-bar Back',
    (tester) async {
      final session = await sessionRepository.getById('session-1');
      await sessionRepository.set(
        'session-1',
        session!.copyWith(
          policy: const FocusSessionPolicyModel(
            lockToTaskScreen: true,
            allowOtherApps: false,
            backButtonEnabled: false,
          ),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: FocusSessionScreen()));
      await tester.pump();
      await tester.pump();

      final popScope = tester.widget<PopScope<Object?>>(
        find.byWidgetPredicate((widget) => widget is PopScope<Object?>),
      );
      expect(popScope.canPop, isFalse);
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).automaticallyImplyLeading,
        isFalse,
      );

      store.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('explains that expiry leaves the task incomplete', (
    tester,
  ) async {
    final expired = (await sessionRepository.getById('session-1'))!.copyWith(
      startedAt: now.subtract(const Duration(minutes: 30)),
      endsAt: now.subtract(const Duration(minutes: 5)),
    );
    await sessionRepository.set(expired.id, expired);

    await tester.pumpWidget(const MaterialApp(home: FocusSessionScreen()));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Time expired. Your task was not marked complete.'),
      findsOneWidget,
    );
    expect((await taskRepository.getById('task-1'))?.isCompleted, isFalse);
    store.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('offers safe recovery for invalid restored progress', (
    tester,
  ) async {
    final session = await sessionRepository.getById('session-1');
    await sessionRepository.set(
      'session-1',
      session!.copyWith(
        studyContent: const SessionStudyContentModel(
          format: StudyFormat.quiz,
          items: <StudyItemModel>[
            StudyItemModel(id: 'item-1', prompt: 'Prompt', answer: 'Answer'),
          ],
        ),
        studyProgress: const StudyProgressModel(
          currentItemIndex: 0,
          responses: <StudyResponseModel>[
            StudyResponseModel(
              itemId: 'not-in-snapshot',
              response: 'Response',
              isRevealed: true,
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: FocusSessionScreen()));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Saved study progress is invalid. Start a new focus session.'),
      findsOneWidget,
    );
    expect(find.text('End session and unlock'), findsOneWidget);
    store.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
