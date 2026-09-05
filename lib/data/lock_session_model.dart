import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:project_app_lock/data/focus_behavior_settings_model.dart';
import 'package:project_app_lock/data/study_content_model.dart';

part 'lock_session_model.freezed.dart';

enum LockSessionState { scheduled, active, completed, cancelled, unlockPending }

enum StudyAssessment { correct, needsReview }

@freezed
abstract class SessionStudyContentModel with _$SessionStudyContentModel {
  const factory SessionStudyContentModel({
    required StudyFormat format,
    required List<StudyItemModel> items,
  }) = _SessionStudyContentModel;

  const SessionStudyContentModel._();

  factory SessionStudyContentModel.fromStudyContent(
    StudyContentModel content,
  ) => SessionStudyContentModel(format: content.format, items: content.items);

  static SessionStudyContentModel? tryFromMap(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final format = StudyFormat.values.cast<StudyFormat?>().firstWhere(
      (candidate) => candidate?.name == map['format'],
      orElse: () => null,
    );
    final values = map['items'];
    if (format == null || values is! List || values.isEmpty) return null;
    final items = <StudyItemModel>[];
    for (final value in values) {
      if (value is! Map) return null;
      final item = StudyItemModel.fromMap(Map<String, dynamic>.from(value));
      if (item.id.isEmpty || item.prompt.isEmpty || item.answer.isEmpty) {
        return null;
      }
      items.add(item);
    }
    return SessionStudyContentModel(
      format: format,
      items: List<StudyItemModel>.unmodifiable(items),
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'format': format.name,
    'items': items.map((item) => item.toMap()).toList(growable: false),
  };
}

@freezed
abstract class StudyResponseModel with _$StudyResponseModel {
  const factory StudyResponseModel({
    required String itemId,
    required String response,
    required bool isRevealed,
    StudyAssessment? assessment,
  }) = _StudyResponseModel;

  const StudyResponseModel._();

  factory StudyResponseModel.fromMap(Map<String, dynamic> map) =>
      StudyResponseModel(
        itemId: map['itemId'] as String? ?? '',
        response: map['response'] as String? ?? '',
        isRevealed: map['isRevealed'] as bool? ?? false,
        assessment: StudyAssessment.values.cast<StudyAssessment?>().firstWhere(
          (candidate) => candidate?.name == map['assessment'],
          orElse: () => null,
        ),
      );

  Map<String, Object?> toMap() => <String, Object?>{
    'itemId': itemId,
    'response': response,
    'isRevealed': isRevealed,
    if (assessment != null) 'assessment': assessment!.name,
  };
}

@freezed
abstract class StudyProgressModel with _$StudyProgressModel {
  const factory StudyProgressModel({
    required int currentItemIndex,
    required List<StudyResponseModel> responses,
  }) = _StudyProgressModel;

  const StudyProgressModel._();

  factory StudyProgressModel.empty() =>
      const StudyProgressModel(currentItemIndex: 0, responses: []);

  factory StudyProgressModel.fromMap(Map<String, dynamic> map) {
    final responseValues = map['responses'];
    final responses = responseValues is List
        ? responseValues
              .whereType<Map>()
              .map(
                (value) => StudyResponseModel.fromMap(
                  Map<String, dynamic>.from(value),
                ),
              )
              .where((response) => response.itemId.isNotEmpty)
              .toList(growable: false)
        : const <StudyResponseModel>[];
    return StudyProgressModel(
      currentItemIndex: (map['currentItemIndex'] as int? ?? 0).clamp(
        0,
        1 << 31,
      ),
      responses: responses,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'currentItemIndex': currentItemIndex,
    'responses': responses.map((response) => response.toMap()).toList(),
  };
}

@freezed
abstract class LockSessionModel with _$LockSessionModel {
  const factory LockSessionModel({
    required String id,
    required String taskId,
    required String taskTitle,
    required List<String> packageIds,
    required DateTime startedAt,
    required DateTime endsAt,
    required LockSessionState state,
    int? durationMinutes,
    FocusSessionPolicyModel? policy,
    SessionStudyContentModel? studyContent,
    StudyProgressModel? studyProgress,
  }) = _LockSessionModel;

  const LockSessionModel._();

  factory LockSessionModel.fromMap(Map<String, dynamic> map) =>
      LockSessionModel(
        id: map['id'] as String? ?? '',
        taskId: map['taskId'] as String? ?? '',
        taskTitle: map['taskTitle'] as String? ?? '',
        packageIds: (map['packageIds'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .toList(growable: false),
        startedAt:
            DateTime.tryParse(map['startedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        endsAt:
            DateTime.tryParse(map['endsAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        state: LockSessionState.values.firstWhere(
          (value) => value.name == map['state'],
          orElse: () => LockSessionState.cancelled,
        ),
        durationMinutes: map['durationMinutes'] as int?,
        policy: map['policy'] is Map
            ? FocusSessionPolicyModel.fromMap(
                Map<String, dynamic>.from(map['policy'] as Map),
              )
            : null,
        studyContent: SessionStudyContentModel.tryFromMap(map['studyContent']),
        studyProgress: map['studyProgress'] is Map
            ? StudyProgressModel.fromMap(
                Map<String, dynamic>.from(map['studyProgress'] as Map),
              )
            : null,
      );

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'taskId': taskId,
    'taskTitle': taskTitle,
    'packageIds': packageIds,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endsAt': endsAt.toUtc().toIso8601String(),
    'state': state.name,
    if (durationMinutes != null) 'durationMinutes': durationMinutes,
    if (policy != null) 'policy': policy!.toMap(),
    if (studyContent != null) 'studyContent': studyContent!.toMap(),
    if (studyProgress != null) 'studyProgress': studyProgress!.toMap(),
  };
}
