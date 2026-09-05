import 'package:freezed_annotation/freezed_annotation.dart';

part 'focus_behavior_settings_model.freezed.dart';

@freezed
abstract class FocusBehaviorSettingsModel with _$FocusBehaviorSettingsModel {
  const factory FocusBehaviorSettingsModel({
    required bool lockToTaskScreen,
    required bool allowOtherApps,
    required bool backButtonEnabled,
  }) = _FocusBehaviorSettingsModel;

  const FocusBehaviorSettingsModel._();

  factory FocusBehaviorSettingsModel.defaults() =>
      const FocusBehaviorSettingsModel(
        lockToTaskScreen: true,
        allowOtherApps: false,
        backButtonEnabled: false,
      );

  factory FocusBehaviorSettingsModel.fromMap(Map<String, dynamic> map) {
    final defaults = FocusBehaviorSettingsModel.defaults();
    return FocusBehaviorSettingsModel(
      lockToTaskScreen: map['lockToTaskScreen'] is bool
          ? map['lockToTaskScreen'] as bool
          : defaults.lockToTaskScreen,
      allowOtherApps: map['allowOtherApps'] is bool
          ? map['allowOtherApps'] as bool
          : defaults.allowOtherApps,
      backButtonEnabled: map['backButtonEnabled'] is bool
          ? map['backButtonEnabled'] as bool
          : defaults.backButtonEnabled,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'lockToTaskScreen': lockToTaskScreen,
    'allowOtherApps': allowOtherApps,
    'backButtonEnabled': backButtonEnabled,
  };
}

@freezed
abstract class FocusSessionPolicyModel with _$FocusSessionPolicyModel {
  const factory FocusSessionPolicyModel({
    required bool lockToTaskScreen,
    required bool allowOtherApps,
    required bool backButtonEnabled,
  }) = _FocusSessionPolicyModel;

  const FocusSessionPolicyModel._();

  factory FocusSessionPolicyModel.fromSettings(
    FocusBehaviorSettingsModel settings,
  ) => FocusSessionPolicyModel(
    lockToTaskScreen: settings.lockToTaskScreen,
    allowOtherApps: settings.allowOtherApps,
    backButtonEnabled: settings.backButtonEnabled,
  );

  factory FocusSessionPolicyModel.fromMap(Map<String, dynamic> map) {
    final defaults = FocusBehaviorSettingsModel.defaults();
    return FocusSessionPolicyModel(
      lockToTaskScreen: map['lockToTaskScreen'] is bool
          ? map['lockToTaskScreen'] as bool
          : defaults.lockToTaskScreen,
      allowOtherApps: map['allowOtherApps'] is bool
          ? map['allowOtherApps'] as bool
          : defaults.allowOtherApps,
      backButtonEnabled: map['backButtonEnabled'] is bool
          ? map['backButtonEnabled'] as bool
          : defaults.backButtonEnabled,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'lockToTaskScreen': lockToTaskScreen,
    'allowOtherApps': allowOtherApps,
    'backButtonEnabled': backButtonEnabled,
  };
}
