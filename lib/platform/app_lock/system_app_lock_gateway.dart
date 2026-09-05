import 'package:project_app_lock/data/app_lock_capability.dart';

/// Native enforcement scope for a persisted focus-lock session.
enum ExternalAppLockPolicy { selectedOnly, allEligible }

abstract interface class SystemAppLockGateway {
  Future<AppLockCapability> getCapability();

  Future<void> startLockSession({
    required List<String> packageIds,
    required DateTime endsAt,
    required ExternalAppLockPolicy policy,
  });

  Future<void> stopLockSession();
}
