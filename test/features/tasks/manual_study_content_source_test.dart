import 'package:flutter_test/flutter_test.dart';
import 'package:project_app_lock/data/study_content_model.dart';
import 'package:project_app_lock/data/study_content_source.dart';
import 'package:project_app_lock/features/tasks/manual_study_content_source.dart';

void main() {
  late StudyContentSource source;

  setUp(() {
    source = ManualStudyContentSource();
  });

  test(
    'manual source is substitutable and normalizes authored content',
    () async {
      final result = await source.create(
        const StudyContentAuthoringRequest(
          format: StudyFormat.quiz,
          sourceNotes: '  Chapter one  ',
          items: <StudyItemModel>[
            StudyItemModel(
              id: ' item-1 ',
              prompt: ' What is focus? ',
              answer: ' Concentration ',
            ),
          ],
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.failure, isNull);
      expect(result.content?.sourceId, 'manual');
      expect(result.content?.sourceNotes, 'Chapter one');
      expect(
        result.content?.items.single,
        const StudyItemModel(
          id: 'item-1',
          prompt: 'What is focus?',
          answer: 'Concentration',
        ),
      );
    },
  );

  test(
    'manual source returns a typed failure without partial content',
    () async {
      final result = await source.create(
        const StudyContentAuthoringRequest(
          format: StudyFormat.flashcards,
          sourceNotes: 'Notes',
          items: <StudyItemModel>[
            StudyItemModel(id: 'one', prompt: 'Prompt', answer: '  '),
          ],
        ),
      );

      expect(result.isSuccess, isFalse);
      expect(result.content, isNull);
      expect(result.failure, StudyContentValidationFailure.emptyAnswer);
    },
  );
}
