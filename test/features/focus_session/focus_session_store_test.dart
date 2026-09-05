import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_app_lock/data/focus_behavior_settings_model.dart';
import 'package:project_app_lock/data/lock_session_model.dart';
import 'package:project_app_lock/data/protected_app_model.dart';
import 'package:project_app_lock/data/study_content_model.dart';
import 'package:project_app_lock/data/task_model.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';
import 'package:project_app_lock/features/focus_session/lock_session_repository.dart';
import 'package:project_app_lock/platform/app_lock/system_app_lock_gateway.dart';

import '../../fakes/fake_app_lock_gateway.dart';
import '../../fakes/fake_focus_behavior_settings_repository.dart';
import '../../fakes/fake_protected_app_selection_repository.dart';
import '../../fakes/fake_task_repository.dart';

void main() {
  late LockSessionRepository sessionRepository;
  late FakeTaskRepository taskRepository;
  late FakeProtectedAppSelectionRepository selectionRepository;
  late FakeAppLockGateway gateway;
  late FakeFocusBehaviorSettingsRepository settingsRepository;
  late FocusSessionStore store;
  final now = DateTime.utc(2026, 9, 4, 8);
  final task = TaskModel(
    id: 'task-1',
    title: 'Write report',
    durationMinutes: 25,
    createdAt: DateTime.utc(2026, 9, 4),
    studyContent: const StudyContentModel(
      format: StudyFormat.quiz,
      sourceNotes: 'Report notes',
      sourceId: 'manual',
      items: <StudyItemModel>[
        StudyItemModel(id: 'one', prompt: 'Prompt', answer: 'Answer'),
      ],
    ),
  );

  setUp(() async {
    sessionRepository = LockSessionRepository();
    taskRepository = FakeTaskRepository();
    selectionRepository = FakeProtectedAppSelectionRepository({
      'b.app',
      'a.app',
    });
    gateway = FakeAppLockGateway()
      ..apps = const <ProtectedAppModel>[
        ProtectedAppModel(packageId: 'a.app', displayName: 'A'),
        ProtectedAppModel(packageId: 'b.app', displayName: 'B'),
      ];
    settingsRepository = FakeFocusBehaviorSettingsRepository();
    store = FocusSessionStore(
      sessionRepository: sessionRepository,
      taskRepository: taskRepository,
      selectionRepository: selectionRepository,
      gateway: gateway,
      installedAppsGateway: gateway,
      settingsRepository: settingsRepository,
      now: () => now,
    );
    await taskRepository.set(task.id, task);
    await store.initialize();
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() {
    store.dispose();
    sessionRepository.dispose();
    taskRepository.close();
  });

  test('requires at least one selected app', () async {
    selectionRepository.values.clear();

    expect(await store.validateStart(task), 'Select at least one app to lock.');
  });

  test('requires study content before starting a legacy task', () async {
    final legacyTask = task.copyWith(studyContent: null);

    expect(
      await store.validateStart(legacyTask),
      'Add study content before starting this task.',
    );
  });

  test('start snapshots task, apps, and end time', () async {
    expect(await store.start(task), isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(gateway.startCalls, 1);
    expect(gateway.startedPackageIds, ['a.app', 'b.app']);
    expect(gateway.startedEndsAt, now.add(const Duration(minutes: 25)));
    expect(gateway.startedPolicy, ExternalAppLockPolicy.allEligible);
    expect(store.activeSession?.state, LockSessionState.active);
    expect(store.activeSession?.policy?.lockToTaskScreen, isTrue);
    expect(store.activeSession?.policy?.allowOtherApps, isFalse);
    expect(store.activeSession?.policy?.backButtonEnabled, isFalse);
    expect(store.remaining, const Duration(minutes: 25));
    expect(store.activeSession?.studyContent?.format, StudyFormat.quiz);
    expect(store.activeSession?.studyContent?.items.single.prompt, 'Prompt');
    expect(store.activeSession?.durationMinutes, 25);
  });

  test('session policy remains unchanged after settings are changed', () async {
    await store.start(task);
    await Future<void>.delayed(Duration.zero);

    await settingsRepository.save(
      const FocusBehaviorSettingsModel(
        lockToTaskScreen: false,
        allowOtherApps: true,
        backButtonEnabled: true,
      ),
    );

    expect(
      store.activeSession?.policy,
      FocusSessionPolicyModel.fromSettings(
        FocusBehaviorSettingsModel.defaults(),
      ),
    );
  });

  test('uses selected-only enforcement when other apps are allowed', () async {
    await settingsRepository.save(
      const FocusBehaviorSettingsModel(
        lockToTaskScreen: true,
        allowOtherApps: true,
        backButtonEnabled: false,
      ),
    );

    expect(await store.start(task), isTrue);

    expect(gateway.startedPolicy, ExternalAppLockPolicy.selectedOnly);
  });

  test('session study snapshot is isolated from later task edits', () async {
    await store.start(task);
    await Future<void>.delayed(Duration.zero);

    await taskRepository.update(task.id, <String, Object?>{
      'studyContent': const StudyContentModel(
        format: StudyFormat.flashcards,
        sourceNotes: 'Changed notes',
        sourceId: 'manual',
        items: <StudyItemModel>[
          StudyItemModel(id: 'changed', prompt: 'Changed', answer: 'Changed'),
        ],
      ),
    });

    expect(store.activeSession?.studyContent?.format, StudyFormat.quiz);
    expect(store.activeSession?.studyContent?.items.single.id, 'one');
  });

  test('concurrent start calls create only one session', () async {
    final gate = Completer<void>();
    gateway.capabilityGate = gate;

    final first = store.start(task);
    await Future<void>.delayed(Duration.zero);
    expect(store.isBusy, isTrue);
    expect(await store.start(task), isFalse);

    gate.complete();
    expect(await first, isTrue);
    expect(gateway.startCalls, 1);
    expect(await sessionRepository.watch().first, hasLength(1));
  });

  test(
    'validation removes selected packages that are no longer installed',
    () async {
      selectionRepository.values.add('missing.app');

      expect(await store.validateStart(task), isNull);
      expect(selectionRepository.values, {'a.app', 'b.app'});
    },
  );

  test('native start failure cancels persisted session', () async {
    gateway.failStart = true;

    expect(await store.start(task), isFalse);
    await Future<void>.delayed(Duration.zero);

    expect(store.activeSession, isNull);
    expect(store.errorMessage, contains('could not start'));
  });

  test(
    'new study sessions cannot complete before every item is assessed',
    () async {
      await store.start(task);
      await Future<void>.delayed(Duration.zero);

      expect(await store.completeActiveTask(), isFalse);
      await Future<void>.delayed(Duration.zero);

      expect((await taskRepository.getById(task.id))?.isCompleted, isFalse);
      expect(gateway.stopCalls, 0);
    },
  );

  test('unlock failure retains recoverable state', () async {
    await store.start(task);
    await Future<void>.delayed(Duration.zero);
    await _assessOnlyItem(sessionRepository, store);
    gateway.failStop = true;

    expect(await store.completeActiveTask(), isFalse);
    await Future<void>.delayed(Duration.zero);

    expect(store.needsUnlockRetry, isTrue);
  });

  test('concurrent retry taps invoke native unlock only once', () async {
    await store.start(task);
    await Future<void>.delayed(Duration.zero);
    await _assessOnlyItem(sessionRepository, store);
    gateway.failStop = true;
    await store.completeActiveTask();
    await Future<void>.delayed(Duration.zero);
    gateway.failStop = false;
    final gate = Completer<void>();
    gateway.stopGate = gate;
    final callsBeforeRetry = gateway.stopCalls;

    final first = store.retryUnlock();
    await Future<void>.delayed(Duration.zero);
    expect(store.isBusy, isTrue);
    expect(await store.retryUnlock(), isFalse);
    expect(gateway.stopCalls, callsBeforeRetry + 1);

    gate.complete();
    expect(await first, isTrue);
  });

  test('relaunch restores enforcement for an unexpired session', () async {
    store.dispose();
    await sessionRepository.set(
      'session-1',
      LockSessionModel(
        id: 'session-1',
        taskId: task.id,
        taskTitle: task.title,
        packageIds: const <String>['a.app'],
        startedAt: now,
        endsAt: now.add(const Duration(minutes: 25)),
        state: LockSessionState.active,
      ),
    );
    gateway.startCalls = 0;
    store = FocusSessionStore(
      sessionRepository: sessionRepository,
      taskRepository: taskRepository,
      selectionRepository: selectionRepository,
      gateway: gateway,
      installedAppsGateway: gateway,
      settingsRepository: FakeFocusBehaviorSettingsRepository(),
      now: () => now,
    );

    await store.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(gateway.startCalls, 1);
    expect(store.activeSession?.id, 'session-1');
  });

  test('relaunch expires an elapsed session before native unlock', () async {
    store.dispose();
    await sessionRepository.set(
      'session-1',
      LockSessionModel(
        id: 'session-1',
        taskId: task.id,
        taskTitle: task.title,
        packageIds: const <String>['a.app'],
        startedAt: now.subtract(const Duration(minutes: 30)),
        endsAt: now.subtract(const Duration(minutes: 5)),
        state: LockSessionState.active,
      ),
    );
    gateway.stopCalls = 0;
    store = FocusSessionStore(
      sessionRepository: sessionRepository,
      taskRepository: taskRepository,
      selectionRepository: selectionRepository,
      gateway: gateway,
      installedAppsGateway: gateway,
      settingsRepository: FakeFocusBehaviorSettingsRepository(),
      now: () => now,
    );

    await store.initialize();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(gateway.stopCalls, 1);
    expect(store.activeSession, isNull);
  });
}

Future<void> _assessOnlyItem(
  LockSessionRepository repository,
  FocusSessionStore store,
) async {
  final session = store.activeSession!;
  await repository.update(session.id, <String, Object?>{
    'studyProgress': const StudyProgressModel(
      currentItemIndex: 1,
      responses: <StudyResponseModel>[
        StudyResponseModel(
          itemId: 'one',
          response: 'Response',
          isRevealed: true,
          assessment: StudyAssessment.correct,
        ),
      ],
    ),
  });
  await Future<void>.delayed(Duration.zero);
}
