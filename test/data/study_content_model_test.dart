import 'package:flutter_test/flutter_test.dart';
import 'package:project_app_lock/data/study_content_model.dart';
import 'package:project_app_lock/data/task_model.dart';

void main() {
  const firstItem = StudyItemModel(
    id: 'one',
    prompt: 'What is a noun?',
    answer: 'A naming word.',
  );
  const secondItem = StudyItemModel(
    id: 'two',
    prompt: 'What is a verb?',
    answer: 'An action word.',
  );

  test('study content round-trips ordered quiz items', () {
    const content = StudyContentModel(
      format: StudyFormat.quiz,
      sourceNotes: 'Grammar notes',
      items: <StudyItemModel>[firstItem, secondItem],
      sourceId: 'manual',
    );

    final restored = StudyContentModel.fromMap(
      Map<String, dynamic>.from(content.toMap()),
    );

    expect(restored, content);
    expect(restored.items.map((item) => item.id), <String>['one', 'two']);
  });

  test('flashcard content retains its format', () {
    const content = StudyContentModel(
      format: StudyFormat.flashcards,
      sourceNotes: 'Vocabulary',
      items: <StudyItemModel>[firstItem],
      sourceId: 'manual',
    );

    expect(
      StudyContentModel.fromMap(
        Map<String, dynamic>.from(content.toMap()),
      ).format,
      StudyFormat.flashcards,
    );
  });

  test('legacy task map loads without study content', () {
    final task = TaskModel.fromMap(<String, dynamic>{
      'id': 'legacy',
      'title': 'Existing focus task',
      'durationMinutes': 45,
      'createdAt': '2026-09-05T00:00:00.000Z',
      'completedAt': null,
    });

    expect(task.studyContent, isNull);
    expect(task.title, 'Existing focus task');
    expect(task.durationMinutes, 45);
  });

  test('invalid serialized format makes task content unavailable', () {
    final task = TaskModel.fromMap(<String, dynamic>{
      'id': 'invalid',
      'title': 'Needs repair',
      'durationMinutes': 25,
      'createdAt': '2026-09-05T00:00:00.000Z',
      'studyContent': <String, dynamic>{
        'format': 'essay',
        'sourceNotes': 'Notes',
        'sourceId': 'manual',
        'items': <Map<String, String>>[
          <String, String>{'id': 'one', 'prompt': 'Prompt', 'answer': 'Answer'},
        ],
      },
    });

    expect(task.studyContent, isNull);
  });
}
