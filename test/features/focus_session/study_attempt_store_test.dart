import 'package:flutter_test/flutter_test.dart';
import 'package:project_app_lock/data/lock_session_model.dart';
import 'package:project_app_lock/data/protected_app_model.dart';
import 'package:project_app_lock/data/study_content_model.dart';
import 'package:project_app_lock/data/task_model.dart';
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
  late FakeAppLockGateway gateway;
  late FocusSessionStore focusStore;
  late StudyAttemptStore attemptStore;

  final now = DateTime.utc(2026, 9, 4, 8);

  setUp(() async {
    sessionRepository = LockSessionRepository();
    taskRepository = FakeTaskRepository();
    gateway = FakeAppLockGateway()
      ..apps = const <ProtectedAppModel>[
        ProtectedAppModel(packageId: 'app.one', displayName: 'One'),
      ];
    focusStore = FocusSessionStore(
      sessionRepository: sessionRepository,
      taskRepository: taskRepository,
      selectionRepository: FakeProtectedAppSelectionRepository({'app.one'}),
      gateway: gateway,
      installedAppsGateway: gateway,
      settingsRepository: FakeFocusBehaviorSettingsRepository(),
      now: () => now,
    );
    attemptStore = StudyAttemptStore(
      sessionRepository: sessionRepository,
      focusSessionStore: focusStore,
    );
    await taskRepository.set('task-1', _task(StudyFormat.quiz));
    await focusStore.initialize();
    await focusStore.start(_task(StudyFormat.quiz));
    attemptStore.initialize();
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() {
    attemptStore.dispose();
    focusStore.dispose();
    sessionRepository.dispose();
    taskRepository.close();
  });

  test('requires a response, reveal, and assessment in order', () async {
    expect(attemptStore.canReveal, isFalse);
    expect(await attemptStore.revealAnswer(), isFalse);
    expect(attemptStore.errorMessage, contains('Enter a response'));

    attemptStore.setResponseDraft('  A response  ');
    expect(await attemptStore.revealAnswer(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(attemptStore.currentResponse?.response, 'A response');
    expect(attemptStore.currentResponse?.isRevealed, isTrue);
    expect(attemptStore.canAssess, isTrue);

    expect(await attemptStore.assess(StudyAssessment.needsReview), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(attemptStore.isSummary, isTrue);
    expect(attemptStore.needsReviewCount, 1);
    expect(attemptStore.canComplete, isTrue);
  });

  test(
    'persists quiz progress and restores it in a new attempt store',
    () async {
      attemptStore.setResponseDraft('Answer');
      await attemptStore.revealAnswer();
      await Future<void>.delayed(Duration.zero);
      attemptStore.dispose();
      final restored = StudyAttemptStore(
        sessionRepository: sessionRepository,
        focusSessionStore: focusStore,
      )..initialize();
      addTearDown(restored.dispose);
      await Future<void>.delayed(Duration.zero);

      expect(restored.currentItem?.prompt, 'First prompt');
      expect(restored.currentResponse?.response, 'Answer');
      expect(restored.currentResponse?.isRevealed, isTrue);
    },
  );

  test(
    'completion persists the task before unlocking after assessment',
    () async {
      attemptStore.setResponseDraft('Answer');
      await attemptStore.revealAnswer();
      await Future<void>.delayed(Duration.zero);
      await attemptStore.assess(StudyAssessment.correct);
      await Future<void>.delayed(Duration.zero);

      expect(await attemptStore.completeAndUnlock(), isTrue);
      expect((await taskRepository.getById('task-1'))?.isCompleted, isTrue);
      expect(gateway.stopCalls, 1);
    },
  );

  test('flashcards use the same recall, reveal, and assessment flow', () async {
    final active = focusStore.activeSession!;
    await sessionRepository.set(
      active.id,
      active.copyWith(
        studyContent: const SessionStudyContentModel(
          format: StudyFormat.flashcards,
          items: <StudyItemModel>[
            StudyItemModel(
              id: 'flashcard-1',
              prompt: 'Card front',
              answer: 'Card back',
            ),
          ],
        ),
        studyProgress: StudyProgressModel.empty(),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    attemptStore.setResponseDraft('My recall');
    expect(await attemptStore.revealAnswer(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(attemptStore.currentResponse?.isRevealed, isTrue);
    expect(await attemptStore.assess(StudyAssessment.correct), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(attemptStore.isSummary, isTrue);
  });

  test('invalid persisted references show a recoverable error', () async {
    final active = focusStore.activeSession!;
    await sessionRepository.update(active.id, <String, Object?>{
      'studyProgress': const StudyProgressModel(
        currentItemIndex: 0,
        responses: <StudyResponseModel>[
          StudyResponseModel(
            itemId: 'missing-item',
            response: 'Answer',
            isRevealed: true,
          ),
        ],
      ),
    });
    await Future<void>.delayed(Duration.zero);

    expect(attemptStore.hasInvalidProgress, isTrue);
    expect(attemptStore.errorMessage, contains('invalid'));
    expect(await attemptStore.completeAndUnlock(), isFalse);
    expect((await taskRepository.getById('task-1'))?.isCompleted, isFalse);
  });
}

TaskModel _task(StudyFormat format) => TaskModel(
  id: 'task-1',
  title: 'Study task',
  durationMinutes: 25,
  createdAt: DateTime.utc(2026, 9, 4),
  studyContent: StudyContentModel(
    format: format,
    sourceNotes: 'These notes must not be placed in the session snapshot.',
    sourceId: 'manual',
    items: const <StudyItemModel>[
      StudyItemModel(
        id: 'item-1',
        prompt: 'First prompt',
        answer: 'First answer',
      ),
    ],
  ),
);
