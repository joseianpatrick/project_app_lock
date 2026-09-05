import 'package:project_app_lock/data/study_content_model.dart';

/// Input shared by all content sources, including a future AI generator.
final class StudyContentAuthoringRequest {
  const StudyContentAuthoringRequest({
    required this.format,
    required this.sourceNotes,
    required this.items,
  });

  final StudyFormat format;
  final String sourceNotes;
  final List<StudyItemModel> items;
}

enum StudyContentValidationFailure {
  emptySourceNotes,
  emptyItems,
  emptyItemId,
  emptyPrompt,
  emptyAnswer,
}

final class StudyContentSourceResult {
  const StudyContentSourceResult.content(this.content) : failure = null;

  const StudyContentSourceResult.failure(this.failure) : content = null;

  final StudyContentModel? content;
  final StudyContentValidationFailure? failure;

  bool get isSuccess => content != null;
}

abstract interface class StudyContentSource {
  Future<StudyContentSourceResult> create(StudyContentAuthoringRequest request);
}
