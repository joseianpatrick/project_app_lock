import 'package:freezed_annotation/freezed_annotation.dart';

part 'study_content_model.freezed.dart';

enum StudyFormat { quiz, flashcards }

@freezed
abstract class StudyItemModel with _$StudyItemModel {
  const factory StudyItemModel({
    required String id,
    required String prompt,
    required String answer,
  }) = _StudyItemModel;

  const StudyItemModel._();

  factory StudyItemModel.fromMap(Map<String, dynamic> map) => StudyItemModel(
    id: map['id'] as String? ?? '',
    prompt: map['prompt'] as String? ?? '',
    answer: map['answer'] as String? ?? '',
  );

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'prompt': prompt,
    'answer': answer,
  };
}

@freezed
abstract class StudyContentModel with _$StudyContentModel {
  const factory StudyContentModel({
    required StudyFormat format,
    required String sourceNotes,
    required List<StudyItemModel> items,
    required String sourceId,
  }) = _StudyContentModel;

  const StudyContentModel._();

  /// Returns null for incomplete or malformed persisted content. Callers can
  /// then treat the owning task as a legacy task that needs an upgrade.
  static StudyContentModel? tryFromMap(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final format = StudyFormat.values.cast<StudyFormat?>().firstWhere(
      (candidate) => candidate?.name == map['format'],
      orElse: () => null,
    );
    final notes = map['sourceNotes'];
    final sourceId = map['sourceId'];
    final itemValues = map['items'];
    if (format == null ||
        notes is! String ||
        sourceId is! String ||
        itemValues is! List) {
      return null;
    }
    final items = <StudyItemModel>[];
    for (final value in itemValues) {
      if (value is! Map) return null;
      final item = StudyItemModel.fromMap(Map<String, dynamic>.from(value));
      if (item.id.isEmpty || item.prompt.isEmpty || item.answer.isEmpty) {
        return null;
      }
      items.add(item);
    }
    if (notes.isEmpty || sourceId.isEmpty || items.isEmpty) return null;
    return StudyContentModel(
      format: format,
      sourceNotes: notes,
      items: List<StudyItemModel>.unmodifiable(items),
      sourceId: sourceId,
    );
  }

  factory StudyContentModel.fromMap(Map<String, dynamic> map) =>
      tryFromMap(map) ??
      (throw const FormatException('Invalid study content.'));

  Map<String, Object?> toMap() => <String, Object?>{
    'format': format.name,
    'sourceNotes': sourceNotes,
    'items': items.map((item) => item.toMap()).toList(growable: false),
    'sourceId': sourceId,
  };
}
