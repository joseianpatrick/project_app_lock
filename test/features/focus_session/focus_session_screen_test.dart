import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_app_lock/data/lock_session_model.dart';
import 'package:project_app_lock/data/task_model.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/features/focus_session/focus_session_screen.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';
import 'package:project_app_lock/features/focus_session/lock_session_repository.dart';

import '../../fakes/fake_app_lock_gateway.dart';
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
      now: () => now,
    );
    sl.registerSingleton<FocusSessionStore>(store);
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
    await tester.pumpWidget(const MaterialApp(home: FocusSessionScreen()));
    await tester.pump();
    await tester.pump();

    expect(find.text('Write report'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('2 apps locked'), findsOneWidget);
    expect(find.text('Complete task and unlock'), findsOneWidget);
    expect(
      tester.getSize(find.byType(CircularProgressIndicator)),
      const Size.square(220),
    );
    expect(tester.takeException(), isNull);

    store.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
