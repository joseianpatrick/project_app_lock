import 'package:project_app_lock/data/app_lock_capability.dart';

abstract interface class SystemAppLockGateway {
  Future<AppLockCapability> getCapability();

  Future<void> startLockSession({
    required List<String> packageIds,
    required DateTime endsAt,
  });

  Future<void> stopLockSession();
}
