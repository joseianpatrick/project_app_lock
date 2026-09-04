import 'package:project_app_lock/data/repository/protected_app_selection_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class LocalProtectedAppSelectionRepository
    implements ProtectedAppSelectionRepository {
  LocalProtectedAppSelectionRepository(this._preferences);

  static const String _key = 'protected_app_package_ids';
  final SharedPreferences _preferences;

  @override
  Future<Set<String>> load() async =>
      (_preferences.getStringList(_key) ?? const <String>[]).toSet();

  @override
  Future<void> save(Set<String> packageIds) async {
    final values = packageIds.toList()..sort();
    final saved = await _preferences.setStringList(_key, values);
    if (!saved) throw StateError('Could not persist protected app selection.');
  }
}
