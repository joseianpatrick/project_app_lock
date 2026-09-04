import 'package:freezed_annotation/freezed_annotation.dart';

part 'lock_session_model.freezed.dart';

enum LockSessionState { scheduled, active, completed, cancelled, unlockPending }

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
      );

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'taskId': taskId,
    'taskTitle': taskTitle,
    'packageIds': packageIds,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endsAt': endsAt.toUtc().toIso8601String(),
    'state': state.name,
  };
}
