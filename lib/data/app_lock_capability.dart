import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_lock_capability.freezed.dart';

@freezed
abstract class AppLockCapability with _$AppLockCapability {
  const factory AppLockCapability({
    required String platform,
    required bool isAvailable,
    required String reason,
    @Default(false) bool authorizationRequired,
  }) = _AppLockCapability;

  factory AppLockCapability.fromMap(Map<Object?, Object?> map) =>
      AppLockCapability(
        platform: map['platform'] as String? ?? 'unknown',
        isAvailable: map['isAvailable'] as bool? ?? false,
        reason: map['reason'] as String? ?? 'Capability status unavailable.',
        authorizationRequired: map['authorizationRequired'] as bool? ?? false,
      );
}
