import 'package:project_app_lock/data/study_content_model.dart';
import 'package:project_app_lock/data/study_content_source.dart';

final class ManualStudyContentSource implements StudyContentSource {
  static const String sourceId = 'manual';

  @override
  Future<StudyContentSourceResult> create(
    StudyContentAuthoringRequest request,
  ) async {
    final notes = request.sourceNotes.trim();
    if (notes.isEmpty) {
      return const StudyContentSourceResult.failure(
        StudyContentValidationFailure.emptySourceNotes,
      );
    }
    if (request.items.isEmpty) {
      return const StudyContentSourceResult.failure(
        StudyContentValidationFailure.emptyItems,
      );
    }

    final items = <StudyItemModel>[];
    for (final item in request.items) {
      final id = item.id.trim();
      final prompt = item.prompt.trim();
      final answer = item.answer.trim();
      if (id.isEmpty) {
        return const StudyContentSourceResult.failure(
          StudyContentValidationFailure.emptyItemId,
        );
      }
      if (prompt.isEmpty) {
        return const StudyContentSourceResult.failure(
          StudyContentValidationFailure.emptyPrompt,
        );
      }
      if (answer.isEmpty) {
        return const StudyContentSourceResult.failure(
          StudyContentValidationFailure.emptyAnswer,
        );
      }
      items.add(StudyItemModel(id: id, prompt: prompt, answer: answer));
    }

    return StudyContentSourceResult.content(
      StudyContentModel(
        format: request.format,
        sourceNotes: notes,
        items: List<StudyItemModel>.unmodifiable(items),
        sourceId: sourceId,
      ),
    );
  }
}
