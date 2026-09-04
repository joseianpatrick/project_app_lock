import 'package:project_app_lock/data/app_lock_capability.dart';
import 'package:project_app_lock/data/protected_app_model.dart';

abstract interface class InstalledAppsGateway {
  Future<AppLockCapability> getCapability();

  Future<AppLockCapability> requestAuthorization();

  Future<List<ProtectedAppModel>> getInstalledApps();
}
