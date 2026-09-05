import 'package:flutter_test/flutter_test.dart';
import 'package:project_app_lock/data/focus_behavior_settings_model.dart';
import 'package:project_app_lock/data/lock_session_model.dart';
import 'package:project_app_lock/data/study_content_model.dart';
import 'package:project_app_lock/features/focus_session/lock_session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('persists a content, policy, duration, and response snapshot', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = LockSessionRepository(preferences: preferences);
    final session = _session();

    await repository.set(session.id, session);
    final restoredRepository = LockSessionRepository(preferences: preferences);
    final restored = await restoredRepository.getById(session.id);

    expect(restored?.durationMinutes, 25);
    expect(restored?.policy?.lockToTaskScreen, isTrue);
    expect(restored?.studyContent?.format, StudyFormat.flashcards);
    expect(restored?.studyContent?.items.map((item) => item.id), ['item-1']);
    expect(restored?.studyProgress?.currentItemIndex, 1);
    expect(
      restored?.studyProgress?.responses.single.assessment,
      StudyAssessment.correct,
    );
    expect(restored?.toMap()['studyContent'], isNot(contains('sourceNotes')));

    repository.dispose();
    restoredRepository.dispose();
  });

  test(
    'updates only study progress without losing its session snapshot',
    () async {
      final repository = LockSessionRepository();
      final session = _session().copyWith(
        studyProgress: StudyProgressModel.empty(),
      );
      await repository.set(session.id, session);
      await repository.update(session.id, <String, Object?>{
        'studyProgress': const StudyProgressModel(
          currentItemIndex: 1,
          responses: <StudyResponseModel>[
            StudyResponseModel(
              itemId: 'item-1',
              response: 'Recall',
              isRevealed: true,
              assessment: StudyAssessment.needsReview,
            ),
          ],
        ),
      });

      final updated = await repository.getById(session.id);
      expect(updated?.taskTitle, 'Study task');
      expect(updated?.studyContent?.items.single.answer, 'Expected answer');
      expect(
        updated?.studyProgress?.responses.single.assessment,
        StudyAssessment.needsReview,
      );
      repository.dispose();
    },
  );
}

LockSessionModel _session() => LockSessionModel(
  id: 'session-1',
  taskId: 'task-1',
  taskTitle: 'Study task',
  packageIds: const <String>['app.one'],
  startedAt: DateTime.utc(2026, 9, 4, 8),
  endsAt: DateTime.utc(2026, 9, 4, 8, 25),
  state: LockSessionState.active,
  durationMinutes: 25,
  policy: FocusSessionPolicyModel.fromSettings(
    FocusBehaviorSettingsModel.defaults(),
  ),
  studyContent: const SessionStudyContentModel(
    format: StudyFormat.flashcards,
    items: <StudyItemModel>[
      StudyItemModel(id: 'item-1', prompt: 'Prompt', answer: 'Expected answer'),
    ],
  ),
  studyProgress: const StudyProgressModel(
    currentItemIndex: 1,
    responses: <StudyResponseModel>[
      StudyResponseModel(
        itemId: 'item-1',
        response: 'Recall',
        isRevealed: true,
        assessment: StudyAssessment.correct,
      ),
    ],
  ),
);
