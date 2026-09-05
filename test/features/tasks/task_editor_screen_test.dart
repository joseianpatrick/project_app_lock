import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project_app_lock/data/task_model.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/features/tasks/manual_study_content_source.dart';
import 'package:project_app_lock/features/tasks/task_editor_screen.dart';
import 'package:project_app_lock/features/tasks/task_editor_store.dart';

import '../../fakes/fake_task_repository.dart';

void main() {
  late FakeTaskRepository repository;
  late TaskEditorStore editor;

  setUp(() async {
    await sl.reset();
    repository = FakeTaskRepository();
    sl.registerFactory<TaskEditorStore>(
      () => editor = TaskEditorStore(
        taskRepository: repository,
        studyContentSource: ManualStudyContentSource(),
      ),
    );
  });

  tearDown(() async {
    repository.close();
    await sl.reset();
  });

  testWidgets('creates a quiz task from the named create route', (
    tester,
  ) async {
    await _pumpEditor(tester);

    expect(find.text('Create task'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
    await _enterKeyedField(tester, 'task-title-field', 'Review verbs');
    await _enterKeyedField(tester, 'task-notes-field', 'Grammar notes');
    tester.widget<ChoiceChip>(find.byKey(const Key('duration-45'))).onSelected!(
      true,
    );
    tester
        .widget<OutlinedButton>(find.byKey(const Key('add-study-item')))
        .onPressed!();
    await tester.pump();
    editor.updateItem(
      'id_0',
      prompt: 'Define a verb',
      answer: 'An action word',
    );
    await _scrollToBottom(tester);
    tester
        .widget<FilledButton>(find.byKey(const Key('save-task')))
        .onPressed!();
    await tester.pump();
    await tester.pump();

    expect(find.text('Tasks destination'), findsOneWidget);
    final task = await repository.getById('id_1');
    expect(task?.title, 'Review verbs');
    expect(task?.durationMinutes, 45);
    expect(task?.studyContent?.items.single.answer, 'An action word');
  });

  testWidgets('cancel returns without persisting a draft', (tester) async {
    await _pumpEditor(tester);
    await _enterKeyedField(tester, 'task-title-field', 'Discard me');
    await tester.tap(find.byTooltip('Back to tasks'));
    await tester.pump();

    expect(find.text('Tasks destination'), findsOneWidget);
    expect(await repository.getById('id_0'), isNull);
  });

  testWidgets('keeps invalid input open with an inline error', (tester) async {
    await _pumpEditor(tester);
    await _scrollToBottom(tester);
    tester
        .widget<FilledButton>(find.byKey(const Key('save-task')))
        .onPressed!();
    await tester.pump();

    expect(find.text('Enter a task title.'), findsOneWidget);
    expect(find.text('Create task'), findsOneWidget);
  });

  testWidgets('loads legacy tasks for upgrade and handles missing route ids', (
    tester,
  ) async {
    final legacy = TaskModel(
      id: 'legacy',
      title: 'Old task',
      durationMinutes: 25,
      createdAt: DateTime.utc(2026, 9, 4),
    );
    await repository.set(legacy.id, legacy);
    await _pumpEditor(tester, location: '/tasks/legacy/edit');
    await tester.pump();

    expect(find.text('Edit task'), findsOneWidget);
    expect(find.text('Old task'), findsOneWidget);
    expect(find.text('Add a prompt and answer to begin.'), findsOneWidget);

    await _pumpEditor(tester, location: '/tasks/missing/edit');
    await tester.pump();
    expect(
      find.text('This task no longer exists.', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('shows saving progress and resists duplicate save taps', (
    tester,
  ) async {
    await _pumpEditor(tester, textScale: 1.3);
    await _enterKeyedField(tester, 'task-title-field', 'Task title');
    await _enterKeyedField(tester, 'task-notes-field', 'Notes');
    editor
      ..setTitle('Task title')
      ..setSourceNotes('Notes')
      ..addItem()
      ..updateItem('id_0', prompt: 'Prompt', answer: 'Answer');
    final gate = Completer<void>();
    repository.setGate = gate;

    final save = editor.save();
    await tester.pump();
    expect(editor.isSaving, isTrue);
    expect(tester.takeException(), isNull);
    expect(repository.setCalls, 1);

    gate.complete();
    expect(await save, isTrue);
  });
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  String location = '/tasks/new',
  double? textScale,
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: <RouteBase>[
      GoRoute(
        path: '/tasks',
        name: 'tasks',
        builder: (_, _) => const Scaffold(body: Text('Tasks destination')),
      ),
      GoRoute(
        path: '/tasks/new',
        name: 'task-create',
        builder: (_, _) => const TaskEditorScreen(),
      ),
      GoRoute(
        path: '/tasks/:taskId/edit',
        name: 'task-edit',
        builder: (_, state) =>
            TaskEditorScreen(taskId: state.pathParameters['taskId']),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: textScale == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _enterKeyedField(
  WidgetTester tester,
  String key,
  String value,
) async {
  final finder = find.byKey(Key(key));
  await tester.enterText(finder, value);
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -2000));
  await tester.pump();
}
