import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_app_lock/data/focus_behavior_settings_model.dart';
import 'package:project_app_lock/data/lock_session_model.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';
import 'package:project_app_lock/features/focus_session/lock_session_repository.dart';
import 'package:project_app_lock/features/focus_session/study_attempt_store.dart';
import 'package:project_app_lock/features/settings/settings_store.dart';
import 'package:project_app_lock/features/tasks/task_store.dart';
import 'package:project_app_lock/router/app_router.dart';

import '../fakes/fake_app_lock_gateway.dart';
import '../fakes/fake_focus_behavior_settings_repository.dart';
import '../fakes/fake_protected_app_selection_repository.dart';
import '../fakes/fake_task_repository.dart';

void main() {
  late LockSessionRepository sessionRepository;
  late FakeTaskRepository taskRepository;
  late FakeFocusBehaviorSettingsRepository settingsRepository;
  late FocusSessionStore store;
  AppRouter? appRouter;
  final now = DateTime.utc(2026, 9, 5, 8);

  setUp(() async {
    await sl.reset();
    sessionRepository = LockSessionRepository();
    taskRepository = FakeTaskRepository();
    settingsRepository = FakeFocusBehaviorSettingsRepository();
    final gateway = FakeAppLockGateway();
    store = FocusSessionStore(
      sessionRepository: sessionRepository,
      taskRepository: taskRepository,
      selectionRepository: FakeProtectedAppSelectionRepository(),
      gateway: gateway,
      installedAppsGateway: gateway,
      settingsRepository: settingsRepository,
      now: () => now,
    );
    sl.registerSingleton<FocusSessionStore>(store);
    sl.registerSingleton<StudyAttemptStore>(
      StudyAttemptStore(
        sessionRepository: sessionRepository,
        focusSessionStore: store,
      ),
    );
    sl.registerSingleton<TaskStore>(TaskStore(taskRepository: taskRepository));
    sl.registerSingleton<SettingsStore>(
      SettingsStore(
        settingsRepository: settingsRepository,
        focusSessionStore: store,
      ),
    );
  });

  tearDown(() async {
    appRouter?.dispose();
    store.dispose();
    sessionRepository.dispose();
    taskRepository.close();
    await sl.reset();
  });

  Future<void> addSession({required bool lockToTaskScreen}) {
    return sessionRepository.set(
      'session-1',
      LockSessionModel(
        id: 'session-1',
        taskId: 'task-1',
        taskTitle: 'Write report',
        packageIds: const <String>['one.app'],
        startedAt: now,
        endsAt: now.add(const Duration(minutes: 25)),
        state: LockSessionState.active,
        policy: FocusSessionPolicyModel(
          lockToTaskScreen: lockToTaskScreen,
          allowOtherApps: false,
          backButtonEnabled: false,
        ),
      ),
    );
  }

  testWidgets('redirects every protected deep link to the task screen', (
    tester,
  ) async {
    await addSession(lockToTaskScreen: true);
    const protectedPaths = <String>[
      '/',
      '/tasks',
      '/tasks/new',
      '/tasks/task-1/edit',
      '/apps-to-lock',
      '/settings',
    ];

    for (final path in protectedPaths) {
      appRouter = AppRouter(store, initialLocation: path);
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: appRouter!.router),
      );
      await tester.pump();
      await tester.pump();

      expect(
        appRouter!.router.routeInformationProvider.value.uri.path,
        '/focus-session',
      );
      expect(find.text('Write report'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      appRouter!.dispose();
      appRouter = null;
    }
    store.dispose();
  });

  testWidgets('permits normal shell navigation when task-screen lock is off', (
    tester,
  ) async {
    await addSession(lockToTaskScreen: false);
    appRouter = AppRouter(store, initialLocation: '/tasks');

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: appRouter!.router),
    );
    await tester.pump();
    await tester.pump();

    expect(appRouter!.router.routeInformationProvider.value.uri.path, '/tasks');
    expect(
      find.text('No study tasks yet. Add a quiz or flashcard task.'),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    store.dispose();
  });

}
