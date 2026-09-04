import 'package:freezed_annotation/freezed_annotation.dart';

part 'protected_app_model.freezed.dart';

@freezed
abstract class ProtectedAppModel with _$ProtectedAppModel {
  const factory ProtectedAppModel({
    required String packageId,
    required String displayName,
    String? iconBase64,
  }) = _ProtectedAppModel;

  factory ProtectedAppModel.fromMap(Map<Object?, Object?> map) =>
      ProtectedAppModel(
        packageId: map['packageId'] as String? ?? '',
        displayName: map['displayName'] as String? ?? '',
        iconBase64: map['iconBase64'] as String?,
      );
}
