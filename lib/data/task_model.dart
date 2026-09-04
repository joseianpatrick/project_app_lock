import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_model.freezed.dart';

@freezed
abstract class TaskModel with _$TaskModel {
  factory TaskModel({
    required String id,
    required String title,
    required int durationMinutes,
    required DateTime createdAt,
    DateTime? completedAt,
  }) = _TaskModel;

  TaskModel._();

  bool get isCompleted => completedAt != null;

  factory TaskModel.fromMap(Map<String, dynamic> map) => TaskModel(
    id: map['id'] as String? ?? '',
    title: map['title'] as String? ?? '',
    durationMinutes: map['durationMinutes'] as int? ?? 25,
    createdAt:
        DateTime.tryParse(map['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    completedAt: DateTime.tryParse(map['completedAt'] as String? ?? ''),
  );

  factory TaskModel.empty() => TaskModel(
    id: '',
    title: '',
    durationMinutes: 25,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'title': title,
    'durationMinutes': durationMinutes,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'completedAt': completedAt?.toUtc().toIso8601String(),
  };
}
