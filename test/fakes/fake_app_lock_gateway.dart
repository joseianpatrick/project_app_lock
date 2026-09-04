import 'dart:async';

import 'package:project_app_lock/data/app_lock_capability.dart';
import 'package:project_app_lock/data/protected_app_model.dart';
import 'package:project_app_lock/platform/app_lock/installed_apps_gateway.dart';
import 'package:project_app_lock/platform/app_lock/system_app_lock_gateway.dart';

final class FakeAppLockGateway
    implements InstalledAppsGateway, SystemAppLockGateway {
  AppLockCapability capability = const AppLockCapability(
    platform: 'android',
    isAvailable: true,
    reason: 'Available',
  );
  List<ProtectedAppModel> apps = const <ProtectedAppModel>[];
  int startCalls = 0;
  int stopCalls = 0;
  bool failStart = false;
  bool failStop = false;
  Completer<void>? capabilityGate;
  Completer<void>? stopGate;
  List<String>? startedPackageIds;
  DateTime? startedEndsAt;

  @override
  Future<AppLockCapability> getCapability() async {
    final gate = capabilityGate;
    if (gate != null) await gate.future;
    return capability;
  }

  @override
  Future<List<ProtectedAppModel>> getInstalledApps() async => apps;

  @override
  Future<AppLockCapability> requestAuthorization() async => capability;

  @override
  Future<void> startLockSession({
    required List<String> packageIds,
    required DateTime endsAt,
  }) async {
    startCalls += 1;
    if (failStart) throw StateError('start failed');
    startedPackageIds = packageIds;
    startedEndsAt = endsAt;
  }

  @override
  Future<void> stopLockSession() async {
    stopCalls += 1;
    final gate = stopGate;
    if (gate != null) await gate.future;
    if (failStop) throw StateError('stop failed');
  }
}
