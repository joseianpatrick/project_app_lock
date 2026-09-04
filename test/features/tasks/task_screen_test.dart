import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';
import 'package:project_app_lock/features/focus_session/lock_session_repository.dart';
import 'package:project_app_lock/features/tasks/task_screen.dart';
import 'package:project_app_lock/features/tasks/task_store.dart';

import '../../fakes/fake_app_lock_gateway.dart';
import '../../fakes/fake_protected_app_selection_repository.dart';
import '../../fakes/fake_task_repository.dart';

void main() {
  late FakeTaskRepository taskRepository;
  late LockSessionRepository sessionRepository;
  late TaskStore taskStore;
  late FocusSessionStore sessionStore;

  setUp(() async {
    await sl.reset();
    taskRepository = FakeTaskRepository();
    sessionRepository = LockSessionRepository();
    taskStore = TaskStore(taskRepository: taskRepository);
    sessionStore = FocusSessionStore(
      sessionRepository: sessionRepository,
      taskRepository: taskRepository,
      selectionRepository: FakeProtectedAppSelectionRepository({'app.one'}),
      gateway: FakeAppLockGateway(),
      installedAppsGateway: FakeAppLockGateway(),
    );
    sl.registerSingleton<TaskStore>(taskStore);
    sl.registerSingleton<FocusSessionStore>(sessionStore);
  });

  tearDown(() async {
    taskStore.dispose();
    sessionStore.dispose();
    taskRepository.close();
    sessionRepository.dispose();
    await GetIt.instance.reset();
  });

  testWidgets('opens modal and creates a timed task', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TaskScreen()));
    await tester.pump();

    expect(find.textContaining('No tasks yet'), findsOneWidget);

    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Review notes');
    await tester.tap(find.widgetWithText(FilledButton, 'Create task'));
    await tester.pumpAndSettle();

    expect(find.text('Review notes'), findsOneWidget);
    expect(find.text('25 minutes'), findsOneWidget);
  });

  testWidgets('cancel leaves task data unchanged', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TaskScreen()));
    await tester.pump();
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Discard me');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Discard me'), findsNothing);
    expect(taskStore.tasks, isEmpty);
  });

  testWidgets('invalid title keeps modal open with inline error', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TaskScreen()));
    await tester.pump();
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Create task'));
    await tester.pump();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Enter a task title.'), findsOneWidget);
  });
}
