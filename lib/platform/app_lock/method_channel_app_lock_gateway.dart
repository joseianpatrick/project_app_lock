import 'package:flutter/services.dart';
import 'package:project_app_lock/data/app_lock_capability.dart';
import 'package:project_app_lock/data/protected_app_model.dart';
import 'package:project_app_lock/platform/app_lock/installed_apps_gateway.dart';
import 'package:project_app_lock/platform/app_lock/system_app_lock_gateway.dart';

final class MethodChannelAppLockGateway
    implements SystemAppLockGateway, InstalledAppsGateway {
  const MethodChannelAppLockGateway({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.focuslock/app_lock';
  final MethodChannel _channel;

  @override
  Future<AppLockCapability> getCapability() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'getCapability',
    );
    return AppLockCapability.fromMap(result ?? const <Object?, Object?>{});
  }

  @override
  Future<List<ProtectedAppModel>> getInstalledApps() async {
    final result = await _channel.invokeListMethod<Object?>('getInstalledApps');
    return (result ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map(ProtectedAppModel.fromMap)
        .where((app) => app.packageId.isNotEmpty && app.displayName.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<AppLockCapability> requestAuthorization() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'requestAuthorization',
    );
    return AppLockCapability.fromMap(result ?? const <Object?, Object?>{});
  }

  @override
  Future<void> startLockSession({
    required List<String> packageIds,
    required DateTime endsAt,
  }) {
    return _channel.invokeMethod<void>('startLockSession', <String, Object?>{
      'packageIds': packageIds,
      'endsAt': endsAt.toUtc().toIso8601String(),
      'endsAtEpochMillis': endsAt.millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> stopLockSession() =>
      _channel.invokeMethod<void>('stopLockSession');
}
