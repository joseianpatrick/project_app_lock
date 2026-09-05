import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project_app_lock/data/lock_session_model.dart';
import 'package:project_app_lock/data/protected_app_model.dart';
import 'package:project_app_lock/data/task_model.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';
import 'package:project_app_lock/features/focus_session/lock_session_repository.dart';
import 'package:project_app_lock/features/home/home_screen.dart';
import 'package:project_app_lock/features/protected_apps/protected_apps_store.dart';
import 'package:project_app_lock/features/tasks/task_store.dart';

import '../../fakes/fake_app_lock_gateway.dart';
import '../../fakes/fake_focus_behavior_settings_repository.dart';
import '../../fakes/fake_protected_app_selection_repository.dart';
import '../../fakes/fake_task_repository.dart';

void main() {
  late FakeTaskRepository taskRepository;
  late LockSessionRepository sessionRepository;
  late FakeProtectedAppSelectionRepository selectionRepository;
  late FakeAppLockGateway gateway;
  late TaskStore taskStore;
  late ProtectedAppsStore appsStore;
  late FocusSessionStore sessionStore;
  late GoRouter router;
  final now = DateTime.utc(2030, 1, 1, 8);

  setUp(() async {
    await sl.reset();
    taskRepository = FakeTaskRepository();
    sessionRepository = LockSessionRepository();
    selectionRepository = FakeProtectedAppSelectionRepository();
    gateway = FakeAppLockGateway();
    taskStore = TaskStore(taskRepository: taskRepository);
    appsStore = ProtectedAppsStore(
      gateway: gateway,
      selectionRepository: selectionRepository,
      minimumSaveDuration: Duration.zero,
    );
    sessionStore = FocusSessionStore(
      sessionRepository: sessionRepository,
      taskRepository: taskRepository,
      selectionRepository: selectionRepository,
      gateway: gateway,
      installedAppsGateway: gateway,
      settingsRepository: FakeFocusBehaviorSettingsRepository(),
      now: () => now,
    );
    sl.registerSingleton<TaskStore>(taskStore);
    sl.registerSingleton<ProtectedAppsStore>(appsStore);
    sl.registerSingleton<FocusSessionStore>(sessionStore);
    router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/tasks',
          name: 'tasks',
          builder: (context, state) => const Text('Tasks page'),
        ),
        GoRoute(
          path: '/apps-to-lock',
          name: 'apps-to-lock',
          builder: (context, state) => const Text('Apps page'),
        ),
        GoRoute(
          path: '/focus-session',
          name: 'focus-session',
          builder: (context, state) => const Text('Session page'),
        ),
      ],
    );
  });

  tearDown(() async {
    router.dispose();
    taskStore.dispose();
    sessionStore.dispose();
    taskRepository.close();
    sessionRepository.dispose();
    await sl.reset();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 792);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('shows the empty dashboard state', (tester) async {
    await pumpHome(tester);

    expect(find.text('All complete'), findsOneWidget);
    expect(find.text('0 selected'), findsOneWidget);
    expect(find.text('No focus session is active right now.'), findsOneWidget);
    expect(find.text('0 of 0 tasks completed'), findsOneWidget);
  });

  testWidgets('shows populated task, app, and session summaries', (
    tester,
  ) async {
    await taskRepository.set(
      'task-1',
      TaskModel(
        id: 'task-1',
        title: 'Write report',
        durationMinutes: 25,
        createdAt: now,
      ),
    );
    selectionRepository.values = {'com.chat', 'com.video'};
    gateway.apps = const <ProtectedAppModel>[
      ProtectedAppModel(packageId: 'com.chat', displayName: 'Chat'),
      ProtectedAppModel(packageId: 'com.video', displayName: 'Video'),
    ];
    await sessionRepository.set(
      'session-1',
      LockSessionModel(
        id: 'session-1',
        taskId: 'task-1',
        taskTitle: 'Write report',
        packageIds: const <String>['com.chat', 'com.video'],
        startedAt: now,
        endsAt: now.add(const Duration(minutes: 25)),
        state: LockSessionState.active,
      ),
    );

    await pumpHome(tester);

    expect(find.text('1 pending'), findsOneWidget);
    expect(find.text('1 task in your focus list.'), findsOneWidget);
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.text('🔒  Active'), findsOneWidget);
    expect(find.text('Write report is locking 2 apps.'), findsOneWidget);
    expect(find.text('0 of 1 tasks completed'), findsOneWidget);

    sessionStore.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dashboard actions navigate to each feature', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('Create your task list'));
    await tester.pumpAndSettle();
    expect(find.text('Tasks page'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apps to lock'));
    await tester.pumpAndSettle();
    expect(find.text('Apps page'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active focus session'));
    await tester.pumpAndSettle();
    expect(find.text('Session page'), findsOneWidget);
  });
}
